//
//  LoanCalc.swift
//  ChaosBank
//
//  A sample loan offer (banking-breadth cluster). The `loanAprUnderstated` defect
//  advertises a low APR while charging a higher effective rate — so the monthly
//  payment is higher than the advertised APR implies (a misleading-APR dark pattern).
//

import Foundation

enum LoanCalc {
    static let principal = Decimal(5000)
    static let months = 24
    private static let advertisedApr = Decimal(string: "7.9")!

    /// The APR shown to the user — always the advertised (low) one.
    static func displayedApr() -> Decimal { advertisedApr }

    /// The rate actually used to compute the payment.
    static func effectiveApr() -> Decimal {
        Defects.isActive(.loanAprUnderstated) ? Decimal(string: "13.9")! : advertisedApr
    }

    /// Standard amortised monthly payment for `principal` over `months` at `effectiveApr`.
    static func monthlyPayment() -> Decimal {
        let r = (effectiveApr() as NSDecimalNumber).doubleValue / 100.0 / 12.0
        let p = (principal as NSDecimalNumber).doubleValue
        let n = Double(months)
        let payment = r == 0 ? p / n : p * r * pow(1 + r, n) / (pow(1 + r, n) - 1)
        return Decimal(payment).rounded(scale: 2)
    }

    static func totalCost() -> Decimal {
        (monthlyPayment() * Decimal(months)).rounded(scale: 2)
    }
}
