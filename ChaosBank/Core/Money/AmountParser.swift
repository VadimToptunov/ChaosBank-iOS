//
//  AmountParser.swift
//  ChaosBank
//
//  Parses a user-typed amount string into an exact Decimal under the active
//  locale. This is the single injection point for the `localeParse` defect.
//

import Foundation

@MainActor
enum AmountParser {
    /// Parse an amount string (e.g. "1,000.50") using the active locale's
    /// grouping and decimal separators.
    ///
    /// Correct path: a locale-aware NumberFormatter handles separators properly.
    /// `localeParse` defect: grouping separators are stripped as if they were
    /// decimal points, so "1,000.50" collapses toward "1.00050".
    static func parse(_ raw: String, locale: Locale = .current) -> Decimal? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        if Defects.isActive(.localeParse) {
            // Buggy: treat every separator as a decimal point. Multiple dots then
            // fold into one fractional group — "1,000.50" -> "1.00050".
            let normalized = trimmed
                .replacingOccurrences(of: ",", with: ".")
            let parts = normalized.split(separator: ".", omittingEmptySubsequences: false)
            if parts.count > 1 {
                let intPart = parts.first.map(String.init) ?? "0"
                let fraction = parts.dropFirst().joined()
                return Decimal(string: "\(intPart).\(fraction)")
            }
            return Decimal(string: normalized)
        }

        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .decimal
        f.generatesDecimalNumbers = true
        if let n = f.number(from: trimmed) as? NSDecimalNumber {
            return n.decimalValue
        }
        // Fall back to a locale-agnostic parse for plain "1234.56" input.
        return Decimal(string: trimmed, locale: Locale(identifier: "en_US"))
    }
}
