//
//  PortfolioViewModelTests.swift
//  ChaosBankTests
//

import XCTest
@testable import ChaosBank

@MainActor
final class PortfolioViewModelTests: XCTestCase {

    override func tearDown() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        super.tearDown()
    }

    private func vm(_ defects: Set<DefectID> = []) async -> PortfolioViewModel {
        let config = BuildConfig(seed: 0, activeDefects: defects, label: "t")
        Defects.configure(config)
        let m = PortfolioViewModel(services: AppServices(config: config))
        await m.load()
        return m
    }

    func testTotalsAreConsistent() async {
        let m = await vm()
        XCTAssertGreaterThan(m.totalValue.amount, 0)
        XCTAssertEqual(m.totalCost, SeedData.holdings.reduce(Decimal(0)) { $0 + $1.costBasis })
        // total P&L == sum of per-holding P&L
        let perHolding = m.holdings.reduce(Decimal(0)) { $0 + m.pnl($1) }
        XCTAssertEqual(m.totalPnL, perHolding)
    }

    func testPnlPercentAgainstCost() async {
        let m = await vm()
        XCTAssertEqual(m.totalPnLPercent, m.totalPnL / m.totalCost * 100)
    }

    func testPnlPercentVsValueDefect() async {
        let m = await vm([.pnlPercentVsValue])
        XCTAssertEqual(m.totalPnLPercent, m.totalPnL / m.totalValue.amount * 100)
    }

    func testPnlPercentAbsOnlyDefect() async {
        let m = await vm([.pnlPercentAbsOnly])
        XCTAssertGreaterThanOrEqual(m.totalPnLPercent, 0)
    }

    func testHoldingValueUsesCostDefect() async {
        let m = await vm([.holdingValueUsesCost])
        guard let tsla = m.holdings.first(where: { $0.symbol == "TSLA" }) else { return XCTFail() }
        XCTAssertEqual(m.marketValue(tsla).amount, tsla.costBasis)
    }

    func testTotalValueOmitsHoldingDefect() async {
        let full = await vm()
        let fullTotal = full.totalValue.amount   // capture while the clean config is active
        let omitted = await vm([.totalValueOmitsHolding])
        XCTAssertLessThan(omitted.totalValue.amount, fullTotal)
    }

    func testDisplayPnlSignDefect() async {
        let m = await vm([.pnlSign])
        guard let tsla = m.holdings.first(where: { $0.symbol == "TSLA" }) else { return XCTFail() }
        XCTAssertLessThan(m.pnl(tsla), 0)
        XCTAssertGreaterThan(m.displayPnL(m.pnl(tsla)), 0)
    }

    func testAllocationFractionsSumToOne() async {
        let m = await vm()
        let sum = m.holdings.reduce(0.0) { $0 + m.allocationFraction($1) }
        XCTAssertEqual(sum, 1.0, accuracy: 0.0001)
    }
}
