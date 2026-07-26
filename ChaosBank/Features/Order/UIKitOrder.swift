//
//  UIKitOrder.swift
//  ChaosBank
//
//  The "views build" rendering of the order ticket with UIKit — a faithful twin
//  of SwiftUI's OrderView: Buy/Sell and Market/Limit segments, a quantity
//  stepper, an optional limit-price field, a live summary, and Review → confirm
//  sheet → Place order → status toast. Reuses OrderViewModel unchanged, so it
//  shares the same defects (qtyIncrementByTwo, orderDoubleSubmit, missingA11yLabel…).
//

import SwiftUI
import UIKit

@MainActor
final class OrderViewController: UIViewController {
    private let vm: OrderViewModel

    private let sideBar = SegmentControl()
    private let typeBar = SegmentControl()
    private let qtyValueLabel = UILabel()
    private let limitRow = UIStackView()
    private let limitField = UITextField()
    private let refPriceLabel = UILabel()
    private let estTotalLabel = UILabel()
    private let warningLabel = UILabel()
    private let errorLabel = UILabel()
    private let reviewButton = UIButton(configuration: .filled())

    init(request: OrderRequest, services: AppServices) {
        self.vm = OrderViewModel(request: request, services: services)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Order · \(vm.symbol)"
        view.backgroundColor = UIColor(Palette.bg)
        view.accessibilityIdentifier = A11y.Order.root
        buildUI()
        Task { await vm.load(); render() }
        render()
    }

    private func buildUI() {
        sideBar.configure([
            (OrderSide.buy.rawValue, "Buy", A11y.Order.sideBuy),
            (OrderSide.sell.rawValue, "Sell", A11y.Order.sideSell),
        ], selected: vm.side.rawValue) { [weak self] id in
            self?.vm.side = OrderSide(rawValue: id) ?? .buy
            self?.render()
        }

        typeBar.configure([
            (OrderType.market.rawValue, "Market", A11y.Order.typeMarket),
            (OrderType.limit.rawValue, "Limit", A11y.Order.typeLimit),
        ], selected: vm.type.rawValue) { [weak self] id in
            self?.vm.type = OrderType(rawValue: id) ?? .market
            self?.render()
        }

        // Quantity stepper.
        let qtyTitle = label("Quantity", 14, .regular, UIColor(Palette.muted))
        qtyValueLabel.font = .monospacedDigitSystemFont(ofSize: 18, weight: .bold)
        qtyValueLabel.textColor = UIColor(Palette.text)
        qtyValueLabel.textAlignment = .center
        qtyValueLabel.accessibilityIdentifier = A11y.Order.qtyStepperValue
        qtyValueLabel.widthAnchor.constraint(equalToConstant: 56).isActive = true
        let dec = stepper("minus", A11y.Order.qtyStepperDecrement) { [weak self] in self?.vm.decrement(); self?.render() }
        let inc = stepper("plus", A11y.Order.qtyStepperIncrement) { [weak self] in self?.vm.increment(); self?.render() }
        let stepStack = UIStackView(arrangedSubviews: [dec, qtyValueLabel, inc])
        stepStack.axis = .horizontal
        stepStack.spacing = 12
        stepStack.alignment = .center
        let qtyRow = UIStackView(arrangedSubviews: [qtyTitle, UIView(), stepStack])
        qtyRow.axis = .horizontal
        qtyRow.alignment = .center

        // Limit price row (hidden unless type == limit).
        let limitTitle = label("Limit price", 14, .regular, UIColor(Palette.muted))
        let dollar = label("$", 16, .semibold, UIColor(Palette.sand))
        limitField.placeholder = "0.00"
        limitField.keyboardType = .decimalPad
        limitField.textAlignment = .right
        limitField.textColor = UIColor(Palette.text)
        limitField.accessibilityIdentifier = A11y.Order.limitPriceField
        limitField.widthAnchor.constraint(equalToConstant: 100).isActive = true
        limitField.addTarget(self, action: #selector(limitChanged), for: .editingChanged)
        let limitEntry = UIStackView(arrangedSubviews: [dollar, limitField])
        limitEntry.axis = .horizontal
        limitEntry.spacing = 4
        limitRow.axis = .horizontal
        limitRow.alignment = .center
        limitRow.addArrangedSubview(limitTitle)
        limitRow.addArrangedSubview(UIView())
        limitRow.addArrangedSubview(limitEntry)

        let ticketCard = card([qtyRow, limitRow])

        // Summary card.
        refPriceLabel.accessibilityIdentifier = A11y.Order.refPrice
        estTotalLabel.accessibilityIdentifier = A11y.Order.estTotal
        let summaryCard = card([
            summaryRow("Reference price", refPriceLabel),
            summaryRow("Estimated total", estTotalLabel),
        ])

        warningLabel.font = .systemFont(ofSize: 13, weight: .medium)
        warningLabel.textColor = UIColor(Palette.loss)
        warningLabel.numberOfLines = 0
        warningLabel.text = "Limit sell below market — will execute immediately."
        warningLabel.accessibilityIdentifier = A11y.Order.warning

        errorLabel.font = .systemFont(ofSize: 14, weight: .medium)
        errorLabel.textColor = UIColor(Palette.loss)
        errorLabel.numberOfLines = 0

        var reviewCfg = UIButton.Configuration.filled()
        reviewCfg.title = "Review order"
        reviewCfg.baseBackgroundColor = UIColor(Palette.sand)
        reviewCfg.baseForegroundColor = UIColor(Palette.bg)
        reviewButton.configuration = reviewCfg
        reviewButton.accessibilityIdentifier = A11y.Order.reviewButton
        reviewButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        reviewButton.addAction(UIAction { [weak self] _ in self?.review() }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [
            sideBar, typeBar, ticketCard, summaryCard, warningLabel, errorLabel, reviewButton,
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
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -40),
        ])
    }

