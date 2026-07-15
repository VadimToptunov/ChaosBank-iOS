//
//  Typography.swift
//  ChaosBank
//
//  The spec asks for Space Grotesk / Inter / a tabular mono. To keep the app
//  dependency-free we map those roles onto system faces: rounded-ish system for
//  display, system for body, and a monospaced, tabular-figure face for all money
//  and ticking prices (mandatory so digits don't jump).
//

import SwiftUI

extension Font {
    static func appDisplay(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func appBody(_ size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// Monospaced tabular figures for money / prices.
    static func appMono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension View {
    /// Apply to any numeric label so digits are tabular and don't jump on ticks.
    func moneyStyle(_ size: CGFloat, weight: Font.Weight = .medium) -> some View {
        self.font(.appMono(size, weight: weight)).monospacedDigit()
    }
}
