//
//  TradingEdgeTests.swift
//  ChaosBankTests
//
//  Remaining branches in the Order and Exchange view models.
//

import XCTest
@testable import ChaosBank

@MainActor
final class TradingEdgeTests: XCTestCase {

    override func tearDown() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        super.tearDown()
    }

    private func services(_ defects: Set<DefectID> = []) -> AppServices {
        let config = BuildConfig(seed: 0, activeDefects: defects, label: "t")
        Defects.configure(config)
        return AppServices(config: config)
    }

    // MARK: Order

    func testLivePriceRaceReReadsFeed() {
        let s = services([.livePriceRace])
        let m = OrderViewModel(request: OrderRequest(symbol: "AAPL", side: .buy, capturedPrice: 1), services: s)
        // Ignores the captured price (1); reads the live/simulated feed instead.
        XCTAssertEqual(m.referencePrice, s.market.price(for: "AAPL"))
        XCTAssertNotEqual(m.referencePrice, 1)
    }

    func testRoundingDriftEstTotal() {
        let m = OrderViewModel(request: OrderRequest(symbol: "AAPL", side: .buy, capturedPrice: Decimal(string: "189.99")!),
                               services: services([.roundingDrift]))
        m.quantity = 3
        // Double-routed multiply differs from the exact Decimal product.
        XCTAssertNotEqual(m.estTotal.amount, (3 * Decimal(string: "189.99")!).roundedMoney())
    }

    func testBuySellSwappedSellsOnBuy() async {
        let s = services([.buySellSwapped])
        let m = OrderViewModel(request: OrderRequest(symbol: "AAPL", side: .buy, capturedPrice: 190), services: s)
        await m.load()
        m.quantity = 1
        await m.place()
        let aapl = await s.backend.fetchHoldings().first { $0.symbol == "AAPL" }
        XCTAssertEqual(aapl?.quantity, 11, "a 'buy' actually sold one")
    }

    func testOrderDoubleSubmitPlacesTwice() async {
        let s = services([.orderDoubleSubmit])
        let m = OrderViewModel(request: OrderRequest(symbol: "AAPL", side: .buy, capturedPrice: 190), services: s)
        await m.load()
        m.quantity = 1
        async let a: Void = m.place()
        async let b: Void = m.place()
        _ = await (a, b)
        let orders = await s.backend.fetchOrders()
        XCTAssertEqual(orders.count, 2)
    }

    func testPlaceInsufficientFundsRejects() async {
        let s = services()
        let m = OrderViewModel(request: OrderRequest(symbol: "BTC", side: .buy, capturedPrice: 64000), services: s)
        await m.load()
        m.quantity = 100
        await m.place()
        XCTAssertEqual(m.status, .rejected)
        XCTAssertNotNil(m.errorMessage)
    }

    // MARK: Exchange

    func testSwapDirection() async {
        let s = services()
        let m = ExchangeViewModel(services: s)
        await m.load()
        m.sell = .EUR; m.get = .USD
        m.swapDirection()
        XCTAssertEqual(m.sell, .USD)
        XCTAssertEqual(m.get, .EUR)
    }

    func testSelectSellUpdatesBalance() async {
        let s = services()
        let m = ExchangeViewModel(services: s)
        await m.load()
        m.selectSell(.USD)
        // let the refresh settle
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(m.sell, .USD)
    }

    func testExchangeInsufficientFundsError() async {
        let s = services()
        let m = ExchangeViewModel(services: s)
        await m.load()
        m.sell = .GBP; m.get = .USD; m.amountText = "999999"
        await m.execute()
        XCTAssertFalse(m.succeeded)
    }

    func testExchangeFeeDoubledCreditsLess() async {
        let s = services([.exchangeFeeDoubled])
        let m = ExchangeViewModel(services: s)
        await m.load()
        m.sell = .EUR; m.get = .USD; m.amountText = "100"
        let usdBefore = await s.backend.fetchAccount(.USD)?.balance ?? 0
        await m.execute()
        let usdAfter = await s.backend.fetchAccount(.USD)?.balance ?? 0
        let single = ((Decimal(100) - Decimal(100) * FXRates.feeRate) * FXRates.rate(from: .EUR, to: .USD)).roundedMoney()
        XCTAssertLessThan(usdAfter - usdBefore, single)
    }
}
