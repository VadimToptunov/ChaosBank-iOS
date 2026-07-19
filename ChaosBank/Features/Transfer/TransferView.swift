//
//  TransferView.swift
//  ChaosBank
//

import SwiftUI

struct TransferView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var vm: TransferViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm {
                    form(vm)
                }
            }
            .background(Palette.bg)
            .navigationTitle("Transfer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.tint(Palette.sand)
                }
            }
            .toolbarBackground(Palette.bg, for: .navigationBar)
        }
        .task {
            if vm == nil { vm = TransferViewModel(services: services) }
            await vm?.load()
        }
    }

    @ViewBuilder
    private func form(_ vm: TransferViewModel) -> some View {
        @Bindable var vm = vm

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Saved payment templates (banking-breadth). Tapping one prefills the form.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(services.templates.templates) { t in
                            Button {
                                vm.recipient = t.recipient
                                vm.amountText = NSDecimalNumber(decimal: services.templates.prefillAmount(t)).stringValue
                            } label: {
                                Text(t.name)
                                    .font(.appBody(13, weight: .medium)).foregroundStyle(Palette.text)
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(Palette.surface2)
                                    .clipShape(Capsule())
                            }
                            .accessibilityIdentifier(A11y.Transfer.template(t.id))
                        }
                    }
                }
                .accessibilityIdentifier(A11y.Transfer.templatesRow)

                CardSurface {
                    VStack(alignment: .leading, spacing: 14) {
                        field("Recipient", text: $vm.recipient,
                              a11y: A11y.Transfer.recipientField, placeholder: "Name or IBAN")
                        Divider().overlay(Palette.line)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Amount").font(.appBody(13)).foregroundStyle(Palette.muted)
                            HStack {
                                Text(vm.fromCurrency.symbol)
                                    .moneyStyle(24, weight: .bold).foregroundStyle(Palette.sand)
                                TextField("0.00", text: $vm.amountText)
                                    .keyboardType(.decimalPad)
                                    .moneyStyle(24, weight: .bold)
                                    .foregroundStyle(Palette.text)
                                    .accessibilityIdentifier(A11y.Transfer.amountField)
                            }
                        }
                        Divider().overlay(Palette.line)
                        field("Note", text: $vm.note,
                              a11y: A11y.Transfer.noteField, placeholder: "Optional")
                    }
                }

                HStack {
                    Text("Balance after")
                        .font(.appBody(14)).foregroundStyle(Palette.muted)
                    Spacer()
                    Text(vm.balanceAfter?.formatted ?? Money(vm.fromBalance, vm.fromCurrency).formatted)
                        .moneyStyle(15, weight: .semibold)
                        .foregroundStyle(Palette.text)
                        .accessibilityIdentifier(A11y.Transfer.balanceAfter)
                }
                .padding(.horizontal, 4)

                if let error = vm.errorMessage {
                    Text(error)
                        .font(.appBody(14, weight: .medium))
                        .foregroundStyle(Palette.loss)
                        .accessibilityIdentifier(A11y.Transfer.error)
                }

                // `disabledButtonTappable` defect: the button looks disabled when
                // the form is invalid but is still interactive.
                let fakeDisabled = Defects.isActive(.disabledButtonTappable)
                PrimaryButton(title: "Continue",
                              enabled: fakeDisabled ? true : vm.canContinue,
                              looksDisabled: !vm.canContinue) {
                    vm.errorMessage = nil
                    vm.showConfirm = true
                }
                .accessibilityIdentifier(A11y.Transfer.continueButton)
            }
            .padding(20)
        }
        .overlay(alignment: .top) {
            // `successToastMissing` defect: no confirmation toast is shown.
            if vm.succeeded && !Defects.isActive(.successToastMissing) {
                Toast(message: "Transfer sent", a11y: A11y.Transfer.successToast)
                    .padding(.top, 12)
            }
        }
        .sheet(isPresented: $vm.showConfirm) {
            confirmSheet(vm)
        }
        .onChange(of: vm.succeeded) { _, done in
            guard done else { return }
            Task {
                // `successToastTooBrief`: dismiss almost immediately.
                try? await Task.sleep(for: Defects.isActive(.successToastTooBrief) ? .milliseconds(120) : .seconds(1.4))
                dismiss()
            }
        }
    }

    @ViewBuilder
    private func confirmSheet(_ vm: TransferViewModel) -> some View {
        VStack(spacing: 20) {
            Capsule().fill(Palette.line).frame(width: 40, height: 5).padding(.top, 10)
            Text("Confirm transfer")
                .font(.appDisplay(20, weight: .bold))
                .foregroundStyle(Palette.text)

            CardSurface {
                VStack(spacing: 12) {
                    confirmRow("To", vm.confirmRecipientText)
                    Divider().overlay(Palette.line)
                    confirmRow("Amount", Money(vm.amount ?? 0, vm.fromCurrency).formatted)
                    if !vm.note.isEmpty {
                        Divider().overlay(Palette.line)
                        confirmRow("Note", vm.note)
                    }
                }
            }

            if let error = vm.errorMessage {
                Text(error)
                    .font(.appBody(13, weight: .medium))
                    .foregroundStyle(Palette.loss)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier(A11y.Transfer.error)
            }

            Spacer()

            if vm.canRetry {
                SecondaryButton(title: "Retry", systemImage: "arrow.clockwise") {
                    Task {
                        await vm.retry()
                        if vm.succeeded { vm.showConfirm = false }
                    }
                }
                .accessibilityIdentifier(A11y.Transfer.retryButton)
            }

            // Intentionally NOT disabled while submitting: idempotency is enforced
            // in the view model, not by hiding the button. This is what lets a
            // rapid double-tap exercise the doubleCharge defect.
            PrimaryButton(title: "Confirm") {
                Task {
                    await vm.confirmTransfer()
                    if vm.succeeded { vm.showConfirm = false }
                }
            }
            .accessibilityIdentifier(A11y.Transfer.confirmButton)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg)
        .accessibilityIdentifier(A11y.Transfer.confirmSheet)
        .presentationDetents([.medium])
    }

    private func confirmRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.appBody(14)).foregroundStyle(Palette.muted)
            Spacer()
            Text(value).font(.appBody(15, weight: .semibold)).foregroundStyle(Palette.text)
        }
    }

    private func field(_ label: String, text: Binding<String>, a11y: String, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.appBody(13)).foregroundStyle(Palette.muted)
            TextField(placeholder, text: text)
                .font(.appBody(16))
                .foregroundStyle(Palette.text)
                .accessibilityIdentifier(a11y)
        }
    }
}
