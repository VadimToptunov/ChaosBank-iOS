//
//  ExchangeViewModelTests.swift
//  ChaosBankTests
//

import XCTest
@testable import ChaosBank

@MainActor
final class ExchangeViewModelTests: XCTestCase {

    override func tearDown() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        super.tearDown()
    }

    private func make(_ defects: Set<DefectID> = []) async -> (ExchangeViewModel, AppServices) {
        let config = BuildConfig(seed: 0, activeDefects: defects, label: "t")
        Defects.configure(config)
        let services = AppServices(config: config)
        let m = ExchangeViewModel(services: services)
        await m.load()
        return (m, services)
    }

    func testRateAndYouGet() async {
        let (m, _) = await make()
        m.sell = .EUR; m.get = .USD; m.amountText = "100"
        XCTAssertEqual(m.rate, FXRates.rate(from: .EUR, to: .USD))
        let net = Decimal(100) - Decimal(100) * FXRates.feeRate
        XCTAssertEqual(m.youGet.amount, (net * m.rate).roundedMoney())
    }

    func testInverseRateDefect() async {
        let (m, _) = await make([.exchangeInverseRate])
        m.sell = .EUR; m.get = .USD
        XCTAssertEqual(m.rate, FXRates.rate(from: .USD, to: .EUR))
    }

    func testYouGetShowsGrossDefect() async {
        let (clean, _) = await make()
        clean.sell = .EUR; clean.get = .USD; clean.amountText = "100"
        let cleanYouGet = clean.youGet.amount   // capture while the clean config is active
        let (buggy, _) = await make([.youGetShowsGross])
        buggy.sell = .EUR; buggy.get = .USD; buggy.amountText = "100"
        XCTAssertGreaterThan(buggy.youGet.amount, cleanYouGet, "gross omits the fee")
    }

    func testSameCurrencyValidation() async {
        let (clean, _) = await make()
        clean.sell = .EUR; clean.get = .EUR; clean.amountText = "100"
        XCTAssertFalse(clean.canExecute)

        let (buggy, _) = await make([.exchangeSameCurrencyAllowed])
        buggy.sell = .EUR; buggy.get = .EUR; buggy.amountText = "100"
        XCTAssertTrue(buggy.canExecute)
    }

    func testExecuteDebits() async {
        let (m, _) = await make()
        m.sell = .EUR; m.get = .USD; m.amountText = "100"
        let eurBefore = m.sellBalance
        await m.execute()
        XCTAssertTrue(m.succeeded)
        XCTAssertEqual(m.sellBalance, eurBefore - 100)
    }

    func testFeeNotAppliedCreditsGross() async {
        let (m, services) = await make([.exchangeFeeNotApplied])
        m.sell = .EUR; m.get = .USD; m.amountText = "100"
        let usdBefore = await services.backend.fetchAccount(.USD)?.balance ?? 0
        await m.execute()
        let usdAfter = await services.backend.fetchAccount(.USD)?.balance ?? 0
        let gross = (Decimal(100) * FXRates.rate(from: .EUR, to: .USD)).roundedMoney()
        XCTAssertEqual(usdAfter - usdBefore, gross)
    }
}
