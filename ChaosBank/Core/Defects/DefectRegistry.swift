//
//  DefectRegistry.swift
//  ChaosBank
//
//  The single catalog. Every defect is declared here exactly once, with its
//  category. The seed → active-defects mapping lives here too.
//

import Foundation

nonisolated enum DefectRegistry {
    /// The full catalog. Order matches DefectID.allCases.
    static let all: [Defect] = [
        Defect(id: .roundingDrift, title: "Conversion rounds wrong into history",
               feature: "Exchange / Order", category: .money, severity: .major,
               violates: "Displayed value and stored value are identical, correctly rounded (Decimal).",
               flakiness: .deterministic),
        Defect(id: .pnlSign, title: "Loss displayed as gain",
               feature: "Portfolio", category: .money, severity: .critical,
               violates: "P&L sign matches actual gain/loss.",
               flakiness: .deterministic),
        Defect(id: .exchangeFeeNotApplied, title: "Exchange ignores the fee it displays",
               feature: "Exchange", category: .money, severity: .major,
               violates: "The credited amount reflects the displayed fee.",
               flakiness: .deterministic),
        Defect(id: .pnlPercentVsValue, title: "P&L % divides by market value, not cost",
               feature: "Portfolio", category: .money, severity: .major,
               violates: "P&L percent is measured against cost basis.",
               flakiness: .deterministic),
        Defect(id: .homeTotalOmitsAccount, title: "Total balance omits an account",
               feature: "Home", category: .money, severity: .major,
               violates: "Total balance sums every account.",
               flakiness: .deterministic),

        Defect(id: .limitValidation, title: "Bad limit orders accepted silently",
               feature: "Order", category: .validation, severity: .major,
               violates: "Limit sell below market warns; qty must be > 0.",
               flakiness: .deterministic),
        Defect(id: .zeroAmountAccepted, title: "Zero-amount transfer allowed",
               feature: "Transfer", category: .validation, severity: .major,
               violates: "Continue requires an amount greater than zero.",
               flakiness: .deterministic),
        Defect(id: .whitespaceRecipient, title: "Recipient whitespace not trimmed",
               feature: "Transfer", category: .validation, severity: .minor,
               violates: "Leading/trailing whitespace is trimmed before validation.",
               flakiness: .deterministic),
        Defect(id: .passcodeWeakAccepted, title: "Short passcode accepted",
               feature: "Auth", category: .validation, severity: .major,
               violates: "The app passcode must be the full required length.",
               flakiness: .deterministic),
        Defect(id: .amountExceedsBalanceAllowed, title: "Transfer over balance allowed",
               feature: "Transfer", category: .validation, severity: .major,
               violates: "Continue is blocked when the amount exceeds the balance.",
               flakiness: .deterministic),

        Defect(id: .localeParse, title: "1,000.50 parsed as 1.00050",
               feature: "Exchange / Transfer", category: .localization, severity: .major,
               violates: "Amounts parse correctly under the active locale.",
               flakiness: .deterministic),
        Defect(id: .dateTimezoneShift, title: "Transaction date shifts by timezone",
               feature: "Transactions", category: .localization, severity: .minor,
               violates: "Dates render in a stable, correct timezone.",
               flakiness: .deterministic),

        Defect(id: .staleBalance, title: "Dashboard shows pre-transfer balance",
               feature: "Home", category: .state, severity: .major,
               violates: "Balance reflects latest state after any mutation.",
               flakiness: .deterministic),
        Defect(id: .paginationDup, title: "Transaction duplicated after Load more",
               feature: "Transactions", category: .state, severity: .minor,
               violates: "Each transaction appears once.",
               flakiness: .deterministic),
        Defect(id: .cardToggleInvert, title: "Freeze toggle reads back inverted",
               feature: "Card", category: .state, severity: .major,
               violates: "Toggle state persists and reads back correctly.",
               flakiness: .deterministic),
        Defect(id: .filterLeaksCategory, title: "Money-in filter leaks money-out rows",
               feature: "Transactions", category: .state, severity: .major,
               violates: "A filter shows only its own category.",
               flakiness: .deterministic),
        Defect(id: .orderStuckPending, title: "Filled order still shows pending",
               feature: "Order", category: .state, severity: .major,
               violates: "A filled order reports filled, not pending.",
               flakiness: .deterministic),

        Defect(id: .doubleCharge, title: "Rapid double-tap sends twice",
               feature: "Transfer", category: .concurrency, severity: .critical,
               violates: "Confirm is idempotent; one tap = one transaction.",
               flakiness: .raceCondition),
        Defect(id: .livePriceRace, title: "Order price ≠ tapped price",
               feature: "Markets / Order", category: .concurrency, severity: .critical,
               violates: "Confirmation price equals the price acted on.",
               flakiness: .raceCondition),
        Defect(id: .orderDoubleSubmit, title: "Rapid double-tap places two orders",
               feature: "Order", category: .concurrency, severity: .critical,
               violates: "Place is idempotent; one tap = one order.",
               flakiness: .raceCondition),
        Defect(id: .exchangeDoubleSubmit, title: "Rapid double-tap exchanges twice",
               feature: "Exchange", category: .concurrency, severity: .critical,
               violates: "Execute is idempotent; one tap = one exchange.",
               flakiness: .raceCondition),

        Defect(id: .transactionsHeavyList, title: "History renders a huge non-lazy list",
               feature: "Transactions", category: .performance, severity: .major,
               violates: "Long lists render lazily and stay smooth.",
               flakiness: .deterministic),
        Defect(id: .mainThreadStall, title: "Portfolio blocks the main thread on open",
               feature: "Portfolio", category: .performance, severity: .major,
               violates: "Work stays off the main thread; the UI never hangs.",
               flakiness: .deterministic),
        Defect(id: .feedPollsTooOften, title: "Live feed polls 10× too often",
               feature: "Markets", category: .performance, severity: .minor,
               violates: "The live feed polls at a sane interval.",
               flakiness: .deterministic),
        Defect(id: .transactionsSortEveryRender, title: "History re-sorts on every render",
               feature: "Transactions", category: .performance, severity: .minor,
               violates: "Expensive work is not redone on every render.",
               flakiness: .deterministic),

        Defect(id: .disabledButtonTappable, title: "Button looks disabled but still fires",
               feature: "Transfer", category: .ui, severity: .major,
               violates: "A disabled-looking control is actually non-interactive.",
               flakiness: .deterministic),
        Defect(id: .otpResendNoCooldown, title: "OTP resend ignores the cooldown",
               feature: "Auth", category: .ui, severity: .minor,
               violates: "Resend is blocked until the cooldown elapses.",
               flakiness: .deterministic),
        Defect(id: .successToastMissing, title: "No success toast after a transfer",
               feature: "Transfer", category: .ui, severity: .minor,
               violates: "A successful action shows a confirmation toast.",
               flakiness: .deterministic),

        Defect(id: .duplicateAssetA11yId, title: "Two market rows share one identifier",
               feature: "Markets", category: .accessibility, severity: .major,
               violates: "Every element has a unique, stable accessibility identifier.",
               flakiness: .deterministic),
        Defect(id: .missingA11yLabel, title: "Place-order button has no accessibility label",
               feature: "Order", category: .accessibility, severity: .major,
               violates: "Every control exposes a meaningful accessibility label.",
               flakiness: .deterministic),
        Defect(id: .wrongA11yLabel, title: "Buy button is labelled 'Sell'",
               feature: "Asset detail", category: .accessibility, severity: .critical,
               violates: "A control's accessibility label matches its action.",
               flakiness: .deterministic),

        Defect(id: .authBypass, title: "Gate skipped after backgrounding",
               feature: "Auth", category: .security, severity: .critical,
               violates: "Sensitive screens always require the gate.",
               flakiness: .deterministic),
        Defect(id: .noPrivacyBlur, title: "Sensitive data visible in app switcher",
               feature: "Card / Auth", category: .security, severity: .major,
               violates: "Sensitive screens are obscured when the app is inactive.",
               flakiness: .deterministic),
        Defect(id: .otpAcceptsExpired, title: "Expired OTP still accepted",
               feature: "Auth", category: .security, severity: .critical,
               violates: "An expired one-time code is rejected.",
               flakiness: .deterministic),
        Defect(id: .otpNoLockout, title: "No lockout after repeated wrong OTP",
               feature: "Auth", category: .security, severity: .critical,
               violates: "Too many wrong codes locks the OTP step.",
               flakiness: .deterministic),
        Defect(id: .sessionTimeoutDisabled, title: "Session never times out",
               feature: "Auth", category: .security, severity: .major,
               violates: "An idle session re-locks after the timeout.",
               flakiness: .deterministic),
        Defect(id: .tokenInUserDefaults, title: "Session token stored in UserDefaults",
               feature: "Auth", category: .security, severity: .critical,
               violates: "Secrets live in the Keychain, never in UserDefaults.",
               flakiness: .deterministic),
        Defect(id: .cardNumberFullyVisible, title: "Full card number shown unmasked",
               feature: "Card", category: .security, severity: .critical,
               violates: "The card PAN is masked except the last 4 digits.",
               flakiness: .deterministic),
        Defect(id: .cardCvvVisible, title: "CVV shown on the card face",
               feature: "Card", category: .security, severity: .critical,
               violates: "The CVV is never displayed on screen.",
               flakiness: .deterministic),
        Defect(id: .otpCodeInLog, title: "OTP code written to the console log",
               feature: "Auth", category: .security, severity: .major,
               violates: "Secrets are never logged.",
               flakiness: .deterministic),

        Defect(id: .retryDuplicate, title: "Retry after slow response duplicates the payment",
               feature: "Transfer / Network", category: .network, severity: .critical,
               violates: "Retries are idempotent; a retried request never double-posts.",
               flakiness: .raceCondition),
        Defect(id: .slowResponseRace, title: "Stale response overwrites fresh state",
               feature: "Markets / Network", category: .network, severity: .major,
               violates: "An out-of-order/late response never clobbers newer data.",
               flakiness: .raceCondition),
        Defect(id: .timeoutAsSuccess, title: "Timeout shown as a successful transfer",
               feature: "Transfer / Network", category: .network, severity: .critical,
               violates: "A failed/timed-out request is surfaced as an error, not success.",
               flakiness: .deterministic),
        Defect(id: .staleOfflineBalance, title: "Offline cache shows an outdated balance",
               feature: "Home / Network", category: .network, severity: .major,
               violates: "A stale cache is refreshed or clearly marked as stale.",
               flakiness: .deterministic),
    ]

    static func defect(_ id: DefectID) -> Defect {
        // Force-unwrap is safe: every DefectID has a catalog entry (verified in tests).
        all.first { $0.id == id }!
    }

    static func ids(in category: DefectCategory) -> Set<DefectID> {
        Set(all.filter { $0.category == category }.map(\.id))
    }

    /// Maps a build seed to the set of defects it activates.
    ///
    /// - `0`  → clean baseline (no defects).
    /// - `1…N` → a single defect, in `DefectID.allCases` order (seed 1 = first case).
    /// - `99` → every defect at once.
    ///
    /// Any other seed activates no defects (still a valid, clean build).
    static func defects(forSeed seed: Int) -> Set<DefectID> {
        if seed == 0 { return [] }
        if seed == 99 { return Set(DefectID.allCases) }
        let cases = DefectID.allCases
        if (1...cases.count).contains(seed) {
            return [cases[seed - 1]]
        }
        return []
    }
}
