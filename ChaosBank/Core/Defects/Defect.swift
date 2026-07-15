//
//  Defect.swift
//  ChaosBank
//
//  A defect is a documented, first-class object — never a magic boolean.
//

import Foundation

nonisolated enum Severity: String, Sendable {
    case critical
    case major
    case minor
}

nonisolated enum Flakiness: String, Sendable {
    /// Fails every time the defect is active.
    case deterministic
    /// Fails intermittently; tuned probability, reproducible under the build seed.
    case raceCondition
}

nonisolated struct Defect: Identifiable, Sendable {
    let id: DefectID
    let title: String        // "Double charge on rapid double-tap"
    let feature: String      // "Transfer"
    let category: DefectCategory
    let severity: Severity
    let violates: String     // the correct behavior it breaks
    let flakiness: Flakiness
}
