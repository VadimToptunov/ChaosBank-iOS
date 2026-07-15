//
//  Defects.swift
//  ChaosBank
//
//  The single query surface every guarded injection point uses:
//      if Defects.isActive(.someBug) { ... }
//

import Foundation

@MainActor
enum Defects {
    /// The active build. Set once at launch from `BuildConfig.resolve()`.
    private(set) static var config = BuildConfig(seed: 0, activeDefects: [], label: "clean")

    static func configure(_ config: BuildConfig) {
        self.config = config
    }

    static func isActive(_ id: DefectID) -> Bool {
        config.activeDefects.contains(id)
    }

    static var seed: Int { config.seed }
}
