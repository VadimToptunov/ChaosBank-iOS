//
//  Holding.swift
//  ChaosBank
//

import Foundation

/// A position in the portfolio. Cost basis is exact (Decimal).
nonisolated struct Holding: Identifiable, Equatable, Sendable {
    var id: String { symbol }
    let symbol: String
    var quantity: Decimal
    /// Average cost per unit in USD.
    var avgCost: Decimal

    var costBasis: Decimal { quantity * avgCost }

    func marketValue(at price: Decimal) -> Decimal { quantity * price }

    /// Unrealized P&L at the given price. Positive = gain, negative = loss.
    func pnl(at price: Decimal) -> Decimal { (price - avgCost) * quantity }

    func pnlPercent(at price: Decimal) -> Decimal {
        guard costBasis != 0 else { return 0 }
        return pnl(at: price) / costBasis * 100
    }
}
