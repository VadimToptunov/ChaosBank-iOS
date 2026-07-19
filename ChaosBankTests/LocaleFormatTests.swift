//
//  LocaleFormatTests.swift
//  ChaosBankTests
//

import XCTest
@testable import ChaosBank

@MainActor
final class LocaleFormatTests: XCTestCase {
    private let value = Decimal(string: "1234567.89")!

    override func tearDown() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        super.tearDown()
    }

    func testEnUsUsesCommaAndDot() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        XCTAssertEqual(LocaleFormat.grouped(value, locale: .enUS), "1,234,567.89")
    }

    func testDeDeUsesDotAndComma() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        XCTAssertEqual(LocaleFormat.grouped(value, locale: .deDE), "1.234.567,89")
    }

    func testDefectAlwaysUsesEnUsRegardlessOfLocale() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [.numberGroupingIgnoresLocale], label: "t"))
        XCTAssertEqual(LocaleFormat.grouped(value, locale: .deDE), "1,234,567.89")
        XCTAssertEqual(LocaleFormat.grouped(value, locale: .enUS), "1,234,567.89")
    }

    func testLocaleIdFromParsesNames() {
        XCTAssertEqual(LocaleId.from("deDE"), .deDE)
        XCTAssertEqual(LocaleId.from(nil), .enUS)
        XCTAssertEqual(LocaleId.from("nope"), .enUS)
    }
}
