//
//  ExchangeView.swift
//  ChaosBank
//

import SwiftUI

struct ExchangeView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var vm: ExchangeViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm { content(vm) }
            }
            .background(Palette.bg)
            .navigationTitle("Exchange")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.tint(Palette.sand)
                }
            }
            .toolbarBackground(Palette.bg, for: .navigationBar)
        }
        .task {
            if vm == nil { vm = ExchangeViewModel(services: services) }
            await vm?.load()
        }
    }

    @ViewBuilder
    private func content(_ vm: ExchangeViewModel) -> some View {
        @Bindable var vm = vm

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CardSurface {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Sell").font(.appBody(13)).foregroundStyle(Palette.muted)
                            Spacer()
                            currencyMenu(selection: Binding(get: { vm.sell },
                                                            set: { vm.selectSell($0) }),
                                         a11y: A11y.Exchange.sellCurrency)
                        }
                        HStack {
                            Text(vm.sell.symbol).moneyStyle(24, weight: .bold).foregroundStyle(Palette.sand)
                            TextField("0.00", text: $vm.amountText)
                                .keyboardType(.decimalPad)
                                .moneyStyle(24, weight: .bold)
                                .foregroundStyle(Palette.text)
                                .accessibilityIdentifier(A11y.Exchange.amountField)
                        }
                        Text("Balance \(Money(vm.sellBalance, vm.sell).formatted)")
                            .font(.appBody(12)).foregroundStyle(Palette.muted)
                    }
                }

                Button {
                    vm.swapDirection()
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Palette.bg)
                        .frame(width: 40, height: 40)
                        .background(Palette.sand)
                        .clipShape(Circle())
                }
                .frame(maxWidth: .infinity)

                CardSurface {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Get").font(.appBody(13)).foregroundStyle(Palette.muted)
                            Spacer()
                            currencyMenu(selection: Binding(get: { vm.get }, set: { vm.get = $0 }),
                                         a11y: A11y.Exchange.getCurrency)
                        }
                        Text(vm.youGet.formatted)
                            .moneyStyle(24, weight: .bold)
                            .foregroundStyle(Palette.text)
                            .accessibilityIdentifier(A11y.Exchange.youGet)
                    }
                }

                infoRow("Rate", "1 \(vm.sell.code) = \(MoneyFormat.decimal(vm.rate, fractionDigits: 4)) \(vm.get.code)",
                        a11y: A11y.Exchange.rate)
                infoRow("Fee (0.5%)", vm.fee.formatted, a11y: A11y.Exchange.fee)

                if let error = vm.errorMessage {
                    Text(error)
                        .font(.appBody(14, weight: .medium))
                        .foregroundStyle(Palette.loss)
                }

                // Not disabled while submitting: idempotency lives in the view
                // model so a double-tap can exercise `exchangeDoubleSubmit`.
                PrimaryButton(title: "Exchange", enabled: vm.canExecute) {
                    Task { await vm.execute() }
                }
                .accessibilityIdentifier(A11y.Exchange.executeButton)
            }
            .padding(20)
        }
        .overlay(alignment: .top) {
            if vm.succeeded {
                Toast(message: "Exchanged \(vm.youGet.formatted)", a11y: A11y.Exchange.successToast)
                    .padding(.top, 12)
            }
        }
        .onChange(of: vm.succeeded) { _, done in
            guard done else { return }
            Task {
                try? await Task.sleep(for: .seconds(1.4))
                dismiss()
            }
        }
    }

    private func currencyMenu(selection: Binding<Currency>, a11y: String) -> some View {
        Menu {
            ForEach(Currency.allCases) { c in
                Button(c.code) { selection.wrappedValue = c }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selection.wrappedValue.code).font(.appBody(15, weight: .semibold))
                Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(Palette.sand)
        }
        .accessibilityIdentifier(a11y)
    }

    private func infoRow(_ label: String, _ value: String, a11y: String) -> some View {
        HStack {
            Text(label).font(.appBody(14)).foregroundStyle(Palette.muted)
            Spacer()
            Text(value).moneyStyle(14, weight: .medium).foregroundStyle(Palette.text)
                .accessibilityIdentifier(a11y)
        }
        .padding(.horizontal, 4)
    }
}
