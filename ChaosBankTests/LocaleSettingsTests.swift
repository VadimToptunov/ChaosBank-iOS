//
//  LocaleSettingsTests.swift
//  ChaosBankTests
//

import XCTest
@testable import ChaosBank

@MainActor
final class LocaleSettingsTests: XCTestCase {
    override func tearDown() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        super.tearDown()
    }

    func testEnableRtlUpdatesFlag() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        let locale = LocaleSettings()
        XCTAssertFalse(locale.rtl)
        locale.enableRtl(true)
        XCTAssertTrue(locale.rtl)
    }

    func testCleanNeverForcesLtr() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        XCTAssertFalse(LocaleSettings.forcesLtrRow(rtl: true))
        XCTAssertFalse(LocaleSettings.forcesLtrRow(rtl: false))
    }

    func testRtlBreaksLayoutForcesLtrOnlyWhenRtl() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [.rtlBreaksLayout], label: "t"))
        XCTAssertTrue(LocaleSettings.forcesLtrRow(rtl: true))
        XCTAssertFalse(LocaleSettings.forcesLtrRow(rtl: false))
    }
}
