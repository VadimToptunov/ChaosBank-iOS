//
//  BuildConfig.swift
//  ChaosBank
//
//  A build is identified by a bug profile (or a numeric seed). The active config
//  maps to a set of defect IDs and drives every source of "randomness".
//

import Foundation

nonisolated struct BuildConfig: Sendable {
    let version = "1.0"
    let seed: Int
    var activeDefects: Set<DefectID>
    /// Human-readable label for the badge (profile id, "seed NN", or "custom").
    var label: String
    /// Which price feed to run at launch.
    var priceSource: PriceSourceKind = .simulated

    var seedBadge: String { String(format: "%02d", seed) }

    /// The profile baked into this build **configuration**.
    ///
    /// This is how a distributable "flaky build" is produced without duplicating
    /// targets: one target, one binary, and a per-configuration compile flag read
    /// in exactly this one place (never scattered through the app). Add a build
    /// configuration that sets `SWIFT_ACTIVE_COMPILATION_CONDITIONS` and a matching
    /// case here to introduce a new baked profile.
    static var bakedDefaultProfile: String? {
        #if CHAOSBANK_PROFILE_UI
        return "ui"
        #elseif CHAOSBANK_PROFILE_VALIDATION
        return "validation"
        #elseif CHAOSBANK_PROFILE_ACCESSIBILITY
        return "accessibility"
        #elseif CHAOSBANK_PROFILE_STATE
        return "state"
        #elseif CHAOSBANK_PROFILE_LOCALIZATION
        return "localization"
        #elseif CHAOSBANK_PROFILE_SECURITY
        return "security"
        #elseif CHAOSBANK_PROFILE_NETWORK
        return "network"
        #elseif CHAOSBANK_PROFILE_FLAKY
        return "flaky"
        #elseif CHAOSBANK_PROFILE_BEGINNER
        return "beginner"
        #elseif CHAOSBANK_PROFILE_MIDDLE
        return "middle"
        #elseif CHAOSBANK_PROFILE_SENIOR
        return "senior"
        #elseif CHAOSBANK_PROFILE_ALL
        return "all"
        #else
        return nil
        #endif
    }

    /// Resolves the active build from launch arguments / environment / build config.
    ///
    /// Precedence (highest first):
    ///   1. `-ChaosBankDefects a,b,c` — explicit defect list (label "custom").
    ///   2. `-ChaosBankProfile <id>` / `CHAOSBANK_PROFILE` — a named profile.
    ///   3. `-ChaosBankSeed <n>` / `CHAOSBANK_SEED` — numeric seed mapping.
    ///   4. `bakedDefaultProfile` — the profile baked into this build configuration.
    ///   5. clean.
    ///
    /// A `-ChaosBankSeed` may still override a profile's RNG seed when both are set.
    static func resolve(
        defaults: UserDefaults = .standard,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> BuildConfig {
        let explicitSeed: Int? = {
            if let raw = defaults.string(forKey: "ChaosBankSeed"), let n = Int(raw) { return n }
            if let raw = environment["CHAOSBANK_SEED"], let n = Int(raw) { return n }
            return nil
        }()

        // Runtime override wins; otherwise fall back to the profile baked into the
        // build configuration.
        let profileID = defaults.string(forKey: "ChaosBankProfile")
            ?? environment["CHAOSBANK_PROFILE"]
            ?? bakedDefaultProfile

        var seed = explicitSeed ?? 0
        var defects: Set<DefectID> = []
        var label = "clean"

        if let pid = profileID, let profile = BugProfiles.profile(id: pid) {
            defects = profile.defects
            label = profile.id
            seed = explicitSeed ?? profile.seed
        } else if let explicitSeed, explicitSeed != 0 {
            defects = DefectRegistry.defects(forSeed: explicitSeed)
            label = "seed \(String(format: "%02d", explicitSeed))"
        }

        if let override = defaults.string(forKey: "ChaosBankDefects") {
            let ids = override
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .compactMap { DefectID(rawValue: $0) }
            defects = Set(ids)
            label = "custom"
        }

        let rawSource = defaults.string(forKey: "ChaosBankPriceSource") ?? environment["CHAOSBANK_PRICE_SOURCE"]
        let priceSource = PriceSourceKind(rawValue: rawSource?.lowercased() ?? "") ?? .simulated

        return BuildConfig(seed: seed, activeDefects: defects, label: label, priceSource: priceSource)
    }
}
