//
//  SeededRNG.swift
//  ChaosBank
//
//  Deterministic randomness. Every "random" value in the app — the price walk,
//  race-defect coin flips — is drawn from an RNG seeded off the build seed so
//  two runs with the same seed reproduce exactly.
//

import Foundation

/// SplitMix64: tiny, fast, deterministic. Conforms to RandomNumberGenerator so it
/// can drive the standard `.random(in:using:)` APIs.
nonisolated struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // Avoid a zero state degenerating; mix the seed first.
        self.state = seed &+ 0x9E3779B97F4A7C15
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
