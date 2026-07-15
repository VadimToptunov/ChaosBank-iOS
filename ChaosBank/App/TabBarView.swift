//
//  TabBarView.swift
//  ChaosBank
//

import SwiftUI

struct TabBarView: View {
    @State private var selection = LaunchOptions.current.initialTab

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { HomeView() }
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                        .accessibilityIdentifier(A11y.TabBar.home)
                }
                .tag(0)

            NavigationStack { MarketsView() }
                .tabItem {
                    Label("Markets", systemImage: "chart.line.uptrend.xyaxis")
                        .accessibilityIdentifier(A11y.TabBar.markets)
                }
                .tag(1)

            NavigationStack { PortfolioView() }
                .tabItem {
                    Label("Portfolio", systemImage: "chart.pie.fill")
                        .accessibilityIdentifier(A11y.TabBar.portfolio)
                }
                .tag(2)

            NavigationStack { CardView() }
                .tabItem {
                    Label("Card", systemImage: "creditcard.fill")
                        .accessibilityIdentifier(A11y.TabBar.card)
                }
                .tag(3)
        }
        .tint(Palette.sand)
        .accessibilityIdentifier(A11y.TabBar.root)
    }
}
