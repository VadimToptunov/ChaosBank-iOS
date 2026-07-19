//
//  CardView.swift
//  ChaosBank
//

import SwiftUI

struct CardView: View {
    @State private var vm = CardViewModel()
    @State private var showPIN = false
    @State private var virtualCreated = false

    var body: some View {
        ChaosBankScreen(title: "Card", a11y: A11y.Card.root) {
            cardVisual

            CardSurface {
                VStack(spacing: 4) {
                    Toggle(isOn: Binding(get: { vm.frozen }, set: { vm.frozen = $0 })) {
                        settingLabel("Freeze card", "snowflake")
                    }
                    .tint(Palette.sand)
                    .accessibilityIdentifier(A11y.Card.freezeToggle)
                    // `freezeToggleNoLabel`: strip the toggle's accessibility label.
                    .accessibilityLabel(Defects.isActive(.freezeToggleNoLabel) ? Text(" ") : Text("Freeze card"))

                    Divider().overlay(Palette.line)

                    Toggle(isOn: $vm.onlinePayments) {
                        settingLabel("Online payments", "globe")
                    }
                    .tint(Palette.sand)
                    .accessibilityIdentifier(A11y.Card.onlinePaymentsToggle)

                    Divider().overlay(Palette.line)

                    HStack {
                        settingLabel("Monthly limit", "gauge.with.dots.needle.67percent")
                        Spacer()
                        HStack(spacing: 2) {
                            Text("$").moneyStyle(15, weight: .semibold).foregroundStyle(Palette.sand)
                            TextField("0", text: $vm.monthlyLimitText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .moneyStyle(15, weight: .semibold)
                                .foregroundStyle(Palette.text)
                                .frame(width: 80)
                                .accessibilityIdentifier(A11y.Card.limitField)
                        }
                    }
                    .padding(.vertical, 8)

                    if let limitError = vm.limitError {
                        Text(limitError)
                            .font(.appBody(12, weight: .medium))
                            .foregroundStyle(Palette.loss)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .accessibilityIdentifier(A11y.Card.limitError)
                    }
                }
            }

            SecondaryButton(title: "Show PIN", systemImage: "lock.fill") {
                showPIN = true
            }
            .accessibilityIdentifier(A11y.Card.pinButton)

            // Virtual card issuance (banking-breadth). Should reveal a distinct number.
            if virtualCreated {
                CardSurface {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Virtual card").font(.appBody(12)).foregroundStyle(Palette.muted)
                        Text(vm.virtualCardNumber)
                            .font(.appMono(16, weight: .semibold)).foregroundStyle(Palette.text)
                            .accessibilityIdentifier(A11y.Card.virtualNumber)
                    }
                }
            }
            SecondaryButton(title: "Create virtual card", systemImage: "plus.rectangle.on.rectangle") {
                virtualCreated = true
            }
            .accessibilityIdentifier(A11y.Card.virtualButton)

            PrimaryButton(title: "Order physical card", systemImage: "creditcard") {
            }
            .accessibilityIdentifier(A11y.Card.orderPhysicalButton)
        }
        .alert("Card PIN", isPresented: $showPIN) {
            Button("Done", role: .cancel) {}
        } message: {
            Text("Your PIN is \(vm.pinText)")
        }
    }

    private var cardVisual: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(colors: [Palette.surface2, Palette.bg],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Palette.line, lineWidth: 1)
                )

            VStack(alignment: .leading) {
                HStack {
                    Text("ChaosBank").font(.appDisplay(18, weight: .bold)).foregroundStyle(Palette.sand)
                    Spacer()
                    if vm.frozen {
                        Text("FROZEN")
                            .font(.appMono(11, weight: .bold))
                            .foregroundStyle(Palette.bg)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Palette.loss)
                            .clipShape(Capsule())
                            .accessibilityIdentifier(A11y.Card.frozenBadge)
                    }
                }
                Spacer()
                Text(vm.displayedPAN)
                    .moneyStyle(18, weight: .semibold)
                    .foregroundStyle(Palette.text)
                    .accessibilityIdentifier(A11y.Card.number)
                HStack {
                    Text(vm.holder).font(.appMono(12, weight: .medium)).foregroundStyle(Palette.muted)
                    Spacer()
                    if let cvv = vm.visibleCVV {
                        Text("CVV \(cvv)")
                            .font(.appMono(12, weight: .medium)).foregroundStyle(Palette.loss)
                            .accessibilityIdentifier(A11y.Card.cvv)
                    }
                    Text(vm.expiry).font(.appMono(12, weight: .medium)).foregroundStyle(Palette.muted)
                }
            }
            .padding(18)
        }
        .frame(height: 200)
        .opacity(vm.frozen ? 0.55 : 1)
        .accessibilityIdentifier(A11y.Card.visual)
    }

    private func settingLabel(_ title: String, _ icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(Palette.sand).frame(width: 24)
            Text(title).font(.appBody(15, weight: .medium)).foregroundStyle(Palette.text)
        }
    }
}
