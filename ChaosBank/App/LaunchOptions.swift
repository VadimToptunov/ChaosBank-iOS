//
//  LaunchOptions.swift
//  ChaosBank
//
//  Non-defect launch affordances for UI tests, demos and screenshots. These never
//  change behavior of the product paths — they only skip past the auth ladder or
//  deep-link to a screen so a test/screenshot can start where it needs to.
//
//  Examples:
//    -ChaosBankStartUnlocked 1
//    -ChaosBankTab markets
//    -ChaosBankShowDev 1
//    -ChaosBankShowWebLogin 1
//

import Foundation

nonisolated struct LaunchOptions: Sendable {
    let startUnlocked: Bool
    let initialTab: Int
    let showDevMenu: Bool
    let showWebLogin: Bool

    static let current = resolve()

    static func resolve(
        defaults: UserDefaults = .standard,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> LaunchOptions {
        func flag(_ key: String, _ env: String) -> Bool {
            defaults.bool(forKey: key) || environment[env] == "1"
        }
        let tabRaw = (defaults.string(forKey: "ChaosBankTab") ?? environment["CHAOSBANK_TAB"] ?? "home").lowercased()
        let tab = ["home": 0, "markets": 1, "portfolio": 2, "card": 3][tabRaw] ?? 0
        return LaunchOptions(
            startUnlocked: flag("ChaosBankStartUnlocked", "CHAOSBANK_START_UNLOCKED"),
            initialTab: tab,
            showDevMenu: flag("ChaosBankShowDev", "CHAOSBANK_SHOW_DEV"),
            showWebLogin: flag("ChaosBankShowWebLogin", "CHAOSBANK_SHOW_WEB_LOGIN")
        )
    }
}
