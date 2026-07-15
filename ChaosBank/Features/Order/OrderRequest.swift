//
//  OrderRequest.swift
//  ChaosBank
//
//  Carries the tapped context into the order ticket, including the price the user
//  acted on. The `livePriceRace` defect ignores this captured price and re-reads
//  the live feed instead.
//

import Foundation

struct OrderRequest: Identifiable, Hashable {
    let symbol: String
    let side: OrderSide
    /// The price shown on the asset screen at the moment Buy/Sell was tapped.
    let capturedPrice: Decimal

    var id: String { "\(symbol).\(side.rawValue).\(capturedPrice)" }
}
