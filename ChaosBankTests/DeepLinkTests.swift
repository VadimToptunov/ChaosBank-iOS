//
//  DeepLinkTests.swift
//  ChaosBankTests
//

import XCTest
@testable import ChaosBank

final class DeepLinkTests: XCTestCase {
    func testParsesTabHosts() {
        XCTAssertEqual(DeepLink.tabIndex("chaosbank://markets"), 1)
        XCTAssertEqual(DeepLink.tabIndex("chaosbank://portfolio"), 2)
        XCTAssertEqual(DeepLink.tabIndex("chaosbank://home"), 0)
        XCTAssertEqual(DeepLink.tabIndex("CHAOSBANK://CARD"), 3)
    }

    func testIgnoresUnknownAndWrongScheme() {
        XCTAssertNil(DeepLink.tabIndex("chaosbank://nope"))
        XCTAssertNil(DeepLink.tabIndex("https://markets"))
        XCTAssertNil(DeepLink.tabIndex(nil))
        XCTAssertFalse(DeepLink.isPresent("chaosbank://nope"))
        XCTAssertFalse(DeepLink.isPresent(nil))
    }

    func testStripsPathAndQuery() {
        XCTAssertEqual(DeepLink.tabIndex("chaosbank://markets/AAPL?x=1"), 1)
    }

    func testIsPresentForRouteHosts() {
        XCTAssertTrue(DeepLink.isPresent("chaosbank://transfer"))
        XCTAssertTrue(DeepLink.isPresent("chaosbank://markets"))
    }

    func testBypassesAuthOnlyWithDefectAndDeepLink() {
        XCTAssertTrue(DeepLink.bypassesAuth("chaosbank://markets", defectActive: true))
        XCTAssertFalse(DeepLink.bypassesAuth("chaosbank://markets", defectActive: false))
        XCTAssertFalse(DeepLink.bypassesAuth(nil, defectActive: true))
        XCTAssertFalse(DeepLink.bypassesAuth("chaosbank://nope", defectActive: true))
    }
}
