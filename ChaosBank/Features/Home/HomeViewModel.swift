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

    init(services: AppServices) {
        self.services = services
    }

    func load() async {
        accounts = await services.backend.fetchAccounts()
        let all = await services.backend.fetchTransactions()
        recent = Array(all.prefix(4))
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
        let sum = source.reduce(Decimal(0)) { partial, account in
            partial + FXRates.convert(account.balance, from: account.currency, to: selectedCurrency)
        }
        return Money(sum, selectedCurrency)
    }

    /// Deterministic "today" change: +0.40% of the total.
    var todayChange: Money {
        Money(totalBalance.amount * Decimal(string: "0.004")!, selectedCurrency)
    }

    var todayChangePercent: Decimal { Decimal(string: "0.40")! }
}
