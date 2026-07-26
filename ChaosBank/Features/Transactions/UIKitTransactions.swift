//
//  UIKitTransactions.swift
//  ChaosBank
//
//  The "views build": Transactions rendered with UIKit (UITableView) instead of
//  SwiftUI. It reuses the exact same TransactionsViewModel — only the view layer
//  differs — and hosts defects characteristic of the UIKit view system, gated the
//  usual way. Reached when LaunchOptions.current.uiKit is on (-ChaosBankUIKit 1 or
//  the CHAOSBANK_UIKIT build).
//

import SwiftUI
import UIKit

/// SwiftUI entry point: bridges the UIKit list into the existing NavigationStack.
struct UIKitTransactionsView: UIViewControllerRepresentable {
    @Environment(AppServices.self) private var services

    func makeUIViewController(context: Context) -> TransactionsTableViewController {
        TransactionsTableViewController(services: services)
    }

    func updateUIViewController(_ controller: TransactionsTableViewController, context: Context) {}
}

/// A grouped transactions list. Sections mirror `TransactionsViewModel.grouped`
/// (day headers); rows are transactions. The logic layer is identical to the
/// SwiftUI screen — this is purely the UIKit rendering of it.
@MainActor
final class TransactionsTableViewController: UIViewController, UITableViewDataSource {
    // Own the table as a subview (not a UITableViewController, whose `view` *is*
    // the table) so the screen root and the list get distinct locators.
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let vm: TransactionsViewModel
    private var groups: [(key: String, rows: [Transaction])] = []

    init(services: AppServices) {
        self.vm = TransactionsViewModel(services: services)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Transactions"
        view.backgroundColor = UIColor(Palette.bg)
        tableView.dataSource = self
        tableView.register(TransactionCell.self, forCellReuseIdentifier: TransactionCell.reuseID)
        tableView.accessibilityIdentifier = A11y.Transactions.list
        view.accessibilityIdentifier = A11y.Transactions.root
        tableView.rowHeight = 56
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
            groups = vm.grouped
            tableView.reloadData()
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int { groups.count }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        groups[section].key
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        groups[section].rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TransactionCell.reuseID, for: indexPath) as! TransactionCell
        cell.configure(groups[indexPath.section].rows[indexPath.row])
        return cell
    }
}

/// A single transaction row: title + signed amount. The amount label is where the
/// `listCellReuseBleed` defect shows — see `configure`.
final class TransactionCell: UITableViewCell {
    static let reuseID = "tx.cell"

    private let titleLabel = UILabel()
    private let amountLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        amountLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        amountLabel.textAlignment = .right
        let stack = UIStackView(arrangedSubviews: [titleLabel, amountLabel])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }

    func configure(_ tx: Transaction) {
        titleLabel.text = tx.title
        // Correct: every reused cell updates its row locator. `listRecycledA11yStale`:
        // the id is only set once, so a recycled cell keeps a previous row's id and
        // the locator resolves to the wrong row.
        if !Defects.isActive(.listRecycledA11yStale) || accessibilityIdentifier == nil {
            accessibilityIdentifier = A11y.Transactions.row(tx.id)
        }

        let amount = tx.money.formattedSigned
        // Correct: every reused cell resets its amount, so a scrolled row never
        // shows another row's value. `listCellReuseBleed`: the money-out branch is
        // skipped on reuse, so a recycled money-in cell keeps its "+…" amount on a
        // money-out row (the classic dequeueReusableCell "forgot the else" bug).
        if tx.direction == .moneyIn {
            amountLabel.text = amount
            amountLabel.textColor = UIColor(Palette.gain)
            accessibilityValue = amount
        } else if !Defects.isActive(.listCellReuseBleed) {
            amountLabel.text = amount
            amountLabel.textColor = .label
            accessibilityValue = amount
        }
    }
}
