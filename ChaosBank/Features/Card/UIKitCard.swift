//
//  UIKitCard.swift
//  ChaosBank
//
//  The "views build" rendering of the Card screen with UIKit. Reuses the exact
//  same CardViewModel — only the view layer differs — and hosts defects
//  characteristic of the UIKit view layer. Reached when LaunchOptions.current.uiKit
//  is on (-ChaosBankUIKit 1 / CHAOSBANK_UIKIT build).
//

import SwiftUI
import UIKit

/// SwiftUI entry point: bridges the UIKit Card screen into the tab shell.
struct UIKitCardView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CardViewController { CardViewController() }
    func updateUIViewController(_ controller: CardViewController, context: Context) {}
}

@MainActor
final class CardViewController: UIViewController {
    private let vm = CardViewModel()
    private let freezeSwitch = UISwitch()
    private let onlineSwitch = UISwitch()
    private let limitField = UITextField()
    private let limitErrorLabel = UILabel()
    private let frozenBadge = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Card"
        view.backgroundColor = UIColor(Palette.bg)
        view.accessibilityIdentifier = A11y.Card.root

        let stack = UIStackView(arrangedSubviews: [
            cardVisual(),
            settingsCard(),
            button("Show PIN", A11y.Card.pinButton, #selector(showPIN)),
            button("Create virtual card", A11y.Card.virtualButton, #selector(createVirtual)),
            button("Order physical card", A11y.Card.orderPhysicalButton, #selector(noop)),
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -20),
            // Clearance for the floating tab bar (mirrors the SwiftUI screens).
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -96),
        ])

        // Initial control state. Correct: bind from the model. `toggleInitialStateNotBound`:
        // leave the switches at their hardcoded default (off), ignoring the model — so
        // Online payments (model default: on) wrongly shows off on load.
        // Same locators as the SwiftUI build so tests reach either build unchanged.
        freezeSwitch.accessibilityIdentifier = A11y.Card.freezeToggle
        onlineSwitch.accessibilityIdentifier = A11y.Card.onlinePaymentsToggle
        let bound = !Defects.isActive(.toggleInitialStateNotBound)
        freezeSwitch.isOn = bound ? vm.frozen : false
        onlineSwitch.isOn = bound ? vm.onlinePayments : false
        // Change handlers are wired. `switchChangeNotHandled`: the freeze switch's
        // handler is never attached, so flipping it doesn't update the model or the badge.
        if !Defects.isActive(.switchChangeNotHandled) {
            freezeSwitch.addTarget(self, action: #selector(freezeChanged), for: .valueChanged)
        }
        onlineSwitch.addTarget(self, action: #selector(onlineChanged), for: .valueChanged)
    }

    // MARK: Views

    private func cardVisual() -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor(Palette.surface)
        card.layer.cornerRadius = 16
        card.heightAnchor.constraint(equalToConstant: 190).isActive = true

        let brand = label("ChaosBank", size: 18, weight: .bold, color: UIColor(Palette.sand))
        frozenBadge.text = "FROZEN"
        frozenBadge.font = .monospacedSystemFont(ofSize: 11, weight: .bold)
        frozenBadge.textColor = UIColor(Palette.loss)
        frozenBadge.accessibilityIdentifier = A11y.Card.frozenBadge
        frozenBadge.isHidden = !vm.frozen
        let brandRow = UIStackView(arrangedSubviews: [brand, UIView(), frozenBadge])
        brandRow.axis = .horizontal
        brandRow.alignment = .center
        let pan = label(vm.displayedPAN, size: 18, weight: .semibold, color: UIColor(Palette.text))
        pan.accessibilityIdentifier = A11y.Card.number
        let holder = label(vm.holder, size: 12, weight: .medium, color: UIColor(Palette.muted))
        let expiry = label(vm.expiry, size: 12, weight: .medium, color: UIColor(Palette.muted))
        expiry.textAlignment = .right

        let bottom = UIStackView(arrangedSubviews: [holder, expiry])
        bottom.axis = .horizontal
        let v = UIStackView(arrangedSubviews: [brandRow, UIView(), pan, bottom])
        v.axis = .vertical
        v.spacing = 6
        v.translatesAutoresizingMaskIntoConstraints = false
        v.accessibilityIdentifier = A11y.Card.visual
        card.addSubview(v)
        NSLayoutConstraint.activate([
            v.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            v.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            v.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            v.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])
        return card
    }

    private func settingsCard() -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor(Palette.surface)
        container.layer.cornerRadius = 16

        limitField.text = vm.monthlyLimitText
        limitField.keyboardType = .numberPad
        limitField.textColor = UIColor(Palette.text)
        limitField.textAlignment = .right
        limitField.accessibilityIdentifier = A11y.Card.limitField
        limitField.widthAnchor.constraint(equalToConstant: 80).isActive = true
        limitField.addTarget(self, action: #selector(limitChanged), for: .editingChanged)

        limitErrorLabel.font = .systemFont(ofSize: 12, weight: .medium)
        limitErrorLabel.textColor = UIColor(Palette.loss)
        limitErrorLabel.textAlignment = .right
        limitErrorLabel.accessibilityIdentifier = A11y.Card.limitError
        limitErrorLabel.isHidden = true

        let rows = UIStackView(arrangedSubviews: [
            settingRow("Freeze card", freezeSwitch),
            settingRow("Online payments", onlineSwitch),
            settingRow("Monthly limit", limitField),
            limitErrorLabel,
        ])
        rows.axis = .vertical
        rows.spacing = 14
        rows.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(rows)
        NSLayoutConstraint.activate([
            rows.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            rows.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            rows.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            rows.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14),
        ])
        return container
    }

    private func settingRow(_ title: String, _ control: UIView) -> UIView {
        let row = UIStackView(arrangedSubviews: [label(title, size: 15, weight: .medium, color: UIColor(Palette.text)), UIView(), control])
        row.axis = .horizontal
        row.alignment = .center
        return row
    }

    private func label(_ text: String, size: CGFloat, weight: UIFont.Weight, color: UIColor) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: size, weight: weight)
        l.textColor = color
        return l
    }

    private func button(_ title: String, _ id: String, _ action: Selector) -> UIButton {
        var config = UIButton.Configuration.gray()
        config.title = title
        config.baseForegroundColor = UIColor(Palette.text)
        let b = UIButton(configuration: config)
        b.accessibilityIdentifier = id
        b.addTarget(self, action: action, for: .touchUpInside)
        b.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return b
    }

    // MARK: Actions

    @objc private func freezeChanged() {
        vm.frozen = freezeSwitch.isOn
        frozenBadge.isHidden = !vm.frozen
    }
    @objc private func onlineChanged() { vm.onlinePayments = onlineSwitch.isOn }
    @objc private func limitChanged() {
        let digits = (limitField.text ?? "").filter(\.isNumber)
        limitField.text = digits
        // Correct: commit the edit to the model (two-way). `fieldEditNotCommitted`:
        // skip the commit, so the field shows the text but the model — and its
        // validation — keep the old value.
        if !Defects.isActive(.fieldEditNotCommitted) { vm.monthlyLimitText = digits }
        limitErrorLabel.text = vm.limitError
        limitErrorLabel.isHidden = vm.limitError == nil
    }
    @objc private func noop() {}

    @objc private func showPIN() { present(alert("Card PIN", "Your PIN is \(vm.pinText)"), animated: true) }
    @objc private func createVirtual() { present(alert("Virtual card", vm.virtualCardNumber), animated: true) }

    private func alert(_ title: String, _ message: String) -> UIAlertController {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "Done", style: .cancel))
        return a
    }
}
