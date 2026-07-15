//
//  Quote.swift
//  ChaosBank
//

import Foundation

nonisolated enum TickDirection: Sendable {
    case up
    case down
    case flat
}

/// A live price snapshot for one symbol.
nonisolated struct Quote: Equatable, Sendable {
    let symbol: String
    var price: Decimal
    let dayOpen: Decimal
    var dayHigh: Decimal
    var dayLow: Decimal
    var lastDirection: TickDirection

    /// Percent change vs the day's open.
    var changePct: Decimal {
        guard dayOpen != 0 else { return 0 }
        return ((price - dayOpen) / dayOpen * 100)
    }

    var changeAbsolute: Decimal { price - dayOpen }
}
