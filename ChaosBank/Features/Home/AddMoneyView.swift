//
//  AddMoneyView.swift
//  ChaosBank
//
//  A minimal top-up sheet. No planted defect — a straightforward correct credit.
//

import SwiftUI

struct AddMoneyView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss

    @State private var amountText = ""
    @State private var currency: Currency = .EUR
    @State private var submitting = false

    private var amount: Decimal? {
        guard let a = AmountParser.parse(amountText), a > 0 else { return nil }
        return a
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SegmentBar(
                        items: Currency.allCases.map {
                            SegmentItem(id: $0.code, title: $0.code, a11y: "addMoney.currency.\($0.code)")
                        },
                        selection: Binding(get: { currency.code },
                                           set: { currency = Currency(rawValue: $0) ?? .EUR })
                    )

                    CardSurface {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Amount").font(.appBody(13)).foregroundStyle(Palette.muted)
                            HStack {
                                Text(currency.symbol).moneyStyle(24, weight: .bold).foregroundStyle(Palette.sand)
                                TextField("0.00", text: $amountText)
                                    .keyboardType(.decimalPad)
                                    .moneyStyle(24, weight: .bold)
                                    .foregroundStyle(Palette.text)
                                    .accessibilityIdentifier("addMoney.amountField")
                            }
                        }
                    }

                    PrimaryButton(title: "Add money", enabled: amount != nil && !submitting) {
                        Task { await add() }
                    }
                    .accessibilityIdentifier("addMoney.confirmButton")
                }
                .padding(20)
            }
            .background(Palette.bg)
            .navigationTitle("Add money")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.tint(Palette.sand)
                }
            }
            .toolbarBackground(Palette.bg, for: .navigationBar)
        }
    }

    private func add() async {
        guard let amount, !submitting else { return }
        submitting = true
        defer { submitting = false }
        do {
            try await services.backend.deposit(to: currency, amount: amount)
            services.bumpData()
            dismiss()
        } catch {
            // No error surface needed for the happy-path top-up.
        }
    }
}
