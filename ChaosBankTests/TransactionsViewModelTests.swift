//
//  TransactionsViewModelTests.swift
//  ChaosBankTests
//

import XCTest
@testable import ChaosBank

@MainActor
final class TransactionsViewModelTests: XCTestCase {

    override func tearDown() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        super.tearDown()
    }

    private func make(_ defects: Set<DefectID> = []) async -> TransactionsViewModel {
        let config = BuildConfig(seed: 0, activeDefects: defects, label: "t")
        Defects.configure(config)
        let m = TransactionsViewModel(services: AppServices(config: config))
        await m.load()
        return m
    }

    func testFilters() async {
        let m = await make()
        m.filter = .moneyIn
        XCTAssertTrue(m.filtered.allSatisfy { $0.direction == .moneyIn })
        m.filter = .moneyOut
        XCTAssertTrue(m.filtered.allSatisfy { $0.direction == .moneyOut })
    }

    func testSearch() async {
        let m = await make()
        m.search = "grocery"
        XCTAssertTrue(m.filtered.contains { $0.title.lowercased().contains("grocery") })
        XCTAssertFalse(m.filtered.isEmpty)
    }

    func testSearchCaseSensitiveDefect() async {
        let m = await make([.searchCaseSensitive])
        m.search = "grocery"   // real title is "Grocery Store"
        XCTAssertFalse(m.filtered.contains { $0.title == "Grocery Store" })
    }

    func testPagination() async {
        let m = await make()
        XCTAssertEqual(m.visible.count, m.pageSize)
        XCTAssertTrue(m.canLoadMore)
        m.loadMore()
        XCTAssertEqual(m.visible.count, min(m.pageSize * 2, m.filtered.count))
    }

    func testPaginationDupDefect() async {
        let m = await make([.paginationDup])
        m.loadMore()
        let ids = m.visible.map(\.id)
        XCTAssertNotEqual(Set(ids).count, ids.count, "a row is duplicated after Load more")
    }

    func testFilterOutLeaksInDefect() async {
        let m = await make([.filterOutLeaksIn])
        m.filter = .moneyOut
        XCTAssertTrue(m.filtered.contains { $0.direction == .moneyIn })
    }

    func testHeavyListDefectInflatesAndUnpaginates() async {
        let m = await make([.transactionsHeavyList])
        XCTAssertGreaterThan(m.filtered.count, 1000)
        XCTAssertEqual(m.visible.count, m.filtered.count, "renders everything, no pagination")
    }

    func testGroupedPreservesRows() async {
        let m = await make()
        let grouped = m.grouped.reduce(0) { $0 + $1.rows.count }
        XCTAssertEqual(grouped, m.visible.count)
    }
}
