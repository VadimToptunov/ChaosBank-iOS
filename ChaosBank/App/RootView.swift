//
//  RootView.swift
//  ChaosBank
//
//  Tab shell + the auth ladder. On entering the background the flow re-locks
//  (correct); `authBypass` skips it. An idle session re-locks after a timeout
//  (correct); `sessionTimeoutDisabled` skips that.
//

import SwiftUI

struct RootView: View {
    @Environment(AppServices.self) private var services
    @Environment(AuthFlow.self) private var auth
    @Environment(\.scenePhase) private var scenePhase
    @State private var showDevMenu = LaunchOptions.current.showDevMenu

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()

            TabBarView()
                .id(services.configVersion) // rebuild the tree when the profile changes
                .opacity(auth.isUnlocked ? 1 : 0)
                .accessibilityHidden(!auth.isUnlocked)
                // Any interaction keeps the session alive (idle-timeout reset).
                .simultaneousGesture(TapGesture().onEnded { auth.keepAlive() })

            if !auth.isUnlocked {
                AuthContainerView()
                    .transition(.opacity)
            }

            // Obscure sensitive content in the app switcher while inactive.
            // The `noPrivacyBlur` defect suppresses this cover.
            if showPrivacyCover {
                PrivacyCover()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: auth.isUnlocked)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { auth.handleBackground() }
        }
        .sheet(isPresented: $showDevMenu) { DevMenuView() }
    }

    private var showPrivacyCover: Bool {
        scenePhase != .active && auth.isUnlocked && !Defects.isActive(.noPrivacyBlur)
    }
}

private struct PrivacyCover: View {
    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Palette.sand)
                Text("ChaosBank")
                    .font(.appDisplay(24, weight: .bold))
                    .foregroundStyle(Palette.text)
            }
        }
        .accessibilityIdentifier(A11y.Privacy.cover)
    }
}
