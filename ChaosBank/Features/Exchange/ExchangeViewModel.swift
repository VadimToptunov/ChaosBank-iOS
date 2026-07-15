//
//  ExchangeViewModel.swift
//  ChaosBank
//

import Foundation
import Observation

@MainActor
@Observable
final class ExchangeViewModel {
    var sell: Currency = .EUR
    var get: Currency = .USD
    var amountText = ""
    var isSubmitting = false
    var succeeded = false
    var errorMessage: String?

    private(set) var sellBalance: Decimal = 0

    private let services: AppServices
    private var requestToken = 0

    init(services: AppServices) { self.services = services }

    func load() async {
        requestToken += 1
        let token = requestToken
        let value = (await services.backend.fetchAccount(sell))?.balance ?? 0
        applyBalance(value, token: token)
    }

    /// Refresh the sell-account balance.
    ///
    /// When switching currency, a stale in-flight response for the previous
    /// currency can land late. Correct code drops any response superseded by a
    /// newer request (token check). The `slowResponseRace` defect skips that guard,
    /// so the late stale response clobbers the fresh balance.
    func refreshBalance(previous: Currency? = nil) async {
        requestToken += 1
        let token = requestToken

        if let previous, previous != sell {
            let staleToken = token - 1
            Task { [weak self] in
                guard let self else { return }
                let stale = (await self.services.backend.fetchAccount(previous, extraDelay: .milliseconds(300)))?.balance ?? 0
                self.applyBalance(stale, token: staleToken)
            }
        }

        let value = (await services.backend.fetchAccount(sell))?.balance ?? 0
        applyBalance(value, token: token)
    }

    private func applyBalance(_ value: Decimal, token: Int) {
        if !Defects.isActive(.slowResponseRace), token < requestToken { return }
        sellBalance = value
    }

    var amount: Decimal? {
        guard let a = AmountParser.parse(amountText), a > 0 else { return nil }
        return a
    }

    private let cachedInitialRate = FXRates.rate(from: .EUR, to: .USD)

    var rate: Decimal {
        // `exchangeInverseRate`: apply the inverse (wrong-direction) rate.
        if Defects.isActive(.exchangeInverseRate) { return FXRates.rate(from: get, to: sell) }
        // `exchangeRateStaleAfterSwap`: keep the original EUR→USD rate after a swap.
        if Defects.isActive(.exchangeRateStaleAfterSwap) { return cachedInitialRate }
        return FXRates.rate(from: sell, to: get)
    }

    /// Fee charged on the sold amount, in the sell currency.
    var fee: Money {
        Money((amount ?? 0) * FXRates.feeRate, sell).rounded
    }

    /// The amount the user is told they will receive — correct Decimal math.
    var youGet: Money {
        guard let amount else { return Money.zero(get) }
        // `youGetShowsGross`: display the pre-fee amount while the credit is net.
        let base = Defects.isActive(.youGetShowsGross) ? amount : (amount - amount * FXRates.feeRate)
        return Money((base * rate).roundedMoney(), get)
    }

    var canExecute: Bool {
        guard let a = amount else { return false }
        // `exchangeSameCurrencyAllowed`: allow sell == get.
        let currenciesOK = sell != get || Defects.isActive(.exchangeSameCurrencyAllowed)
        return a > 0 && a <= sellBalance && currenciesOK
    }

    /// The value actually credited to the receiving account / written to history.
    ///
    /// Correct path: identical to the displayed `youGet` (Decimal, rounded).
    /// `roundingDrift` defect: routes the conversion through Double, so the stored
    /// value drifts away from what the user was shown.
    private func creditedValue() -> Decimal {
        guard let amount else { return 0 }
        // `exchangeFeeNotApplied`: credit the gross amount, ignoring the fee.
        // `exchangeFeeDoubled`: subtract the fee twice.
        let base: Decimal
        if Defects.isActive(.exchangeFeeNotApplied) {
            base = amount
        } else if Defects.isActive(.exchangeFeeDoubled) {
            base = amount - amount * FXRates.feeRate * 2
        } else {
            base = amount - amount * FXRates.feeRate
        }
        if Defects.isActive(.roundingDrift) {
            let drifted = base.doubleValue * rate.doubleValue
            return Decimal(drifted)
        }
        return (base * rate).roundedMoney()
    }

    func execute() async {
        guard let amount else { return }
        // Correct: re-entrant execute while one is in flight is ignored. The
        // `exchangeDoubleSubmit` defect removes that guard, so a double-tap
        // exchanges twice.
        if !Defects.isActive(.exchangeDoubleSubmit) {
            guard !isSubmitting else { return }
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            // `exchangeCreditsWrongAccount`: credit the sell account instead of get.
            let creditTo = Defects.isActive(.exchangeCreditsWrongAccount) ? sell : get
            try await services.backend.exchange(sell: sell, get: creditTo,
                                                debit: amount, credited: creditedValue())
            services.bumpData()
            succeeded = true
            await refreshBalance()
        } catch BackendError.insufficientFunds {
            errorMessage = "Insufficient funds"
        } catch {
            errorMessage = "Exchange failed"
        }
    }

    func swapDirection() {
        let previous = sell
        swap(&sell, &get)
        Task { await refreshBalance(previous: previous) }
    }

    func selectSell(_ currency: Currency) {
        let previous = sell
        sell = currency
        Task { await refreshBalance(previous: previous) }
    }
}
