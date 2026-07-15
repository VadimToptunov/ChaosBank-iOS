//
//  Order.swift
//  ChaosBank
//

import Foundation

nonisolated enum OrderSide: String, Sendable {
    case buy
    case sell
}

nonisolated enum OrderType: String, Sendable {
    case market
    case limit
}

nonisolated enum OrderStatus: String, Sendable {
    case pending
    case filled
    case rejected
}

nonisolated struct Order: Identifiable, Equatable, Sendable {
    let id: String
    let symbol: String
    let side: OrderSide
    let type: OrderType
    var quantity: Decimal
    var limitPrice: Decimal?
    /// Reference price the user acted on when placing the order.
    var referencePrice: Decimal
    var executionPrice: Decimal
    var status: OrderStatus
    let placedAt: Date

    var estimatedTotal: Decimal { quantity * executionPrice }
}