    @objc private func limitChanged() {
        vm.limitPriceText = limitField.text ?? ""
        render()
    }

    private func render() {
        sideBar.select(vm.side.rawValue)
        typeBar.select(vm.type.rawValue)
        qtyValueLabel.text = qtyString(vm.quantity)
        limitRow.isHidden = vm.type != .limit
        refPriceLabel.text = "$" + MoneyFormat.price(vm.referencePrice)
        estTotalLabel.text = vm.estTotal.formatted
        warningLabel.isHidden = !vm.showWarning
        errorLabel.isHidden = vm.errorMessage == nil
        errorLabel.text = vm.errorMessage
        reviewButton.isEnabled = vm.isValid
        reviewButton.alpha = vm.isValid ? 1 : 0.5
    }

    private func review() {
        vm.errorMessage = nil
        let sheet = OrderConfirmViewController(vm: vm) { [weak self] in self?.onPlaced() }
        sheet.modalPresentationStyle = .pageSheet
        if let s = sheet.sheetPresentationController { s.detents = [.medium()] }
        present(sheet, animated: true)
    }

    private func onPlaced() {
        guard vm.placed else { return }
        dismiss(animated: true)   // close the confirm sheet
        showToast(statusMessage(vm.status))
        if vm.status == .filled {
            Task {
                try? await Task.sleep(for: .seconds(1.4))
                navigationController?.popViewController(animated: true)
            }
        }
    }

    private func showToast(_ message: String) {
        let toast = PaddedLabel()
        toast.text = message
        toast.font = .systemFont(ofSize: 14, weight: .semibold)
        toast.textColor = UIColor(Palette.text)
        toast.backgroundColor = UIColor(Palette.surface2)
        toast.layer.cornerRadius = 10
        toast.clipsToBounds = true
        toast.accessibilityIdentifier = A11y.Order.statusToast
        toast.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
        ])
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { toast.removeFromSuperview() }
    }

    private func statusMessage(_ status: OrderStatus?) -> String {
        switch status {
        case .filled: return "Order filled"
        case .pending: return "Order pending…"
        case .rejected: return "Order rejected"
        case nil: return ""
        }
    }

    // MARK: Builders

    private func stepper(_ icon: String, _ a11y: String, _ action: @escaping () -> Void) -> UIButton {
        var cfg = UIButton.Configuration.gray()
        cfg.image = UIImage(systemName: icon)
        cfg.baseForegroundColor = UIColor(Palette.text)
        cfg.cornerStyle = .capsule
        let b = UIButton(configuration: cfg)
        b.accessibilityIdentifier = a11y
        b.widthAnchor.constraint(equalToConstant: 36).isActive = true
        b.heightAnchor.constraint(equalToConstant: 36).isActive = true
        b.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return b
    }

    private func summaryRow(_ title: String, _ valueLabel: UILabel) -> UIView {
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        valueLabel.textColor = UIColor(Palette.text)
        valueLabel.textAlignment = .right
        let row = UIStackView(arrangedSubviews: [label(title, 14, .regular, UIColor(Palette.muted)), UIView(), valueLabel])
        row.axis = .horizontal
        row.alignment = .center
        return row
    }

    private func card(_ rows: [UIView]) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor(Palette.surface)
        container.layer.cornerRadius = 14
        let stack = UIStackView(arrangedSubviews: rows)
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
        ])
        return container
    }

    private func label(_ text: String, _ size: CGFloat, _ weight: UIFont.Weight, _ color: UIColor) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: size, weight: weight)
        l.textColor = color
        return l
    }

    private func qtyString(_ q: Decimal) -> String {
        if q == q.rounded(scale: 0) { return NSDecimalNumber(decimal: q).stringValue }
        return MoneyFormat.decimal(q, fractionDigits: 4)
    }
}

