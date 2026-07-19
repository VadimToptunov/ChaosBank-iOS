//
//  LocaleFormat.swift
//  ChaosBank
//
//  Locale-aware number grouping (Localization cluster), distinct from the fixed money
//  format. The `numberGroupingIgnoresLocale` defect always uses en-US separators.
//

import Foundation

nonisolated enum LocaleId: String, CaseIterable, Sendable {
    case enUS
    case deDE
    case ar

    var title: String {
        switch self {
        case .enUS: return "en-US"
        case .deDE: return "de-DE"
        case .ar: return "ar"
        }
    }

    var foundationLocale: Locale {
        switch self {
        case .enUS: return Locale(identifier: "en_US")
        case .deDE: return Locale(identifier: "de_DE")
        case .ar: return Locale(identifier: "ar")
        }
    }

    static func from(_ raw: String?) -> LocaleId { LocaleId(rawValue: raw ?? "") ?? .enUS }
}

enum LocaleFormat {
    static func grouped(_ value: Decimal, locale: LocaleId) -> String {
        let effective = Defects.isActive(.numberGroupingIgnoresLocale)
            ? Locale(identifier: "en_US")
            : locale.foundationLocale
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = effective
        f.usesGroupingSeparator = true
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f.string(from: value as NSDecimalNumber) ?? ""
    }
}
