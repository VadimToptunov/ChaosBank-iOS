//
//  Backend.swift
//  ChaosBank
//
//  What screens and view models talk to. Two implementations: `MockBackend`, the
//  embedded, offline default, and `HttpBackend`, ChaosBank-Server reached over HTTP
//  when the app is launched with `-ChaosBankBackend <url>`. Reads never throw (a
//  failed read serves the last value it knows); writes throw `BackendError`.
//

import Foundation

nonisolated protocol Backend: Actor {
    /// Where the data comes from, for the developer menu.
    nonisolated var label: String { get }

    func fetchAccounts() async -> [Account]
    func fetchAccount(_ currency: Currency, extraDelay: Duration) async -> Account?
    func fetchTransactions() async -> [Transaction]
    func fetchHoldings() async -> [Holding]
    func fetchOrders() async -> [Order]

    func syncValue() async -> Int
    func syncSet(_ value: Int) async
    func syncIncrement() async
    func syncReset() async

    @discardableResult
    func transfer(from currency: Currency, amount: Decimal, recipient: String, note: String,
                  idempotencyKey: String) async throws -> Transaction
    @discardableResult
    func deposit(to currency: Currency, amount: Decimal, title: String) async throws -> Transaction
    @discardableResult
    func exchange(sell: Currency, get: Currency, debit: Decimal, credited: Decimal) async throws -> Transaction
    func placeOrder(_ order: Order) async throws -> Order

    func setScenario(_ scenario: BackendScenario) async
    func setCondition(_ value: NetworkCondition) async
    /// The active defects changed (developer menu). Only a server backend cares:
    /// it forwards the ones it knows. (No default in an extension: in async code Swift
    /// would pick an async default over an implementation's own sync method.)
    func setDefects(_ defects: Set<DefectID>) async
}

extension Backend {
    func fetchAccount(_ currency: Currency) async -> Account? {
        await fetchAccount(currency, extraDelay: .zero)
    }

    @discardableResult
    func deposit(to currency: Currency, amount: Decimal) async throws -> Transaction {
        try await deposit(to: currency, amount: amount, title: "Add money")
    }
}
