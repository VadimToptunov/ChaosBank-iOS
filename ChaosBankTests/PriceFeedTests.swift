//
//  PriceFeedTests.swift
//  ChaosBankTests
//

import XCTest
@testable import ChaosBank

final class PriceFeedTests: XCTestCase {

    private func walk(seed: Int, steps: Int) async -> Decimal {
        let feed = PriceFeed(seed: seed, assets: SeedData.assets, interval: .milliseconds(1))
        var price = Decimal(0)
        for _ in 0..<steps { price = (await feed.step())["AAPL"]?.price ?? 0 }
        return price
    }

    func testSameSeedReproducesWalk() async {
        let a = await walk(seed: 7, steps: 25)
        let b = await walk(seed: 7, steps: 25)
        XCTAssertEqual(a, b)
    }

    func testDifferentSeedDiffers() async {
        let a = await walk(seed: 7, steps: 25)
        let b = await walk(seed: 8, steps: 25)
        XCTAssertNotEqual(a, b)
    }

    func testSeededRNGIsDeterministic() {
        var r1 = SeededRNG(seed: 42)
        var r2 = SeededRNG(seed: 42)
        XCTAssertEqual(r1.next(), r2.next())
        XCTAssertEqual(Double.random(in: 0...1, using: &r1), Double.random(in: 0...1, using: &r2))
    }
}
