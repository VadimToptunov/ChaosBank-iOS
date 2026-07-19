//
//  Exercise.swift
//  ChaosBank
//
//  The machine-readable training catalog: one exercise per defect. Codable, so it
//  serializes to `exercises.json` for external tooling, and it drives the in-app
//  Exercises browser. Fields are derived from the DefectRegistry where possible so
//  the catalog can't drift from the actual defects.
//

import Foundation

nonisolated struct Exercise: Codable, Identifiable, Sendable {
    let id: String            // "IOS-VAL-002"
    let title: String
    let difficulty: String    // junior | middle | senior
    let category: String
    let feature: String
    let defects: [String]     // DefectID raw values
    let launchArgument: String
    let profile: String?      // suggested profile, if any
    let condition: String     // what goes wrong
    let expectedClean: String
    let expectedBuggy: String
    let task: String          // what the tester should automate
    let keyLocators: [String]
}

nonisolated enum Exercises {
    private struct Spec {
        let difficulty: String
        let task: String
        let expectedClean: String
        let expectedBuggy: String
        let locators: [String]
    }

    private static func code(_ c: DefectCategory) -> String {
        switch c {
        case .money: return "MON"
        case .validation: return "VAL"
        case .localization: return "LOC"
        case .state: return "STA"
        case .concurrency: return "CON"
        case .ui: return "UI"
        case .accessibility: return "A11Y"
        case .security: return "SEC"
        case .network: return "NET"
        case .performance: return "PERF"
        }
    }

    // Curated per-defect guidance. Derived metadata (title, category, feature,
    // severity) comes from the DefectRegistry.
    private static let specs: [DefectID: Spec] = [
        .roundingDrift: Spec(difficulty: "middle",
            task: "Exchange EUR→USD and assert the credited history amount equals the displayed 'You get'.",
            expectedClean: "Stored amount == displayed amount.",
            expectedBuggy: "Stored amount drifts (Double rounding).",
            locators: ["exchange.youGet", "exchange.executeButton", "exchange.successToast"]),
        .pnlSign: Spec(difficulty: "junior",
            task: "Open Portfolio and assert TSLA's P&L renders as a loss (negative, red).",
            expectedClean: "Loss shows negative / loss color.",
            expectedBuggy: "Loss shows positive / gain color.",
            locators: ["portfolio.holding.TSLA.pnl", "portfolio.pnl"]),
        .limitValidation: Spec(difficulty: "middle",
            task: "Set qty to 0 and assert Review is disabled; place a below-market limit sell and assert a warning shows.",
            expectedClean: "Zero qty blocked; below-market limit sell warns.",
            expectedBuggy: "Zero qty accepted; no warning.",
            locators: ["order.qtyStepper.value", "order.reviewButton", "order.warning"]),
        .zeroAmountAccepted: Spec(difficulty: "junior",
            task: "Enter recipient and amount 0; assert Continue is disabled.",
            expectedClean: "Continue disabled at amount 0.",
            expectedBuggy: "Continue enabled at amount 0.",
            locators: ["transfer.amountField", "transfer.continueButton"]),
        .whitespaceRecipient: Spec(difficulty: "junior",
            task: "Enter a spaces-only recipient; assert Continue stays disabled.",
            expectedClean: "Whitespace trimmed → recipient empty → disabled.",
            expectedBuggy: "Spaces accepted as a valid recipient.",
            locators: ["transfer.recipientField", "transfer.continueButton"]),
        .passcodeWeakAccepted: Spec(difficulty: "middle",
            task: "During passcode setup, assert a 4-digit passcode is rejected (6 required).",
            expectedClean: "Requires 6 digits.",
            expectedBuggy: "Accepts 4 digits.",
            locators: ["auth.passcodeField", "auth.passcodeSubmit", "auth.passcodeError"]),
        .localeParse: Spec(difficulty: "middle",
            task: "Type '1,000.50' into an amount field under en_US; assert it parses to 1000.50.",
            expectedClean: "Parses to 1000.50.",
            expectedBuggy: "Collapses toward 1.0005.",
            locators: ["transfer.amountField", "transfer.balanceAfter", "exchange.amountField"]),
        .dateTimezoneShift: Spec(difficulty: "middle",
            task: "Open Transactions and assert a known transaction's day/time matches the home timezone.",
            expectedClean: "Dates in the app's home timezone.",
            expectedBuggy: "Dates shifted to a far-off timezone.",
            locators: ["transactions.list", "transactions.row.t01"]),
        .staleBalance: Spec(difficulty: "middle",
            task: "Note the Home balance, make a transfer, return to Home; assert the balance decreased.",
            expectedClean: "Balance refreshes after the transfer.",
            expectedBuggy: "Home keeps showing the pre-transfer balance.",
            locators: ["home.totalBalance", "home.quickAction.transfer", "transfer.confirmButton"]),
        .paginationDup: Spec(difficulty: "middle",
            task: "Tap Load more and assert each transaction id appears exactly once.",
            expectedClean: "No duplicates after Load more.",
            expectedBuggy: "A boundary transaction appears twice.",
            locators: ["transactions.loadMore", "transactions.list"]),
        .cardToggleInvert: Spec(difficulty: "junior",
            task: "Turn on Freeze; assert the FROZEN badge appears.",
            expectedClean: "Freeze state reads back correctly.",
            expectedBuggy: "Freeze reads back inverted.",
            locators: ["card.freezeToggle", "card.frozenBadge"]),
        .doubleCharge: Spec(difficulty: "senior",
            task: "Rapidly double-tap Confirm; assert exactly one transaction / one debit.",
            expectedClean: "Idempotent — one transaction.",
            expectedBuggy: "Two transactions (double charge).",
            locators: ["transfer.confirmButton", "home.totalBalance"]),
        .livePriceRace: Spec(difficulty: "senior",
            task: "Read the asset price, tap Buy, and assert the order's reference price equals it.",
            expectedClean: "Order price == tapped price.",
            expectedBuggy: "Order re-reads live price → differs.",
            locators: ["asset.price", "asset.buyButton", "order.refPrice"]),
        .orderDoubleSubmit: Spec(difficulty: "senior",
            task: "Double-tap Place order; assert only one order/holding change occurs.",
            expectedClean: "Idempotent — one order.",
            expectedBuggy: "Two orders placed.",
            locators: ["order.placeButton", "portfolio.holding.AAPL"]),
        .disabledButtonTappable: Spec(difficulty: "junior",
            task: "With an invalid form, assert Continue reports isEnabled == false.",
            expectedClean: "Disabled-looking button is non-interactive.",
            expectedBuggy: "Button looks disabled but is hittable.",
            locators: ["transfer.continueButton"]),
        .otpResendNoCooldown: Spec(difficulty: "middle",
            task: "On the OTP screen, assert Resend is disabled until the cooldown elapses.",
            expectedClean: "Resend blocked during cooldown.",
            expectedBuggy: "Resend fires during cooldown.",
            locators: ["auth.otpResend", "auth.otpExpiry"]),
        .duplicateAssetA11yId: Spec(difficulty: "middle",
            task: "In Markets, assert each asset identifier matches exactly one element.",
            expectedClean: "Every row has a unique identifier.",
            expectedBuggy: "NVDA collides onto AAPL's identifier.",
            locators: ["markets.asset.AAPL", "markets.asset.NVDA"]),
        .authBypass: Spec(difficulty: "senior",
            task: "Unlock, background then foreground the app; assert re-auth is required.",
            expectedClean: "Background re-locks to passcode entry.",
            expectedBuggy: "App stays unlocked after backgrounding.",
            locators: ["auth.passcode", "tabBar.home"]),
        .noPrivacyBlur: Spec(difficulty: "senior",
            task: "Send the app to the inactive/switcher state; assert the privacy cover appears.",
            expectedClean: "Sensitive content is covered when inactive.",
            expectedBuggy: "Balances/card leak into the switcher.",
            locators: ["privacy.cover"]),
        .otpAcceptsExpired: Spec(difficulty: "senior",
            task: "Let the OTP expire (>20s), enter the code; assert it is rejected.",
            expectedClean: "Expired code rejected.",
            expectedBuggy: "Expired code accepted.",
            locators: ["auth.otpField", "auth.otpError", "auth.otpExpiry"]),
        .otpNoLockout: Spec(difficulty: "middle",
            task: "Enter a wrong code 3×; assert the OTP step locks.",
            expectedClean: "Locks after 3 wrong attempts.",
            expectedBuggy: "No lockout — brute-forceable.",
            locators: ["auth.otpField", "auth.otpError"]),
        .sessionTimeoutDisabled: Spec(difficulty: "senior",
            task: "Leave the app idle past the timeout; assert it re-locks.",
            expectedClean: "Idle session re-locks.",
            expectedBuggy: "Session never times out.",
            locators: ["auth.passcode", "tabBar.home"]),
        .tokenInUserDefaults: Spec(difficulty: "middle",
            task: "After login, inspect storage; assert the session token is NOT in UserDefaults.",
            expectedClean: "Token in Keychain only.",
            expectedBuggy: "Token written to UserDefaults.",
            locators: ["dev.tokenStorage"]),
        .retryDuplicate: Spec(difficulty: "senior",
            task: "Trigger a timeout, tap Retry; assert only one transaction/debit results.",
            expectedClean: "Retry is idempotent (same key).",
            expectedBuggy: "Retry double-posts the payment.",
            locators: ["transfer.retryButton", "transfer.confirmButton", "home.totalBalance"]),
        .slowResponseRace: Spec(difficulty: "senior",
            task: "Switch the sell currency quickly; assert the balance shows the newest currency.",
            expectedClean: "Stale late response is dropped.",
            expectedBuggy: "Stale response clobbers the fresh balance.",
            locators: ["exchange.sellCurrency", "exchange.amountField"]),
        .timeoutAsSuccess: Spec(difficulty: "middle",
            task: "Make a transfer that times out; assert an error (not success) is shown.",
            expectedClean: "Timeout surfaced as an error.",
            expectedBuggy: "Timeout shown as success.",
            locators: ["transfer.confirmButton", "transfer.successToast", "transfer.error"]),
        .staleOfflineBalance: Spec(difficulty: "middle",
            task: "Mutate a balance and refresh; assert reads reflect the change.",
            expectedClean: "Reads reflect the latest state.",
            expectedBuggy: "Reads keep serving a stale snapshot.",
            locators: ["home.totalBalance", "home.account.EUR"]),
        .transactionsHeavyList: Spec(difficulty: "middle",
            task: "Open Transactions and assert scrolling stays responsive / paginated.",
            expectedClean: "Lazy, paginated, smooth.",
            expectedBuggy: "Whole huge list rendered at once → hitches.",
            locators: ["transactions.list", "transactions.loadMore"]),
        .mainThreadStall: Spec(difficulty: "middle",
            task: "Open Portfolio and assert the tab becomes responsive within a small budget.",
            expectedClean: "No main-thread hang on open.",
            expectedBuggy: "UI blocks ~1.2s on open.",
            locators: ["portfolio.root", "portfolio.totalValue"]),

        .exchangeFeeNotApplied: Spec(difficulty: "middle",
            task: "Exchange and assert the credited amount matches the fee-deducted 'You get'.",
            expectedClean: "Credited amount reflects the displayed fee.",
            expectedBuggy: "Fee ignored — credited amount is higher than shown.",
            locators: ["exchange.fee", "exchange.youGet", "exchange.executeButton"]),
        .pnlPercentVsValue: Spec(difficulty: "middle",
            task: "Assert portfolio P&L % equals P&L ÷ cost basis.",
            expectedClean: "Percent measured against cost basis.",
            expectedBuggy: "Percent measured against market value.",
            locators: ["portfolio.pnl", "portfolio.totalValue"]),
        .homeTotalOmitsAccount: Spec(difficulty: "junior",
            task: "Assert Home total equals the sum of all three accounts.",
            expectedClean: "Total = EUR + USD + GBP.",
            expectedBuggy: "GBP account omitted from the total.",
            locators: ["home.totalBalance", "home.account.GBP"]),
        .amountExceedsBalanceAllowed: Spec(difficulty: "junior",
            task: "Enter an amount above the balance; assert Continue is disabled.",
            expectedClean: "Over-balance amount blocks Continue.",
            expectedBuggy: "Continue enabled beyond the balance.",
            locators: ["transfer.amountField", "transfer.continueButton", "transfer.balanceAfter"]),
        .filterLeaksCategory: Spec(difficulty: "middle",
            task: "Select the Money-in filter; assert every visible row is money-in.",
            expectedClean: "Filter shows only money-in rows.",
            expectedBuggy: "Money-out rows leak through.",
            locators: ["transactions.filter.in", "transactions.list"]),
        .orderStuckPending: Spec(difficulty: "middle",
            task: "Place a market order; assert the status reports filled.",
            expectedClean: "Order reports filled.",
            expectedBuggy: "Order stuck showing pending.",
            locators: ["order.placeButton", "order.statusToast"]),
        .exchangeDoubleSubmit: Spec(difficulty: "senior",
            task: "Double-tap Exchange; assert only one exchange executes.",
            expectedClean: "Idempotent — one exchange.",
            expectedBuggy: "Two exchanges executed.",
            locators: ["exchange.executeButton", "home.account.USD"]),
        .feedPollsTooOften: Spec(difficulty: "middle",
            task: "In live mode, assert the quote endpoint isn't polled excessively.",
            expectedClean: "Polls at a sane interval (~3s).",
            expectedBuggy: "Polls ~10× too often.",
            locators: ["markets.liveBadge"]),
        .transactionsSortEveryRender: Spec(difficulty: "middle",
            task: "Profile Transactions rendering; assert the list isn't re-sorted each render.",
            expectedClean: "Sort computed once.",
            expectedBuggy: "Whole list re-sorted on every render.",
            locators: ["transactions.list"]),
        .successToastMissing: Spec(difficulty: "junior",
            task: "Complete a transfer; assert the success toast appears.",
            expectedClean: "Confirmation toast shown.",
            expectedBuggy: "No confirmation toast.",
            locators: ["transfer.confirmButton", "transfer.successToast"]),
        .missingA11yLabel: Spec(difficulty: "middle",
            task: "Assert the Place-order button exposes a non-empty accessibility label.",
            expectedClean: "Label is 'Place order'.",
            expectedBuggy: "Label is empty.",
            locators: ["order.placeButton"]),
        .wrongA11yLabel: Spec(difficulty: "middle",
            task: "Assert the Buy button's accessibility label reads 'Buy'.",
            expectedClean: "Label matches the action ('Buy').",
            expectedBuggy: "Label says 'Sell'.",
            locators: ["asset.buyButton"]),
        .cardNumberFullyVisible: Spec(difficulty: "junior",
            task: "Assert the card number is masked except the last four digits.",
            expectedClean: "Masked PAN.",
            expectedBuggy: "Full PAN visible.",
            locators: ["card.number"]),
        .cardCvvVisible: Spec(difficulty: "junior",
            task: "Assert no CVV is shown on the card face.",
            expectedClean: "CVV never displayed.",
            expectedBuggy: "CVV printed on the card.",
            locators: ["card.cvv", "card.visual"]),
        .otpCodeInLog: Spec(difficulty: "senior",
            task: "Inspect the console during OTP; assert the code is never logged.",
            expectedClean: "No secret in logs.",
            expectedBuggy: "OTP code written to the console.",
            locators: ["auth.otpField"]),
        .flakyAnimation: Spec(difficulty: "senior",
            task: "Open Markets in live mode and assert a price cell settles to its neutral colour within a bounded time on every tick.",
            expectedClean: "Flash animation settles within a stable, bounded duration.",
            expectedBuggy: "Settle time jitters per tick — a wait-for-idle step flakes.",
            locators: ["markets.asset.AAPL.price", "markets.liveBadge"]),
        .offlineBannerMissing: Spec(difficulty: "middle",
            task: "Enable offline mode (dev menu network selector) and assert the offline banner is shown on the current screen.",
            expectedClean: "Offline banner visible while offline.",
            expectedBuggy: "No banner — the app serves cached data silently.",
            locators: ["dev.networkCondition.offline", "net.offlineBanner"]),
        .paginationNeverEnds: Spec(difficulty: "middle",
            task: "Tap Load more repeatedly and assert pagination terminates once every matching row is shown.",
            expectedClean: "Load more stops when the list is exhausted.",
            expectedBuggy: "Load more never stops — the list grows forever.",
            locators: ["transactions.loadMore", "transactions.list"]),
        .syncLostUpdate: Spec(difficulty: "senior",
            task: "On the dev-menu Sync playground, run the concurrent +1 batch and assert the counter equals start + N.",
            expectedClean: "Concurrent increments are atomic; counter == start + N.",
            expectedBuggy: "Increments are lost to a race; counter < start + N.",
            locators: ["dev.sync", "sync.runButton", "sync.counter"]),
        .deepLinkSkipsAuth: Spec(difficulty: "senior",
            task: "Cold-launch a deep link (e.g. chaosbank://markets) while locked and assert the auth gate is still shown.",
            expectedClean: "Deep links land on the auth gate until unlocked.",
            expectedBuggy: "Deep link opens the target screen without any auth.",
            locators: ["auth.passcode", "tabBar.markets"]),
        .notificationBadgeStale: Spec(difficulty: "middle",
            task: "Open the notification centre from Home, dismiss it, and assert the unread badge cleared.",
            expectedClean: "Badge reflects the unread count (0 after reading).",
            expectedBuggy: "Badge stays at the original count after reading.",
            locators: ["home.notificationsBell", "home.notificationsBadge"]),
        .notificationOpensWrongScreen: Spec(difficulty: "middle",
            task: "Tap a notification and assert it opens the destination it names.",
            expectedClean: "Notification opens its stated destination.",
            expectedBuggy: "Notification opens a different screen.",
            locators: ["home.notificationsBell", "notifications.root"]),
        .biometricUnlocksFromAnyStage: Spec(difficulty: "senior",
            task: "From a fresh launch (login stage) assert a biometric unlock does NOT skip login/OTP/passcode.",
            expectedClean: "Biometrics only re-enter from the passcode stage.",
            expectedBuggy: "Biometrics unlock straight from login — the ladder is skipped.",
            locators: ["auth.biometricButton", "auth.passcode"]),
        .rtlBreaksLayout: Spec(difficulty: "middle",
            task: "Enable RTL (dev menu), open Transactions, and assert the rows mirror correctly.",
            expectedClean: "Rows mirror under RTL (start/end).",
            expectedBuggy: "A row stays left-to-right — hard-coded left/right doesn't mirror.",
            locators: ["dev.rtlToggle", "transactions.list"]),
        .numberGroupingIgnoresLocale: Spec(difficulty: "middle",
            task: "Select the de-DE locale (dev menu) and assert the sample number groups as 1.234.567,89.",
            expectedClean: "Grouping follows the locale (de-DE → 1.234.567,89).",
            expectedBuggy: "Grouping is stuck on en-US regardless of locale.",
            locators: ["dev.localeSelector", "dev.localeSample"]),
        .currencySymbolPlacementIgnoresLocale: Spec(difficulty: "middle",
            task: "Select de-DE and assert the currency symbol follows the amount (e.g. 1.234,56 €), not before it.",
            expectedClean: "Symbol placed per locale (after in de-DE, before in en-US).",
            expectedBuggy: "Symbol always placed before the amount (en-US style).",
            locators: ["dev.localeSelector", "dev.localeCurrencySample"]),
        .templatePrefillsWrongAmount: Spec(difficulty: "junior",
            task: "On Transfer, tap the Rent template and assert the amount field prefills its saved value (1200.00).",
            expectedClean: "Template prefills its exact saved amount.",
            expectedBuggy: "Prefilled amount is wrong (e.g. ×10).",
            locators: ["transfer.template.t1", "transfer.amountField"]),
    ]

    static let all: [Exercise] = {
        var counters: [DefectCategory: Int] = [:]
        return DefectID.allCases.map { id in
            let defect = DefectRegistry.defect(id)
            let n = (counters[defect.category] ?? 0) + 1
            counters[defect.category] = n
            let spec = specs[id]
            return Exercise(
                id: "IOS-\(code(defect.category))-\(String(format: "%02d", n))",
                title: defect.title,
                difficulty: spec?.difficulty ?? "middle",
                category: defect.category.rawValue,
                feature: defect.feature,
                defects: [id.rawValue],
                launchArgument: "-ChaosBankDefects \(id.rawValue)",
                profile: nil,
                condition: defect.violates,
                expectedClean: spec?.expectedClean ?? "Behaves per the requirement.",
                expectedBuggy: spec?.expectedBuggy ?? "Requirement violated.",
                task: spec?.task ?? "Reproduce the defect and write a stable test that fails only when active.",
                keyLocators: spec?.locators ?? []
            )
        }
    }()

    /// The catalog as pretty-printed JSON (used to emit exercises.json).
    static func json() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(all) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}
