//
//  HttpBackendTests.swift
//  ChaosBankTests
//
//  `HttpBackend` against a running ChaosBank-Server. Skipped unless
//  `CHAOSBANK_TEST_SERVER` (e.g. http://localhost:8080) is set; with xcodebuild pass it as
//  `TEST_RUNNER_CHAOSBANK_TEST_SERVER`. CI starts a server. The point: on a clean build
//  both backends answer the same.
//

import XCTest
@testable import ChaosBank

final class HttpBackendTests: XCTestCase {

    private var url: URL!

    override func setUpWithError() throws {
        guard let raw = ProcessInfo.processInfo.environment["CHAOSBANK_TEST_SERVER"], !raw.isEmpty,
              let url = URL(string: raw) else {
            throw XCTSkip("set CHAOSBANK_TEST_SERVER to run")
        }
        self.url = url
    }

    private func http(_ defects: Set<DefectID> = []) -> HttpBackend { HttpBackend(baseURL: url, seed: 0, defects: defects) }
    private func mock() -> MockBackend { MockBackend(latency: .zero) }

    func testCleanReadsMatchTheEmbeddedMock() async {
        let http = http(), mock = mock()
        let (ha, ma) = (await http.fetchAccounts(), await mock.fetchAccounts())
        XCTAssertEqual(ha, ma)
        let (ht, mt) = (await http.fetchTransactions(), await mock.fetchTransactions())
        XCTAssertEqual(ht, mt)
        let (hh, mh) = (await http.fetchHoldings(), await mock.fetchHoldings())
        XCTAssertEqual(hh, mh)
        let (hg, mg) = (await http.fetchAccount(.GBP), await mock.fetchAccount(.GBP))
        XCTAssertEqual(hg, mg)
    }

    func testEachLaunchStartsFromTheSeed() async throws {
        try await http().transfer(from: .EUR, amount: 100, recipient: "Alex", note: "", idempotencyKey: "k")
        let eur = await http().fetchAccount(.EUR)
        XCTAssertEqual(eur?.balance, Decimal(string: "4820.55"))
    }

    func testATransferDebitsOnceForOneKey() async throws {
        let http = http()
        let first = try await http.transfer(from: .EUR, amount: 100, recipient: "Alex", note: "", idempotencyKey: "same-key")
        let again = try await http.transfer(from: .EUR, amount: 100, recipient: "Alex", note: "", idempotencyKey: "same-key")
        XCTAssertEqual(first, again)
        let eur = await http.fetchAccount(.EUR)
        XCTAssertEqual(eur?.balance, Decimal(string: "4720.55"))
        let newest = await http.fetchTransactions().first
        XCTAssertEqual(newest?.id, first.id)
    }

    func testTheServerPricesAnExchangeLikeTheApp() async throws {
        let http = http()
        let tx = try await http.exchange(sell: .EUR, get: .USD, debit: 100, credited: 1)
        XCTAssertEqual(tx.amount, Decimal(string: "107.46"))
        let usd = await http.fetchAccount(.USD)
        XCTAssertEqual(usd?.balance, Decimal(string: "12857.46"))
    }

    func testAnOrderFillsAtTheAppsExecutionPrice() async throws {
        let http = http()
        let order = Order(id: "x", symbol: "AAPL", side: .buy, type: .limit, quantity: 2, limitPrice: 180,
                          referencePrice: Decimal(string: "189.50")!, executionPrice: Decimal(string: "189.50")!,
                          status: .pending, placedAt: Date())
        let filled = try await http.placeOrder(order)
        XCTAssertEqual(filled.status, .filled)
        XCTAssertEqual(filled.executionPrice, Decimal(string: "189.50"))
        let aapl = await http.fetchHoldings().first { $0.symbol == "AAPL" }
        XCTAssertEqual(aapl?.quantity, 14)
    }

    func testBusinessErrorsKeepTheirNames() async {
        do {
            try await http().transfer(from: .EUR, amount: 99_999, recipient: "", note: "", idempotencyKey: "k")
            XCTFail("should throw")
        } catch {
            XCTAssertEqual(error as? BackendError, .insufficientFunds)
        }
    }

