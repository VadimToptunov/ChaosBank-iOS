//
//  MockBackendTests.swift
//  ChaosBankTests
//
//  The backend is the authoritative, always-correct money layer. These tests pin
//  the clean behavior and the network scenarios (which power several defects).
//

import XCTest
@testable import ChaosBank

final class MockBackendTests: XCTestCase {

    private func backend(_ scenario: BackendScenario = BackendScenario()) -> MockBackend {
        MockBackend(latency: .milliseconds(1), scenario: scenario)
    }

    func testOfflineWritesThrowOffline() async {
        let b = backend()
        await b.setOffline(true)
        do {
            try await b.transfer(from: .EUR, amount: Decimal(10), recipient: "A", note: "", idempotencyKey: "k")
            XCTFail("offline write should throw")
        } catch let error as BackendError {
            XCTAssertEqual(error, .offline)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testOfflineReadsStillServeCachedData() async {
        let b = backend()
        await b.setOffline(true)
        let accounts = await b.fetchAccounts()
        XCTAssertEqual(accounts.count, 3)
    }

    func testBackOnlineRestoresWrites() async throws {
        let b = backend()
        await b.setOffline(true)
        await b.setOffline(false)
        let tx = try await b.transfer(from: .EUR, amount: Decimal(10), recipient: "A", note: "", idempotencyKey: "k")
        XCTAssertEqual(tx.amount, Decimal(-10))
    }

    func testFlakyConditionFailsSomeWrites() async {
        let b = backend()
        await b.setCondition(.flaky)
        var ok = 0, failed = 0
        for _ in 0..<12 {
            do { _ = try await b.deposit(to: .EUR, amount: Decimal(1)); ok += 1 }
            catch { failed += 1 }
        }
        XCTAssertGreaterThan(failed, 0, "expected some failures under flaky")
        XCTAssertGreaterThan(ok, 0, "expected some successes under flaky")
    }

    func testNormalConditionNeverFails() async throws {
        let b = backend()
        await b.setCondition(.normal)
        for _ in 0..<12 { _ = try await b.deposit(to: .EUR, amount: Decimal(1)) }
    }

    func testNetworkConditionFromParsesNames() {
        XCTAssertEqual(NetworkCondition.from("slow"), .slow)
        XCTAssertEqual(NetworkCondition.from("OFFLINE"), .offline)
        XCTAssertEqual(NetworkCondition.from(nil), .normal)
        XCTAssertEqual(NetworkCondition.from("nope"), .normal)
    }

    func testNetworkConditionTitles() {
        XCTAssertEqual(NetworkCondition.allCases.map(\.title),
                       ["Normal", "Offline", "Slow", "Flaky"])
    }

    func testSlowConditionAddsLatency() async {
        let b = backend()
        await b.setCondition(.slow)
        let start = Date()
        _ = await b.fetchAccounts()
        XCTAssertGreaterThan(Date().timeIntervalSince(start), 2.5)
    }

    func testTransferDebitsExactly() async throws {
        let b = backend()
        let before = await b.fetchAccount(.EUR)!.balance
        try await b.transfer(from: .EUR, amount: Decimal(100), recipient: "A", note: "", idempotencyKey: "k1")
        let after = await b.fetchAccount(.EUR)!.balance
        XCTAssertEqual(before - after, Decimal(100))
    }

    func testRetryWithSameKeyIsIdempotent() async throws {
        let b = backend()
        let before = await b.fetchAccount(.EUR)!.balance
        try await b.transfer(from: .EUR, amount: Decimal(100), recipient: "A", note: "", idempotencyKey: "k")
        try await b.transfer(from: .EUR, amount: Decimal(100), recipient: "A", note: "", idempotencyKey: "k")
        let after = await b.fetchAccount(.EUR)!.balance
        XCTAssertEqual(before - after, Decimal(100), "same key must debit once")
    }

    func testRetryDuplicateDoublePosts() async throws {
        let b = backend(BackendScenario(retryDuplicate: true))
        let before = await b.fetchAccount(.EUR)!.balance
        try await b.transfer(from: .EUR, amount: Decimal(100), recipient: "A", note: "", idempotencyKey: "k")
        try await b.transfer(from: .EUR, amount: Decimal(100), recipient: "A", note: "", idempotencyKey: "k")
        let after = await b.fetchAccount(.EUR)!.balance
        XCTAssertEqual(before - after, Decimal(200))
    }

    func testTimeoutAsSuccessThrowsButCommits() async {
        let b = backend(BackendScenario(timeoutAsSuccess: true))
        let before = await b.fetchAccount(.EUR)!.balance
        do {
            try await b.transfer(from: .EUR, amount: Decimal(50), recipient: "A", note: "", idempotencyKey: "k")
            XCTFail("expected timeout")
        } catch {
            XCTAssertEqual(error as? BackendError, .timeout)
        }
        let after = await b.fetchAccount(.EUR)!.balance
        XCTAssertEqual(before - after, Decimal(50), "server committed despite the timeout")
    }

    func testStaleOfflineBalance() async throws {
        let b = backend(BackendScenario(staleOfflineBalance: true))
        let before = await b.fetchAccount(.EUR)!.balance
        try await b.transfer(from: .EUR, amount: Decimal(100), recipient: "A", note: "", idempotencyKey: "k")
        let after = await b.fetchAccount(.EUR)!.balance
        XCTAssertEqual(before, after, "reads keep serving the stale snapshot")
    }

    func testBalanceReadReturnsZero() async {
        let b = backend(BackendScenario(balanceReadReturnsZero: true))
        let balance = await b.fetchAccount(.EUR)!.balance
        XCTAssertEqual(balance, 0)
    }

    func testTransactionsDupOnFetch() async {
        let clean = await backend().fetchTransactions().count
        let dup = await backend(BackendScenario(transactionsDupOnFetch: true)).fetchTransactions().count
        XCTAssertEqual(dup, clean * 2)
    }

    func testMarketBuyMath() async throws {
        let b = backend()
        let cashBefore = await b.fetchAccount(.USD)!.balance
        let order = Order(id: "o", symbol: "AAPL", side: .buy, type: .market, quantity: 2,
                          limitPrice: nil, referencePrice: Decimal(190), executionPrice: Decimal(190),
                          status: .pending, placedAt: Date())
        let filled = try await b.placeOrder(order)
        XCTAssertEqual(filled.status, .filled)
        let cashAfter = await b.fetchAccount(.USD)!.balance
        XCTAssertEqual(cashBefore - cashAfter, Decimal(380))
        let holding = await b.fetchHoldings().first { $0.symbol == "AAPL" }
        XCTAssertEqual(holding?.quantity, Decimal(14)) // 12 seed + 2
    }

    func testExchangeCreditsAndDebits() async throws {
        let b = backend()
        let eurBefore = await b.fetchAccount(.EUR)!.balance
        let usdBefore = await b.fetchAccount(.USD)!.balance
        try await b.exchange(sell: .EUR, get: .USD, debit: Decimal(100), credited: Decimal(108))
        let eurAfter = await b.fetchAccount(.EUR)!.balance
        let usdAfter = await b.fetchAccount(.USD)!.balance
        XCTAssertEqual(eurBefore - eurAfter, Decimal(100))
        XCTAssertEqual(usdAfter - usdBefore, Decimal(108))
    }

    func testInsufficientFundsThrows() async {
        let b = backend()
        do {
            try await b.transfer(from: .EUR, amount: Decimal(1_000_000), recipient: "A", note: "", idempotencyKey: "k")
            XCTFail("expected insufficientFunds")
        } catch {
            XCTAssertEqual(error as? BackendError, .insufficientFunds)
        }
    }
}
