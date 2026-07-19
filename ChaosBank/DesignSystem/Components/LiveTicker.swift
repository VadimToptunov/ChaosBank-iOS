//
//  LiveTicker.swift
//  ChaosBank
//
//  The signature element: a price that briefly flashes green/up or red/down on
//  each tick, then settles back to the neutral text color. Respects Reduce
//  Motion — the value still updates, it just doesn't animate the flash.
//

import SwiftUI

struct LiveTickerText: View {
    let text: String
    let direction: TickDirection
    var size: CGFloat = 16
    var weight: Font.Weight = .semibold
    var a11y: String? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var color = Palette.text

    var body: some View {
        Text(text)
            .moneyStyle(size, weight: weight)
            .foregroundStyle(color)
            .accessibilityIdentifier(a11y ?? "")
            .onChange(of: text) {
                guard !reduceMotion else { color = Palette.text; return }
                color = Palette.tick(direction)
                // `flakyAnimation`: the settle duration jitters per tick — sometimes
                // near-instant, sometimes very long — so a "wait for the flash to
                // clear" step flakes.
                let duration: Double = Defects.isActive(.flakyAnimation)
                    ? (StableHash.of(text) % 2 == 0 ? 0.02 : 2.6)
                    : 0.6
                withAnimation(.easeOut(duration: duration)) { color = Palette.text }
            }
    }
}

enum StableHash {
    /// Deterministic 64-bit hash (FNV-1a), unlike `String.hashValue` which is
    /// randomized per process.
    static func of(_ string: String) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        for scalar in string.unicodeScalars {
            h ^= UInt64(scalar.value)
            h = h &* 0x100000001b3
        }
        return h
    }
}
