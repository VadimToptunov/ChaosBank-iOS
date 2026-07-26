//
//  UIKitExchange.swift
//  ChaosBank
//
//  The "views build" rendering of the Exchange form with UIKit. Reuses
//  ExchangeViewModel; only the view layer differs. Presented from Home's Exchange
//  quick action when LaunchOptions.current.uiKit is on.
//

import SwiftUI
import UIKit

struct UIKitExchangeView: UIViewControllerRepresentable {
    @Environment(AppServices.self) private var services
    func makeUIViewController(context: Context) -> ExchangeViewController { ExchangeViewController(services: services) }
    func updateUIViewController(_ controller: ExchangeViewController, context: Context) {}
}

@MainActor
final class ExchangeViewController: UIViewController {
    private let vm: ExchangeViewModel
    private let amountField = UITextField()
    private let rateLabel = UILabel()
    private let feeLabel = UILabel()
    private let youGetLabel = UILabel()

    init(services: AppServices) {
        self.vm = ExchangeViewModel(services: services)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(Palette.bg)
        view.accessibilityIdentifier = A11y.Exchange.root

        let title = UILabel()
        title.text = "\(vm.sell.code) → \(vm.get.code)"
        title.font = .systemFont(ofSize: 24, weight: .bold)
        title.textColor = UIColor(Palette.text)

        amountField.placeholder = "Amount"
        amountField.borderStyle = .roundedRect
        amountField.keyboardType = .decimalPad
        amountField.accessibilityIdentifier = A11y.Exchange.amountField
        amountField.addTarget(self, action: #selector(amountChanged), for: .editingChanged)
        amountField.heightAnchor.constraint(equalToConstant: 44).isActive = true

        rateLabel.accessibilityIdentifier = A11y.Exchange.rate
        feeLabel.accessibilityIdentifier = A11y.Exchange.fee
        for l in [rateLabel, feeLabel] { l.font = .systemFont(ofSize: 13); l.textColor = UIColor(Palette.muted) }
        youGetLabel.accessibilityIdentifier = A11y.Exchange.youGet
        youGetLabel.font = .monospacedDigitSystemFont(ofSize: 22, weight: .bold)
        youGetLabel.textColor = UIColor(Palette.text)

        let execute = UIButton(configuration: .filled())
        execute.setTitle("Exchange", for: .normal)
        execute.accessibilityIdentifier = A11y.Exchange.executeButton
        execute.addTarget(self, action: #selector(executeTapped), for: .touchUpInside)
        execute.heightAnchor.constraint(equalToConstant: 50).isActive = true

        let stack = UIStackView(arrangedSubviews: [title, amountField, rateLabel, feeLabel, youGetLabel, execute])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])

        // Initial values always render; only the recompute-on-change is defective.
        rateLabel.text = "Rate \(vm.rate)"
        youGetLabel.text = vm.youGet.formatted
        feeLabel.text = "Fee \(vm.fee.formatted)"
        Task { await vm.load() }
    }

    private func refreshOutput() {
        // Correct: recompute the derived fields when the amount changes.
        // `outputNotRecomputed`: skip it, so 'You get' stays at its initial value.
        guard !Defects.isActive(.outputNotRecomputed) else { return }
        youGetLabel.text = vm.youGet.formatted
        feeLabel.text = "Fee \(vm.fee.formatted)"
    }

    @objc private func amountChanged() {
        vm.amountText = amountField.text ?? ""
        refreshOutput()
    }

    @objc private func executeTapped() {
        let alert = UIAlertController(title: "Exchange", message: "You get \(vm.youGet.formatted)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Done", style: .cancel))
        present(alert, animated: true)
    }
}
