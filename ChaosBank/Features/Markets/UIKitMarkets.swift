//
//  UIKitMarkets.swift
//  ChaosBank
//
//  The "views build" rendering of Markets with UIKit — a faithful twin of the
//  SwiftUI MarketsView: a segment bar (Watchlist / Stocks / Crypto) over a list
//  of asset rows, each with a price sparkline, tapping through to the asset
//  detail (push navigation, like the SwiftUI NavigationStack). Reuses the same
//  data, locators and defects; only the view layer is UIKit. Reached when
//  LaunchOptions.current.uiKit is on.
//

import SwiftUI
import UIKit

struct UIKitMarketsView: UIViewControllerRepresentable {
    @Environment(AppServices.self) private var services
    func makeUIViewController(context: Context) -> UINavigationController {
        UINavigationController(rootViewController: MarketsViewController(services: services))
    }
    func updateUIViewController(_ controller: UINavigationController, context: Context) {}
}

@MainActor
final class MarketsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let services: AppServices
    // Own the table as a subview so the screen root and the list get distinct
    // locators (a UITableViewController's `view` *is* the table).
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let segments = [
        ("watchlist", "Watchlist", A11y.Markets.segmentWatchlist),
        ("stocks", "Stocks", A11y.Markets.segmentStocks),
        ("crypto", "Crypto", A11y.Markets.segmentCrypto),
    ]
    private var current = "watchlist"
    private var rows: [Asset] = []

    init(services: AppServices) {
        self.services = services
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Markets"
        view.backgroundColor = UIColor(Palette.bg)
        view.accessibilityIdentifier = A11y.Markets.root
        tableView.accessibilityIdentifier = A11y.Markets.list
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 64
        tableView.register(MarketCell.self, forCellReuseIdentifier: MarketCell.reuseID)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        tableView.tableHeaderView = segmentBar()
        reload()
        services.startFeed()
    }

    private func segmentBar() -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 8
        for (id, title, a11y) in segments {
            var config = UIButton.Configuration.gray()
            config.title = title
            let b = UIButton(configuration: config)
            b.accessibilityIdentifier = a11y
            // Correct: every segment's action is wired. `controlActionNotWired`: the
            // target-action is never added, so tapping a segment does nothing and the
            // list stays on the watchlist.
            if !Defects.isActive(.controlActionNotWired) {
                b.addAction(UIAction { [weak self] _ in self?.select(id) }, for: .touchUpInside)
            }
            stack.addArrangedSubview(b)
        }
        stack.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 52)
        stack.translatesAutoresizingMaskIntoConstraints = true
        stack.autoresizingMask = .flexibleWidth
        stack.layoutMargins = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        stack.isLayoutMarginsRelativeArrangement = true
        return stack
    }

    private func select(_ segment: String) {
        current = segment
        reload()
    }

    private func reload() {
        let next: [Asset]
        switch current {
        case "stocks": next = SeedData.assets.filter { $0.kind == .stock }
        case "crypto": next = SeedData.assets.filter { $0.kind == .crypto }
        default: next = SeedData.assets.filter { SeedData.watchlistSymbols.contains($0.symbol) }
        }
        // Correct: replace the list. `listNotClearedOnReload`: append instead, so
        // switching segments accumulates rows from every segment visited.
        if Defects.isActive(.listNotClearedOnReload) { rows += next } else { rows = next }
        tableView.reloadData()
    }

    /// Push the tapped asset's detail. `assetRowOpensWrongDetail` /
    /// `rowTapOpensWrongItem`: open the *next* row's asset (off-by-one), so the
    /// detail shows a neighbouring symbol.
    private func openDetail(for asset: Asset) {
        guard let idx = rows.firstIndex(of: asset) else { return }
        let wrong = Defects.isActive(.assetRowOpensWrongDetail) || Defects.isActive(.rowTapOpensWrongItem)
        let target = rows[wrong ? (idx + 1) % rows.count : idx].symbol
        navigationController?.pushViewController(
            AssetDetailViewController(symbol: target, services: services), animated: true)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MarketCell.reuseID, for: indexPath) as! MarketCell
        let asset = rows[indexPath.row]
        cell.configure(asset: asset, quote: services.market.quote(for: asset.symbol)) { [weak self] in
            self?.openDetail(for: asset)
        }
        return cell
    }

    // Kept for completeness; the tappable row is driven by the cell's own button
    // because a UITableView's cell-selection gesture is swallowed when the view is
    // embedded in SwiftUI (controls still receive touches, so the cell button does).
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        openDetail(for: rows[indexPath.row])
    }
}

