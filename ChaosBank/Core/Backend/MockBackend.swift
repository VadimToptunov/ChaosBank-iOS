//
//  MockBackend.swift
//  ChaosBank
//
//  In-memory authoritative state with configurable latency. No network, no
//  persistence. All money math here is correct (Decimal); defects live in the
//  callers' guarded injection points, never in this file.
//

import Foundation

enum BackendError: Error, Equatable {
    case insufficientFunds
    case unknownAccount
    case invalidAmount
    case unknownAsset
    case insufficientHolding
    case timeout
    case offline
}

actor MockBackend {
    private var accountsByCurrency: [Currency: Account]
    private var transactions: [Transaction]   // newest first
    private var holdings: [String: Holding]
    private var orders: [Order]
    private let assets: [String: Asset]

    /// Fixed (not random) simulated round-trip latency, so timing is reproducible.
    let latency: Duration
    private var sequence = 0
    private var scenario: BackendScenario
    /// Simulated network environment (dev-menu / reliability cluster).
    private var condition: NetworkCondition = .normal
    private var flakySeq: UInt64 = 0

    /// Idempotency ledger: key → the transaction that key produced.
    private var processedKeys: [String: Transaction] = [:]
    /// Immutable offline snapshots captured at init, used by staleOfflineBalance /
    /// staleHoldingsAfterOrder.
    private let offlineAccounts: [Currency: Account]
    private let offlineHoldings: [String: Holding]

    /// The account used as trading cash.
    private let cashCurrency: Currency = .USD

    init(latency: Duration = .milliseconds(120), scenario: BackendScenario = BackendScenario()) {
        self.latency = latency
        self.scenario = scenario
        let seeded = Dictionary(uniqueKeysWithValues: SeedData.accounts.map { ($0.currency, $0) })
        self.accountsByCurrency = seeded
        self.offlineAccounts = seeded
        self.transactions = SeedData.transactions.sorted { $0.date > $1.date }
        let seededHoldings = Dictionary(uniqueKeysWithValues: SeedData.holdings.map { ($0.symbol, $0) })
        self.holdings = seededHoldings
        self.offlineHoldings = seededHoldings
        self.orders = []
        self.assets = Dictionary(uniqueKeysWithValues: SeedData.assets.map { ($0.symbol, $0) })
    }

    func setScenario(_ scenario: BackendScenario) {
        self.scenario = scenario
    }

    func setCondition(_ value: NetworkCondition) {
        condition = value
    }

    /// Convenience for the offline-only path (kept for existing callers/tests).
    func setOffline(_ value: Bool) {
        condition = value ? .offline : .normal
    }

    /// Offline blocks writes.
    private func requireOnline() throws {
        if condition == .offline { throw BackendError.offline }
    }

    /// `flaky` fails writes transiently; the sequence is seeded so it reproduces.
    private func failIfFlaky() throws {
        guard condition == .flaky else { return }
        var rng = SeededRNG(seed: flakySeq)
        flakySeq += 1
        if Double.random(in: 0..<1, using: &rng) < 0.5 { throw BackendError.timeout }
    }

    private func delay(extra: Duration = .zero) async {
        try? await Task.sleep(for: latency)
        if condition == .slow { try? await Task.sleep(for: .seconds(3)) }
        if extra != .zero { try? await Task.sleep(for: extra) }
    }

    private func nextID(_ prefix: String) -> String {
        sequence += 1
        return "\(prefix)-\(sequence)"
    }

    // MARK: - Reads

    func fetchAccounts() async -> [Account] {
        await delay()
        let source = scenario.staleOfflineBalance ? offlineAccounts : accountsByCurrency
        return Currency.allCases.compactMap { source[$0] }.map(zeroedIfNeeded)
    }

    func fetchAccount(_ currency: Currency, extraDelay: Duration = .zero) async -> Account? {
        await delay(extra: extraDelay)
        let source = scenario.staleOfflineBalance ? offlineAccounts : accountsByCurrency
        return source[currency].map(zeroedIfNeeded)
    }

    /// `balanceReadReturnsZero`: a read error surfaces as a zero balance.
    private func zeroedIfNeeded(_ account: Account) -> Account {
        guard scenario.balanceReadReturnsZero else { return account }
        return Account(name: account.name, currency: account.currency, balance: 0)
    }

    func fetchTransactions() async -> [Transaction] {
        await delay()
        // `transactionsDupOnFetch`: every row is returned twice.
        return scenario.transactionsDupOnFetch ? transactions.flatMap { [$0, $0] } : transactions
    }

    func fetchHoldings() async -> [Holding] {
        await delay()
        // `staleHoldingsAfterOrder`: serve the pre-order snapshot.
        let source = scenario.staleHoldingsAfterOrder ? offlineHoldings : holdings
        return SeedData.assets.compactMap { source[$0.symbol] }
    }

    func fetchOrders() async -> [Order] {
        await delay()
        return orders
    }

    // MARK: - Sync playground (reliability cluster)

    /// A shared counter with an atomic increment (correct) plus separate read/write
    /// primitives (for the lost-update race).
    private var syncCounter = 0

    func syncValue() async -> Int { await delay(); return syncCounter }
    func syncSet(_ value: Int) async { await delay(); syncCounter = value }
    func syncIncrement() async { await delay(); syncCounter += 1 }
    func syncReset() { syncCounter = 0 }

    // MARK: - Mutations

    /// Money out from the chosen account to an external recipient. Correct,
    /// non-idempotent primitive: every call that passes validation records one
    /// transaction. Idempotency (one tap = one transfer) is enforced by the
    /// caller; the `doubleCharge` defect removes that guard.
    @discardableResult
    func transfer(from currency: Currency, amount: Decimal, recipient: String, note: String,
                  idempotencyKey: String) async throws -> Transaction {
        await delay()
        try requireOnline()
        try failIfFlaky()

        // Idempotent replay: a retry with the same key returns the original
        // transaction without re-posting — unless the `retryDuplicate` scenario
        // disables the ledger, in which case the retry double-posts.
        if let existing = processedKeys[idempotencyKey], !scenario.retryDuplicate {
            return existing
        }

        guard amount > 0 else { throw BackendError.invalidAmount }
        guard var account = accountsByCurrency[currency] else { throw BackendError.unknownAccount }
        guard account.balance >= amount else { throw BackendError.insufficientFunds }

        account.balance -= amount
        accountsByCurrency[currency] = account

        let title = recipient.isEmpty ? "Transfer" : "Transfer to \(recipient)"
        let tx = Transaction(id: nextID("tx"), title: title, category: "Transfer",
                             date: Date(), amount: -amount, currency: currency)
        transactions.insert(tx, at: 0)
        processedKeys[idempotencyKey] = tx

        // The server committed, but the client "times out" before the ack. A
        // correct client surfaces an error; the `timeoutAsSuccess` defect (handled
        // client-side) mistakes it for success.
        if scenario.timeoutAsSuccess {
            throw BackendError.timeout
        }
        return tx
    }

    /// Add money to an account (a top-up). Correct, simple credit.
    @discardableResult
    func deposit(to currency: Currency, amount: Decimal, title: String = "Add money") async throws -> Transaction {
        await delay()
        try requireOnline()
        try failIfFlaky()
        guard amount > 0 else { throw BackendError.invalidAmount }
        guard var account = accountsByCurrency[currency] else { throw BackendError.unknownAccount }
        account.balance += amount
        accountsByCurrency[currency] = account
        let tx = Transaction(id: nextID("dep"), title: title, category: "Top-up",
                             date: Date(), amount: amount, currency: currency)
        transactions.insert(tx, at: 0)
        return tx
    }

    /// Sell `amount` of `sell` currency, receive `credited` of `get` currency.
    /// `credited` and `fee` are computed by the caller and stored verbatim so the
    /// stored history matches what the user was shown — except when the caller's
    /// `roundingDrift` injection passes a value that differs from the display.
    @discardableResult
    func exchange(sell: Currency, get: Currency, debit: Decimal, credited: Decimal) async throws -> Transaction {
        await delay()
        try requireOnline()
        try failIfFlaky()
        guard debit > 0 else { throw BackendError.invalidAmount }
        guard var from = accountsByCurrency[sell] else { throw BackendError.unknownAccount }
        guard var to = accountsByCurrency[get] else { throw BackendError.unknownAccount }
        guard from.balance >= debit else { throw BackendError.insufficientFunds }

        from.balance -= debit
        to.balance += credited
        accountsByCurrency[sell] = from
        accountsByCurrency[get] = to

        // The history line records the credited amount actually written to the
        // receiving account — this is where the `roundingDrift` defect surfaces:
        // the stored value can differ from the displayed "you get".
        let title = "Exchange \(sell.code) → \(get.code)"
        let tx = Transaction(id: nextID("fx"), title: title, category: "Exchange",
                             date: Date(), amount: credited, currency: get)
        transactions.insert(tx, at: 0)
        return tx
    }

    /// Execute an order. Buys debit the USD cash account and grow the holding;
    /// sells credit cash and shrink the holding. Cost basis math is correct.
    @discardableResult
    func placeOrder(_ order: Order) async throws -> Order {
        await delay()
        try requireOnline()
        try failIfFlaky()
        guard assets[order.symbol] != nil else { throw BackendError.unknownAsset }
        guard order.quantity > 0 else { throw BackendError.invalidAmount }
        guard var cash = accountsByCurrency[cashCurrency] else { throw BackendError.unknownAccount }

        let total = order.quantity * order.executionPrice

        switch order.side {
        case .buy:
            guard cash.balance >= total else { throw BackendError.insufficientFunds }
            cash.balance -= total
            accountsByCurrency[cashCurrency] = cash

            if var existing = holdings[order.symbol] {
                let newQty = existing.quantity + order.quantity
                let newCostBasis = existing.costBasis + total
                existing.avgCost = newQty == 0 ? 0 : newCostBasis / newQty
                existing.quantity = newQty
                holdings[order.symbol] = existing
            } else {
                holdings[order.symbol] = Holding(symbol: order.symbol,
                                                 quantity: order.quantity,
                                                 avgCost: order.executionPrice)
            }

        case .sell:
            guard let existing = holdings[order.symbol], existing.quantity >= order.quantity else {
                throw BackendError.insufficientHolding
            }
            cash.balance += total
            accountsByCurrency[cashCurrency] = cash

            var updated = existing
            updated.quantity -= order.quantity
            if updated.quantity == 0 { holdings.removeValue(forKey: order.symbol) }
            else { holdings[order.symbol] = updated }
        }

        var filled = order
        filled.status = .filled
        orders.insert(filled, at: 0)

        let verb = order.side == .buy ? "Buy" : "Sell"
        let signed = order.side == .buy ? -total : total
        let tx = Transaction(id: nextID("ord"),
                             title: "\(verb) \(order.symbol)", category: "Trade",
                             date: Date(), amount: signed, currency: cashCurrency)
        transactions.insert(tx, at: 0)
        return filled
    }
}
