//
//  OrderView.swift
//  ChaosBank
//

import SwiftUI

struct OrderView: View {
    let request: OrderRequest

    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var vm: OrderViewModel?

    var body: some View {
        ChaosBankScreen(title: "Order · \(request.symbol)", a11y: A11y.Order.root, showBadge: false) {
            if let vm { content(vm) }
        }
        .task {
            if vm == nil { vm = OrderViewModel(request: request, services: services) }
            await vm?.load()
        }
    }

    @ViewBuilder
    private func content(_ vm: OrderViewModel) -> some View {
        @Bindable var vm = vm

        SegmentBar(
            items: [
                SegmentItem(id: OrderSide.buy.rawValue, title: "Buy", a11y: A11y.Order.sideBuy),
                SegmentItem(id: OrderSide.sell.rawValue, title: "Sell", a11y: A11y.Order.sideSell),
            ],
            selection: Binding(get: { vm.side.rawValue },
                               set: { vm.side = OrderSide(rawValue: $0) ?? .buy })
        )

        SegmentBar(
            items: [
                SegmentItem(id: OrderType.market.rawValue, title: "Market", a11y: A11y.Order.typeMarket),
                SegmentItem(id: OrderType.limit.rawValue, title: "Limit", a11y: A11y.Order.typeLimit),
            ],
            selection: Binding(get: { vm.type.rawValue },
                               set: { vm.type = OrderType(rawValue: $0) ?? .market })
        )

        CardSurface {
            VStack(spacing: 16) {
                HStack {
                    Text("Quantity").font(.appBody(14)).foregroundStyle(Palette.muted)
                    Spacer()
                    HStack(spacing: 16) {
                        stepperButton("minus", a11y: A11y.Order.qtyStepperDecrement) { vm.decrement() }
                        Text(qtyString(vm.quantity))
                            .moneyStyle(18, weight: .bold)
                            .foregroundStyle(Palette.text)
                            .frame(minWidth: 48)
                            .accessibilityIdentifier(A11y.Order.qtyStepperValue)
                        stepperButton("plus", a11y: A11y.Order.qtyStepperIncrement) { vm.increment() }
                    }
                }

                if vm.type == .limit {
                    Divider().overlay(Palette.line)
                    HStack {
                        Text("Limit price").font(.appBody(14)).foregroundStyle(Palette.muted)
                        Spacer()
                        HStack {
                            Text("$").moneyStyle(16, weight: .semibold).foregroundStyle(Palette.sand)
                            TextField("0.00", text: $vm.limitPriceText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .moneyStyle(16, weight: .semibold)
                                .foregroundStyle(Palette.text)
                                .frame(width: 100)
                                .accessibilityIdentifier(A11y.Order.limitPriceField)
                        }
                    }
                }
            }
        }

        CardSurface {
            VStack(spacing: 12) {
                summaryRow("Reference price", "$" + MoneyFormat.price(vm.referencePrice),
                           a11y: A11y.Order.refPrice)
                Divider().overlay(Palette.line)
                summaryRow("Estimated total", vm.estTotal.formatted, a11y: A11y.Order.estTotal)
            }
        }

        if vm.showWarning {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("Limit sell below market — will execute immediately.")
                    .font(.appBody(13, weight: .medium))
            }
            .foregroundStyle(Palette.loss)
            .accessibilityIdentifier(A11y.Order.warning)
        }

        if let error = vm.errorMessage {
            Text(error).font(.appBody(14, weight: .medium)).foregroundStyle(Palette.loss)
        }

        PrimaryButton(title: "Review order", enabled: vm.isValid) {
            vm.errorMessage = nil
            vm.showConfirm = true
        }
        .accessibilityIdentifier(A11y.Order.reviewButton)
        .sheet(isPresented: $vm.showConfirm) { confirmSheet(vm) }
        .overlay(alignment: .top) {
            if vm.placed, let status = vm.status {
                Toast(message: statusMessage(status), a11y: A11y.Order.statusToast)
                    .padding(.top, 12)
            }
        }
        .onChange(of: vm.placed) { _, done in
            guard done, vm.status == .filled else { return }
            Task {
                try? await Task.sleep(for: .seconds(1.4))
                dismiss()
            }
        }
    }

    @ViewBuilder
    private func confirmSheet(_ vm: OrderViewModel) -> some View {
        VStack(spacing: 18) {
            Capsule().fill(Palette.line).frame(width: 40, height: 5).padding(.top, 10)
            Text("\(vm.side == .buy ? "Buy" : "Sell") \(vm.symbol)")
                .font(.appDisplay(20, weight: .bold))
                .foregroundStyle(Palette.text)

            CardSurface {
                VStack(spacing: 12) {
                    summaryRow("Quantity", qtyString(vm.quantity))
                    Divider().overlay(Palette.line)
                    summaryRow("Price", "$" + MoneyFormat.price(vm.executionPrice))
                    Divider().overlay(Palette.line)
                    summaryRow("Total", vm.estTotal.formatted)
                }
            }

            Spacer()

            // Not disabled while submitting: idempotency lives in the view model
            // so a double-tap can exercise `orderDoubleSubmit`.
            PrimaryButton(title: "Place order") {
                Task {
                    await vm.place()
                    if vm.placed { vm.showConfirm = false }
                }
            }
            .accessibilityIdentifier(A11y.Order.placeButton)
            // `missingA11yLabel`: the button exposes no meaningful label.
            .accessibilityLabel(Defects.isActive(.missingA11yLabel) ? Text(" ") : Text("Place order"))
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg)
        .accessibilityIdentifier(A11y.Order.confirmSheet)
        .presentationDetents([.medium])
    }

    private func stepperButton(_ icon: String, a11y: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Palette.text)
                .frame(width: 36, height: 36)
                .background(Palette.surface2)
                .clipShape(Circle())
        }
        .accessibilityIdentifier(a11y)
    }

    private func statusMessage(_ status: OrderStatus) -> String {
        switch status {
        case .filled: return "Order filled"
        case .pending: return "Order pending…"
        case .rejected: return "Order rejected"
        }
    }

    private func summaryRow(_ label: String, _ value: String, a11y: String? = nil) -> some View {
        HStack {
            Text(label).font(.appBody(14)).foregroundStyle(Palette.muted)
            Spacer()
            Text(value).moneyStyle(15, weight: .semibold).foregroundStyle(Palette.text)
                .accessibilityIdentifier(a11y ?? "")
        }
    }

    private func qtyString(_ q: Decimal) -> String {
        if q == q.rounded(scale: 0) {
            return NSDecimalNumber(decimal: q).stringValue
        }
        return MoneyFormat.decimal(q, fractionDigits: 4)
    }
}
