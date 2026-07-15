//
//  AuthFlowEdgeTests.swift
//  ChaosBankTests
//
//  Branch coverage for the auth ladder beyond the happy path.
//

import XCTest
@testable import ChaosBank

@MainActor
final class AuthFlowEdgeTests: XCTestCase {

    override func tearDown() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        super.tearDown()
    }

    private func configure(_ defects: Set<DefectID>) {
        Defects.configure(BuildConfig(seed: 0, activeDefects: defects, label: "t"))
    }

    private func toOTP(_ f: AuthFlow) { f.username = "u"; f.password = "p"; f.submitLogin() }

    func testResendBlockedDuringCooldownThenAllowed() {
        configure([])
        let f = AuthFlow()
        toOTP(f)
        XCTAssertFalse(f.canResend)
        f.otpEntry = "123"
        f.resendOTP()                 // blocked → no reset
        XCTAssertEqual(f.otpEntry, "123")
    }

    func testResendNoCooldownDefect() {
        configure([.otpResendNoCooldown])
        let f = AuthFlow()
        toOTP(f)
        XCTAssertTrue(f.canResend)
        f.otpEntry = "123"
        f.resendOTP()                 // allowed → clears entry
        XCTAssertEqual(f.otpEntry, "")
    }

    func testOtpAutoFillsCodeDefect() {
        configure([.otpAutoFillsCode])
        let f = AuthFlow()
        toOTP(f)
        XCTAssertEqual(f.otpEntry, f.mockOTP)
    }

    func testCredentialAndOtpLoggingDefectsRunCleanly() {
        // Exercises the logging branches (side-effect only); flow still advances.
        configure([.credentialsInLog, .otpCodeInLog])
        let f = AuthFlow()
        toOTP(f)
        XCTAssertEqual(f.stage, .otp)
    }

    func testWrongThenCorrectOtpAdvances() {
        configure([])
        let f = AuthFlow()
        toOTP(f)
        f.otpEntry = "000000"; f.verifyOTP()
        XCTAssertNotNil(f.otpError)
        f.otpEntry = f.mockOTP; f.verifyOTP()
        XCTAssertEqual(f.stage, .passcodeSetup)
    }

    func testPasscodeSetupRejectsShort() {
        configure([])
        let f = AuthFlow()
        toOTP(f); f.otpEntry = f.mockOTP; f.verifyOTP()
        f.passcodeEntry = "12"
        f.setPasscode()
        XCTAssertNotNil(f.passcodeError)
        XCTAssertEqual(f.stage, .passcodeSetup)
    }

    func testWrongPasscodeOnEntry() {
        configure([])
        let f = AuthFlow()
        toOTP(f); f.otpEntry = f.mockOTP; f.verifyOTP()
        f.passcodeEntry = "123456"; f.setPasscode()
        f.handleBackground()
        f.passcodeEntry = "000000"; f.submitPasscode()
        XCTAssertEqual(f.stage, .passcodeEntry)
        XCTAssertNotNil(f.passcodeError)
    }

    func testBackgroundNoOpWhenAlreadyLocked() {
        configure([])
        let f = AuthFlow()
        XCTAssertEqual(f.stage, .login)
        f.handleBackground()          // guard: only re-locks when unlocked
        XCTAssertEqual(f.stage, .login)
    }

    func testKeepAliveAndBiometrics() {
        configure([])
        let f = AuthFlow()
        toOTP(f); f.otpEntry = f.mockOTP; f.verifyOTP()
        f.passcodeEntry = "123456"; f.setPasscode()
        f.handleBackground()
        f.keepAlive()
        f.unlockWithBiometrics()
        XCTAssertTrue(f.isUnlocked)
    }

    func testPasscodeStoredPlaintextDefect() {
        configure([.passcodeStoredPlaintext])
        let f = AuthFlow()
        toOTP(f); f.otpEntry = f.mockOTP; f.verifyOTP()
        f.passcodeEntry = "123456"; f.setPasscode()
        XCTAssertEqual(UserDefaults.standard.string(forKey: "chaosbank.passcode"), "123456")
        UserDefaults.standard.removeObject(forKey: "chaosbank.passcode")
    }
}
