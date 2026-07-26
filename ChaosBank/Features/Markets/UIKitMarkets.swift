//
//  UIKitMarkets.swift
//  ChaosBank
//
//  The "views build" rendering of Markets with UIKit: a segment bar (Watchlist /
//  Stocks / Crypto) over a UITableView of assets. Hosts defects characteristic of
//  the UIKit view layer. Reached when LaunchOptions.current.uiKit is on.
//

import SwiftUI
import UIKit

struct UIKitMarketsView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> MarketsViewController { MarketsViewController() }
    func updateUIViewController(_ controller: MarketsViewController, context: Context) {}
}

@MainActor
final class MarketsViewController: UITableViewController {
    private let segments = [
        ("watchlist", "Watchlist", A11y.Markets.segmentWatchlist),
        ("stocks", "Stocks", A11y.Markets.segmentStocks),
        ("crypto", "Crypto", A11y.Markets.segmentCrypto),
    ]
    private var current = "watchlist"
    private var rows: [Asset] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Markets"
        view.accessibilityIdentifier = A11y.Markets.root
        tableView.accessibilityIdentifier = A11y.Markets.list
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "asset")
        tableView.tableHeaderView = segmentBar()
        reload()
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
        stack.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 52)
        stack.translatesAutoresizingMaskIntoConstraints = true
        stack.layoutMargins = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        stack.isLayoutMarginsRelativeArrangement = true
        return stack
    }

    private func select(_ segment: String) {
        current = segment
        reload()
    }

    private func reload() {
        switch current {
        case "stocks": rows = SeedData.assets.filter { $0.kind == .stock }
        case "crypto": rows = SeedData.assets.filter { $0.kind == .crypto }
        default: rows = SeedData.assets.filter { SeedData.watchlistSymbols.contains($0.symbol) }
        }
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "asset", for: indexPath)
        let asset = rows[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = asset.symbol
        config.secondaryText = asset.name
        cell.contentConfiguration = config
        let price = UILabel()
        price.text = Money(asset.basePrice, asset.currency).formatted
        price.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        price.sizeToFit()
        cell.accessoryView = price
        cell.accessibilityIdentifier = A11y.Markets.asset(asset.symbol)
        return cell
    }
}
