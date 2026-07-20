//
//  FinalCoverageTests.swift
//  ChaosBankTests
//

import XCTest
@testable import ChaosBank

@MainActor
final class FinalCoverageTests: XCTestCase {

    override func tearDown() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        super.tearDown()
    }

    func testCurrencyAll() {
        for c in Currency.allCases {
            XCTAssertFalse(c.symbol.isEmpty)
            XCTAssertEqual(c.code, c.rawValue)
            XCTAssertEqual(c.id, c.rawValue)
        }
        XCTAssertEqual(Currency.GBP.symbol, "£")
    }

    func testSeedData() {
        XCTAssertEqual(SeedData.accounts.count, 3)
        XCTAssertEqual(SeedData.assets.count, 6)
        XCTAssertFalse(SeedData.watchlistSymbols.isEmpty)
        XCTAssertFalse(SeedData.holdings.isEmpty)
        XCTAssertGreaterThan(SeedData.transactions.count, 10)
        XCTAssertLessThan(SeedData.daysAgo(1), SeedData.referenceDate)
    }

    func testExercisesJSON() {
        let json = Exercises.json()
        XCTAssertTrue(json.contains("IOS-"))
        XCTAssertTrue(json.contains("launchArgument"))
        XCTAssertGreaterThan(json.count, 1000)
        // Guard against the hand-editing bug the parity checker caught: ids are unique.
        let ids = Exercises.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "duplicate exercise ids")
    }

    /// Utility: prints the canonical catalog JSON so Scripts/regenerate_exercises.sh can
    /// capture it (the simulator sandbox can't write to the repo directly).
    func testDumpExercisesCatalog() {
        print("<<<EXERCISES_JSON_BEGIN>>>")
        print(Exercises.json())
        print("<<<EXERCISES_JSON_END>>>")
    }

    func testDefectRegistrySeedOutOfRange() {
        XCTAssertTrue(DefectRegistry.defects(forSeed: 500).isEmpty)
        XCTAssertTrue(DefectRegistry.defects(forSeed: -3).isEmpty)
    }

    func testOrderSellInsufficientHoldingRejected() async {
        let config = BuildConfig(seed: 0, activeDefects: [.sellWithoutHoldingReviewable], label: "t")
        Defects.configure(config)
        let s = AppServices(config: config)
        let m = OrderViewModel(request: OrderRequest(symbol: "MSFT", side: .sell, capturedPrice: 400), services: s)
        await m.load()          // no MSFT holding
        m.quantity = 1
        XCTAssertTrue(m.isValid) // defect lets it be reviewed
        await m.place()
        XCTAssertEqual(m.status, .rejected)
        XCTAssertEqual(m.errorMessage, "Not enough to sell")
    }

    func testBugProfilesLookupUnknown() {
        XCTAssertNil(BugProfiles.profile(id: "does-not-exist"))
        XCTAssertEqual(BugProfiles.profile(id: "FLAKY")?.id, "flaky") // case-insensitive
    }
}
