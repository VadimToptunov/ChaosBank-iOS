//
//  DefectCategory.swift
//  ChaosBank
//
//  The taxonomy a tester reasons in. Profiles are largely derived from these, so
//  the catalog and the profiles stay in sync as the catalog grows.
//

import Foundation

nonisolated enum DefectCategory: String, CaseIterable, Sendable {
    case money
    case validation
    case localization
    case state
    case concurrency
    case ui
    case accessibility
    case security
    case network
    case performance

    var title: String {
        switch self {
        case .money: return "Money & logic"
        case .validation: return "Validation"
        case .localization: return "Localization"
        case .state: return "State & navigation"
        case .concurrency: return "Concurrency & races"
        case .ui: return "UI & layout"
        case .accessibility: return "Accessibility"
        case .security: return "Security & privacy"
        case .network: return "Networking"
        case .performance: return "Performance"
        }
    }
}
