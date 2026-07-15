//
//  MarketStore.swift
//  ChaosBank
//
//  Observable view of the price feed. Runs one of two sources:
//   - .simulated : seeded deterministic random-walk (default; reproducible).
//   - .live      : real Yahoo Finance quotes (non-deterministic "chaos" mode).
//

import Foundation
import Observation

nonisolated enum PriceSourceKind: String, Sendable, CaseIterable {
    case simulated
    case live

    var title: String { self == .simulated ? "Simulated" : "Live" }
}

@MainActor
@Observable
final class MarketStore {
    private(set) var quotes: [String: Quote]
    let assets: [Asset]
    private(set) var source: PriceSourceKind
    /// True once at least one live snapshot has arrived (drives the LIVE badge).
    private(set) var liveConnected = false

    private let feed: PriceFeed
    private let live = LivePriceService()
    private var task: Task<Void, Never>?

    init(seed: Int, assets: [Asset], source: PriceSourceKind = .simulated,
         interval: Duration = .milliseconds(700)) {
        self.assets = assets
        self.source = source
        self.feed = PriceFeed(seed: seed, assets: assets, interval: interval)
        self.quotes = Dictionary(uniqueKeysWithValues: assets.map { a in
            (a.symbol, Quote(symbol: a.symbol, price: a.basePrice, dayOpen: a.basePrice,
                             dayHigh: a.basePrice, dayLow: a.basePrice, lastDirection: .flat))
        })
    }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            guard let self else { return }
            switch self.source {
            case .simulated: await self.runSimulated()
            case .live: await self.runLive()
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    func setSource(_ kind: PriceSourceKind) {
        guard kind != source else { return }
        stop()
        source = kind
        liveConnected = false
        start()
    }

    private func runSimulated() async {
        let stream = await feed.ticks()
        for await snapshot in stream {
            quotes = snapshot
        }
    }

    private func runLive() async {
        while !Task.isCancelled {
            let ticks = await live.fetch(assets.map(\.symbol))
            if !ticks.isEmpty {
                apply(ticks)
                liveConnected = true
            }
            // `feedPollsTooOften`: hammer the endpoint 10× more often than needed.
            let interval: Duration = Defects.isActive(.feedPollsTooOften) ? .milliseconds(300) : .seconds(3)
            try? await Task.sleep(for: interval)
        }
    }

    private func apply(_ ticks: [String: LiveTick]) {
        for (symbol, tick) in ticks {
            let previous = quotes[symbol]?.price ?? Decimal(tick.price)
            let newPrice = Decimal(tick.price).rounded(scale: 2)
            let direction: TickDirection = newPrice > previous ? .up
                : (newPrice < previous ? .down : .flat)
            quotes[symbol] = Quote(
                symbol: symbol,
                price: newPrice,
                dayOpen: Decimal(tick.previousClose).rounded(scale: 2),
                dayHigh: Decimal(tick.dayHigh).rounded(scale: 2),
                dayLow: Decimal(tick.dayLow).rounded(scale: 2),
                lastDirection: direction
            )
        }
    }

    func quote(for symbol: String) -> Quote? { quotes[symbol] }

    func price(for symbol: String) -> Decimal {
        quotes[symbol]?.price ?? asset(symbol)?.basePrice ?? 0
    }

    func asset(_ symbol: String) -> Asset? {
        assets.first { $0.symbol == symbol }
    }
}
