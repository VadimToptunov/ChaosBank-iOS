//
//  CoreLogicTests.swift
//  ChaosBankTests
//
//  Broad, cheap coverage for the remaining pure-logic surface: models, config
//  resolution, services wiring, market store helpers, and assorted branches.
//

import XCTest
@testable import ChaosBank

@MainActor
final class CoreLogicTests: XCTestCase {

    override func tearDown() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        super.tearDown()
    }

    // MARK: Models

    func testModels() {
        let a = Asset(symbol: "AAPL", name: "Apple", kind: .stock, currency: .USD,
                      basePrice: 100, volatility: Decimal(string: "0.01")!)
        XCTAssertEqual(a.id, "AAPL")

        let h = Holding(symbol: "AAPL", quantity: 10, avgCost: 100)
        XCTAssertEqual(h.costBasis, 1000)
        XCTAssertEqual(h.marketValue(at: 120), 1200)
        XCTAssertEqual(h.pnl(at: 120), 200)
        XCTAssertEqual(h.pnlPercent(at: 120), 20)
        XCTAssertEqual(h.id, "AAPL")

        var q = Quote(symbol: "AAPL", price: 110, dayOpen: 100, dayHigh: 115, dayLow: 95, lastDirection: .up)
        XCTAssertEqual(q.changeAbsolute, 10)
        XCTAssertEqual(q.changePct, 10)
        q.price = 100
        XCTAssertEqual(q.changePct, 0)

        let tx = Transaction(id: "t", title: "x", category: "Transfer", date: Date(), amount: -5, currency: .EUR)
        XCTAssertEqual(tx.direction, .moneyOut)
        XCTAssertEqual(tx.money.amount, -5)

        let order = Order(id: "o", symbol: "AAPL", side: .buy, type: .market, quantity: 2,
                          limitPrice: nil, referencePrice: 100, executionPrice: 100,
                          status: .pending, placedAt: Date())
        XCTAssertEqual(order.estimatedTotal, 200)

        let req = OrderRequest(symbol: "AAPL", side: .sell, capturedPrice: 100)
        XCTAssertTrue(req.id.contains("AAPL"))
    }

    // MARK: Money & currency

    func testMoneyEdges() {
        XCTAssertEqual(Money.zero(.EUR).amount, 0)
        XCTAssertEqual(Money(0, .EUR).formattedSigned.first, "+")
        XCTAssertEqual(Currency.EUR.symbol, "€")
        XCTAssertEqual(Currency.USD.code, "USD")
        XCTAssertEqual(Currency.allCases.count, 3)
        XCTAssertNil(AmountParser.parse("   "))
        XCTAssertEqual(FXRates.convert(100, from: .EUR, to: .EUR), 100)
    }

    // MARK: BuildConfig.resolve

    func testResolveProfile() {
        let cfg = BuildConfig.resolve(defaults: emptyDefaults(), environment: ["CHAOSBANK_PROFILE": "flaky"])
        XCTAssertEqual(cfg.label, "flaky")
        XCTAssertEqual(cfg.activeDefects, DefectRegistry.ids(in: .concurrency))
    }

    func testResolveSeed() {
        let cfg = BuildConfig.resolve(defaults: emptyDefaults(), environment: ["CHAOSBANK_SEED": "1"])
        XCTAssertEqual(cfg.seed, 1)
        XCTAssertEqual(cfg.activeDefects, [DefectID.allCases[0]])
        XCTAssertEqual(cfg.seedBadge, "01")
    }

    func testResolveExplicitDefectsAndPriceSource() {
        let d = emptyDefaults()
        d.set("doubleCharge,roundingDrift", forKey: "ChaosBankDefects")
        let cfg = BuildConfig.resolve(defaults: d, environment: ["CHAOSBANK_PRICE_SOURCE": "live"])
        XCTAssertEqual(cfg.label, "custom")
        XCTAssertEqual(cfg.activeDefects, [.doubleCharge, .roundingDrift])
        XCTAssertEqual(cfg.priceSource, .live)
    }

    func testResolveClean() {
        let cfg = BuildConfig.resolve(defaults: emptyDefaults(), environment: [:])
        XCTAssertEqual(cfg.label, "clean")
        XCTAssertTrue(cfg.activeDefects.isEmpty)
    }

    // MARK: AppServices

    func testAppServicesMutations() {
        let cfg = BuildConfig(seed: 0, activeDefects: [], label: "clean")
        Defects.configure(cfg)
        let s = AppServices(config: cfg)

        s.applyProfile(BugProfiles.profile(id: "security")!)
        XCTAssertEqual(s.config.label, "security")
        XCTAssertTrue(Defects.isActive(.tokenInUserDefaults))

        s.toggle(.doubleCharge)
        XCTAssertTrue(s.isActive(.doubleCharge))
        XCTAssertEqual(s.config.label, "custom")
        s.toggle(.doubleCharge)
        XCTAssertFalse(s.isActive(.doubleCharge))

        s.applyDefects([.pnlSign], label: "x")
        XCTAssertEqual(s.config.activeDefects, [.pnlSign])

        let v = s.configVersion
        s.bumpData()
        s.setPriceSource(.live)
        XCTAssertEqual(s.market.source, .live)
        XCTAssertGreaterThan(s.configVersion, v - 1)
    }

    // MARK: MarketStore

    func testMarketStoreHelpers() {
        let store = MarketStore(seed: 7, assets: SeedData.assets)
        XCTAssertEqual(store.source, .simulated)
        XCTAssertEqual(store.price(for: "AAPL"), SeedData.assets.first { $0.symbol == "AAPL" }!.basePrice)
        XCTAssertNotNil(store.quote(for: "BTC"))
        XCTAssertEqual(store.asset("TSLA")?.symbol, "TSLA")
        XCTAssertNil(store.asset("NOPE"))
        store.setSource(.live)
        XCTAssertEqual(store.source, .live)
        store.stop()
    }

    // MARK: Defects registry access

    func testDefectsAccessors() {
        Defects.configure(BuildConfig(seed: 5, activeDefects: [.pnlSign], label: "t"))
        XCTAssertTrue(Defects.isActive(.pnlSign))
        XCTAssertFalse(Defects.isActive(.doubleCharge))
        XCTAssertEqual(Defects.seed, 5)
        XCTAssertEqual(DefectRegistry.defect(.pnlSign).category, .money)
    }

    private func emptyDefaults() -> UserDefaults {
        let name = "chaosbank.tests"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }
}
