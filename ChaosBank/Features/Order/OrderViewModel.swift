//
//  OrderViewModel.swift
//  ChaosBank
//

import Foundation
import Observation

@MainActor
@Observable
final class OrderViewModel {
    let symbol: String
    var side: OrderSide
    var type: OrderType = .market
    var quantity: Decimal = 1
    var limitPriceText: String
    var showConfirm = false
    var isSubmitting = false
    var placed = false
    var status: OrderStatus?
    var errorMessage: String?

    private let capturedPrice: Decimal
    private let services: AppServices
    let currency: Currency = .USD

    init(request: OrderRequest, services: AppServices) {
        self.symbol = request.symbol
        self.side = request.side
        self.capturedPrice = request.capturedPrice
        self.services = services
        self.limitPriceText = MoneyFormat.price(request.capturedPrice)
    }

    /// The price the order acts on.
    ///
    /// Correct path: the price captured when Buy/Sell was tapped. The
    /// `livePriceRace` defect re-reads the live feed instead, so the confirmation
    /// price differs from the price the user acted on.
    var referencePrice: Decimal {
        if Defects.isActive(.livePriceRace) {
            return services.market.price(for: symbol)
        }
        return capturedPrice
    }

    var limitPrice: Decimal? { AmountParser.parse(limitPriceText) }

    var executionPrice: Decimal {
        switch type {
        case .market: return referencePrice
        case .limit: return limitPrice ?? referencePrice
        }
    }

    /// Displayed estimated total.
    ///
    /// Correct path: exact Decimal, rounded — equal to what the account is
    /// actually charged. The `roundingDrift` defect routes the multiply through
    /// Double, so the displayed total drifts from the charged amount.
    var estTotal: Money {
        if Defects.isActive(.roundingDrift) {
            return Money(Decimal(quantity.doubleValue * executionPrice.doubleValue), currency)
        }
        return Money((quantity * executionPrice).roundedMoney(), currency)
    }

    var limitBelowMarket: Bool {
        type == .limit && side == .sell && (limitPrice ?? 0) < referencePrice
    }

    /// A below-market limit sell should warn (it would execute immediately).
    /// The `limitValidation` defect suppresses the warning.
    var showWarning: Bool {
        if Defects.isActive(.limitValidation) { return false }
        return limitBelowMarket
    }

    /// Whether the order may be reviewed/placed.
    ///
    /// Correct path: quantity must be > 0 and a limit order needs a positive
    /// price. The `limitValidation` defect accepts zero/negative quantity and bad
    /// limits silently.
    var isValid: Bool {
        if Defects.isActive(.limitValidation) { return true }
        guard quantity > 0 else { return false }
        if type == .limit {
            guard let lp = limitPrice, lp > 0 else { return false }
        }
        return true
    }

    func increment() { quantity += 1 }

    func decrement() {
        if Defects.isActive(.limitValidation) {
            quantity -= 1                 // buggy: can go to zero / negative
        } else {
            quantity = max(0, quantity - 1)
        }
    }

    func place() async {
        guard isValid else { return }
        // Correct: re-entrant taps while one placement is in flight are ignored
        // (idempotent). The `orderDoubleSubmit` defect drops that guard, so a
        // rapid double-tap places two orders.
        if !Defects.isActive(.orderDoubleSubmit) {
            guard !isSubmitting else { return }
        }
        isSubmitting = true
        defer { isSubmitting = false }

        let order = Order(id: UUID().uuidString, symbol: symbol, side: side, type: type,
                          quantity: quantity, limitPrice: type == .limit ? limitPrice : nil,
                          referencePrice: referencePrice, executionPrice: executionPrice,
                          status: .pending, placedAt: Date())
        do {
            let filled = try await services.backend.placeOrder(order)
            // `orderStuckPending`: the order actually filled, but the UI keeps
            // reporting it as pending.
            status = Defects.isActive(.orderStuckPending) ? .pending : filled.status
            services.bumpData()
            placed = true
        } catch BackendError.insufficientFunds {
            status = .rejected
            errorMessage = "Insufficient funds"
        } catch BackendError.insufficientHolding {
            status = .rejected
            errorMessage = "Not enough to sell"
        } catch {
            status = .rejected
            errorMessage = "Order rejected"
        }
    }
}
