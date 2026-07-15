//
//  HomeView.swift
//  ChaosBank
//

import SwiftUI

struct HomeView: View {
    @Environment(AppServices.self) private var services
    @State private var vm: HomeViewModel?
    @State private var showTransfer = false
    @State private var showExchange = false
    @State private var showAddMoney = false

    var body: some View {
        ChaosBankScreen(title: "Home", a11y: A11y.Home.root) {
            if let vm {
                content(vm)
            }
        }
        .task {
            if vm == nil { vm = HomeViewModel(services: services) }
            await vm?.load()
        }
        .onChange(of: services.dataVersion) {
            Task { await vm?.refreshAfterMutation() }
        }
        .sheet(isPresented: $showTransfer) { TransferView() }
        .sheet(isPresented: $showExchange) { ExchangeView() }
        .sheet(isPresented: $showAddMoney) { AddMoneyView() }
    }

    @ViewBuilder
    private func content(_ vm: HomeViewModel) -> some View {
        @Bindable var vm = vm

        // Balance card
        CardSurface {
            VStack(alignment: .leading, spacing: 14) {
                SegmentBar(
                    items: Currency.allCases.map {
                        SegmentItem(id: $0.code, title: $0.code,
                                    a11y: "\(A11y.Home.currencySegment).\($0.code)")
                    },
                    selection: Binding(
                        get: { vm.selectedCurrency.code },
                        set: { vm.selectedCurrency = Currency(rawValue: $0) ?? .EUR }
                    )
                )
                .accessibilityIdentifier(A11y.Home.currencySegment)

                Text("Total balance")
                    .font(.appBody(13))
                    .foregroundStyle(Palette.muted)
                Text(vm.totalBalanceText)
                    .moneyStyle(34, weight: .bold)
                    .foregroundStyle(Palette.text)
                    .accessibilityIdentifier(A11y.Home.totalBalance)

                HStack(spacing: 6) {
                    Image(systemName: vm.todayChange.amount < 0 ? "arrow.down.right" : "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                    Text("\(vm.todayChange.formattedSigned) · \(MoneyFormat.percent(vm.todayChangePercent)) today")
                        .moneyStyle(13, weight: .medium)
                }
                .foregroundStyle(Palette.pnl(vm.todayChange.amount))
                .accessibilityIdentifier(A11y.Home.todayChange)
            }
        }

        // Account strip. `accountStripHidesGBP` drops the GBP card.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(vm.accounts.filter { !(Defects.isActive(.accountStripHidesGBP) && $0.currency == .GBP) }) { account in
                    accountCard(account, selected: vm.selectedCurrency)
                        .onTapGesture { vm.selectedCurrency = account.currency }
                }
            }
        }

        // Quick actions. `quickActionTransferOpensExchange` wires Transfer to the
        // Exchange sheet.
        HStack(spacing: 12) {
            quickAction("Transfer", "arrow.left.arrow.right", A11y.Home.quickActionTransfer) {
                if Defects.isActive(.quickActionTransferOpensExchange) { showExchange = true } else { showTransfer = true }
            }
            quickAction("Exchange", "arrow.2.squarepath", A11y.Home.quickActionExchange) { showExchange = true }
            quickAction("Add", "plus", A11y.Home.quickActionAddMoney) { showAddMoney = true }
            NavigationLink {
                CardView()
            } label: {
                quickActionLabel("Card", "creditcard")
            }
            .accessibilityIdentifier(A11y.Home.quickActionCard)
        }

        // Recent activity
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink {
                TransactionsView()
            } label: {
                SectionHeader(title: "Recent activity", trailing: "See all")
            }
            .accessibilityIdentifier(A11y.Home.seeAllActivity)

            CardSurface(padding: 8) {
                VStack(spacing: 0) {
                    ForEach(Array(vm.recent.enumerated()), id: \.offset) { index, tx in
                        TransactionRowView(tx: tx, a11y: A11y.Home.activityRow(tx.id))
                        if index < vm.recent.count - 1 {
                            Divider().overlay(Palette.line)
                        }
                    }
                }
            }
            .accessibilityIdentifier(A11y.Home.recentActivity)
        }
    }

    private func accountCard(_ account: Account, selected: Currency) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(account.currency.symbol)
                    .font(.appDisplay(16, weight: .bold))
                    .foregroundStyle(Palette.sand)
                Text(account.name)
                    .font(.appBody(13, weight: .medium))
                    .foregroundStyle(Palette.muted)
            }
            Text(Money(account.balance, account.currency).formatted)
                .moneyStyle(19, weight: .semibold)
                .foregroundStyle(Palette.text)
        }
        .padding(14)
        .frame(width: 180, alignment: .leading)
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(account.currency == selected ? Palette.sand : Palette.line,
                        lineWidth: account.currency == selected ? 1.5 : 1)
        )
        .accessibilityIdentifier(A11y.Home.account(account.currency))
    }

    private func quickAction(_ title: String, _ icon: String, _ a11y: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { quickActionLabel(title, icon) }
            .accessibilityIdentifier(a11y)
    }

    private func quickActionLabel(_ title: String, _ icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Palette.sand)
                .frame(width: 46, height: 46)
                .background(Palette.surface2)
                .clipShape(Circle())
            Text(title)
                .font(.appBody(12, weight: .medium))
                .foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity)
    }
}
