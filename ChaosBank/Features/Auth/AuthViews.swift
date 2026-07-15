//
//  AuthViews.swift
//  ChaosBank
//
//  The auth-ladder screens: Login → OTP → Passcode (setup/entry) with a biometric
//  fallback. Shown by RootView whenever the flow is not unlocked.
//

import SwiftUI

struct AuthContainerView: View {
    @Environment(AuthFlow.self) private var auth

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            switch auth.stage {
            case .login: LoginView()
            case .otp: OTPView()
            case .passcodeSetup: PasscodeView(mode: .setup)
            case .passcodeEntry: PasscodeView(mode: .entry)
            case .unlocked: EmptyView()
            }
        }
        .accessibilityIdentifier(A11y.Auth.gate)
    }
}

// MARK: - Login

private struct LoginView: View {
    @Environment(AuthFlow.self) private var auth
    @State private var showWebLogin = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            brand
            Spacer()
            if let error = auth.loginError {
                Text(error).font(.appBody(13, weight: .medium)).foregroundStyle(Palette.loss)
                    .accessibilityIdentifier(A11y.Auth.loginError)
            }
            PrimaryButton(title: "Log in", systemImage: "globe") { showWebLogin = true }
                .accessibilityIdentifier(A11y.Auth.webLoginButton)
            Text("Sign in opens a secure web page")
                .font(.appBody(11)).foregroundStyle(Palette.muted)
            Spacer().frame(height: 12)
        }
        .padding(24)
        .accessibilityIdentifier(A11y.Auth.loginRoot)
        .onAppear {
            if LaunchOptions.current.showWebLogin { showWebLogin = true }
        }
        .sheet(isPresented: $showWebLogin) {
            WebLoginSheet { username, password in
                showWebLogin = false
                auth.completeWebLogin(username: username, password: password)
            }
        }
    }

    private var brand: some View {
        VStack(spacing: 6) {
            Image(systemName: "building.columns.fill")
                .font(.system(size: 44)).foregroundStyle(Palette.sand)
            Text("ChaosBank").font(.appDisplay(28, weight: .bold)).foregroundStyle(Palette.text)
            Text("Welcome back").font(.appBody(14)).foregroundStyle(Palette.muted)
        }
    }
}

// MARK: - OTP

private struct OTPView: View {
    @Environment(AuthFlow.self) private var auth

    var body: some View {
        @Bindable var auth = auth
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 40)).foregroundStyle(Palette.sand)
            Text("Enter the code").font(.appDisplay(24, weight: .bold)).foregroundStyle(Palette.text)
            Text("We sent a 6-digit code to your device.")
                .font(.appBody(13)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)

            TextField("000000", text: $auth.otpEntry)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.appMono(30, weight: .bold))
                .foregroundStyle(Palette.text)
                .padding(.vertical, 12)
                .background(Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityIdentifier(A11y.Auth.otpField)
                .onChange(of: auth.otpEntry) { _, value in
                    let digits = String(value.filter(\.isNumber).prefix(6))
                    if digits != value { auth.otpEntry = digits }
                    if digits.count == 6 { auth.verifyOTP() }
                }

            Text(auth.otpSecondsLeft > 0 ? "Code expires in \(auth.otpSecondsLeft)s" : "Code expired")
                .font(.appBody(12))
                .foregroundStyle(auth.otpSecondsLeft > 0 ? Palette.muted : Palette.loss)
                .accessibilityIdentifier(A11y.Auth.otpExpiry)

            if let error = auth.otpError {
                Text(error).font(.appBody(13, weight: .medium)).foregroundStyle(Palette.loss)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier(A11y.Auth.otpError)
            }

            PrimaryButton(title: "Verify") { auth.verifyOTP() }
                .accessibilityIdentifier(A11y.Auth.otpSubmit)

            Button {
                auth.resendOTP()
            } label: {
                Text(auth.canResend ? "Resend code" : "Resend in \(auth.resendCooldown)s")
                    .font(.appBody(14, weight: .semibold))
                    .foregroundStyle(auth.canResend ? Palette.sand : Palette.muted)
            }
            .disabled(!auth.canResend)
            .accessibilityIdentifier(A11y.Auth.otpResend)

            Text("Dev code: \(auth.mockOTP)")
                .font(.appMono(11)).foregroundStyle(Palette.muted)
                .accessibilityIdentifier(A11y.Auth.otpHint)
            Spacer()
        }
        .padding(24)
        .accessibilityIdentifier(A11y.Auth.otpRoot)
    }
}

// MARK: - Passcode

private struct PasscodeView: View {
    enum Mode { case setup, entry }
    let mode: Mode

    @Environment(AuthFlow.self) private var auth

    private var targetLength: Int {
        switch mode {
        case .setup: return auth.requiredPasscodeLength
        case .entry: return auth.storedPasscode?.count ?? auth.passcodeLength
        }
    }

    var body: some View {
        @Bindable var auth = auth
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 40)).foregroundStyle(Palette.sand)
            Text(mode == .setup ? "Create a passcode" : "Enter passcode")
                .font(.appDisplay(24, weight: .bold)).foregroundStyle(Palette.text)

            dots(count: auth.passcodeEntry.count)

            TextField("", text: $auth.passcodeEntry)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.appMono(24, weight: .bold))
                .foregroundStyle(Palette.text)
                .padding(.vertical, 10)
                .background(Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityIdentifier(A11y.Auth.passcodeField)
                .onChange(of: auth.passcodeEntry) { _, value in
                    let digits = String(value.filter(\.isNumber).prefix(max(targetLength, 6)))
                    if digits != value { auth.passcodeEntry = digits }
                    if digits.count >= targetLength { submit() }
                }

            if let error = auth.passcodeError {
                Text(error).font(.appBody(13, weight: .medium)).foregroundStyle(Palette.loss)
                    .accessibilityIdentifier(A11y.Auth.passcodeError)
            }

            PrimaryButton(title: mode == .setup ? "Set passcode" : "Unlock") { submit() }
                .accessibilityIdentifier(A11y.Auth.passcodeSubmit)

            if mode == .entry {
                Button { auth.unlockWithBiometrics() } label: {
                    Label("Unlock with Face ID", systemImage: "faceid")
                        .font(.appBody(15, weight: .semibold)).foregroundStyle(Palette.sand)
                }
                .accessibilityIdentifier(A11y.Auth.biometricButton)
            }

            Text(mode == .setup ? "\(auth.requiredPasscodeLength) digits" : " ")
                .font(.appBody(11)).foregroundStyle(Palette.muted)
            Spacer()
        }
        .padding(24)
        .accessibilityIdentifier(A11y.Auth.passcodeRoot)
    }

    private func submit() {
        switch mode {
        case .setup: auth.setPasscode()
        case .entry: auth.submitPasscode()
        }
    }

    private func dots(count: Int) -> some View {
        HStack(spacing: 14) {
            ForEach(0..<targetLength, id: \.self) { index in
                Circle()
                    .fill(index < count ? Palette.sand : Palette.surface2)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Palette.line, lineWidth: 1))
            }
        }
    }
}
