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

    /// Backing store for online payments — always written correctly.
    private var storedOnlinePayments = true

    /// `onlinePaymentsInverted`: the toggle reads back inverted.
    var onlinePayments: Bool {
        get { Defects.isActive(.onlinePaymentsInverted) ? !storedOnlinePayments : storedOnlinePayments }
        set { storedOnlinePayments = newValue }
    }

    var monthlyLimitText = "2000"

    let holder = "V. TOPTUNOV"
    let panSuffix = "4291"
    private let fullPAN = "4916 2043 1188 4291"
    private let cvv = "829"
    private let pin = "4821"

    /// `cardExpiryInPast`: the displayed expiry is already in the past.
    var expiry: String { Defects.isActive(.cardExpiryInPast) ? "08/20" : "08/29" }

    /// `pinShownPlaintext`: the PIN is shown in the clear instead of masked.
    var pinText: String { Defects.isActive(.pinShownPlaintext) ? pin : "••••" }

    /// `cardLimitAcceptsZero`: a zero limit is accepted without an error.
    var limitError: String? {
        let value = Int(monthlyLimitText) ?? -1
        if value <= 0 && !Defects.isActive(.cardLimitAcceptsZero) {
            return "Monthly limit must be greater than zero"
        }
        return nil
    }

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
