//
//  Currency.swift
//  ChaosBank
//

import Foundation

nonisolated enum Currency: String, CaseIterable, Codable, Sendable, Identifiable {
    case EUR
    case USD
    case GBP

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .EUR: return "€"
        case .USD: return "$"
        case .GBP: return "£"
        }
    }

    var code: String { rawValue }
}
