//
//  DeepLink.swift
//  ChaosBank
//
//  Parses `chaosbank://<host>` deep links into an initial tab. Pure string parsing
//  so it is unit-testable. A deep link normally still passes through the auth gate;
//  the `deepLinkSkipsAuth` defect lets it bypass authentication (see ChaosBankApp).
//
//  NOTE: registering the `chaosbank` URL scheme (Info.plist `CFBundleURLTypes`) is a
//  one-time Xcode project step — the project uses a generated Info.plist. The parsing
//  and the defect below are wired and tested regardless.
//

import Foundation

nonisolated enum DeepLink {
    private static let scheme = "chaosbank://"
    private static let tabs = ["home": 0, "markets": 1, "portfolio": 2, "card": 3]
    private static let routeHosts: Set<String> = ["transfer", "exchange", "addmoney", "transactions"]

    private static func host(_ uri: String?) -> String? {
        guard let uri, uri.lowercased().hasPrefix(scheme) else { return nil }
        let rest = String(uri.dropFirst(scheme.count))
        let h = rest.split(whereSeparator: { $0 == "/" || $0 == "?" }).first.map(String.init) ?? ""
        let lowered = h.lowercased()
        return lowered.isEmpty ? nil : lowered
    }

    static func tabIndex(_ uri: String?) -> Int? {
        guard let h = host(uri) else { return nil }
        return tabs[h]
    }

    /// True when the URI names a known destination (a tab or a pushed screen).
    static func isPresent(_ uri: String?) -> Bool {
        guard let h = host(uri) else { return false }
        return tabs[h] != nil || routeHosts.contains(h)
    }

    /// Whether this deep link should skip the auth gate — only under the defect.
    static func bypassesAuth(_ uri: String?, defectActive: Bool) -> Bool {
        isPresent(uri) && defectActive
    }
}
