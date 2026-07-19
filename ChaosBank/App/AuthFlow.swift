//
//  AuthFlow.swift
//  ChaosBank
//
//  The full mock authentication ladder: login → OTP → passcode setup → unlocked,
//  with a fast passcode/biometric re-entry after background or idle timeout.
//  Every step is mock (no LocalAuthentication, no real credentials) but carries
//  the tester-hostile mechanics — cooldowns, expiry, lockout, timeouts — and
//  hosts several guarded defects.
//

import Foundation
import Observation

enum AuthStage: Equatable {
    case login
    case otp
    case passcodeSetup
    case passcodeEntry
    case unlocked
}

@MainActor
@Observable
final class AuthFlow {
    // Config
    let mockOTP = "424242"
    let otpValidity: TimeInterval = 20
    let resendCooldownSeconds = 30
    let maxOTPAttempts = 3
    let passcodeLength = 6
    let sessionTimeout: TimeInterval = 90

    // Stage
    private(set) var stage: AuthStage = .login

    // Login
    var username = ""
    var password = ""
    var loginError: String?

    // OTP
    var otpEntry = ""
    var otpError: String?
    private(set) var otpAttempts = 0
    private(set) var resendCooldown = 0
    private(set) var otpSecondsLeft = 0
    private var otpGeneratedAt: Date?
    private var otpLocked = false

    // Passcode
    private(set) var storedPasscode: String?
    var passcodeEntry = ""
    var passcodeError: String?

    // Session
    private var lastActiveAt = Date()

    private var ticker: Task<Void, Never>?

    init(startUnlocked: Bool = false) {
        if startUnlocked {
            storedPasscode = "000000"
            stage = .unlocked
            startTicker()
        }
    }

    var isUnlocked: Bool { stage == .unlocked }

    /// Required passcode length. The `passcodeWeakAccepted` defect lowers it so a
    /// short passcode is accepted against policy.
    var requiredPasscodeLength: Int {
        Defects.isActive(.passcodeWeakAccepted) ? 4 : passcodeLength
    }

    // MARK: - Login

    func submitLogin() {
        // `loginAcceptsEmptyCreds`: skip the non-empty check.
        if !Defects.isActive(.loginAcceptsEmptyCreds) {
            guard !username.trimmingCharacters(in: .whitespaces).isEmpty,
                  !password.isEmpty else {
                loginError = "Enter a username and password"
                return
            }
        }
        // `credentialsInLog`: leak the credentials to the console.
        if Defects.isActive(.credentialsInLog) {
            print("[ChaosBank] login user=\(username) pass=\(password)")
        }
        loginError = nil
        startOTP()
    }

    /// Completes login from the web sheet's JS bridge, then continues to OTP.
    func completeWebLogin(username: String, password: String) {
        self.username = username
        self.password = password
        submitLogin()
    }

    // MARK: - OTP

    private func startOTP() {
        // `otpAutoFillsCode`: the field is pre-filled with the real code.
        otpEntry = Defects.isActive(.otpAutoFillsCode) ? mockOTP : ""
        otpError = nil
        otpAttempts = 0
        otpLocked = false
        otpGeneratedAt = Date()
        resendCooldown = resendCooldownSeconds
        otpSecondsLeft = Int(otpValidity)
        // `otpCodeInLog`: the one-time code is leaked to the console log.
        if Defects.isActive(.otpCodeInLog) {
            print("[ChaosBank] OTP code: \(mockOTP)")
        }
        stage = .otp
        startTicker()
    }

    private var otpExpired: Bool {
        guard let generatedAt = otpGeneratedAt else { return true }
        return Date().timeIntervalSince(generatedAt) > otpValidity
    }

    func verifyOTP() {
        // Lockout after too many wrong attempts.
        if otpLocked && !Defects.isActive(.otpNoLockout) {
            otpError = "Too many attempts — locked. Resend a new code."
            return
        }

        // Expiry.
        if otpExpired && !Defects.isActive(.otpAcceptsExpired) {
            otpError = "Code expired — request a new one."
            return
        }

        // `otpAcceptsAnyCode`: any entered code is treated as correct.
        guard otpEntry == mockOTP || Defects.isActive(.otpAcceptsAnyCode) else {
            otpAttempts += 1
            if otpAttempts >= maxOTPAttempts { otpLocked = true }
            otpError = "Incorrect code (\(otpAttempts)/\(maxOTPAttempts))"
            return
        }

        otpError = nil
        stopTicker()
        // First run sets a passcode; afterwards go straight in.
        stage = storedPasscode == nil ? .passcodeSetup : .unlocked
        if stage == .unlocked { markUnlocked() }
    }

