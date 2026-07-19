//
//  LoansView.swift
//  ChaosBank
//

import SwiftUI

struct LoansView: View {
    var body: some View {
        ChaosBankScreen(title: "Personal loan", a11y: A11y.Loans.root, showBadge: false) {
            CardSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Borrow \(Money(LoanCalc.principal, .EUR).formatted) over \(LoanCalc.months) months")
                        .font(.appBody(15, weight: .semibold)).foregroundStyle(Palette.text)
                    row("APR", "\(MoneyFormat.decimal(LoanCalc.displayedApr(), fractionDigits: 1))%", A11y.Loans.apr)
                    row("Monthly payment", Money(LoanCalc.monthlyPayment(), .EUR).formatted, A11y.Loans.monthly)
                    row("Total repayable", Money(LoanCalc.totalCost(), .EUR).formatted, A11y.Loans.total)
                }
            }
            Text("Representative example. Not a real credit offer.")
                .font(.appBody(11)).foregroundStyle(Palette.muted)
        }
    }

    private func row(_ label: String, _ value: String, _ a11y: String) -> some View {
        HStack {
            Text(label).font(.appBody(14)).foregroundStyle(Palette.muted)
            Spacer()
            Text(value).moneyStyle(15, weight: .semibold).foregroundStyle(Palette.text)
                .accessibilityIdentifier(a11y)
        }
    }
}
