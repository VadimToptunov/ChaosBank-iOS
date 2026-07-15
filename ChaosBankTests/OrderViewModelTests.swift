//
//  OrderViewModelTests.swift
//  ChaosBankTests
//

import XCTest
@testable import ChaosBank

@MainActor
final class OrderViewModelTests: XCTestCase {

    override func tearDown() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        super.tearDown()
    }

    private func services(_ defects: Set<DefectID> = []) -> AppServices {
        let config = BuildConfig(seed: 0, activeDefects: defects, label: "t")
        Defects.configure(config)
        return AppServices(config: config)
    }

    private func vm(_ side: OrderSide = .buy, symbol: String = "AAPL", price: Decimal = 190,
                    defects: Set<DefectID> = []) -> OrderViewModel {
        OrderViewModel(request: OrderRequest(symbol: symbol, side: side, capturedPrice: price),
                       services: services(defects))
    }

    func testMarketExecutionPriceIsReference() {
        let m = vm()
        XCTAssertEqual(m.executionPrice, 190)
        m.quantity = 3
        XCTAssertEqual(m.estTotal.amount, 570)
    }

    func testLimitExecutionPrice() {
        let m = vm()
        m.type = .limit
        m.limitPriceText = "200"
        XCTAssertEqual(m.executionPrice, 200)
    }

    func testLimitExecutesAtMarketDefect() {
        let m = vm(defects: [.limitExecutesAtMarket])
        m.type = .limit
        m.limitPriceText = "200"
        XCTAssertEqual(m.executionPrice, 190)
    }

    func testEstTotalIgnoresQtyDefect() {
        let m = vm(defects: [.estTotalIgnoresQty])
        m.quantity = 5
        XCTAssertEqual(m.estTotal.amount, 190)
    }

    func testStepper() {
        let m = vm()
        m.quantity = 1
        m.increment(); XCTAssertEqual(m.quantity, 2)
        m.decrement(); m.decrement(); m.decrement()
        XCTAssertEqual(m.quantity, 0, "clamps at zero")
    }

    func testQtyIncrementByTwoDefect() {
        let m = vm(defects: [.qtyIncrementByTwo])
        m.quantity = 1
        m.increment()
        XCTAssertEqual(m.quantity, 3)
    }

    func testValidityRequiresPositiveQty() {
        let m = vm()
        m.quantity = 0
        XCTAssertFalse(m.isValid)
        m.quantity = 1
        XCTAssertTrue(m.isValid)
    }

    func testOrderQtyDefaultsZeroDefect() {
        let m = vm(defects: [.orderQtyDefaultsZero])
        XCTAssertEqual(m.quantity, 0)
        XCTAssertFalse(m.isValid)
    }

    func testSellWithoutHoldingReviewable() async {
        let clean = vm(.sell, symbol: "MSFT")   // no MSFT holding
        await clean.load()
        clean.quantity = 1
        XCTAssertFalse(clean.isValid, "cannot sell what you don't hold")

        let buggy = vm(.sell, symbol: "MSFT", defects: [.sellWithoutHoldingReviewable])
        await buggy.load()
        buggy.quantity = 1
        XCTAssertTrue(buggy.isValid)
    }

    func testLimitBelowMarketWarns() {
        let m = vm(.sell)
        m.type = .limit
        m.limitPriceText = "100"   // below market 190
        XCTAssertTrue(m.showWarning)

        let buggy = vm(.sell, defects: [.limitValidation])
        buggy.type = .limit
        buggy.limitPriceText = "100"
        XCTAssertFalse(buggy.showWarning)
    }

    func testPlaceMarketBuyFills() async {
        let m = vm()
        m.quantity = 1
        await m.place()
        XCTAssertTrue(m.placed)
        XCTAssertEqual(m.status, .filled)
    }

    func testOrderStuckPendingDefect() async {
        let m = vm(defects: [.orderStuckPending])
        m.quantity = 1
        await m.place()
        XCTAssertTrue(m.placed)
        XCTAssertEqual(m.status, .pending)
    }
}
