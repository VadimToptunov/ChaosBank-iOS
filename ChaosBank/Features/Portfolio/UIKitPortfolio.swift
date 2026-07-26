//
//  UIKitPortfolio.swift
//  ChaosBank
//
//  The "views build" rendering of Portfolio with UIKit: a header (total value +
//  P&L) over a UITableView of holdings. Reuses PortfolioViewModel; only the view
//  layer differs. Reached when LaunchOptions.current.uiKit is on.
//

import SwiftUI
import UIKit

struct UIKitPortfolioView: UIViewControllerRepresentable {
    @Environment(AppServices.self) private var services
    func makeUIViewController(context: Context) -> PortfolioViewController { PortfolioViewController(services: services) }
    func updateUIViewController(_ controller: PortfolioViewController, context: Context) {}
}

@MainActor
final class PortfolioViewController: UITableViewController {
    private let vm: PortfolioViewModel
    private var holdings: [Holding] = []

    init(services: AppServices) {
        self.vm = PortfolioViewModel(services: services)
        super.init(style: .plain)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Portfolio"
        view.accessibilityIdentifier = A11y.Portfolio.root
        tableView.accessibilityIdentifier = A11y.Portfolio.list
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "holding")
        Task {
            await vm.load()
            holdings = vm.holdings
            tableView.tableHeaderView = header()
            tableView.reloadData()
        }
    }

    private func header() -> UIView {
        let total = UILabel()
        total.text = vm.totalValue.formatted
        total.font = .systemFont(ofSize: 28, weight: .bold)
        total.textColor = UIColor(Palette.text)
        total.accessibilityIdentifier = A11y.Portfolio.totalValue
        let pnl = UILabel()
        pnl.text = Money(vm.totalPnL, .USD).formattedSigned
        pnl.font = .systemFont(ofSize: 15, weight: .semibold)
        pnl.textColor = UIColor(vm.totalPnL < 0 ? Palette.loss : Palette.gain)
        pnl.accessibilityIdentifier = A11y.Portfolio.pnl
        let stack = UIStackView(arrangedSubviews: [total, pnl])
        stack.axis = .vertical
        stack.spacing = 4
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 92)
        return stack
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { holdings.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "holding", for: indexPath)
        let h = holdings[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = h.symbol
        config.secondaryText = vm.name(h.symbol)
        cell.contentConfiguration = config
        let value = UILabel()
        value.text = vm.marketValue(h).formatted
        value.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        value.textColor = UIColor(Palette.text)
        value.sizeToFit()
        cell.accessoryView = value
        // Correct: each row sets its locator. `rowLocatorMissing`: the id is never
        // set, so per-holding locators (portfolio.holding.<symbol>) don't exist.
        if !Defects.isActive(.rowLocatorMissing) {
            cell.accessibilityIdentifier = A11y.Portfolio.holding(h.symbol)
        }
        return cell
    }
}
