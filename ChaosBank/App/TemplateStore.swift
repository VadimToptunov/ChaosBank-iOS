//
//  TemplateStore.swift
//  ChaosBank
//
//  Saved payment templates (banking-breadth cluster). Applying a template prefills the
//  Transfer form. The `templatePrefillsWrongAmount` defect mangles the prefilled amount.
//

import Foundation
import Observation

struct PaymentTemplate: Identifiable, Sendable {
    let id: String
    let name: String
    let recipient: String
    let amount: Decimal
}

@MainActor
@Observable
final class TemplateStore {
    let templates: [PaymentTemplate] = [
        PaymentTemplate(id: "t1", name: "Rent", recipient: "Landlord GmbH", amount: Decimal(string: "1200.00")!),
        PaymentTemplate(id: "t2", name: "Alex", recipient: "Alex Müller", amount: Decimal(string: "50.00")!),
        PaymentTemplate(id: "t3", name: "Savings", recipient: "My Savings", amount: Decimal(string: "300.00")!),
    ]

    /// The amount to prefill when a template is applied.
    func prefillAmount(_ template: PaymentTemplate) -> Decimal {
        Defects.isActive(.templatePrefillsWrongAmount) ? template.amount * 10 : template.amount
    }
}
