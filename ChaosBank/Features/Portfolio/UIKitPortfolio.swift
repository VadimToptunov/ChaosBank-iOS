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
final class PortfolioViewController: UIViewController, UITableViewDataSource {
    // Own the table as a subview (not a UITableViewController, whose `view` *is*
    // the table) so the screen root and the list get distinct locators.
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let vm: PortfolioViewModel
    private var holdings: [Holding] = []

    init(services: AppServices) {
        self.vm = PortfolioViewModel(services: services)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Portfolio"
        view.backgroundColor = UIColor(Palette.bg)
        view.accessibilityIdentifier = A11y.Portfolio.root
        tableView.accessibilityIdentifier = A11y.Portfolio.list
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "holding")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        Task {
            await vm.load()
            holdings = vm.holdings
            tableView.tableHeaderView = header()
            tableView.reloadData()
        }
    }

    private func header() -> UIView {
        let total = UILabel()
        // Correct: render via the currency formatter. `labelNotFormatted`: bind the
        // raw Decimal, so the total shows with no symbol/grouping.
        total.text = Defects.isActive(.labelNotFormatted) ? "\(vm.totalValue.amount)" : vm.totalValue.formatted
        total.font = .systemFont(ofSize: 28, weight: .bold)
        total.textColor = UIColor(Palette.text)
        total.accessibilityIdentifier = A11y.Portfolio.totalValue
        let pnl = UILabel()
        pnl.text = Money(vm.totalPnL, .USD).formattedSigned
        pnl.font = .systemFont(ofSize: 15, weight: .semibold)
        pnl.textColor = UIColor(vm.totalPnL < 0 ? Palette.loss : Palette.gain)
        pnl.accessibilityIdentifier = A11y.Portfolio.pnl

        // Allocation bar — the UIKit twin of the SwiftUI capsule of proportional
        // segments (same colour cycle).
        let allocation = AllocationBarView()
        allocation.accessibilityIdentifier = A11y.Portfolio.allocationBar
        allocation.segments = holdings.map { CGFloat(vm.allocationFraction($0)) }
        allocation.heightAnchor.constraint(equalToConstant: 10).isActive = true

        let stack = UIStackView(arrangedSubviews: [total, pnl, allocation])
        stack.axis = .vertical
        stack.spacing = 8
        stack.setCustomSpacing(4, after: total)
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 110)
        return stack
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { holdings.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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

/// A horizontal capsule of proportional colour segments — the UIKit twin of the
/// SwiftUI Portfolio allocation bar. `segments` are fractions that should sum to ~1.
@MainActor
final class AllocationBarView: UIView {
    var segments: [CGFloat] = [] { didSet { setNeedsLayout() } }

    // Same cycle as the SwiftUI `allocationColors`.
    private let colors: [UIColor] = [
        UIColor(Palette.sand), UIColor(Palette.gain),
        UIColor(red: CGFloat(0x6E) / 255, green: CGFloat(0xA8) / 255, blue: CGFloat(0xFE) / 255, alpha: 1),
        UIColor(red: CGFloat(0xC7) / 255, green: CGFloat(0x92) / 255, blue: CGFloat(0xEA) / 255, alpha: 1),
        UIColor(Palette.loss), UIColor(Palette.muted),
    ]

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
        clipsToBounds = true
        subviews.forEach { $0.removeFromSuperview() }
        var x: CGFloat = 0
        for (i, fraction) in segments.enumerated() {
            let w = max(2, bounds.width * fraction)
            let seg = UIView(frame: CGRect(x: x, y: 0, width: w, height: bounds.height))
            seg.backgroundColor = colors[i % colors.count]
            addSubview(seg)
            x += w
        }
    }
}
