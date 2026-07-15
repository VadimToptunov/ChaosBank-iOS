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

    /// Resolves the active build from launch arguments / environment.
    ///
    /// Precedence:
    ///   1. `-ChaosBankDefects a,b,c` — explicit defect list (label "custom").
    ///   2. `-bugProfile <id>` / `CHAOSBANK_PROFILE` — a named profile.
    ///   3. `-ChaosBankSeed <n>` / `CHAOSBANK_SEED` — numeric seed mapping.
    ///   4. clean.
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

        let profileID = defaults.string(forKey: "ChaosBankProfile") ?? environment["CHAOSBANK_PROFILE"]

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
