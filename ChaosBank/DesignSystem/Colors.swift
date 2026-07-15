//
//  Colors.swift
//  ChaosBank
//
//  Design tokens from the spec (§9). Green/red are reserved strictly for
//  gain/loss — the sand accent is deliberately NOT green.
//

import SwiftUI

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

enum Palette {
    static let bg = Color(hex: 0x0E1218)        // deep blue-black background
    static let surface = Color(hex: 0x171C25)   // cards
    static let surface2 = Color(hex: 0x1F2733)  // elevated
    static let line = Color(hex: 0x262F3D)      // hairline borders
    static let sand = Color(hex: 0xE9B45E)      // brand / primary actions
    static let gain = Color(hex: 0x34D399)      // gains only
    static let loss = Color(hex: 0xF87171)      // losses only
    static let text = Color(hex: 0xF4F1EA)      // warm off-white
    static let muted = Color(hex: 0x8B95A6)     // secondary text

    /// Sign-aware gain/loss color. Zero counts as neutral (muted).
    static func pnl(_ value: Decimal) -> Color {
        if value > 0 { return gain }
        if value < 0 { return loss }
        return muted
    }

    static func tick(_ direction: TickDirection) -> Color {
        switch direction {
        case .up: return gain
        case .down: return loss
        case .flat: return muted
        }
    }
}
