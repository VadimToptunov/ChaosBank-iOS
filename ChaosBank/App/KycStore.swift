//
//  KycStore.swift
//  ChaosBank
//
//  Identity-verification (KYC) state (banking-breadth cluster). Verified by default.
//  Transfers above the threshold require a verified identity; the
//  `kycBypassAllowsTransfer` defect lets an unverified user send a large transfer.
//

import Foundation
import Observation

@MainActor
@Observable
final class KycStore {
    private(set) var verified = true
    func applyVerified(_ value: Bool) { verified = value }
}

enum KycGate {
    static let threshold = Decimal(1000)

    static func allowsTransfer(_ amount: Decimal, verified: Bool) -> Bool {
        if verified { return true }
        if amount <= threshold { return true }
        return Defects.isActive(.kycBypassAllowsTransfer)
    }
}
