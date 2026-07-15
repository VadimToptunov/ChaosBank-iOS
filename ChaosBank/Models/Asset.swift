//
//  Asset.swift
//  ChaosBank
//

import Foundation

nonisolated enum AssetKind: String, Sendable {
    case stock
    case crypto
}

/// Static reference data for a tradable instrument. Live price lives in `Quote`.
nonisolated struct Asset: Identifiable, Equatable, Sendable {
    var id: String { symbol }
    let symbol: String          // "AAPL"
    let name: String            // "Apple Inc."
    let kind: AssetKind
    /// Priced in USD across the sandbox.
    let currency: Currency
    /// Anchor price the seeded walk starts from.
    let basePrice: Decimal
    /// Annualized-ish volatility knob for the walk (fraction of price per tick).
    let volatility: Decimal
}
