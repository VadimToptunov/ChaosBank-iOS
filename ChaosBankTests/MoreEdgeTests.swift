//
//  MoreEdgeTests.swift
//  ChaosBankTests
//
//  Final branch coverage across the remaining view-model and parser paths.
//

import XCTest
@testable import ChaosBank

@MainActor
final class MoreEdgeTests: XCTestCase {

    override func tearDown() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        super.tearDown()
    }

    private func services(_ defects: Set<DefectID> = []) -> AppServices {
        let config = BuildConfig(seed: 0, activeDefects: defects, label: "t")
        Defects.configure(config)
        return AppServices(config: config)
    }

    // MARK: Transfer

    func testDoubleChargeSendsTwice() async {
        let s = services([.doubleCharge])
        let m = TransferViewModel(services: s)
        await m.load()
        m.recipient = "Alex"; m.amountText = "100"
        let before = await s.backend.fetchAccount(.EUR)?.balance ?? 0
        async let a: Void = m.confirmTransfer()
        async let b: Void = m.confirmTransfer()
        _ = await (a, b)
        let after = await s.backend.fetchAccount(.EUR)?.balance ?? 0
        XCTAssertEqual(before - after, 200, "double-tap posted twice")
    }

    func testRetryAfterTimeoutSucceeds() async {
        let s = services()
        await s.backend.setScenario(BackendScenario(timeoutAsSuccess: true))
        let m = TransferViewModel(services: s)
        await m.load()
        m.recipient = "Alex"; m.amountText = "50"
        await m.confirmTransfer()
        XCTAssertTrue(m.canRetry)
        await s.backend.setScenario(BackendScenario())   // network recovers
        await m.retry()
        XCTAssertTrue(m.succeeded)
    }

    func testTransferRoundsUpDefect() async {
        let s = services([.transferRoundsUp])
        let m = TransferViewModel(services: s)
        await m.load()
        m.recipient = "Alex"; m.amountText = "99.20"
        let before = await s.backend.fetchAccount(.EUR)?.balance ?? 0
        await m.confirmTransfer()
        let after = await s.backend.fetchAccount(.EUR)?.balance ?? 0
        XCTAssertEqual(before - after, 100)
    }

    func testConfirmWrongRecipientDefect() async {
        let s = services([.transferConfirmWrongRecipient])
        let m = TransferViewModel(services: s)
        await m.load()
        m.recipient = "Alex"
        XCTAssertNotEqual(m.confirmRecipientText, "Alex")
    }

    func testNegativeCreditsValidation() async {
        let s = services([.transferNegativeCredits])
        let m = TransferViewModel(services: s)
        await m.load()
        m.recipient = "Alex"; m.amountText = "-30"
        XCTAssertTrue(m.canContinue)
    }

    func testInsufficientFundsError() async {
        let s = services([.amountExceedsBalanceAllowed])
        let m = TransferViewModel(services: s)
        await m.load()
        m.recipient = "Alex"; m.amountText = "999999"
        await m.confirmTransfer()
        XCTAssertFalse(m.succeeded)
        XCTAssertEqual(m.errorMessage, "Insufficient funds")
    }

    func testWhitespaceRecipientKept() async {
        let s = services([.whitespaceRecipient])
        let m = TransferViewModel(services: s)
        await m.load()
        m.recipient = "  Alex  "
        XCTAssertEqual(m.effectiveRecipient, "  Alex  ")
    }

    // MARK: Portfolio

    func testPortfolioName() async {
        let s = services()
        let m = PortfolioViewModel(services: s)
        await m.load()
        XCTAssertEqual(m.name("AAPL"), "Apple Inc.")
        XCTAssertEqual(m.name("ZZZ"), "ZZZ")
    }

    // MARK: Transactions

    func testSearchIgnoresCategoryDefect() async {
        let s = services([.searchIgnoresCategory])
        let m = TransactionsViewModel(services: s)
        await m.load()
        m.search = "exchange"   // a category, not in the visible titles
        XCTAssertFalse(m.filtered.contains { $0.category == "Exchange" && !$0.title.lowercased().contains("exchange") })
    }

    func testLoadMoreToEndAndRegroup() async {
        let s = services([.transactionsSortEveryRender, .transactionsRegroupHeavy])
        let m = TransactionsViewModel(services: s)
        await m.load()
        while m.canLoadMore { m.loadMore() }
        XCTAssertEqual(m.visible.count, m.filtered.count)
        XCTAssertFalse(m.grouped.isEmpty)
    }

    // MARK: Exchange

    func testYouGetZeroWithoutAmount() async {
        let s = services()
        let m = ExchangeViewModel(services: s)
        await m.load()
        m.amountText = ""
        XCTAssertEqual(m.youGet.amount, 0)
        XCTAssertGreaterThan(m.fee.amount, -1) // fee computed path
    }

    func testRateStaleAfterSwapDefect() async {
        let s = services([.exchangeRateStaleAfterSwap])
        let m = ExchangeViewModel(services: s)
        await m.load()
        m.sell = .GBP; m.get = .EUR
        XCTAssertEqual(m.rate, FXRates.rate(from: .EUR, to: .USD), "keeps the original EUR→USD rate")
    }

    // MARK: Order

    func testDecrementCanGoNegativeUnderLimitValidation() {
        let s = services([.limitValidation])
        let m = OrderViewModel(request: OrderRequest(symbol: "AAPL", side: .buy, capturedPrice: 190), services: s)
        m.quantity = 0
        m.decrement()
        XCTAssertLessThan(m.quantity, 0)
    }

    // MARK: AmountParser

    func testAmountParserBranches() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [.localeParse], label: "t"))
        XCTAssertEqual(AmountParser.parse("500", locale: Locale(identifier: "en_US")), 500)
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        XCTAssertNil(AmountParser.parse("not-a-number"))
    }
}
