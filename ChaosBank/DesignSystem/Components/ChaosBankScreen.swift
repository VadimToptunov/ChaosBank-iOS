//
//  ChaosBankScreen.swift
//  ChaosBank
//
//  Common scrollable screen scaffold: dark background, large title, and the
//  build badge pinned in the navigation bar so the active seed is always on
//  screen.
//

import SwiftUI

struct ChaosBankScreen<Content: View>: View {
    let title: String
    let a11y: String
    var showBadge: Bool = true
    var spacing: CGFloat = 20
    @ViewBuilder var content: () -> Content

    @Environment(AppServices.self) private var services

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing) {
                // Offline indicator. `offlineBannerMissing` suppresses it — the app
                // serves cached data silently, so the user can't tell they're offline.
                if services.offline && !Defects.isActive(.offlineBannerMissing) {
                    Text("⚠︎ You're offline — showing cached data")
                        .font(.appBody(13, weight: .semibold))
                        .foregroundStyle(Palette.bg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Palette.loss)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .accessibilityIdentifier(A11y.Net.offlineBanner)
                }
                content()
                // Clearance for the floating (iOS 26 glass) tab bar, which draws
                // over the scroll content: without it the last control (e.g. Card's
                // "Order physical card") stays behind the bar. This bottom space lets
                // it scroll clear.
                Color.clear.frame(height: 96)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Palette.bg)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if showBadge {
                ToolbarItem(placement: .topBarTrailing) { BuildBadge() }
            }
        }
        .toolbarBackground(Palette.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .accessibilityIdentifier(a11y)
    }
}
