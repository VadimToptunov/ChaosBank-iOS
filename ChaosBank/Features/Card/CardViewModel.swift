//
//  CardViewModel.swift
//  ChaosBank
//

import Foundation
import Observation

@MainActor
@Observable
final class CardViewModel {
    /// Backing store for the freeze state — always written correctly.
    private var storedFrozen = false

    /// Freeze state as read by the UI.
    ///
    /// Correct path: what was stored. The `cardToggleInvert` defect returns the
    /// inverse, so after freezing the toggle reads back off.
    var frozen: Bool {
        get { Defects.isActive(.cardToggleInvert) ? !storedFrozen : storedFrozen }
        set { storedFrozen = newValue }
    }

    var onlinePayments = true
    var monthlyLimitText = "2000"

    let holder = "V. TOPTUNOV"
    let panSuffix = "4291"
    let expiry = "08/29"
    private let fullPAN = "4916 2043 1188 4291"
    private let cvv = "829"

    /// The card number shown on the face.
    ///
    /// Correct path: masked except the last 4. The `cardNumberFullyVisible` defect
    /// shows the full PAN.
    var displayedPAN: String {
        Defects.isActive(.cardNumberFullyVisible) ? fullPAN : "•••• •••• •••• \(panSuffix)"
    }

    /// The `cardCvvVisible` defect prints the CVV on the card face.
    var visibleCVV: String? {
        Defects.isActive(.cardCvvVisible) ? cvv : nil
    }
}
