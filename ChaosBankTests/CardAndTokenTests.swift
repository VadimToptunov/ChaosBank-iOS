//
//  CardAndTokenTests.swift
//  ChaosBankTests
//

import XCTest
@testable import ChaosBank

@MainActor
final class CardAndTokenTests: XCTestCase {

    override func tearDown() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        TokenStore.shared.clear()
        super.tearDown()
    }

    private func configure(_ defects: Set<DefectID>) {
        Defects.configure(BuildConfig(seed: 0, activeDefects: defects, label: "t"))
    }

    // MARK: Card

    func testVirtualCardShowsDistinctNumberByDefault() {
        configure([])
        XCTAssertEqual(CardViewModel().virtualCardNumber, "4000 1234 5678 9010")
    }

    func testVirtualCardShowsRealPanDefect() {
        configure([.virtualCardShowsRealPan])
        XCTAssertEqual(CardViewModel().virtualCardNumber, "4916 2043 1188 4291")
    }

    func testFreezeTogglePersists() {
        configure([])
        let vm = CardViewModel()
        vm.frozen = true
        XCTAssertTrue(vm.frozen)
    }

    func testFreezeInvertDefect() {
        configure([.cardToggleInvert])
        let vm = CardViewModel()
        vm.frozen = true
        XCTAssertFalse(vm.frozen, "reads back inverted")
    }

    func testOnlinePaymentsInvertDefect() {
        configure([.onlinePaymentsInverted])
        let vm = CardViewModel()
        vm.onlinePayments = true
        XCTAssertFalse(vm.onlinePayments)
    }

    func testPanMasking() {
        configure([])
        XCTAssertTrue(CardViewModel().displayedPAN.hasPrefix("••••"))
        configure([.cardNumberFullyVisible])
        XCTAssertFalse(CardViewModel().displayedPAN.contains("••••"))
    }

    func testCvvHiddenByDefault() {
        configure([])
        XCTAssertNil(CardViewModel().visibleCVV)
        configure([.cardCvvVisible])
        XCTAssertNotNil(CardViewModel().visibleCVV)
    }

    func testPinMasking() {
        configure([])
        XCTAssertEqual(CardViewModel().pinText, "••••")
        configure([.pinShownPlaintext])
        XCTAssertNotEqual(CardViewModel().pinText, "••••")
    }

    func testExpiryInPastDefect() {
        configure([])
        XCTAssertEqual(CardViewModel().expiry, "08/29")
        configure([.cardExpiryInPast])
        XCTAssertEqual(CardViewModel().expiry, "08/20")
    }

    func testLimitZeroError() {
        configure([])
        let vm = CardViewModel()
        vm.monthlyLimitText = "0"
        XCTAssertNotNil(vm.limitError)
        configure([.cardLimitAcceptsZero])
        let buggy = CardViewModel()
        buggy.monthlyLimitText = "0"
        XCTAssertNil(buggy.limitError)
    }

    // MARK: TokenStore

    func testTokenInKeychainByDefault() {
        configure([])
        TokenStore.shared.saveSessionToken("abc")
        XCTAssertEqual(TokenStore.shared.secureToken, "abc")
        XCTAssertFalse(TokenStore.shared.isTokenInUserDefaults)
        XCTAssertEqual(TokenStore.shared.storageDescription, "Keychain (secure)")
    }

    func testTokenInUserDefaultsDefect() {
        configure([.tokenInUserDefaults])
        TokenStore.shared.saveSessionToken("abc")
        XCTAssertTrue(TokenStore.shared.isTokenInUserDefaults)
        XCTAssertEqual(TokenStore.shared.storageDescription, "UserDefaults (INSECURE)")
    }
}
