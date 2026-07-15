//
//  TransactionsView.swift
//  ChaosBank
//

import SwiftUI

struct TransactionsView: View {
    @Environment(AppServices.self) private var services
    @State private var vm: TransactionsViewModel?

    var body: some View {
        ChaosBankScreen(title: "Transactions", a11y: A11y.Transactions.root) {
            if let vm {
                content(vm)
            }
        }
        .task {
            if vm == nil { vm = TransactionsViewModel(services: services) }
            await vm?.load()
        }
    }

    @ViewBuilder
    private func content(_ vm: TransactionsViewModel) -> some View {
        @Bindable var vm = vm

        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted)
            TextField("Search", text: $vm.search)
                .foregroundStyle(Palette.text)
                .accessibilityIdentifier(A11y.Transactions.searchField)
        }
        .padding(12)
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Palette.line, lineWidth: 1))

        SegmentBar(
            items: [
                SegmentItem(id: TxFilter.all.rawValue, title: "All", a11y: A11y.Transactions.filterAll),
                SegmentItem(id: TxFilter.moneyIn.rawValue, title: "Money in", a11y: A11y.Transactions.filterIn),
                SegmentItem(id: TxFilter.moneyOut.rawValue, title: "Money out", a11y: A11y.Transactions.filterOut),
            ],
            selection: Binding(
                get: { vm.filter.rawValue },
                set: { vm.filter = TxFilter(rawValue: $0) ?? .all }
            )
        )

        // `transactionCountWrong`: report the visible count, not the filtered total.
        Text("\(Defects.isActive(.transactionCountWrong) ? vm.visible.count : vm.filtered.count) transactions")
            .font(.appBody(13))
            .foregroundStyle(Palette.muted)
            .accessibilityIdentifier(A11y.Transactions.count)

        VStack(spacing: 16) {
            ForEach(vm.grouped, id: \.key) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.key)
                        .font(.appBody(13, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                    CardSurface(padding: 8) {
                        VStack(spacing: 0) {
                            ForEach(Array(group.rows.enumerated()), id: \.offset) { index, tx in
                                TransactionRowView(tx: tx, a11y: A11y.Transactions.row(tx.id))
                                if index < group.rows.count - 1 {
                                    Divider().overlay(Palette.line)
                                }
                            }
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier(A11y.Transactions.list)

        if vm.canLoadMore {
            SecondaryButton(title: "Load more", systemImage: "arrow.down") {
                vm.loadMore()
            }
            .accessibilityIdentifier(A11y.Transactions.loadMore)
        }
    }
}
