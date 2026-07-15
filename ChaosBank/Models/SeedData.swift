//
//  SeedData.swift
//  ChaosBank
//
//  Concrete starting data for the sandbox — real tickers and plausible
//  transactions, no lorem. Deterministic (fixed timestamps).
//

import Foundation

nonisolated enum SeedData {
    /// Fixed reference "now" so grouped-by-date views are deterministic.
    static let referenceDate = Date(timeIntervalSince1970: 1_752_000_000) // 2025-07-08 18:40 UTC

    static func daysAgo(_ d: Int, hours: Int = 0) -> Date {
        referenceDate.addingTimeInterval(TimeInterval(-(d * 86_400 + hours * 3_600)))
    }

    static let accounts: [Account] = [
        Account(name: "EUR Main", currency: .EUR, balance: Decimal(string: "4820.55")!),
        Account(name: "USD Savings", currency: .USD, balance: Decimal(string: "12750.00")!),
        Account(name: "GBP Travel", currency: .GBP, balance: Decimal(string: "640.20")!),
    ]

    static let assets: [Asset] = [
        Asset(symbol: "AAPL", name: "Apple Inc.", kind: .stock, currency: .USD,
              basePrice: Decimal(string: "189.50")!, volatility: Decimal(string: "0.004")!),
        Asset(symbol: "MSFT", name: "Microsoft Corp.", kind: .stock, currency: .USD,
              basePrice: Decimal(string: "415.20")!, volatility: Decimal(string: "0.0035")!),
        Asset(symbol: "NVDA", name: "NVIDIA Corp.", kind: .stock, currency: .USD,
              basePrice: Decimal(string: "875.30")!, volatility: Decimal(string: "0.006")!),
        Asset(symbol: "TSLA", name: "Tesla Inc.", kind: .stock, currency: .USD,
              basePrice: Decimal(string: "242.10")!, volatility: Decimal(string: "0.007")!),
        Asset(symbol: "BTC", name: "Bitcoin", kind: .crypto, currency: .USD,
              basePrice: Decimal(string: "64200.00")!, volatility: Decimal(string: "0.008")!),
        Asset(symbol: "ETH", name: "Ethereum", kind: .crypto, currency: .USD,
              basePrice: Decimal(string: "3120.00")!, volatility: Decimal(string: "0.009")!),
    ]

    static let watchlistSymbols: [String] = ["AAPL", "NVDA", "BTC"]

    static let holdings: [Holding] = [
        // Gain: bought AAPL below current.
        Holding(symbol: "AAPL", quantity: Decimal(string: "12")!, avgCost: Decimal(string: "150.00")!),
        // Loss: bought TSLA above current — the pnlSign defect target.
        Holding(symbol: "TSLA", quantity: Decimal(string: "8")!, avgCost: Decimal(string: "280.00")!),
        // Gain: ETH.
        Holding(symbol: "ETH", quantity: Decimal(string: "3.5")!, avgCost: Decimal(string: "2400.00")!),
    ]

    static let transactions: [Transaction] = [
        tx("t01", "Salary — Acme Corp", "Income", 0, "3200.00", .EUR),
        tx("t02", "Grocery Store", "Groceries", 1, "-64.30", .EUR),
        tx("t03", "Transfer to Alex", "Transfer", 1, "-120.00", .EUR),
        tx("t04", "Coffee Roasters", "Dining", 2, "-4.80", .EUR),
        tx("t05", "Refund — Zalando", "Shopping", 2, "39.99", .EUR),
        tx("t06", "Electricity Bill", "Utilities", 3, "-88.10", .EUR),
        tx("t07", "Exchange EUR → USD", "Exchange", 3, "-500.00", .EUR),
        tx("t08", "Freelance Payout", "Income", 4, "740.00", .USD),
        tx("t09", "App Store", "Digital", 4, "-9.99", .EUR),
        tx("t10", "Restaurant Bella", "Dining", 5, "-52.40", .EUR),
        tx("t11", "Pharmacy", "Health", 6, "-18.75", .EUR),
        tx("t12", "Transfer from Mia", "Transfer", 6, "85.00", .EUR),
        tx("t13", "Gym Membership", "Health", 7, "-29.90", .EUR),
        tx("t14", "Fuel Station", "Transport", 8, "-61.20", .EUR),
        tx("t15", "Book Depository", "Shopping", 9, "-23.45", .EUR),
        tx("t16", "Interest", "Income", 10, "12.06", .USD),
    ]

    private static func tx(_ id: String, _ title: String, _ category: String,
                           _ daysAgo: Int, _ amount: String, _ currency: Currency) -> Transaction {
        // Deterministic intra-day hour from the id's trailing digits.
        let hour = (Int(id.suffix(2)) ?? 0) % 12
        return Transaction(id: id, title: title, category: category,
                           date: SeedData.daysAgo(daysAgo, hours: hour),
                           amount: Decimal(string: amount)!, currency: currency)
    }
}
