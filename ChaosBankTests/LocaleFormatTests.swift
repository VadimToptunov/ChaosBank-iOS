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

    func testMoneySymbolPlacementFollowsLocale() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        let amount = Decimal(string: "1234.56")!
        XCTAssertTrue(LocaleFormat.money(amount, currencyCode: "EUR", locale: .enUS)
            .trimmingCharacters(in: .whitespaces).hasPrefix("€"))
        XCTAssertTrue(LocaleFormat.money(amount, currencyCode: "EUR", locale: .deDE)
            .trimmingCharacters(in: .whitespaces).hasSuffix("€"))
    }

    func testCurrencyPlacementDefectAlwaysEnUsStyle() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [.currencySymbolPlacementIgnoresLocale], label: "t"))
        let amount = Decimal(string: "1234.56")!
        XCTAssertTrue(LocaleFormat.money(amount, currencyCode: "EUR", locale: .deDE)
            .trimmingCharacters(in: .whitespaces).hasPrefix("€"))
    }

    func testLocaleIdTitlesAndLocalesCoverEveryCase() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        XCTAssertEqual(LocaleId.allCases.map(\.title), ["en-US", "de-DE", "ar"])
        // Exercise every foundationLocale (incl. ar) through both formatters.
        for id in LocaleId.allCases {
            XCTAssertFalse(LocaleFormat.grouped(value, locale: id).isEmpty)
            XCTAssertFalse(LocaleFormat.money(Decimal(string: "1234.56")!, currencyCode: "EUR", locale: id).isEmpty)
        }
    }
}
