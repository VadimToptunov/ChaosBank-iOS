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
final class MarketsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    // Own the table as a subview (not a UITableViewController, whose `view` *is*
    // the table) so the screen root and the list get distinct locators.
    private let tableView = UITableView(frame: .zero, style: .plain)
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
        view.backgroundColor = UIColor(Palette.bg)
        view.accessibilityIdentifier = A11y.Markets.root
        tableView.accessibilityIdentifier = A11y.Markets.list
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "asset")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
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

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !rows.isEmpty else { return }
        // Correct: open the tapped row's asset. `rowTapOpensWrongItem`: use the next
        // row's index (off-by-one), so tapping opens a neighbouring asset.
        let idx = Defects.isActive(.rowTapOpensWrongItem) ? (indexPath.row + 1) % rows.count : indexPath.row
        let asset = rows[idx]
        let alert = UIAlertController(title: "Order",
                                      message: "Buy \(asset.symbol) at \(Money(asset.basePrice, asset.currency).formatted)?",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Buy", style: .default))
        present(alert, animated: true)
    }
}
