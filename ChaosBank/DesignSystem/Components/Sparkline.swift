//
//  Sparkline.swift
//  ChaosBank
//
//  A tiny deterministic price sparkline. Shape is seeded off the symbol so it is
//  stable across launches; colored green/red by net direction.
//

import SwiftUI

struct Sparkline: View {
    let symbol: String
    var up: Bool
    var pointCount: Int = 24

    private var points: [Double] {
        var rng = SeededRNG(seed: StableHash.of(symbol))
        var value = 0.5
        var result: [Double] = []
        for _ in 0..<pointCount {
            value += Double.random(in: -0.12...0.12, using: &rng)
            value = min(0.95, max(0.05, value))
            result.append(value)
        }
        return result
    }

    var body: some View {
        GeometryReader { geo in
            let pts = points
            let stepX = pts.count > 1 ? geo.size.width / CGFloat(pts.count - 1) : geo.size.width
            Path { path in
                for (i, v) in pts.enumerated() {
                    let x = CGFloat(i) * stepX
                    let y = geo.size.height * (1 - CGFloat(v))
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(up ? Palette.gain : Palette.loss,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }
}
