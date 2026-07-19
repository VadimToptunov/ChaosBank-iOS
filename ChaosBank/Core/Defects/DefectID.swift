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
    // MARK: Money / logic
    case roundingDrift
    case pnlSign
    case exchangeFeeNotApplied
    case pnlPercentVsValue
    case homeTotalOmitsAccount
    case balanceFloorRounded
    case todayChangeSignFlipped
    case transferDebitsWrongAccount
    case balanceAfterAdds
    case transferRoundsUp
    case exchangeInverseRate
    case exchangeCreditsWrongAccount
    case exchangeFeeDoubled
    case youGetShowsGross
    case changePctSignFlipped
    case detailPriceOffset
    case detailChangeWrongBase
    case estTotalIgnoresQty
    case limitExecutesAtMarket
    case holdingValueUsesCost
    case totalValueOmitsHolding
    case pnlPercentAbsOnly

    // MARK: Validation
    case limitValidation
    case zeroAmountAccepted
    case whitespaceRecipient
    case passcodeWeakAccepted
    case amountExceedsBalanceAllowed
    case transferNegativeCredits
    case exchangeSameCurrencyAllowed
    case searchCaseSensitive
    case sellWithoutHoldingReviewable
    case orderQtyDefaultsZero
    case loginAcceptsEmptyCreds
    case cardLimitAcceptsZero

    // MARK: Localization
    case localeParse
    case dateTimezoneShift
    case rtlBreaksLayout
    case numberGroupingIgnoresLocale
    case currencySymbolPlacementIgnoresLocale
    case balanceWrongCurrencySymbol
    case priceMissingDecimals
    case searchTrimsNothing

    // MARK: State / navigation
    case staleBalance
    case paginationDup
    case paginationNeverEnds
    case cardToggleInvert
    case filterLeaksCategory
    case orderStuckPending
    case quickActionTransferOpensExchange
    case recentActivityShowsTwo
    case exchangeRateStaleAfterSwap
    case filterOutLeaksIn
    case searchIgnoresCategory
    case cryptoShownInStocks
    case watchlistShowsAll
    case assetRowOpensWrongDetail
    case buyButtonPlacesSell
    case buySellSwapped
    case onlinePaymentsInverted
    case transferConfirmWrongRecipient
    case notificationBadgeStale
    case notificationOpensWrongScreen

    // MARK: Concurrency / races
    case doubleCharge
    case livePriceRace
    case orderDoubleSubmit
    case exchangeDoubleSubmit
    case homeRefreshRace
    case syncLostUpdate

    // MARK: Performance
    case transactionsHeavyList
    case mainThreadStall
    case feedPollsTooOften
    case transactionsSortEveryRender
    case sparklineHeavyPoints
    case transactionsRegroupHeavy

    // MARK: UI / layout
    case disabledButtonTappable
    case otpResendNoCooldown
    case successToastMissing
    case accountStripHidesGBP
    case outgoingSignHidden
    case transactionCountWrong
    case detailStatHighLowSwapped
    case qtyIncrementByTwo
    case cardExpiryInPast
    case otpAutoFillsCode
    case successToastTooBrief
    case flakyAnimation

    // MARK: Accessibility
    case duplicateAssetA11yId
    case missingA11yLabel
    case wrongA11yLabel
    case marketRowNoLabel
    case freezeToggleNoLabel

    // MARK: Security / privacy
    case authBypass
    case noPrivacyBlur
    case otpAcceptsExpired
    case otpNoLockout
    case sessionTimeoutDisabled
    case tokenInUserDefaults
    case cardNumberFullyVisible
    case cardCvvVisible
    case otpCodeInLog
    case pinShownPlaintext
    case otpAcceptsAnyCode
    case passcodeAnyAccepted
    case passcodeStoredPlaintext
    case credentialsInLog
    case deepLinkSkipsAuth
    case biometricUnlocksFromAnyStage

    // MARK: Network (scenario-driven backend)
    case retryDuplicate
    case slowResponseRace
    case timeoutAsSuccess
    case staleOfflineBalance
    case balanceReadReturnsZero
    case transactionsDupOnFetch
    case staleHoldingsAfterOrder
    case offlineBannerMissing
}
