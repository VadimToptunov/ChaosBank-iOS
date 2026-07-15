//
//  PortfolioViewModel.swift
//  ChaosBank
//

import Foundation
import Observation

@MainActor
@Observable
final class PortfolioViewModel {
    private(set) var holdings: [Holding] = []
    private let services: AppServices

    init(services: AppServices) { self.services = services }

    func load() async {
        // The `mainThreadStall` defect does blocking work on the main actor when
        // the screen opens, hanging the UI — the exact anti-pattern to catch.
        if Defects.isActive(.mainThreadStall) {
            Thread.sleep(forTimeInterval: 1.2)
        }
        holdings = await services.backend.fetchHoldings()
    }

    private func price(_ symbol: String) -> Decimal {
        services.market.price(for: symbol)
    }

    var totalValue: Money {
        let sum = holdings.reduce(Decimal(0)) { $0 + $1.marketValue(at: price($1.symbol)) }
        return Money(sum, .USD)
    }

    var totalCost: Decimal { holdings.reduce(Decimal(0)) { $0 + $1.costBasis } }

    var totalPnL: Decimal {
        holdings.reduce(Decimal(0)) { $0 + $1.pnl(at: price($1.symbol)) }
    }

    var totalPnLPercent: Decimal {
        // Correct: percent against cost basis. `pnlPercentVsValue` divides by the
        // current market value instead.
        let denom = Defects.isActive(.pnlPercentVsValue) ? totalValue.amount : totalCost
        guard denom != 0 else { return 0 }
        return totalPnL / denom * 100
    }

    func marketValue(_ h: Holding) -> Money { Money(h.marketValue(at: price(h.symbol)), .USD) }

    func pnl(_ h: Holding) -> Decimal { h.pnl(at: price(h.symbol)) }

    func allocationFraction(_ h: Holding) -> Double {
        let total = totalValue.amount
        guard total != 0 else { return 0 }
        return (h.marketValue(at: price(h.symbol)) / total).doubleValue
    }

    /// The P&L value to DISPLAY.
    ///
    /// Correct path: the real signed P&L. The `pnlSign` defect shows a loss as a
    /// gain by taking the absolute value, so red losses render green.
    func displayPnL(_ value: Decimal) -> Decimal {
        if Defects.isActive(.pnlSign) { return abs(value) }
        return value
    }

    func name(_ symbol: String) -> String {
        SeedData.assets.first { $0.symbol == symbol }?.name ?? symbol
    }
}
