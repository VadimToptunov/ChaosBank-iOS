//
//  BackendSelectionTests.swift
//  ChaosBankTests
//
//  `-ChaosBankBackend <url>` picks ChaosBank-Server; anything else keeps the embedded
//  mock. No server needed.
//

import XCTest
@testable import ChaosBank

final class BackendSelectionTests: XCTestCase {

    private func emptyDefaults() -> UserDefaults {
        let name = "chaosbank.tests.backend"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    func testAnHttpURLSelectsTheServer() {
        let cfg = BuildConfig.resolve(defaults: emptyDefaults(), environment: ["CHAOSBANK_BACKEND": " http://localhost:8080 "])
        XCTAssertEqual(cfg.backendURL, URL(string: "http://localhost:8080"))
    }

    func testTheLaunchArgumentWinsOverTheEnvironment() {
        let d = emptyDefaults()
        d.set("https://staging.example.test", forKey: "ChaosBankBackend")
        let cfg = BuildConfig.resolve(defaults: d, environment: ["CHAOSBANK_BACKEND": "http://localhost:8080"])
        XCTAssertEqual(cfg.backendURL, URL(string: "https://staging.example.test"))
    }

    func testNoOrNonHttpValueKeepsTheMock() {
        XCTAssertNil(BuildConfig.resolve(defaults: emptyDefaults(), environment: [:]).backendURL)
        XCTAssertNil(BuildConfig.resolve(defaults: emptyDefaults(), environment: ["CHAOSBANK_BACKEND": "localhost:8080"]).backendURL)
    }

    func testServicesBuildTheMatchingBackend() {
        let mock = AppServices(config: BuildConfig(seed: 0, activeDefects: [], label: "t"))
        XCTAssertEqual(mock.backend.label, "Embedded mock")
        let server = AppServices(config: BuildConfig(seed: 0, activeDefects: [], label: "t",
                                                     backendURL: URL(string: "http://localhost:9")))
        XCTAssertTrue(server.backend is HttpBackend)
        XCTAssertEqual(server.backend.label, "Server http://localhost:9")
    }

    func testDefectChangesReachTheBackend() async {
        let s = AppServices(config: BuildConfig(seed: 0, activeDefects: [], label: "t"))
        s.applyDefects([.balanceReadReturnsZero], label: "custom")
        try? await Task.sleep(for: .milliseconds(50))
        let accounts = await s.backend.fetchAccounts()
        XCTAssertTrue(accounts.allSatisfy { $0.balance == 0 }, "the mock's scenario follows the defects")
    }

    func testTheDepositShorthandUsesTheDefaultTitle() async throws {
        let backend: any Backend = MockBackend(latency: .zero)
        let tx = try await backend.deposit(to: .EUR, amount: 5)
        XCTAssertEqual(tx.title, "Add money")
    }
}
