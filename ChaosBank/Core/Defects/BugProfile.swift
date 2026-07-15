//
//  BugProfile.swift
//  ChaosBank
//
//  Named bug profiles — the "one build, many training tasks" surface. A profile
//  activates a set of defects and pins the RNG seed so races reproduce. Most
//  profiles are derived from DefectCategory so they stay in sync with the catalog.
//
//  Select at launch with `-bugProfile <id>` / `CHAOSBANK_PROFILE=<id>`, or switch
//  live in the in-app developer menu.
//

import Foundation

nonisolated struct BugProfile: Identifiable, Sendable {
    let id: String
    let title: String
    let summary: String
    /// Seed pinned for deterministic price walk / race reproduction.
    let seed: Int
    let defects: Set<DefectID>
}

nonisolated enum BugProfiles {
    private static func category(_ id: String, _ title: String, _ c: DefectCategory,
                                 seed: Int = 0) -> BugProfile {
        BugProfile(id: id, title: title,
                   summary: "All \(c.title.lowercased()) defects.",
                   seed: seed, defects: DefectRegistry.ids(in: c))
    }

    static let clean = BugProfile(id: "clean", title: "Clean",
                                  summary: "No defects. Passes the full reference suite.",
                                  seed: 0, defects: [])

    static let all: [BugProfile] = [
        clean,
        category("ui", "UI & layout", .ui),
        category("validation", "Validation", .validation),
        category("accessibility", "Accessibility", .accessibility),
        category("state", "State & navigation", .state),
        category("localization", "Localization", .localization),
        category("security", "Security & privacy", .security),
        category("network", "Networking", .network, seed: 7),
        BugProfile(id: "flaky", title: "Flaky (races)",
                   summary: "Concurrency & race-condition defects. Seed-pinned.",
                   seed: 7, defects: DefectRegistry.ids(in: .concurrency)),
        BugProfile(id: "beginner", title: "Beginner",
                   summary: "A few easy, deterministic defects to start.",
                   seed: 0, defects: [.zeroAmountAccepted, .staleBalance, .cardToggleInvert]),
        BugProfile(id: "middle", title: "Middle",
                   summary: "Validation, pagination, rounding & locale.",
                   seed: 0, defects: [.paginationDup, .localeParse, .roundingDrift, .limitValidation]),
        BugProfile(id: "senior", title: "Senior",
                   summary: "Races, networking & subtle state/security defects.",
                   seed: 7, defects: DefectRegistry.ids(in: .concurrency)
                        .union(DefectRegistry.ids(in: .network))
                        .union([.pnlSign, .authBypass, .slowResponseRace])),
        BugProfile(id: "all", title: "Everything",
                   summary: "Every defect at once.",
                   seed: 7, defects: Set(DefectID.allCases)),
    ]

    static func profile(id: String) -> BugProfile? {
        all.first { $0.id.caseInsensitiveCompare(id) == .orderedSame }
    }
}
