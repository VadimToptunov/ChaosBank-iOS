//
//  TokenStore.swift
//  ChaosBank
//
//  Where the session token lives. The correct path keeps it in a mock "Keychain"
//  (in memory here). The `tokenInUserDefaults` defect also writes it to
//  UserDefaults, where it is trivially readable — a classic mobile security bug.
//

import Foundation

@MainActor
final class TokenStore {
    static let shared = TokenStore()

    static let userDefaultsKey = "chaosbank.session.token"

    /// The mock secure store (stands in for the Keychain).
    private(set) var secureToken: String?

    private init() {}

    func saveSessionToken(_ token: String) {
        secureToken = token
        if Defects.isActive(.tokenInUserDefaults) {
            UserDefaults.standard.set(token, forKey: Self.userDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.userDefaultsKey)
        }
    }

    func clear() {
        secureToken = nil
        UserDefaults.standard.removeObject(forKey: Self.userDefaultsKey)
    }

    var isTokenInUserDefaults: Bool {
        UserDefaults.standard.string(forKey: Self.userDefaultsKey) != nil
    }

    var storageDescription: String {
        isTokenInUserDefaults ? "UserDefaults (INSECURE)" : "Keychain (secure)"
    }
}
