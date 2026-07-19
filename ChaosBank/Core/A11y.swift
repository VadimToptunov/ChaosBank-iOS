//
//  A11y.swift
//  ChaosBank
//
//  THE single source of truth for accessibility identifiers. Views must never
//  inline identifier string literals — always reference these constants.
//
//  Rules (spec §5):
//   - Format: screen.element or screen.element.qualifier, lowerCamel, dot-separated.
//   - Identifiers are STABLE across seeds. A defect never renames one.
//   - Dynamic rows use a stable key, not an index (markets.asset.AAPL).
//

import Foundation

enum A11y {
    enum TabBar {
        static let root = "tabBar.root"
        static let home = "tabBar.home"
        static let markets = "tabBar.markets"
        static let portfolio = "tabBar.portfolio"
        static let card = "tabBar.card"
    }

    enum Build {
        static let badge = "build.badge"
    }

    enum Net {
        static let offlineBanner = "net.offlineBanner"
    }

    enum Notifications {
        static let root = "notifications.root"
        static let bell = "home.notificationsBell"
        static let badge = "home.notificationsBadge"
        static func row(_ id: String) -> String { "notifications.row.\(id)" }
    }

    enum Sync {
        static let root = "sync.root"
        static let counter = "sync.counter"
        static let runButton = "sync.runButton"
        static let resetButton = "sync.resetButton"
        static let expected = "sync.expected"
    }

    enum Dev {
        static let menu = "dev.menu"
        static let close = "dev.close"
        static let activeLabel = "dev.activeLabel"
        static func profile(_ id: String) -> String { "dev.profile.\(id)" }
        static func defectToggle(_ id: DefectID) -> String { "dev.defect.\(id.rawValue)" }
        static let priceSource = "dev.priceSource"
        static func priceSourceOption(_ kind: String) -> String { "dev.priceSource.\(kind)" }
        static let networkCondition = "dev.networkCondition"
        static func networkConditionOption(_ kind: String) -> String { "dev.networkCondition.\(kind)" }
        static let rtlToggle = "dev.rtlToggle"
        static let tokenStorage = "dev.tokenStorage"
        static let exercises = "dev.exercises"
        static let exercisesList = "dev.exercises.list"
        static let sync = "dev.sync"
        static func exercise(_ id: String) -> String { "dev.exercise.\(id)" }
        static func exerciseApply(_ id: String) -> String { "dev.exercise.\(id).apply" }
    }

    enum Privacy {
        static let cover = "privacy.cover"
    }

    enum Auth {
        static let gate = "auth.gate"

        // Login
        static let loginRoot = "auth.login"
        static let username = "auth.username"
        static let password = "auth.password"
        static let loginButton = "auth.loginButton"
        static let loginError = "auth.loginError"
        // Web login sheet. The form itself lives in a WKWebView; its fields are
        // reachable via web ids (see below), not native accessibility identifiers.
        static let webLoginButton = "auth.webLoginButton"
        static let webSheet = "auth.webSheet"
        static let webCancel = "auth.webCancel"
        // HTML element ids inside the web view (for XCUITest `webViews` queries).
        static let webUsernameHTMLID = "web-username"
        static let webPasswordHTMLID = "web-password"
        static let webSubmitHTMLID = "web-submit"

        // OTP
        static let otpRoot = "auth.otp"
        static let otpField = "auth.otpField"
        static let otpSubmit = "auth.otpSubmit"
        static let otpResend = "auth.otpResend"
        static let otpError = "auth.otpError"
        static let otpHint = "auth.otpHint"
        static let otpExpiry = "auth.otpExpiry"

        // Passcode
        static let passcodeRoot = "auth.passcode"
        static let passcodeField = "auth.passcodeField"
        static let passcodeSubmit = "auth.passcodeSubmit"
        static let passcodeError = "auth.passcodeError"
        static let biometricButton = "auth.biometricButton"
    }

    enum Home {
        static let root = "home.root"
        static let totalBalance = "home.totalBalance"
        static let todayChange = "home.todayChange"
        static let currencySegment = "home.currencySegment"
        static func account(_ currency: Currency) -> String { "home.account.\(currency.code)" }
        static let quickActionTransfer = "home.quickAction.transfer"
        static let quickActionExchange = "home.quickAction.exchange"
        static let quickActionAddMoney = "home.quickAction.addMoney"
        static let quickActionCard = "home.quickAction.card"
        static let recentActivity = "home.recentActivity"
        static func activityRow(_ id: String) -> String { "home.activity.\(id)" }
        static let seeAllActivity = "home.seeAllActivity"
    }