/// The confirm sheet (Buy/Sell summary + Place order). Not disabled while
/// submitting, so a double-tap can exercise `orderDoubleSubmit`, matching SwiftUI.
@MainActor
final class OrderConfirmViewController: UIViewController {
    private let vm: OrderViewModel
    private let onPlaced: () -> Void

    init(vm: OrderViewModel, onPlaced: @escaping () -> Void) {
        self.vm = vm
        self.onPlaced = onPlaced
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(Palette.bg)
        view.accessibilityIdentifier = A11y.Order.confirmSheet

        let heading = UILabel()
        heading.text = "\(vm.side == .buy ? "Buy" : "Sell") \(vm.symbol)"
        heading.font = .systemFont(ofSize: 20, weight: .bold)
        heading.textColor = UIColor(Palette.text)
        heading.textAlignment = .center

        let summary = UIStackView(arrangedSubviews: [
            confirmRow("Quantity", qtyString(vm.quantity)),
            confirmRow("Price", "$" + MoneyFormat.price(vm.executionPrice)),
            confirmRow("Total", vm.estTotal.formatted),
        ])
        summary.axis = .vertical
        summary.spacing = 12

        var placeCfg = UIButton.Configuration.filled()
        placeCfg.title = "Place order"
        placeCfg.baseBackgroundColor = UIColor(Palette.sand)
        placeCfg.baseForegroundColor = UIColor(Palette.bg)
        let place = UIButton(configuration: placeCfg)
        place.accessibilityIdentifier = A11y.Order.placeButton
        // `missingA11yLabel`: the button exposes no meaningful label.
        place.accessibilityLabel = Defects.isActive(.missingA11yLabel) ? " " : "Place order"
        place.heightAnchor.constraint(equalToConstant: 50).isActive = true
        place.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            Task { await self.vm.place(); self.onPlaced() }
        }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [heading, summary, UIView(), place])
        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
        ])
    }

    private func confirmRow(_ title: String, _ value: String) -> UIView {
        let t = UILabel(); t.text = title; t.font = .systemFont(ofSize: 14); t.textColor = UIColor(Palette.muted)
        let v = UILabel(); v.text = value; v.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold); v.textColor = UIColor(Palette.text)
        let row = UIStackView(arrangedSubviews: [t, UIView(), v])
        row.axis = .horizontal
        return row
    }

    private func qtyString(_ q: Decimal) -> String {
        if q == q.rounded(scale: 0) { return NSDecimalNumber(decimal: q).stringValue }
        return MoneyFormat.decimal(q, fractionDigits: 4)
    }
}

/// A small horizontal segmented control built from buttons (so taps register in
/// the SwiftUI-embedded views build).
@MainActor
final class SegmentControl: UIStackView {
    private var onSelect: ((String) -> Void)?
    private var buttons: [String: UIButton] = [:]

    func configure(_ items: [(id: String, title: String, a11y: String)], selected: String, onSelect: @escaping (String) -> Void) {
        axis = .horizontal
        distribution = .fillEqually
        spacing = 8
        self.onSelect = onSelect
        for item in items {
            var cfg = UIButton.Configuration.gray()
            cfg.title = item.title
            let b = UIButton(configuration: cfg)
            b.accessibilityIdentifier = item.a11y
            b.addAction(UIAction { [weak self] _ in self?.onSelect?(item.id) }, for: .touchUpInside)
            buttons[item.id] = b
            addArrangedSubview(b)
        }
        heightAnchor.constraint(equalToConstant: 40).isActive = true
        select(selected)
    }

    func select(_ id: String) {
        for (key, button) in buttons {
            var cfg = button.configuration
            cfg?.baseBackgroundColor = key == id ? UIColor(Palette.sand) : nil
            cfg?.baseForegroundColor = key == id ? UIColor(Palette.bg) : UIColor(Palette.text)
            button.configuration = cfg
        }
    }
}

/// A label with inset padding (used for the status toast).
final class PaddedLabel: UILabel {
    private let inset = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: inset)) }
    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + inset.left + inset.right, height: s.height + inset.top + inset.bottom)
    }
}
