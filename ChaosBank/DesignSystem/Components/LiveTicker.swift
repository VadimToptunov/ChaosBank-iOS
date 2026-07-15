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
                withAnimation(.easeOut(duration: 0.6)) { color = Palette.text }
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
