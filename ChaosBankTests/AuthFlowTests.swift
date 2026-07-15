//
//  AuthFlowTests.swift
//  ChaosBankTests
//
//  Exercises the auth ladder state machine and several of its guarded defects.
//

import XCTest
@testable import ChaosBank

@MainActor
final class AuthFlowTests: XCTestCase {

    override func tearDown() {
        configure([])
        super.tearDown()
    }

    private func configure(_ defects: Set<DefectID>) {
        Defects.configure(BuildConfig(seed: 0, activeDefects: defects, label: "t"))
    }

    private func passOTP(_ flow: AuthFlow) {
        flow.username = "demo"; flow.password = "pw"
        flow.submitLogin()
        flow.otpEntry = flow.mockOTP
        flow.verifyOTP()
    }

    func testLoginRequiresCredentials() {
        configure([])
        let f = AuthFlow()
        f.submitLogin()
        XCTAssertEqual(f.stage, .login)
        XCTAssertNotNil(f.loginError)
    }

    func testLoginAcceptsEmptyCredsDefect() {
        configure([.loginAcceptsEmptyCreds])
        let f = AuthFlow()
        f.submitLogin()
        XCTAssertEqual(f.stage, .otp)
    }

    func testCleanPasscodeLengthIsSix() {
        configure([])
        XCTAssertEqual(AuthFlow().requiredPasscodeLength, 6)
    }

    func testWeakPasscodeDefect() {
        configure([.passcodeWeakAccepted])
        XCTAssertEqual(AuthFlow().requiredPasscodeLength, 4)
    }

    func testLockoutBlocksAfterThreeWrong() {
        configure([])
        let f = AuthFlow()
        f.username = "u"; f.password = "p"; f.submitLogin()
        for _ in 0..<3 { f.otpEntry = "000000"; f.verifyOTP() }
        f.otpEntry = f.mockOTP; f.verifyOTP()
        XCTAssertEqual(f.stage, .otp, "locked: correct code no longer works")
    }

    func testOtpNoLockoutDefect() {
        configure([.otpNoLockout])
        let f = AuthFlow()
        f.username = "u"; f.password = "p"; f.submitLogin()
        for _ in 0..<3 { f.otpEntry = "000000"; f.verifyOTP() }
        f.otpEntry = f.mockOTP; f.verifyOTP()
        XCTAssertEqual(f.stage, .passcodeSetup)
    }

    func testOtpAcceptsAnyCodeDefect() {
        configure([.otpAcceptsAnyCode])
        let f = AuthFlow()
        f.username = "u"; f.password = "p"; f.submitLogin()
        f.otpEntry = "111111"; f.verifyOTP()
        XCTAssertEqual(f.stage, .passcodeSetup)
    }

    func testBackgroundRelocksToPasscode() {
        configure([])
        let f = AuthFlow()
        passOTP(f)
        f.passcodeEntry = "123456"; f.setPasscode()
        XCTAssertEqual(f.stage, .unlocked)
        f.handleBackground()
        XCTAssertEqual(f.stage, .passcodeEntry)
    }

    func testAuthBypassStaysUnlocked() {
        configure([.authBypass])
        let f = AuthFlow()
        passOTP(f)
        f.passcodeEntry = "123456"; f.setPasscode()
        f.handleBackground()
        XCTAssertEqual(f.stage, .unlocked)
    }

    func testPasscodeAnyAcceptedDefect() {
        configure([.passcodeAnyAccepted])
        let f = AuthFlow()
        passOTP(f)
        f.passcodeEntry = "123456"; f.setPasscode()   // sets stored passcode
        f.handleBackground()
        f.passcodeEntry = "999999"; f.submitPasscode() // wrong, but accepted
        XCTAssertEqual(f.stage, .unlocked)
    }

    func testStartUnlockedBypassesLadder() {
        configure([])
        XCTAssertTrue(AuthFlow(startUnlocked: true).isUnlocked)
    }
}
