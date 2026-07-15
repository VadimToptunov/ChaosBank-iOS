//
//  BackendScenario.swift
//  ChaosBank
//
//  Network scenario knobs for the mock backend. Resolved on the main actor from
//  the active defect set and pushed into the backend actor, which cannot read the
//  main-actor `Defects` registry directly.
//

import Foundation

nonisolated struct BackendScenario: Sendable, Equatable {
    /// A retry re-posts instead of being idempotent (duplicate payment).
    var retryDuplicate = false
    /// The server processes the request but the client "times out" (no ack).
    var timeoutAsSuccess = false
    /// A stale, late response is allowed to clobber fresher state.
    var slowResponseRace = false
    /// Reads return an outdated offline snapshot instead of live state.
    var staleOfflineBalance = false

    static func from(_ defects: Set<DefectID>) -> BackendScenario {
        BackendScenario(
            retryDuplicate: defects.contains(.retryDuplicate),
            timeoutAsSuccess: defects.contains(.timeoutAsSuccess),
            slowResponseRace: defects.contains(.slowResponseRace),
            staleOfflineBalance: defects.contains(.staleOfflineBalance)
        )
    }
}
