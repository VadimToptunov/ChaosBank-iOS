//
//  BuildBadge.swift
//  ChaosBank
//
//  "sandbox · 1.0 · <profile>" — always shows the real active profile/seed so a
//  tester can read it off-screen. Long-press opens the hidden developer menu.
//

import SwiftUI

struct BuildBadge: View {
    @Environment(AppServices.self) private var services
    @State private var showDevMenu = false

    var body: some View {
        Text("sandbox · \(services.config.version) · \(services.config.label)")
            .font(.appMono(11, weight: .medium))
            .foregroundStyle(Palette.muted)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Palette.surface2)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Palette.line, lineWidth: 1))
            .accessibilityIdentifier(A11y.Build.badge)
            .onLongPressGesture(minimumDuration: 0.5) { showDevMenu = true }
            .onTapGesture(count: 3) { showDevMenu = true }
            .sheet(isPresented: $showDevMenu) { DevMenuView() }
    }
}
