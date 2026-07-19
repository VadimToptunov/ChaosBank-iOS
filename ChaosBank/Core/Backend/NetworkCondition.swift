//
//  NetworkCondition.swift
//  ChaosBank
//
//  A simulated network environment (reliability cluster), chosen from the dev menu.
//  Not a defect — an environment condition testers can exercise:
//   - normal:  live reads and writes.
//   - offline: reads serve cached data; writes fail.
//   - slow:    every call gets a large extra latency (spinner / timeout testing).
//   - flaky:   writes fail transiently at random (retry / error-handling testing).
//

import Foundation

enum NetworkCondition: String, CaseIterable, Sendable {
    case normal
    case offline
    case slow
    case flaky

    var title: String {
        switch self {
        case .normal: return "Normal"
        case .offline: return "Offline"
        case .slow: return "Slow"
        case .flaky: return "Flaky"
        }
    }

    static func from(_ raw: String?) -> NetworkCondition {
        guard let raw else { return .normal }
        return NetworkCondition(rawValue: raw.lowercased()) ?? .normal
    }
}
