//
//  Transaction.swift
//  ChaosBank
//

import Foundation

nonisolated enum TransactionDirection: String, Sendable {
    case moneyIn
    case moneyOut
}

nonisolated struct Transaction: Identifiable, Equatable, Sendable {
    let id: String
    let title: String           // "Grocery Store", "Transfer to Alex"
    let category: String        // "Groceries", "Transfer", "Exchange"
    let date: Date
    /// Signed: negative = money out, positive = money in.
    let amount: Decimal
    let currency: Currency

    var direction: TransactionDirection {
        amount < 0 ? .moneyOut : .moneyIn
    }

    var money: Money { Money(amount, currency) }
}