    func resendOTP() {
        // Correct: blocked until the cooldown elapses. `otpResendNoCooldown`
        // defect lets it fire during the cooldown.
        if resendCooldown > 0 && !Defects.isActive(.otpResendNoCooldown) { return }
        otpGeneratedAt = Date()
        otpEntry = ""
        otpError = nil
        otpAttempts = 0
        otpLocked = false
        resendCooldown = resendCooldownSeconds
        otpSecondsLeft = Int(otpValidity)
    }

    var canResend: Bool {
        resendCooldown == 0 || Defects.isActive(.otpResendNoCooldown)
    }

    // MARK: - Passcode

    func setPasscode() {
        guard passcodeEntry.count >= requiredPasscodeLength else {
            passcodeError = "Passcode must be \(requiredPasscodeLength) digits"
            return
        }
        storedPasscode = String(passcodeEntry.prefix(requiredPasscodeLength))
        // `passcodeStoredPlaintext`: persist the passcode in UserDefaults.
        if Defects.isActive(.passcodeStoredPlaintext) {
            UserDefaults.standard.set(storedPasscode, forKey: "chaosbank.passcode")
        }
        passcodeEntry = ""
        passcodeError = nil
        markUnlocked()
        stage = .unlocked
    }

    func submitPasscode() {
        // `passcodeAnyAccepted`: any entered passcode unlocks.
        guard passcodeEntry == storedPasscode || Defects.isActive(.passcodeAnyAccepted) else {
            passcodeError = "Wrong passcode"
            passcodeEntry = ""
            return
        }
        passcodeError = nil
        passcodeEntry = ""
        markUnlocked()
        stage = .unlocked
    }

    func unlockWithBiometrics() {
        // Biometrics are a fast RE-ENTRY only (after a session exists). From a fresh
        // login they must not bypass the ladder — unless `biometricUnlocksFromAnyStage`.
        guard stage == .passcodeEntry || Defects.isActive(.biometricUnlocksFromAnyStage) else { return }
        markUnlocked()
        stage = .unlocked
    }

    /// Unlock without any authentication — used ONLY by the `deepLinkSkipsAuth` defect
    /// when a deep link arrives (see ChaosBankApp).
    func forceUnlock() {
        markUnlocked()
        stage = .unlocked
    }

    // MARK: - Session / lifecycle

    func keepAlive() { lastActiveAt = Date() }

    private func markUnlocked() {
        lastActiveAt = Date()
        // Issue and persist a session token (Keychain vs UserDefaults — see the
        // `tokenInUserDefaults` defect).
        TokenStore.shared.saveSessionToken("sess-\(username.isEmpty ? "user" : username)-\(Int(Date().timeIntervalSince1970))")
        startTicker()
    }

    /// Re-lock when going to the background.
    ///
    /// Correct: a sensitive app requires re-auth on return (passcode/biometric).
    /// The `authBypass` defect skips the re-lock entirely.
    func handleBackground() {
        guard stage == .unlocked else { return }
        if Defects.isActive(.authBypass) { return }
        stage = storedPasscode == nil ? .login : .passcodeEntry
    }

    /// Idle timeout while foregrounded.
    ///
    /// Correct: after `sessionTimeout` of inactivity the session re-locks. The
    /// `sessionTimeoutDisabled` defect never re-locks.
    private func checkIdleTimeout() {
        guard stage == .unlocked else { return }
        if Defects.isActive(.sessionTimeoutDisabled) { return }
        if Date().timeIntervalSince(lastActiveAt) > sessionTimeout {
            stage = storedPasscode == nil ? .login : .passcodeEntry
        }
    }

    // MARK: - Ticker

    private func startTicker() {
        guard ticker == nil else { return }
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                if self.resendCooldown > 0 { self.resendCooldown -= 1 }
                if self.otpSecondsLeft > 0 { self.otpSecondsLeft -= 1 }
                self.checkIdleTimeout()
            }
        }
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }
}
