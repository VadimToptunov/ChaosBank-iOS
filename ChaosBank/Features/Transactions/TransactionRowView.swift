//
//  TransactionRowView.swift
//  ChaosBank
//
//  Shared row used by Home's recent activity and the full Transactions list.
//

import SwiftUI

nonisolated enum TxFormat {
    /// The app's home timezone. The `dateTimezoneShift` defect renders dates in a
    /// far-off timezone instead, so times (and some day boundaries) shift.
    static let homeTimeZone = TimeZone(identifier: "Europe/Berlin")!
    static let shiftedTimeZone = TimeZone(identifier: "Pacific/Midway")!

    private static func formatter(_ format: String, shifted: Bool) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = format
        f.timeZone = shifted ? shiftedTimeZone : homeTimeZone
        return f
    }

    static func dayHeader(_ date: Date, shifted: Bool) -> String {
        formatter("EEEE, d MMM", shifted: shifted).string(from: date)
    }

    static func rowTime(_ date: Date, shifted: Bool) -> String {
        formatter("d MMM · HH:mm", shifted: shifted).string(from: date)
    }

    static func icon(for category: String) -> String {
        switch category {
        case "Income", "Top-up": return "arrow.down.left.circle.fill"
        case "Transfer": return "arrow.left.arrow.right.circle.fill"
        case "Exchange": return "arrow.2.squarepath.circle.fill"
        case "Groceries": return "cart.fill"
        case "Dining": return "fork.knife"
        case "Utilities": return "bolt.fill"
        case "Health": return "cross.case.fill"
        case "Transport": return "car.fill"
        case "Shopping": return "bag.fill"
        case "Digital": return "app.fill"
        case "Trade": return "chart.line.uptrend.xyaxis"
        default: return "circle.fill"
        }
    }
}

struct TransactionRowView: View {
    let tx: Transaction
    var a11y: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: TxFormat.icon(for: tx.category))
                .font(.system(size: 18))
                .foregroundStyle(tx.direction == .moneyIn ? Palette.gain : Palette.muted)
                .frame(width: 38, height: 38)
                .background(Palette.surface2)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(tx.title)
                    .font(.appBody(15, weight: .medium))
                    .foregroundStyle(Palette.text)
                Text(TxFormat.rowTime(tx.date, shifted: Defects.isActive(.dateTimezoneShift)))
                    .font(.appBody(12))
                    .foregroundStyle(Palette.muted)
            }

            Spacer()

            // `outgoingSignHidden`: outgoing amounts drop the leading minus.
            Text(tx.direction == .moneyOut && Defects.isActive(.outgoingSignHidden)
                 ? tx.money.formatted : tx.money.formattedSigned)
                .moneyStyle(15, weight: .semibold)
                .foregroundStyle(tx.direction == .moneyIn ? Palette.gain : Palette.text)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .accessibilityIdentifier(a11y)
    }
}
