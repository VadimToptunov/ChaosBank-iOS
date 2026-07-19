//
//  TemplateStoreTests.swift
//  ChaosBankTests
//

import XCTest
@testable import ChaosBank

@MainActor
final class TemplateStoreTests: XCTestCase {
    override func tearDown() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        super.tearDown()
    }

    func testCleanPrefillsExactAmount() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        let store = TemplateStore()
        let rent = store.templates.first { $0.name == "Rent" }!
        XCTAssertEqual(store.prefillAmount(rent), Decimal(string: "1200.00")!)
    }

    func testTemplatePrefillsWrongAmountDefect() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [.templatePrefillsWrongAmount], label: "t"))
        let store = TemplateStore()
        let rent = store.templates.first { $0.name == "Rent" }!
        XCTAssertGreaterThan(store.prefillAmount(rent), rent.amount)
    }

    func testSeedHasTemplates() {
        XCTAssertEqual(TemplateStore().templates.count, 3)
    }
}
