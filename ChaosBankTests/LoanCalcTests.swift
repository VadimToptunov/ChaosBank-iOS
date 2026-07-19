//
//  LoanCalcTests.swift
//  ChaosBankTests
//

import XCTest
@testable import ChaosBank

@MainActor
final class LoanCalcTests: XCTestCase {
    override func tearDown() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        super.tearDown()
    }

    func testCleanEffectiveMatchesDisplayedApr() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        XCTAssertEqual(LoanCalc.displayedApr(), LoanCalc.effectiveApr())
    }

    func testLoanAprUnderstatedEffectiveExceedsDisplayed() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [.loanAprUnderstated], label: "t"))
        XCTAssertGreaterThan(LoanCalc.effectiveApr(), LoanCalc.displayedApr())
    }

    func testLoanAprUnderstatedRaisesMonthlyPayment() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        let cleanPayment = LoanCalc.monthlyPayment()
        Defects.configure(BuildConfig(seed: 0, activeDefects: [.loanAprUnderstated], label: "t"))
        XCTAssertGreaterThan(LoanCalc.monthlyPayment(), cleanPayment)
    }

    func testMonthlyPaymentPositiveAndTotalConsistent() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        let monthly = LoanCalc.monthlyPayment()
        XCTAssertGreaterThan(monthly, 0)
        XCTAssertEqual((monthly * Decimal(LoanCalc.months)).rounded(scale: 2), LoanCalc.totalCost())
    }
}
