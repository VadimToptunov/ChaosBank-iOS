//
//  NotificationStore.swift
//  ChaosBank
//
//  In-app notification centre (Platform cluster). Real APNs delivery is a platform
//  step; this models the in-app surface, unread badge and routing — where the
//  `notificationBadgeStale` and `notificationOpensWrongScreen` bugs live.
//

import Foundation
import Observation

enum NotificationTarget: String, Identifiable, Sendable {
    case transactions, exchange, addMoney
    var id: String { rawValue }
}

struct AppNotification: Identifiable, Sendable {
    let id: String
    let title: String
    let body: String
    let target: NotificationTarget
    var read: Bool = false
}

@MainActor
@Observable
final class NotificationStore {
    private(set) var items: [AppNotification]
    private let initialUnread: Int

    init() {
        let seed = [
            AppNotification(id: "n1", title: "Transfer received", body: "€85.00 from Mia", target: .transactions),
            AppNotification(id: "n2", title: "FX rate alert", body: "EUR/USD moved 0.4% today", target: .exchange),
            AppNotification(id: "n3", title: "Add money reminder", body: "Top up before the weekend", target: .addMoney),
            AppNotification(id: "n4", title: "Statement ready", body: "June statement is available", target: .transactions, read: true),
        ]
        items = seed
        initialUnread = seed.filter { !$0.read }.count
    }

    /// `notificationBadgeStale`: the badge keeps the original count after reading.
    var unreadCount: Int {
        Defects.isActive(.notificationBadgeStale) ? initialUnread : items.filter { !$0.read }.count
    }

    func markAllRead() {
        items = items.map { var n = $0; n.read = true; return n }
    }

    /// `notificationOpensWrongScreen`: tapping opens a different destination.
    func target(_ n: AppNotification) -> NotificationTarget {
        Defects.isActive(.notificationOpensWrongScreen) ? wrong(n.target) : n.target
    }

    private func wrong(_ t: NotificationTarget) -> NotificationTarget {
        t == .transactions ? .exchange : .transactions
    }
}
