//
//  Account.swift
//  ChaosBank
//

import Foundation

nonisolated struct Account: Identifiable, Equatable, Sendable {
    var id: Currency { currency }
    let name: String        // "EUR Main"
    let currency: Currency
    var balance: Decimal
}
