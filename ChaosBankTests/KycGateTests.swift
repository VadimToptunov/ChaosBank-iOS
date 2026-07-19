//
//  KycGateTests.swift
//  ChaosBankTests
//

import XCTest
@testable import ChaosBank

@MainActor
final class KycGateTests: XCTestCase {
    override func tearDown() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        super.tearDown()
    }

    func testVerifiedAllowsAnyAmount() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        XCTAssertTrue(KycGate.allowsTransfer(Decimal(5000), verified: true))
    }

    func testUnverifiedAllowsSmallBlocksLarge() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        XCTAssertTrue(KycGate.allowsTransfer(Decimal(1000), verified: false))
        XCTAssertFalse(KycGate.allowsTransfer(Decimal(2000), verified: false))
    }

    func testKycBypassAllowsLargeWhenUnverified() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [.kycBypassAllowsTransfer], label: "t"))
        XCTAssertTrue(KycGate.allowsTransfer(Decimal(2000), verified: false))
    }

    func testStoreDefaultVerifiedAndToggle() {
        let store = KycStore()
        XCTAssertTrue(store.verified)
        store.applyVerified(false)
        XCTAssertFalse(store.verified)
    }
}
