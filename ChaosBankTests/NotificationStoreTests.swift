//
//  NotificationStoreTests.swift
//  ChaosBankTests
//

import XCTest
@testable import ChaosBank

@MainActor
final class NotificationStoreTests: XCTestCase {
    override func tearDown() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        super.tearDown()
    }

    private func configure(_ defects: Set<DefectID> = []) {
        Defects.configure(BuildConfig(seed: 0, activeDefects: defects, label: "t"))
    }

    func testCleanBadgeClearsAfterReading() {
        configure()
        let store = NotificationStore()
        XCTAssertGreaterThan(store.unreadCount, 0)
        store.markAllRead()
        XCTAssertEqual(store.unreadCount, 0)
    }

    func testBadgeStaleKeepsOriginalCount() {
        configure([.notificationBadgeStale])
        let store = NotificationStore()
        let before = store.unreadCount
        store.markAllRead()
        XCTAssertEqual(store.unreadCount, before)
        XCTAssertGreaterThan(store.unreadCount, 0)
    }

    func testCleanTargetIsStatedRoute() {
        configure()
        let store = NotificationStore()
        let n = store.items.first { $0.target == .transactions }!
        XCTAssertEqual(store.target(n), .transactions)
    }

    func testOpensWrongScreenTargetDiffers() {
        configure([.notificationOpensWrongScreen])
        let store = NotificationStore()
        let n = store.items.first { $0.target == .transactions }!
        XCTAssertNotEqual(store.target(n), n.target)
    }
}
