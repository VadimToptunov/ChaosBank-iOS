//
//  TransactionsViewModel.swift
//  ChaosBank
//

import Foundation
import Observation

enum TxFilter: String, CaseIterable {
    case all
    case moneyIn
    case moneyOut

    func matches(_ tx: Transaction) -> Bool {
        switch self {
        case .all: return true
        case .moneyIn: return tx.direction == .moneyIn
        case .moneyOut: return tx.direction == .moneyOut
        }
    }
}

@MainActor
@Observable
final class TransactionsViewModel {
    var search = "" { didSet { pagesLoaded = 1 } }
    var filter: TxFilter = .all { didSet { pagesLoaded = 1 } }

    let pageSize = 6
    private(set) var pagesLoaded = 1
    private var all: [Transaction] = []

    private let services: AppServices

    init(services: AppServices) { self.services = services }

    func load() async {
        var data = await services.backend.fetchTransactions()
        // The `transactionsHeavyList` defect balloons the dataset; combined with
        // non-lazy, non-paginated rendering below it makes the list lag.
        if Defects.isActive(.transactionsHeavyList) {
            data += Self.synthetic(count: 1500)
        }
        all = data
    }

    private static func synthetic(count: Int) -> [Transaction] {
        let titles = ["Coffee", "Groceries", "Taxi", "Subscription", "Refund", "Salary"]
        let categories = ["Dining", "Groceries", "Transport", "Digital", "Shopping", "Income"]
        return (0..<count).map { i in
            let sign: Decimal = i % 5 == 0 ? 1 : -1
            return Transaction(id: "syn-\(i)", title: "\(titles[i % titles.count]) #\(i)",
                               category: categories[i % categories.count],
                               date: SeedData.daysAgo(11 + i / 40),
                               amount: sign * Decimal(i % 90 + 1), currency: .EUR)
        }
    }

    var filtered: [Transaction] {
        // `transactionsSortEveryRender`: re-sort the whole list on every access
        // (evaluated on each render) instead of relying on the pre-sorted data.
        let source = Defects.isActive(.transactionsSortEveryRender)
            ? all.sorted { $0.date > $1.date }
            : all
        // `searchTrimsNothing`: don't trim the query before matching.
        let query = Defects.isActive(.searchTrimsNothing) ? search : search.trimmingCharacters(in: .whitespaces)
        return source.filter { tx in
            // `filterLeaksCategory` / `filterOutLeaksIn`: a filter leaks the other category.
            let categoryOK = filter.matches(tx)
                || (Defects.isActive(.filterLeaksCategory) && filter == .moneyIn)
                || (Defects.isActive(.filterOutLeaksIn) && filter == .moneyOut)
            guard categoryOK else { return false }
            guard !query.isEmpty else { return true }
            // `searchCaseSensitive`: don't fold case. `searchIgnoresCategory`: match title only.
            let cs = Defects.isActive(.searchCaseSensitive)
            let q = cs ? query : query.lowercased()
            let title = cs ? tx.title : tx.title.lowercased()
            let category = cs ? tx.category : tx.category.lowercased()
            if Defects.isActive(.searchIgnoresCategory) { return title.contains(q) }
            return title.contains(q) || category.contains(q)
        }
    }

    /// The rows currently shown. The `paginationDup` defect re-inserts the first
    /// row of page 2 so it appears twice after "Load more".
    var visible: [Transaction] {
        // The `transactionsHeavyList` defect renders the whole (inflated) list at
        // once instead of paginating — the non-lazy render then hitches.
        if Defects.isActive(.transactionsHeavyList) {
            return filtered
        }
        let count = min(pageSize * pagesLoaded, filtered.count)
        var rows = Array(filtered.prefix(count))
        if Defects.isActive(.paginationDup), pagesLoaded > 1, rows.indices.contains(pageSize) {
            rows.insert(rows[pageSize], at: pageSize)
        }
        return rows
    }

    // `paginationNeverEnds`: there's always "more" — a scroll-to-end loop never terminates.
    var canLoadMore: Bool {
        if Defects.isActive(.paginationNeverEnds) { return true }
        return pageSize * pagesLoaded < filtered.count
    }

    private var syntheticSeq = 0

    func loadMore() {
        guard canLoadMore else { return }
        pagesLoaded += 1
        // Keep the tail perpetually ahead so the list can never catch up.
        if Defects.isActive(.paginationNeverEnds) { all += endlessBatch(count: pageSize) }
    }

    private func endlessBatch(count: Int) -> [Transaction] {
        let titles = ["Coffee", "Groceries", "Taxi", "Subscription", "Refund", "Salary"]
        let categories = ["Dining", "Groceries", "Transport", "Digital", "Shopping", "Income"]
        return (0..<count).map { _ in
            let i = syntheticSeq
            syntheticSeq += 1
            let sign: Decimal = i % 5 == 0 ? 1 : -1
            return Transaction(id: "pag-\(i)", title: "\(titles[i % titles.count]) #\(i)",
                               category: categories[i % categories.count],
                               date: SeedData.daysAgo(11 + i / 40),
                               amount: sign * Decimal(i % 90 + 1), currency: .EUR)
        }
    }

    /// Visible rows grouped by calendar day, preserving order.
    var grouped: [(key: String, rows: [Transaction])] {
        let rows = visible
        let shifted = Defects.isActive(.dateTimezoneShift)
        // `transactionsRegroupHeavy`: rebuild groups with an O(n²) scan each render.
        if Defects.isActive(.transactionsRegroupHeavy) {
            var result: [(key: String, rows: [Transaction])] = []
            for tx in rows {
                let key = TxFormat.dayHeader(tx.date, shifted: shifted)
                let sameDay = rows.filter { TxFormat.dayHeader($0.date, shifted: shifted) == key }
                if !result.contains(where: { $0.key == key }) {
                    result.append((key: key, rows: sameDay))
                }
            }
            return result
        }
        var result: [(key: String, rows: [Transaction])] = []
        for tx in rows {
            let key = TxFormat.dayHeader(tx.date, shifted: shifted)
            if let idx = result.firstIndex(where: { $0.key == key }) {
                result[idx].rows.append(tx)
            } else {
                result.append((key: key, rows: [tx]))
            }
        }
        return result
    }
}