/// A market row: symbol/name, a price sparkline, and price + % change — the UIKit
/// twin of the SwiftUI `MarketRow`. The whole row is a transparent button because
/// SwiftUI swallows the table's own cell-tap gesture.
@MainActor
final class MarketCell: UITableViewCell {
    static let reuseID = "market.cell"

    private let symbolLabel = UILabel()
    private let nameLabel = UILabel()
    private let sparkline = SparklineUIView()
    private let priceLabel = UILabel()
    private let changeLabel = UILabel()
    private let tapButton = UIButton(type: .custom)
    private var onTap: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        symbolLabel.font = .systemFont(ofSize: 16, weight: .bold)
        symbolLabel.textColor = UIColor(Palette.text)
        nameLabel.font = .systemFont(ofSize: 12, weight: .regular)
        nameLabel.textColor = UIColor(Palette.muted)
        let idStack = UIStackView(arrangedSubviews: [symbolLabel, nameLabel])
        idStack.axis = .vertical
        idStack.spacing = 2
        idStack.widthAnchor.constraint(equalToConstant: 110).isActive = true

        sparkline.setContentHuggingPriority(.defaultLow, for: .horizontal)

        priceLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        priceLabel.textColor = UIColor(Palette.text)
        priceLabel.textAlignment = .right
        changeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        changeLabel.textAlignment = .right
        let priceStack = UIStackView(arrangedSubviews: [priceLabel, changeLabel])
        priceStack.axis = .vertical
        priceStack.spacing = 2
        priceStack.alignment = .trailing
        priceStack.widthAnchor.constraint(equalToConstant: 96).isActive = true

        let row = UIStackView(arrangedSubviews: [idStack, sparkline, priceStack])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            sparkline.heightAnchor.constraint(equalToConstant: 32),
        ])

        // Transparent full-row button that actually receives the tap.
        tapButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tapButton)
        NSLayoutConstraint.activate([
            tapButton.topAnchor.constraint(equalTo: contentView.topAnchor),
            tapButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            tapButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tapButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
        tapButton.addAction(UIAction { [weak self] _ in self?.onTap?() }, for: .touchUpInside)
        // The button only carries the tap; the cell is the queryable row element.
        tapButton.isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }

    func configure(asset: Asset, quote: Quote?, onTap: @escaping () -> Void) {
        self.onTap = onTap
        symbolLabel.text = asset.symbol
        nameLabel.text = asset.name

        let price = quote?.price ?? asset.basePrice
        let changePct = quote?.changePct ?? 0
        // `changePctSignFlipped`: the displayed % change is negated.
        let shownChange = Defects.isActive(.changePctSignFlipped) ? -changePct : changePct
        // `priceMissingDecimals`: render whole-dollar prices.
        let digits = Defects.isActive(.priceMissingDecimals) ? 0 : 2
        priceLabel.text = "$" + MoneyFormat.price(price, fractionDigits: digits)
        changeLabel.text = MoneyFormat.percent(shownChange)
        changeLabel.textColor = UIColor(shownChange < 0 ? Palette.loss : Palette.gain)

        sparkline.symbol = asset.symbol
        sparkline.up = changePct >= 0
        // `sparklineHeavyPoints`: compute an absurd number of points.
        sparkline.pointCount = Defects.isActive(.sparklineHeavyPoints) ? 4000 : 24

        priceLabel.accessibilityIdentifier = A11y.Markets.assetPrice(asset.symbol)
        changeLabel.accessibilityIdentifier = A11y.Markets.assetChange(asset.symbol)
        // `duplicateAssetA11yId`: NVDA collides onto AAPL's row id.
        let rowID = (Defects.isActive(.duplicateAssetA11yId) && asset.symbol == "NVDA")
            ? A11y.Markets.asset("AAPL") : A11y.Markets.asset(asset.symbol)
        accessibilityIdentifier = rowID
        // `marketRowNoLabel`: strip the row's accessibility label.
        accessibilityLabel = Defects.isActive(.marketRowNoLabel) ? " " : asset.symbol
    }
}
