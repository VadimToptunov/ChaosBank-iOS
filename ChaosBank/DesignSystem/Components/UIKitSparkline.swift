//
//  UIKitSparkline.swift
//  ChaosBank
//
//  UIKit twin of the SwiftUI `Sparkline`. Same deterministic shape (seeded off
//  the symbol), same green/red-by-direction colouring — so the "views build"
//  renders identical price sparklines on Markets rows and the asset detail.
//

import SwiftUI
import UIKit

/// Deterministic sparkline samples in 0…1, seeded off `symbol` so the curve is
/// stable across launches. Shared with the SwiftUI `Sparkline` algorithm.
@MainActor
func sparklineSamples(symbol: String, pointCount: Int = 24) -> [Double] {
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

/// A tiny stroked price line, mirroring the SwiftUI `Sparkline` view.
@MainActor
final class SparklineUIView: UIView {
    var symbol: String = "" { didSet { refresh() } }
    var up: Bool = true { didSet { refresh() } }
    /// `sparklineHeavyPoints` drives this to an absurd count on the SwiftUI side;
    /// callers pass the same value so the views build shares the defect.
    var pointCount: Int = 24 { didSet { refresh() } }

    private let shape = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        shape.fillColor = UIColor.clear.cgColor
        shape.lineWidth = 2
        shape.lineCap = .round
        shape.lineJoin = .round
        layer.addSublayer(shape)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }

    override func layoutSubviews() {
        super.layoutSubviews()
        shape.frame = bounds
        refresh()
    }

    private func refresh() {
        guard bounds.width > 0, bounds.height > 0, !symbol.isEmpty else { return }
        let pts = sparklineSamples(symbol: symbol, pointCount: pointCount)
        let stepX = pts.count > 1 ? bounds.width / CGFloat(pts.count - 1) : bounds.width
        let path = UIBezierPath()
        for (i, v) in pts.enumerated() {
            let x = CGFloat(i) * stepX
            let y = bounds.height * (1 - CGFloat(v))
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        shape.path = path.cgPath
        shape.strokeColor = UIColor(up ? Palette.gain : Palette.loss).cgColor
    }
}
