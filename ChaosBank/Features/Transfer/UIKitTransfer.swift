//
//  UIKitTransfer.swift
//  ChaosBank
//
//  The "views build" rendering of the Transfer form with UIKit. Reuses
//  TransferViewModel; only the view layer differs. Presented from Home's Transfer
//  quick action when LaunchOptions.current.uiKit is on.
//

import SwiftUI
import UIKit

struct UIKitTransferView: UIViewControllerRepresentable {
    @Environment(AppServices.self) private var services
    func makeUIViewController(context: Context) -> TransferViewController { TransferViewController(services: services) }
    func updateUIViewController(_ controller: TransferViewController, context: Context) {}
}

@MainActor
final class TransferViewController: UIViewController {
    private let vm: TransferViewModel
    private let recipientField = UITextField()
    private let amountField = UITextField()
    private let noteField = UITextField()
    private let continueButton = UIButton(configuration: .filled())

    init(services: AppServices) {
        self.vm = TransferViewModel(services: services)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(Palette.bg)
        view.accessibilityIdentifier = A11y.Transfer.root

        field(recipientField, "Recipient", A11y.Transfer.recipientField, #selector(recipientChanged))
        field(amountField, "Amount", A11y.Transfer.amountField, #selector(amountChanged))
        amountField.keyboardType = .decimalPad
        field(noteField, "Note (optional)", A11y.Transfer.noteField, #selector(noteChanged))

        continueButton.setTitle("Continue", for: .normal)
        continueButton.accessibilityIdentifier = A11y.Transfer.continueButton
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        continueButton.heightAnchor.constraint(equalToConstant: 50).isActive = true

        let title = UILabel()
        title.text = "Transfer"
        title.font = .systemFont(ofSize: 28, weight: .bold)
        title.textColor = UIColor(Palette.text)

        let stack = UIStackView(arrangedSubviews: [title, recipientField, amountField, noteField, continueButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])

        Task { await vm.load(); refreshContinue() }
        refreshContinue()
    }

    private func field(_ tf: UITextField, _ placeholder: String, _ id: String, _ action: Selector) {
        tf.placeholder = placeholder
        tf.borderStyle = .roundedRect
        tf.accessibilityIdentifier = id
        tf.addTarget(self, action: action, for: .editingChanged)
        tf.heightAnchor.constraint(equalToConstant: 44).isActive = true
    }

    private func refreshContinue() {
        // Correct: the button tracks form validity. `submitEnabledWhenInvalid`: it's
        // left enabled regardless, so an empty/invalid form can still be submitted.
        continueButton.isEnabled = Defects.isActive(.submitEnabledWhenInvalid) ? true : vm.canContinue
    }

    @objc private func recipientChanged() { vm.recipient = recipientField.text ?? ""; refreshContinue() }
    @objc private func amountChanged() { vm.amountText = amountField.text ?? ""; refreshContinue() }
    @objc private func noteChanged() { vm.note = noteField.text ?? "" }

    @objc private func continueTapped() {
        let alert = UIAlertController(title: "Confirm transfer",
                                      message: "Send \(vm.amountText) to \(vm.effectiveRecipient)?",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Send", style: .default) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
}
