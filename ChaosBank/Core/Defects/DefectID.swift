//
//  DefectID.swift
//  ChaosBank
//
//  The stable identity of every deliberate defect. Adding a case here and to
//  DefectRegistry is the only way a new bug enters the app.
//

import Foundation

/// Identity of a single planted defect. Values are used verbatim in launch
/// arguments (`-ChaosBankDefects roundingDrift,doubleCharge`) so they must stay
/// stable across builds.
nonisolated enum DefectID: String, CaseIterable, Codable, Sendable {
    // Money / logic
    case roundingDrift
    case pnlSign
    case exchangeFeeNotApplied
    case pnlPercentVsValue
    case homeTotalOmitsAccount

    // Validation
    case limitValidation
    case zeroAmountAccepted
    case whitespaceRecipient
    case passcodeWeakAccepted
    case amountExceedsBalanceAllowed

    // Localization
    case localeParse
    case dateTimezoneShift

    // State / navigation
    case staleBalance
    case paginationDup
    case cardToggleInvert
    case filterLeaksCategory
    case orderStuckPending

    // Concurrency / races
    case doubleCharge
    case livePriceRace
    case orderDoubleSubmit
    case exchangeDoubleSubmit

    // Performance
    case transactionsHeavyList
    case mainThreadStall
    case feedPollsTooOften
    case transactionsSortEveryRender

    // UI / layout
    case disabledButtonTappable
    case successToastMissing

    // Accessibility
    case duplicateAssetA11yId
    case missingA11yLabel
    case wrongA11yLabel

    // UI / layout (auth)
    case otpResendNoCooldown

    // Security / privacy
    case authBypass
    case noPrivacyBlur
    case otpAcceptsExpired
    case otpNoLockout
    case sessionTimeoutDisabled
    case tokenInUserDefaults
    case cardNumberFullyVisible
    case cardCvvVisible
    case otpCodeInLog

    // Network (scenario-driven backend)
    case retryDuplicate
    case slowResponseRace
    case timeoutAsSuccess
    case staleOfflineBalance
}
