//
//  UIKitAssetDetail.swift
//  ChaosBank
//
//  The "views build" rendering of the asset detail with UIKit — a faithful twin
//  of SwiftUI's AssetDetailView: name / live price / % change, a timeframe
//  segment, a price sparkline, a 2×2 stat grid and Sell / Buy (which push the
//  order ticket). Reuses the same data, locators and defects.
//

import SwiftUI
import UIKit

@MainActor
final class AssetDetailViewController: UIViewController {
    private let symbol: String
    private let services: AppServices

    private var asset: Asset? { SeedData.assets.first { $0.symbol == symbol } }
    private var quote: Quote? { services.market.quote(for: symbol) }
    private var price: Decimal {
        let base = quote?.price ?? asset?.basePrice ?? 0
        // `detailPriceOffset`: the detail price drifts from the market price.
        return Defects.isActive(.detailPriceOffset) ? base + Decimal(string: "5")! : base
    }
    private var changePct: Decimal {
        // `detailChangeWrongBase`: measure change vs the anchor base, not day open.
        if Defects.isActive(.detailChangeWrongBase), let base = asset?.basePrice, base != 0 {
            return (price - base) / base * 100
        }
        return quote?.changePct ?? 0
    }

    init(symbol: String, services: AppServices) {
        self.symbol = symbol
        self.services = services
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = symbol
        view.backgroundColor = UIColor(Palette.bg)
        view.accessibilityIdentifier = A11y.Asset.root
        services.startFeed()
        guard let asset else { return }

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Header: name / price / change.
        let name = label(asset.name, size: 14, weight: .regular, color: UIColor(Palette.muted))
        name.accessibilityIdentifier = A11y.Asset.symbol
        let priceLabel = label("$" + MoneyFormat.price(price), size: 40, weight: .bold, color: UIColor(Palette.text))
        priceLabel.accessibilityIdentifier = A11y.Asset.price
        let changeLabel = label("\(MoneyFormat.percent(changePct)) today", size: 15, weight: .semibold,
                                color: UIColor(changePct < 0 ? Palette.loss : Palette.gain))
        changeLabel.accessibilityIdentifier = A11y.Asset.change
        let header = UIStackView(arrangedSubviews: [name, priceLabel, changeLabel])
        header.axis = .vertical
        header.spacing = 6
        header.alignment = .leading
        stack.addArrangedSubview(header)

        // Timeframe segment (visual; the sparkline shape is fixed per symbol).
        stack.addArrangedSubview(timeframeBar())

        // Sparkline chart.
        let spark = SparklineUIView()
        spark.symbol = symbol
        spark.up = changePct >= 0
        spark.heightAnchor.constraint(equalToConstant: 140).isActive = true
        stack.addArrangedSubview(spark)

        // 2×2 stat grid.
        stack.addArrangedSubview(statGrid(asset))

        // Sell / Buy.
        stack.addArrangedSubview(actionRow())

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -96),
        ])
    }

    // MARK: Pieces

    private func timeframeBar() -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 8
        for tf in ["1D", "1W", "1M", "1Y"] {
            var config = UIButton.Configuration.gray()
            config.title = tf
            config.baseForegroundColor = UIColor(Palette.text)
            let b = UIButton(configuration: config)
            b.accessibilityIdentifier = A11y.Asset.timeframe(tf)
            stack.addArrangedSubview(b)
        }
        stack.heightAnchor.constraint(equalToConstant: 40).isActive = true
        return stack
    }

    private func statGrid(_ asset: Asset) -> UIView {
        // `detailStatHighLowSwapped`: the high and low values are swapped.
        let swapped = Defects.isActive(.detailStatHighLowSwapped)
        let high = "$" + MoneyFormat.price((swapped ? quote?.dayLow : quote?.dayHigh) ?? price)
        let low = "$" + MoneyFormat.price((swapped ? quote?.dayHigh : quote?.dayLow) ?? price)
        let tiles = [
            statTile("Market cap", marketCap(asset), A11y.Asset.statMarketCap),
            statTile("Volume", volume(asset), A11y.Asset.statVolume),
            statTile("Day high", high, A11y.Asset.statHigh),
            statTile("Day low", low, A11y.Asset.statLow),
        ]
        let rowA = UIStackView(arrangedSubviews: [tiles[0], tiles[1]])
        let rowB = UIStackView(arrangedSubviews: [tiles[2], tiles[3]])
        [rowA, rowB].forEach { $0.axis = .horizontal; $0.distribution = .fillEqually; $0.spacing = 12 }
        let grid = UIStackView(arrangedSubviews: [rowA, rowB])
        grid.axis = .vertical
        grid.spacing = 12
        return grid
    }

    private func statTile(_ title: String, _ value: String, _ a11y: String) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor(Palette.surface)
        container.layer.cornerRadius = 12
        let t = label(title, size: 12, weight: .regular, color: UIColor(Palette.muted))
        let v = label(value, size: 16, weight: .semibold, color: UIColor(Palette.text))
        v.accessibilityIdentifier = a11y
        let s = UIStackView(arrangedSubviews: [t, v])
        s.axis = .vertical
        s.spacing = 4
        s.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(s)
        NSLayoutConstraint.activate([
            s.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            s.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            s.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            s.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
        ])
        return container
    }

    private func actionRow() -> UIView {
        var sellCfg = UIButton.Configuration.gray()
        sellCfg.title = "Sell"
        sellCfg.baseForegroundColor = UIColor(Palette.text)
        let sell = UIButton(configuration: sellCfg)
        sell.accessibilityIdentifier = A11y.Asset.sellButton
        sell.addAction(UIAction { [weak self] _ in self?.openOrder(side: .sell) }, for: .touchUpInside)

        var buyCfg = UIButton.Configuration.filled()
        buyCfg.title = "Buy"
        buyCfg.baseBackgroundColor = UIColor(Palette.sand)
        buyCfg.baseForegroundColor = UIColor(Palette.bg)
        let buy = UIButton(configuration: buyCfg)
        buy.accessibilityIdentifier = A11y.Asset.buyButton
        // `wrongA11yLabel`: the Buy button announces itself as "Sell".
        buy.accessibilityLabel = Defects.isActive(.wrongA11yLabel) ? "Sell" : "Buy"
        buy.addAction(UIAction { [weak self] _ in
            // `buyButtonPlacesSell`: the Buy button starts a sell ticket.
            self?.openOrder(side: Defects.isActive(.buyButtonPlacesSell) ? .sell : .buy)
        }, for: .touchUpInside)

        let row = UIStackView(arrangedSubviews: [sell, buy])
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 12
        row.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return row
    }

    private func openOrder(side: OrderSide) {
        let request = OrderRequest(symbol: symbol, side: side, capturedPrice: price)
        navigationController?.pushViewController(
            OrderViewController(request: request, services: services), animated: true)
    }

    // MARK: Derived stats (identical to the SwiftUI screen)

    private func marketCap(_ asset: Asset) -> String {
        let shares = Decimal(1_000_000_000 + Int(StableHash.of(asset.symbol) % 4_000_000_000))
        let cap = (price * shares) / Decimal(1_000_000_000)
        return "$" + MoneyFormat.decimal(cap.rounded(scale: 1), fractionDigits: 1) + "B"
    }

    private func volume(_ asset: Asset) -> String {
        let vol = Decimal(10_000_000 + Int(StableHash.of(asset.symbol + "v") % 90_000_000))
        return "$" + MoneyFormat.decimal((vol / Decimal(1_000_000)).rounded(scale: 1), fractionDigits: 1) + "M"
    }

    private func label(_ text: String, size: CGFloat, weight: UIFont.Weight, color: UIColor) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: size, weight: weight)
        l.textColor = color
        l.numberOfLines = 1
        return l
    }
}
