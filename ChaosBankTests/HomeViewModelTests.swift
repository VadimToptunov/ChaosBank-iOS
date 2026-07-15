//
//  HomeViewModelTests.swift
//  ChaosBankTests
//

import XCTest
@testable import ChaosBank

@MainActor
final class HomeViewModelTests: XCTestCase {

    override func tearDown() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        super.tearDown()
    }

    private func make(_ defects: Set<DefectID> = []) async -> (HomeViewModel, AppServices) {
        let config = BuildConfig(seed: 0, activeDefects: defects, label: "t")
        Defects.configure(config)
        let s = AppServices(config: config)
        let m = HomeViewModel(services: s)
        await m.load()
        return (m, s)
    }

    private func eurBalance(_ m: HomeViewModel) -> Decimal {
        m.accounts.first { $0.currency == .EUR }?.balance ?? 0
    }

    func testLoadPopulates() async {
        let (m, _) = await make()
        XCTAssertEqual(m.accounts.count, 3)
        XCTAssertEqual(m.recent.count, 4)
    }

    func testRecentActivityShowsTwoDefect() async {
        let (m, _) = await make([.recentActivityShowsTwo])
        XCTAssertEqual(m.recent.count, 2)
    }

    func testRefreshAfterMutationReloads() async {
        let (m, s) = await make()
        let before = eurBalance(m)
        try? await s.backend.transfer(from: .EUR, amount: 100, recipient: "A", note: "", idempotencyKey: "k")
        await m.refreshAfterMutation()
        XCTAssertEqual(eurBalance(m), before - 100)
    }

    func testStaleBalanceDefectSkipsRefresh() async {
        let (m, s) = await make([.staleBalance])
        let before = eurBalance(m)
        try? await s.backend.transfer(from: .EUR, amount: 100, recipient: "A", note: "", idempotencyKey: "k")
        await m.refreshAfterMutation()
        XCTAssertEqual(eurBalance(m), before, "dashboard keeps the pre-transfer balance")
    }

    func testCurrencySwitchChangesTotal() async {
        let (m, _) = await make()
        m.selectedCurrency = .EUR
        let inEUR = m.totalBalance.amount
        m.selectedCurrency = .USD
        let inUSD = m.totalBalance.amount
        XCTAssertNotEqual(inEUR, inUSD)
        XCTAssertTrue(m.totalBalanceText.hasPrefix("$"))
    }

    func testWrongCurrencySymbolDefect() async {
        let (m, _) = await make([.balanceWrongCurrencySymbol])
        m.selectedCurrency = .USD
        XCTAssertTrue(m.totalBalanceText.hasPrefix("€"))
    }

    func testTodayChangeSignFlippedDefect() async {
        let (clean, _) = await make()
        XCTAssertGreaterThanOrEqual(clean.todayChange.amount, 0)
        let (buggy, _) = await make([.todayChangeSignFlipped])
        XCTAssertLessThan(buggy.todayChange.amount, 0)
    }

    func testBalanceFloorRoundedDefect() async {
        let (m, _) = await make([.balanceFloorRounded])
        let amount = m.totalBalance.amount
        XCTAssertEqual(amount, amount.rounded(scale: 0), "floored to a whole unit")
    }

    func testAccountStripHidesGbpIsAppState() async {
        // GBP still present in the model; the defect only hides it in the view layer.
        let (m, _) = await make([.accountStripHidesGBP])
        XCTAssertTrue(m.accounts.contains { $0.currency == .GBP })
    }
}
