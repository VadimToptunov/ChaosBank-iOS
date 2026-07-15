//
//  DefectCatalogTests.swift
//  ChaosBankTests
//
//  The catalog is the backbone: every DefectID must have a registry entry, the
//  profiles must derive from the categories, and every defect must have an
//  exercise. A gap here would crash the dev menu / exercises at runtime.
//

import XCTest
@testable import ChaosBank

final class DefectCatalogTests: XCTestCase {

    func testEveryDefectHasExactlyOneRegistryEntry() {
        XCTAssertEqual(DefectRegistry.all.count, DefectID.allCases.count)
        XCTAssertEqual(Set(DefectRegistry.all.map(\.id)).count, DefectID.allCases.count)
    }

    func testCategoryCountsSumToTotal() {
        let sum = DefectCategory.allCases.reduce(0) { $0 + DefectRegistry.ids(in: $1).count }
        XCTAssertEqual(sum, DefectID.allCases.count)
    }

    func testProfilesDeriveFromCategories() {
        XCTAssertEqual(BugProfiles.profile(id: "security")?.defects, DefectRegistry.ids(in: .security))
        XCTAssertEqual(BugProfiles.profile(id: "network")?.defects, DefectRegistry.ids(in: .network))
        XCTAssertEqual(BugProfiles.profile(id: "validation")?.defects, DefectRegistry.ids(in: .validation))
        XCTAssertEqual(BugProfiles.profile(id: "clean")?.defects, [])
        XCTAssertEqual(BugProfiles.profile(id: "all")?.defects, Set(DefectID.allCases))
    }

    func testExercisesCoverEveryDefect() {
        XCTAssertEqual(Exercises.all.count, DefectID.allCases.count)
        let covered = Set(Exercises.all.flatMap { $0.defects })
        XCTAssertEqual(covered, Set(DefectID.allCases.map(\.rawValue)))
        XCTAssertEqual(Set(Exercises.all.map(\.id)).count, Exercises.all.count, "exercise ids are unique")
    }

    func testSeedMapping() {
        XCTAssertTrue(DefectRegistry.defects(forSeed: 0).isEmpty)
        XCTAssertEqual(DefectRegistry.defects(forSeed: 99), Set(DefectID.allCases))
        XCTAssertEqual(DefectRegistry.defects(forSeed: 1), [DefectID.allCases[0]])
    }
}
