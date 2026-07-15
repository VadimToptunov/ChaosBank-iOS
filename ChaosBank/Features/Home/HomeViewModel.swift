//
//  HomeViewModel.swift
//  ChaosBank
//

import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    var accounts: [Account] = []
    var recent: [Transaction] = []
    var selectedCurrency: Currency = .EUR

    private let services: AppServices
    private var loadToken = 0

    init(services: AppServices) {
        self.services = services
    }

    func load() async {
        // `homeRefreshRace`: a stale in-flight load is allowed to clobber a newer
        // one (the token guard below is skipped).
        loadToken += 1
        let token = loadToken
        let fetchedAccounts = await services.backend.fetchAccounts()
        let all = await services.backend.fetchTransactions()
        if token < loadToken && !Defects.isActive(.homeRefreshRace) { return }
        accounts = fetchedAccounts
        // `recentActivityShowsTwo`: the dashboard shows too few recent rows.
        recent = Array(all.prefix(Defects.isActive(.recentActivityShowsTwo) ? 2 : 4))
    }

    /// Called when a mutation happened elsewhere (dataVersion bumped).
    ///
    /// Correct behavior refreshes so the dashboard reflects the latest state.
    /// The `staleBalance` defect skips the refresh, so the dashboard keeps showing
    /// the pre-transfer balance until a full reload.
    func refreshAfterMutation() async {
        if Defects.isActive(.staleBalance) { return }
        await load()
    }

    var totalBalance: Money {
        // `homeTotalOmitsAccount`: the GBP account is left out of the total.
        let source = Defects.isActive(.homeTotalOmitsAccount)
            ? accounts.filter { $0.currency != .GBP }
            : accounts
        var sum = source.reduce(Decimal(0)) { partial, account in
            partial + FXRates.convert(account.balance, from: account.currency, to: selectedCurrency)
        }
        // `balanceFloorRounded`: floor to the whole unit instead of rounding cents.
        if Defects.isActive(.balanceFloorRounded) {
            var floored = Decimal()
            var input = sum
            NSDecimalRound(&floored, &input, 0, .down)
            sum = floored
        }
        return Money(sum, selectedCurrency)
    }

    /// The rendered total. `balanceWrongCurrencySymbol` forces the € symbol
    /// regardless of the selected currency.
    var totalBalanceText: String {
        if Defects.isActive(.balanceWrongCurrencySymbol) {
            return "€" + MoneyFormat.decimal(totalBalance.amount.roundedMoney())
        }
        return totalBalance.formatted
    }

    /// Deterministic "today" change: +0.40% of the total.
    /// `todayChangeSignFlipped` negates it so a gain reads as a loss.
    var todayChange: Money {
        let base = totalBalance.amount * Decimal(string: "0.004")!
        let signed = Defects.isActive(.todayChangeSignFlipped) ? -base : base
        return Money(signed, selectedCurrency)
    }

    var todayChangePercent: Decimal {
        let base = Decimal(string: "0.40")!
        return Defects.isActive(.todayChangeSignFlipped) ? -base : base
    }
}
