//
//  FXRates.swift
//  ChaosBank
//
//  Fixed mid-market FX rates for the sandbox. Deterministic; not a live feed.
//

import Foundation

enum FXRates {
    /// Mid rates expressed as units of currency per 1 EUR.
    private static let perEUR: [Currency: Decimal] = [
        .EUR: 1,
        .USD: Decimal(string: "1.08")!,
        .GBP: Decimal(string: "0.85")!,
    ]

    /// Exchange fee applied on the sold amount (0.5%).
    static let feeRate = Decimal(string: "0.005")!

    /// Mid-market rate to convert 1 unit of `from` into `to`.
    static func rate(from: Currency, to: Currency) -> Decimal {
        guard let f = perEUR[from], let t = perEUR[to], f != 0 else { return 1 }
        return t / f
    }

    /// Gross converted amount before fees.
    static func convert(_ amount: Decimal, from: Currency, to: Currency) -> Decimal {
        amount * rate(from: from, to: to)
    }
}
