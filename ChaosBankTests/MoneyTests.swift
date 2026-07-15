//
//  MoneyTests.swift
//  ChaosBankTests
//

import XCTest
@testable import ChaosBank

final class MoneyTests: XCTestCase {

    func testBankersRounding() {
        XCTAssertEqual(Decimal(string: "1.005")!.roundedMoney(), Decimal(string: "1.00")!)
        XCTAssertEqual(Decimal(string: "1.015")!.roundedMoney(), Decimal(string: "1.02")!)
        XCTAssertEqual(Decimal(string: "2.5")!.rounded(scale: 0), Decimal(string: "2")!)
        XCTAssertEqual(Decimal(string: "3.5")!.rounded(scale: 0), Decimal(string: "4")!)
    }

    func testFormatted() {
        XCTAssertEqual(Money(Decimal(string: "1234.5")!, .EUR).formatted, "€1,234.50")
        XCTAssertEqual(Money(Decimal(string: "12750")!, .USD).formatted, "$12,750.00")
        XCTAssertEqual(Money(Decimal(string: "640.2")!, .GBP).formatted, "£640.20")
    }

    func testFormattedSigned() {
        XCTAssertTrue(Money(Decimal(50), .EUR).formattedSigned.hasPrefix("+"))
        XCTAssertTrue(Money(Decimal(-50), .EUR).formattedSigned.hasPrefix("\u{2212}")) // minus sign
    }

    func testPercent() {
        XCTAssertEqual(MoneyFormat.percent(Decimal(string: "0.40")!), "+0.40%")
        XCTAssertEqual(MoneyFormat.percent(Decimal(string: "-1.17")!), "\u{2212}1.17%")
    }

    func testMoneyArithmetic() {
        let m = Money(Decimal(100), .EUR)
        XCTAssertEqual(m.subtracting(Decimal(30)).amount, Decimal(70))
        XCTAssertEqual(m.adding(Decimal(30)).amount, Decimal(130))
    }
}
