//
//  MockBackendEdgeTests.swift
//  ChaosBankTests
//
//  Branch coverage for the backend: sells, deposits, and every error path.
//

import XCTest
@testable import ChaosBank

final class MockBackendEdgeTests: XCTestCase {

    private func backend(_ s: BackendScenario = BackendScenario()) -> MockBackend {
        MockBackend(latency: .milliseconds(1), scenario: s)
    }

    func testSellReducesHoldingAndCreditsCash() async throws {
        let b = backend()
        let cashBefore = await b.fetchAccount(.USD)!.balance
        let order = Order(id: "s", symbol: "TSLA", side: .sell, type: .market, quantity: 2,
                          limitPrice: nil, referencePrice: 250, executionPrice: 250,
                          status: .pending, placedAt: Date())
        let filled = try await b.placeOrder(order)
        XCTAssertEqual(filled.status, .filled)
        let cashAfter = await b.fetchAccount(.USD)!.balance
        XCTAssertEqual(cashAfter - cashBefore, 500)
        let tsla = await b.fetchHoldings().first { $0.symbol == "TSLA" }
        XCTAssertEqual(tsla?.quantity, 6) // 8 seed - 2
    }

    func testSellEntireHoldingRemovesIt() async throws {
        let b = backend()
        let order = Order(id: "s", symbol: "ETH", side: .sell, type: .market, quantity: Decimal(string: "3.5")!,
                          limitPrice: nil, referencePrice: 3000, executionPrice: 3000,
                          status: .pending, placedAt: Date())
        _ = try await b.placeOrder(order)
        let eth = await b.fetchHoldings().first { $0.symbol == "ETH" }
        XCTAssertNil(eth)
    }

    func testSellInsufficientHolding() async {
        let b = backend()
        let order = Order(id: "s", symbol: "AAPL", side: .sell, type: .market, quantity: 9999,
                          limitPrice: nil, referencePrice: 190, executionPrice: 190,
                          status: .pending, placedAt: Date())
        await assertThrows(BackendError.insufficientHolding) { try await b.placeOrder(order) }
    }

    func testOrderUnknownAssetAndInvalidQty() async {
        let b = backend()
        let unknown = Order(id: "u", symbol: "ZZZZ", side: .buy, type: .market, quantity: 1,
                            limitPrice: nil, referencePrice: 1, executionPrice: 1, status: .pending, placedAt: Date())
        await assertThrows(BackendError.unknownAsset) { try await b.placeOrder(unknown) }

        let zeroQty = Order(id: "z", symbol: "AAPL", side: .buy, type: .market, quantity: 0,
                            limitPrice: nil, referencePrice: 190, executionPrice: 190, status: .pending, placedAt: Date())
        await assertThrows(BackendError.invalidAmount) { try await b.placeOrder(zeroQty) }
    }

    func testBuyInsufficientFunds() async {
        let b = backend()
        let order = Order(id: "b", symbol: "BTC", side: .buy, type: .market, quantity: 100,
                          limitPrice: nil, referencePrice: 64000, executionPrice: 64000,
                          status: .pending, placedAt: Date())
        await assertThrows(BackendError.insufficientFunds) { try await b.placeOrder(order) }
    }

    func testDepositCredits() async throws {
        let b = backend()
        let before = await b.fetchAccount(.EUR)!.balance
        try await b.deposit(to: .EUR, amount: 250)
        let after = await b.fetchAccount(.EUR)!.balance
        XCTAssertEqual(after - before, 250)
    }

    func testDepositInvalidAmount() async {
        let b = backend()
        await assertThrows(BackendError.invalidAmount) { try await b.deposit(to: .EUR, amount: 0) }
    }

    func testExchangeInvalidAndInsufficient() async {
        let b = backend()
        await assertThrows(BackendError.invalidAmount) {
            try await b.exchange(sell: .EUR, get: .USD, debit: 0, credited: 0)
        }
        await assertThrows(BackendError.insufficientFunds) {
            try await b.exchange(sell: .EUR, get: .USD, debit: 9_999_999, credited: 1)
        }
    }

    func testTransferInvalidAmount() async {
        let b = backend()
        await assertThrows(BackendError.invalidAmount) {
            try await b.transfer(from: .EUR, amount: 0, recipient: "A", note: "", idempotencyKey: "k")
        }
    }

    func testFetchOrdersAndExtraDelayRead() async throws {
        let b = backend()
        _ = try await b.transfer(from: .EUR, amount: 10, recipient: "A", note: "", idempotencyKey: "k")
        let order = Order(id: "o", symbol: "AAPL", side: .buy, type: .market, quantity: 1,
                          limitPrice: nil, referencePrice: 190, executionPrice: 190, status: .pending, placedAt: Date())
        _ = try await b.placeOrder(order)
        let orders = await b.fetchOrders()
        XCTAssertEqual(orders.count, 1)
        let delayed = await b.fetchAccount(.USD, extraDelay: .milliseconds(1))
        XCTAssertNotNil(delayed)
    }

    // MARK: helper

    private func assertThrows<T>(_ expected: BackendError, _ block: () async throws -> T,
                                 file: StaticString = #filePath, line: UInt = #line) async {
        do { _ = try await block(); XCTFail("expected \(expected)", file: file, line: line) }
        catch { XCTAssertEqual(error as? BackendError, expected, file: file, line: line) }
    }
}
