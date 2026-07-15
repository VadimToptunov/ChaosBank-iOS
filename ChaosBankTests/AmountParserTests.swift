//
//  AmountParserTests.swift
//  ChaosBankTests
//

import XCTest
@testable import ChaosBank

@MainActor
final class AmountParserTests: XCTestCase {

    private let en = Locale(identifier: "en_US")

    override func tearDown() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        super.tearDown()
    }

    func testCleanParse() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        XCTAssertEqual(AmountParser.parse("1,000.50", locale: en), Decimal(string: "1000.50"))
        XCTAssertEqual(AmountParser.parse("42", locale: en), Decimal(42))
        XCTAssertNil(AmountParser.parse("", locale: en))
    }

    func testLocaleParseDefectMisparses() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [.localeParse], label: "t"))
        let value = AmountParser.parse("1,000.50", locale: en)
        XCTAssertNotEqual(value, Decimal(string: "1000.50"))
        XCTAssertEqual(value, Decimal(string: "1.00050"))
    }
}
