//
//  ViewModelDefectTests.swift
//  ChaosBankTests
//
//  Demonstrates the core regression pattern at the view-model layer: the same
//  assertion passes on the clean profile and fails when the defect is active.
//

import XCTest
@testable import ChaosBank

@MainActor
final class ViewModelDefectTests: XCTestCase {

    override func tearDown() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        super.tearDown()
    }

    private func services(_ defects: Set<DefectID>) -> AppServices {
        let config = BuildConfig(seed: 0, activeDefects: defects, label: "t")
        Defects.configure(config)
        return AppServices(config: config)
    }

    func testHomeTotalOmitsAccountDefect() async {
        let cleanVM = HomeViewModel(services: services([]))
        await cleanVM.load()
        let full = cleanVM.totalBalance.amount

        let buggyVM = HomeViewModel(services: services([.homeTotalOmitsAccount]))
        await buggyVM.load()
        let omitted = buggyVM.totalBalance.amount

        XCTAssertGreaterThan(full, omitted, "omitting GBP must lower the total")
    }

    func testTransferBalanceAfterDefect() async {
        let cleanVM = TransferViewModel(services: services([]))
        await cleanVM.load()
        cleanVM.recipient = "Alex"; cleanVM.amountText = "100"
        XCTAssertEqual(cleanVM.balanceAfter?.amount, cleanVM.fromBalance - 100)

        let buggyVM = TransferViewModel(services: services([.balanceAfterAdds]))
        await buggyVM.load()
        buggyVM.recipient = "Alex"; buggyVM.amountText = "100"
        XCTAssertEqual(buggyVM.balanceAfter?.amount, buggyVM.fromBalance + 100)
    }

    func testPortfolioPnlSignDefect() async {
        let cleanVM = PortfolioViewModel(services: services([]))
        await cleanVM.load()
        guard let tsla = cleanVM.holdings.first(where: { $0.symbol == "TSLA" }) else {
            return XCTFail("TSLA holding missing")
        }
        XCTAssertLessThan(cleanVM.pnl(tsla), 0, "TSLA is a real loss")
        XCTAssertLessThan(cleanVM.displayPnL(cleanVM.pnl(tsla)), 0, "clean shows the loss")

        let buggyVM = PortfolioViewModel(services: services([.pnlSign]))
        await buggyVM.load()
        XCTAssertGreaterThan(buggyVM.displayPnL(buggyVM.pnl(tsla)), 0, "pnlSign shows a loss as a gain")
    }

    func testTransactionsFilterLeakDefect() async {
        let cleanVM = TransactionsViewModel(services: services([]))
        await cleanVM.load()
        cleanVM.filter = .moneyIn
        XCTAssertTrue(cleanVM.filtered.allSatisfy { $0.direction == .moneyIn })

        let buggyVM = TransactionsViewModel(services: services([.filterLeaksCategory]))
        await buggyVM.load()
        buggyVM.filter = .moneyIn
        XCTAssertTrue(buggyVM.filtered.contains { $0.direction == .moneyOut }, "filter leaks money-out rows")
    }
}
