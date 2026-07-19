//
//  NotificationsView.swift
//  ChaosBank
//

import SwiftUI

struct NotificationsView: View {
    @Environment(AppServices.self) private var services
    @State private var target: NotificationTarget?

    var body: some View {
        NavigationStack {
            ChaosBankScreen(title: "Notifications", a11y: A11y.Notifications.root, showBadge: false) {
                CardSurface(padding: 6) {
                    VStack(spacing: 0) {
                        let items = services.notifications.items
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, n in
                            Button {
                                target = services.notifications.target(n)
                            } label: {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(n.read ? Color.clear : Palette.sand)
                                        .frame(width: 8, height: 8)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(n.title).font(.appBody(15, weight: .semibold)).foregroundStyle(Palette.text)
                                        Text(n.body).font(.appBody(13)).foregroundStyle(Palette.muted)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 10).padding(.horizontal, 8)
                                .contentShape(Rectangle())
                            }
                            .accessibilityIdentifier(A11y.Notifications.row(n.id))
                            if index < items.count - 1 { Divider().overlay(Palette.line) }
                        }
                    }
                }
            }
            .background(Palette.bg)
        }
        .onAppear { services.notifications.markAllRead() }
        .sheet(item: $target) { destination($0) }
    }

    @ViewBuilder
    private func destination(_ t: NotificationTarget) -> some View {
        switch t {
        case .transactions: NavigationStack { TransactionsView() }
        case .exchange: ExchangeView()
        case .addMoney: AddMoneyView()
        }
    }
}
