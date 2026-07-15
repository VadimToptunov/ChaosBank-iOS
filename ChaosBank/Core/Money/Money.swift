//
//  Money.swift
//  ChaosBank
//
//  Decimal-based money. This is the correct implementation used by every
//  production path. The single place money is ever routed through Double is the
//  guarded `roundingDrift` injection point — never here.
//

import Foundation

/// A monetary amount tied to a currency. Amounts are always exact `Decimal`.
nonisolated struct Money: Equatable, Hashable, Codable, Sendable {
    var amount: Decimal
    var currency: Currency

    init(_ amount: Decimal, _ currency: Currency) {
        self.amount = amount
        self.currency = currency
    }

    static func zero(_ currency: Currency) -> Money { Money(0, currency) }

    /// Rounded to the currency's minor unit (2 places) using banker's rounding.
    var rounded: Money { Money(amount.roundedMoney(), currency) }

    func adding(_ other: Decimal) -> Money { Money(amount + other, currency) }
    func subtracting(_ other: Decimal) -> Money { Money(amount - other, currency) }

    /// "€1,234.56" — grouping and separators are fixed for the sandbox so the
    /// display is deterministic regardless of the device locale.
    var formatted: String {
        currency.symbol + MoneyFormat.decimal(amount.roundedMoney())
    }

    /// Signed with an explicit leading + or − (used for deltas / P&L).
    var formattedSigned: String {
        let rounded = amount.roundedMoney()
        let sign = rounded < 0 ? "−" : "+"
        return sign + currency.symbol + MoneyFormat.decimal(abs(rounded))
    }
}

nonisolated extension Decimal {
    /// Round to 2 fractional digits with banker's rounding (half-to-even).
    func roundedMoney() -> Decimal {
        var input = self
        var result = Decimal()
        NSDecimalRound(&result, &input, 2, .bankers)
        return result
    }

    /// Round to an arbitrary scale with banker's rounding.
    func rounded(scale: Int) -> Decimal {
        var input = self
        var result = Decimal()
        NSDecimalRound(&result, &input, scale, .bankers)
        return result
    }

    var doubleValue: Double { (self as NSDecimalNumber).doubleValue }
}

nonisolated enum MoneyFormat {
    /// Fixed en_US-style grouping: comma thousands, dot decimal, 2 fraction digits.
    static func decimal(_ value: Decimal, fractionDigits: Int = 2) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .decimal
        f.minimumFractionDigits = fractionDigits
        f.maximumFractionDigits = fractionDigits
        f.usesGroupingSeparator = true
        return f.string(from: value as NSDecimalNumber) ?? "\(value)"
    }

    static func price(_ value: Decimal, fractionDigits: Int = 2) -> String {
        decimal(value, fractionDigits: fractionDigits)
    }

    static func percent(_ value: Decimal) -> String {
        let rounded = value.rounded(scale: 2)
        let sign = rounded < 0 ? "−" : "+"
        return sign + decimal(abs(rounded)) + "%"
    }
}