    func testOfflineWritesFailWithoutAskingTheServer() async {
        let http = http()
        await http.setCondition(.offline)
        do {
            try await http.deposit(to: .EUR, amount: 1)
            XCTFail("should throw")
        } catch {
            XCTAssertEqual(error as? BackendError, .offline)
        }
        let eur = await http.fetchAccount(.EUR)
        XCTAssertEqual(eur?.balance, Decimal(string: "4820.55"), "reads still work")
    }

    func testActiveDefectsTheServerKnowsAreSwitchedOnThere() async {
        let http = http([.balanceReadReturnsZero, .pnlSign])   // pnlSign is client-only
        let zeroed = await http.fetchAccounts()
        XCTAssertFalse(zeroed.isEmpty)
        XCTAssertTrue(zeroed.allSatisfy { $0.balance == 0 })
        await http.setDefects([])
        let eur = await http.fetchAccount(.EUR)
        XCTAssertEqual(eur?.balance, Decimal(string: "4820.55"))
    }

    func testTheSyncCounterLivesOnTheServer() async {
        let http = http()
        for _ in 0..<3 { await http.syncIncrement() }
        let three = await http.syncValue()
        XCTAssertEqual(three, 3)
        await http.syncReset()
        let zero = await http.syncValue()
        XCTAssertEqual(zero, 0)
    }

    func testAnUnreachableServerServesTheLastGoodRead() async {
        let dead = HttpBackend(baseURL: URL(string: "http://127.0.0.1:1")!, seed: 0, defects: [], timeout: 1)
        let accounts = await dead.fetchAccounts()
        XCTAssertEqual(accounts, [])
        do {
            try await dead.deposit(to: .EUR, amount: 1)
            XCTFail("should throw")
        } catch {
            XCTAssertEqual(error as? BackendError, .timeout)
        }
    }

    func testOrdersAreListedAndBadOrdersKeepTheirErrors() async throws {
        let http = http()
        let buy = Order(id: "x", symbol: "AAPL", side: .buy, type: .market, quantity: 1, limitPrice: nil,
                        referencePrice: Decimal(string: "189.50")!, executionPrice: Decimal(string: "189.50")!,
                        status: .pending, placedAt: Date())
        _ = try await http.placeOrder(buy)
        let orders = await http.fetchOrders()
        XCTAssertEqual(orders.count, 1)
        XCTAssertEqual(orders.first?.type, .market)

        let unknown = Order(id: "y", symbol: "ZZZZ", side: .buy, type: .market, quantity: 1, limitPrice: nil,
                            referencePrice: 1, executionPrice: 1, status: .pending, placedAt: Date())
        let tooMany = Order(id: "z", symbol: "TSLA", side: .sell, type: .market, quantity: 9, limitPrice: nil,
                            referencePrice: Decimal(string: "242.10")!, executionPrice: Decimal(string: "242.10")!,
                            status: .pending, placedAt: Date())
        for (order, expected) in [(unknown, BackendError.unknownAsset), (tooMany, .insufficientHolding)] {
            do {
                _ = try await http.placeOrder(order)
                XCTFail("should throw")
            } catch {
                XCTAssertEqual(error as? BackendError, expected)
            }
        }
        do {
            try await http.transfer(from: .EUR, amount: -1, recipient: "", note: "", idempotencyKey: "neg")
            XCTFail("should throw")
        } catch {
            XCTAssertEqual(error as? BackendError, .invalidAmount)
        }
    }

    func testSyncSetWritesTheValue() async {
        let http = http()
        await http.syncSet(41)
        let value = await http.syncValue()
        XCTAssertEqual(value, 41)
    }

    func testANetworkChangeReachesTheSession() async {
        let http = http()
        _ = await http.fetchAccounts()
        await http.setCondition(.flaky)
        var failures = 0
        for _ in 0..<6 {
            do { try await http.deposit(to: .EUR, amount: 1) } catch { failures += 1 }
        }
        XCTAssertGreaterThan(failures, 0, "flaky writes fail on the server")
    }
}