    enum Transfer {
        static let root = "transfer.root"
        static let recipientField = "transfer.recipientField"
        static let amountField = "transfer.amountField"
        static let noteField = "transfer.noteField"
        static let balanceAfter = "transfer.balanceAfter"
        static let continueButton = "transfer.continueButton"
        static let confirmSheet = "transfer.confirmSheet"
        static let confirmButton = "transfer.confirmButton"
        static let retryButton = "transfer.retryButton"
        static let successToast = "transfer.successToast"
        static let error = "transfer.error"
    }

    enum Exchange {
        static let root = "exchange.root"
        static let sellCurrency = "exchange.sellCurrency"
        static let getCurrency = "exchange.getCurrency"
        static let amountField = "exchange.amountField"
        static let rate = "exchange.rate"
        static let fee = "exchange.fee"
        static let youGet = "exchange.youGet"
        static let executeButton = "exchange.executeButton"
        static let successToast = "exchange.successToast"
    }

    enum Transactions {
        static let root = "transactions.root"
        static let searchField = "transactions.searchField"
        static let filterAll = "transactions.filter.all"
        static let filterIn = "transactions.filter.in"
        static let filterOut = "transactions.filter.out"
        static let list = "transactions.list"
        static func row(_ id: String) -> String { "transactions.row.\(id)" }
        static let loadMore = "transactions.loadMore"
        static let count = "transactions.count"
    }

    enum Markets {
        static let root = "markets.root"
        static let segmentWatchlist = "markets.segment.watchlist"
        static let segmentStocks = "markets.segment.stocks"
        static let segmentCrypto = "markets.segment.crypto"
        static let liveBadge = "markets.liveBadge"
        static let list = "markets.list"
        static func asset(_ symbol: String) -> String { "markets.asset.\(symbol)" }
        static func assetPrice(_ symbol: String) -> String { "markets.asset.\(symbol).price" }
        static func assetChange(_ symbol: String) -> String { "markets.asset.\(symbol).change" }
    }

    enum Asset {
        static let root = "asset.root"
        static let symbol = "asset.symbol"
        static let price = "asset.price"
        static let change = "asset.change"
        static func timeframe(_ label: String) -> String { "asset.timeframe.\(label)" }
        static let buyButton = "asset.buyButton"
        static let sellButton = "asset.sellButton"
        static let statMarketCap = "asset.stat.marketCap"
        static let statVolume = "asset.stat.volume"
        static let statHigh = "asset.stat.high"
        static let statLow = "asset.stat.low"
    }

    enum Order {
        static let root = "order.root"
        static let sideBuy = "order.side.buy"
        static let sideSell = "order.side.sell"
        static let typeMarket = "order.type.market"
        static let typeLimit = "order.type.limit"
        static let qtyStepperDecrement = "order.qtyStepper.decrement"
        static let qtyStepperIncrement = "order.qtyStepper.increment"
        static let qtyStepperValue = "order.qtyStepper.value"
        static let limitPriceField = "order.limitPriceField"
        static let refPrice = "order.refPrice"
        static let estTotal = "order.estTotal"
        static let warning = "order.warning"
        static let reviewButton = "order.reviewButton"
        static let confirmSheet = "order.confirmSheet"
        static let placeButton = "order.placeButton"
        static let statusToast = "order.statusToast"
    }

    enum Portfolio {
        static let root = "portfolio.root"
        static let totalValue = "portfolio.totalValue"
        static let pnl = "portfolio.pnl"
        static let allocationBar = "portfolio.allocationBar"
        static let list = "portfolio.list"
        static func holding(_ symbol: String) -> String { "portfolio.holding.\(symbol)" }
        static func holdingValue(_ symbol: String) -> String { "portfolio.holding.\(symbol).value" }
        static func holdingPnl(_ symbol: String) -> String { "portfolio.holding.\(symbol).pnl" }
        static let empty = "portfolio.empty"
    }

    enum Card {
        static let root = "card.root"
        static let visual = "card.visual"
        static let number = "card.number"
        static let cvv = "card.cvv"
        static let freezeToggle = "card.freezeToggle"
        static let frozenBadge = "card.frozenBadge"
        static let onlinePaymentsToggle = "card.onlinePaymentsToggle"
        static let limitField = "card.limitField"
        static let limitError = "card.limitError"
        static let pinButton = "card.pinButton"
        static let orderPhysicalButton = "card.orderPhysicalButton"
    }
}
