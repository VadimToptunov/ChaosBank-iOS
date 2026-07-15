//
//  PriceFeed.swift
//  ChaosBank
//
//  Seeded random-walk price feed. Two runs with the same build seed produce the
//  same price walk. Emits full quote snapshots as an AsyncStream of ticks.
//

import Foundation

actor PriceFeed {
    private var rng: SeededRNG
    private var quotes: [String: Quote]
    private let assets: [Asset]
    let interval: Duration

    init(seed: Int, assets: [Asset], interval: Duration = .milliseconds(700)) {
        self.assets = assets
        self.interval = interval
        // Derive the walk RNG from the build seed so it reproduces per seed.
        self.rng = SeededRNG(seed: UInt64(bitPattern: Int64(seed)) &+ 0xA5A5_5A5A)
        self.quotes = Dictionary(uniqueKeysWithValues: assets.map { a in
            (a.symbol, Quote(symbol: a.symbol, price: a.basePrice, dayOpen: a.basePrice,
                             dayHigh: a.basePrice, dayLow: a.basePrice, lastDirection: .flat))
        })
    }

    func snapshot() -> [String: Quote] { quotes }

    /// Advance every quote one tick along the seeded walk.
    func step() -> [String: Quote] {
        let floor = Decimal(string: "0.01")!
        for a in assets {
            guard var quote = quotes[a.symbol] else { continue }
            let r = Decimal(Double.random(in: -1...1, using: &rng))
            let delta = quote.price * a.volatility * r
            var newPrice = (quote.price + delta).rounded(scale: 2)
            if newPrice < floor { newPrice = floor }
            quote.lastDirection = newPrice > quote.price ? .up
                : (newPrice < quote.price ? .down : .flat)
            quote.price = newPrice
            if newPrice > quote.dayHigh { quote.dayHigh = newPrice }
            if newPrice < quote.dayLow { quote.dayLow = newPrice }
            quotes[a.symbol] = quote
        }
        return quotes
    }

    /// An AsyncStream that yields the initial snapshot, then a new snapshot every
    /// `interval`.
    func ticks() -> AsyncStream<[String: Quote]> {
        AsyncStream { continuation in
            let task = Task {
                continuation.yield(quotes)
                while !Task.isCancelled {
                    try? await Task.sleep(for: interval)
                    if Task.isCancelled { break }
                    continuation.yield(step())
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
