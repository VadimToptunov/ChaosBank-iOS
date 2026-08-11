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
//    -ChaosBankInspectableWeb 1
//

import Foundation

nonisolated struct LaunchOptions: Sendable {
    let startUnlocked: Bool
    let initialTab: Int
    let showDevMenu: Bool
    let showWebLogin: Bool
    /// Render the ported screens with **UIKit** (UITableView/UIViewController)
    /// instead of SwiftUI — the "views build". Enabled by `-ChaosBankUIKit 1`, by
    /// the `CHAOSBANK_UIKIT` env var, or baked in via the `CHAOSBANK_UIKIT` compile
    /// flag (a distributable build configuration, read in this one place).
    let uiKit: Bool
    /// Mark the web-login `WKWebView` as **inspectable** (`-ChaosBankInspectableWeb 1`,
    /// iOS 16.4+). Off by default, so the web login stays an opaque hybrid — tests
    /// must reach its fields through the native tree (WebView "Mode 1"). Turned on,
    /// the WKWebView exposes a WEBVIEW automation context, so Appium/Chromedriver can
    /// `switch_to.context(WEBVIEW_…)` and walk the DOM (WebView "Mode 2").
    let inspectableWeb: Bool

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
        var uiKit = flag("ChaosBankUIKit", "CHAOSBANK_UIKIT")
        #if CHAOSBANK_UIKIT
        uiKit = true
        #endif
        return LaunchOptions(
            startUnlocked: flag("ChaosBankStartUnlocked", "CHAOSBANK_START_UNLOCKED"),
            initialTab: tab,
            showDevMenu: flag("ChaosBankShowDev", "CHAOSBANK_SHOW_DEV"),
            showWebLogin: flag("ChaosBankShowWebLogin", "CHAOSBANK_SHOW_WEB_LOGIN"),
            uiKit: uiKit,
            inspectableWeb: flag("ChaosBankInspectableWeb", "CHAOSBANK_INSPECTABLE_WEB")
        )
    }
}
