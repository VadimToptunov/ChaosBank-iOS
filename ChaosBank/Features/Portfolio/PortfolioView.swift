//
//  PortfolioView.swift
//  ChaosBank
//

import SwiftUI

struct PortfolioView: View {
    @Environment(AppServices.self) private var services
    @State private var vm: PortfolioViewModel?

    private let allocationColors: [Color] = [Palette.sand, Palette.gain, Color(hex: 0x6EA8FE),
                                             Color(hex: 0xC792EA), Palette.loss, Palette.muted]

    var body: some View {
        ChaosBankScreen(title: "Portfolio", a11y: A11y.Portfolio.root) {
            if let vm { content(vm) }
        }
        .task {
            if vm == nil { vm = PortfolioViewModel(services: services) }
            await vm?.load()
        }
        .onAppear { services.startFeed() }
        .onChange(of: services.dataVersion) {
            Task { await vm?.load() }
        }
    }

    @ViewBuilder
    private func content(_ vm: PortfolioViewModel) -> some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 10) {
                Text("Invested value").font(.appBody(13)).foregroundStyle(Palette.muted)
                Text(vm.totalValue.formatted)
                    .moneyStyle(32, weight: .bold)
                    .foregroundStyle(Palette.text)
                    .accessibilityIdentifier(A11y.Portfolio.totalValue)

                let shownPnL = vm.displayPnL(vm.totalPnL)
                Text("\(Money(shownPnL, .USD).formattedSigned) · \(MoneyFormat.percent(vm.displayPnL(vm.totalPnLPercent))) all-time")
                    .moneyStyle(14, weight: .semibold)
                    .foregroundStyle(Palette.pnl(shownPnL))
                    .accessibilityIdentifier(A11y.Portfolio.pnl)
            }
        }

        if vm.holdings.isEmpty {
            Text("No holdings yet")
                .font(.appBody(15))
                .foregroundStyle(Palette.muted)
                .accessibilityIdentifier(A11y.Portfolio.empty)
        } else {
            allocationBar(vm)

            CardSurface(padding: 6) {
                VStack(spacing: 0) {
                    ForEach(Array(vm.holdings.enumerated()), id: \.element.id) { index, holding in
                        holdingRow(vm, holding)
                        if index < vm.holdings.count - 1 {
                            Divider().overlay(Palette.line)
                        }
                    }
                }
            }
            .accessibilityIdentifier(A11y.Portfolio.list)
        }
    }

    private func allocationBar(_ vm: PortfolioViewModel) -> some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(Array(vm.holdings.enumerated()), id: \.element.id) { index, holding in
                    Rectangle()
                        .fill(allocationColors[index % allocationColors.count])
                        .frame(width: max(2, geo.size.width * vm.allocationFraction(holding)))
                }
            }
        }
        .frame(height: 10)
        .clipShape(Capsule())
        .accessibilityIdentifier(A11y.Portfolio.allocationBar)
    }

    private func holdingRow(_ vm: PortfolioViewModel, _ holding: Holding) -> some View {
        let pnl = vm.displayPnL(vm.pnl(holding))
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(holding.symbol).font(.appBody(16, weight: .bold)).foregroundStyle(Palette.text)
                Text("\(qtyString(holding.quantity)) @ $\(MoneyFormat.price(holding.avgCost))")
                    .font(.appBody(12)).foregroundStyle(Palette.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(vm.marketValue(holding).formatted)
                    .moneyStyle(15, weight: .semibold).foregroundStyle(Palette.text)
                    .accessibilityIdentifier(A11y.Portfolio.holdingValue(holding.symbol))
                Text(Money(pnl, .USD).formattedSigned)
                    .moneyStyle(12, weight: .semibold)
                    .foregroundStyle(Palette.pnl(pnl))
                    .accessibilityIdentifier(A11y.Portfolio.holdingPnl(holding.symbol))
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .accessibilityIdentifier(A11y.Portfolio.holding(holding.symbol))
    }

    private func qtyString(_ q: Decimal) -> String {
        if q == q.rounded(scale: 0) { return NSDecimalNumber(decimal: q).stringValue }
        return MoneyFormat.decimal(q, fractionDigits: 4)
    }
}
