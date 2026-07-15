# Sandbank — Project Specification

> A deliberately-buggy iOS neobank + broker, built as a **practice target for XCUITest / KassiOS**.
> This document is the source of truth. Read it fully before writing code.

---

## 1. What this project is

Sandbank is a native iOS app that looks and behaves like a real fintech product (a Revolut/Robinhood-style hybrid of a bank and a stock/crypto broker), but it exists for one purpose: to give QA automation engineers a realistic app to **write UI tests against**.

It is two things at once, and both must stay true:

1. **A model of testability.** Every interactive element is reachable through a stable, well-named accessibility identifier. The app is what a perfectly-instrumented app should look like from a test's perspective.
2. **A host for deliberate bugs.** The app ships known defects — money that doesn't add up, stale balances, race conditions on live prices — that a good test suite should catch and a naive one will miss.

The companion deliverable is a **reference KassiOS test suite** that catches every planted defect. The app plus that suite is the teaching material: "here is the bug, here is the test that catches it, here is why a naive test flakes."

### Non-goals
- No real backend, no real money, no real authentication. Everything is in-memory and mocked.
- Not a trading or banking product. Do not add features for their own sake; every screen exists to host a testing scenario.
- No third-party app dependencies (see §4). KassiOS is a **test-target** dependency only.

---

## 2. Core principle: correct code and bugs are separated

This is the most important rule in the project.

**Production logic is always written correctly.** Money math, order pricing, balance updates — the reference implementation is the correct one. Defects are never baked into the core; they are injected at explicit, guarded points controlled by a central registry.

```
Correct behavior  ──────────────►  always the default code path
                                    (active when a defect is OFF)

Defect            ──────────────►  a small, isolated override, guarded by
                                    `if Defects.isActive(.someBug) { ... }`
```

Why this matters:
- **Regression training works.** Write a test against the clean baseline (it passes), flip a seed that activates the defect, re-run (it fails). The test proved it catches the regression.
- **The clean build is a real, correct app.** Seed `00` = zero defects. It should pass the full reference suite.
- **Locators never move.** A defect changes *behavior or values*, never the accessibility-identifier surface. Tests stay stable across builds; only assertions on state change outcome.

Anti-pattern to avoid: scattering `if buggy` checks through view code, or letting a defect rename/hide an element. Keep injection points few, named, and listed in the registry.

---

## 3. The build / seed / defect system

### BuildConfig
A build is identified by a **seed** (two digits, e.g. `07`). The seed maps to a set of active defect IDs. This is what the `sandbox · build 1.0 · seed 07` badge in the UI refers to.

```swift
struct BuildConfig {
    let version = "1.0"
    let seed: Int              // 0 = clean baseline
    var activeDefects: Set<DefectID>
}
```

- `seed 00` → `activeDefects = []` (clean; passes the full reference suite).
- Other seeds → curated subsets, so a build can present one or several bugs at a time.
- The active seed is chosen at launch via a launch argument / environment variable so tests can pin it deterministically:
  - `-SandbankSeed 07` (launch argument), or scheme env `SANDBANK_SEED=7`.
- The badge in the UI must always show the real active seed, so a tester can read it off-screen.

### DefectRegistry
Each defect is a first-class, documented object — not a magic boolean.

```swift
enum DefectID: String, CaseIterable { case doubleCharge, staleBalance, roundingDrift, … }

struct Defect {
    let id: DefectID
    let title: String            // "Double charge on rapid double-tap"
    let feature: String          // "Transfer"
    let severity: Severity       // .critical / .major / .minor
    let violates: String         // the correct behavior it breaks
    let flakiness: Flakiness     // .deterministic / .raceCondition (fails intermittently)
}
```

`Defects.isActive(_:)` reads from the current `BuildConfig`. Registry lives in `Core/Defects/` and is the single list every defect is declared in.

### Determinism
The price feed and any injected randomness use a **seeded RNG** derived from the build seed. Two runs with the same seed produce the same price walk. Race-condition defects should be reproducibly flaky (fail often enough to be caught, rarely enough to punish naive tests) — tune their probability, don't leave it to raw `Double.random`.

---

## 4. Tech stack

| Concern | Choice | Notes |
|---|---|---|
| UI | **SwiftUI** | iOS 17+. Native, declarative. |
| Language | Swift 5.9+ | |
| Architecture | **MVVM** | `View` + `@Observable`/`ObservableObject` view model per feature. |
| Concurrency | async/await + `AsyncStream` | Live price feed; simulated backend latency. |
| Money | **`Decimal`** everywhere | Never `Double`/`Float` for money — except where a defect deliberately routes through `Double` (the rounding-drift bug). |
| Persistence | In-memory repositories | No Core Data, no network. A `MockBackend` actor with configurable latency. |
| Auth | Mock biometric gate | A fake Face ID prompt; no real `LocalAuthentication` requirement. |
| App dependencies | **None** | Keep the app pure so the test target is the star. |
| Test target | **KassiOS** (SPM) | XCUITest-based; the reference suite lives here. |
| Min iOS | 17.0 | |

Bundle id placeholder: `io.sandbank.app` (set your own). App name: **Sandbank**.

---

## 5. Accessibility identifier convention (non-negotiable)

Tests are only as stable as the locators. Follow these rules exactly.

- Every interactive or asserted element gets `.accessibilityIdentifier(...)`.
- Identifiers come from **one central constants file** — `Core/A11y.swift` — never inline string literals in views. The app and the reference test suite both import these constants (share the source of truth via the KassiOS test target reading a generated/shared list, or by duplicating a small plist — pick one and document it).
- Format: `screen.element` or `screen.element.qualifier`, lowerCamel segments, dot-separated.
- Identifiers are **stable across seeds**. A defect never changes an identifier.
- Dynamic rows use a stable key, not an index: `markets.asset.AAPL`, not `markets.asset.0`.

Examples:

```
home.totalBalance
home.account.EUR
home.quickAction.transfer
transfer.amountField
transfer.recipientField
transfer.continueButton
transfer.confirmButton          // on the confirmation sheet
markets.segment.watchlist
markets.asset.AAPL
asset.price
asset.buyButton
asset.sellButton
order.side.buy
order.type.limit
order.qtyStepper.increment
order.qtyStepper.value
order.estTotal
order.reviewButton
order.placeButton
portfolio.totalValue
portfolio.pnl
portfolio.holding.TSLA
card.freezeToggle
```

---

## 6. Screens & features

Mirror the prototype. Each screen lists the elements that must be identifiable and the defects it can host.

### 6.1 Home (bank dashboard)
- Total balance (currency-switchable: EUR/USD/GBP), today's change.
- Account strip: EUR Main, USD Savings, GBP Travel.
- Quick actions: Transfer, Exchange, Add money, Card.
- Recent activity list (last few transactions).
- **Hosts:** `staleBalance` (balance not refreshed after a transfer).

### 6.2 Transfer
- Recipient, amount, note; "balance after" preview; Continue → confirmation sheet → Confirm.
- Success toast; balance and transaction history update.
- **Hosts:** `doubleCharge` (rapid double-tap on Confirm creates two transactions), `staleBalance`.

### 6.3 Exchange
- Sell currency → get currency, live rate, fee, execute.
- **Hosts:** `roundingDrift` (displayed converted amount ≠ amount written to history), `localeParse` (thousands/decimal separator mishandled).

### 6.4 Transactions (full history)
- Search + filter (All / Money in / Money out); grouped by date; "Load more" pagination.
- **Hosts:** pagination/dedup bugs (a transaction appears twice after Load more), filter that leaks the wrong category.

### 6.5 Markets (watchlist)
- Segments: Watchlist / Stocks / Crypto.
- Asset rows: symbol, name, sparkline, **live ticking price**, % change (green/red).
- Prices update on a feed; each tick flashes.
- **Hosts:** the signature `livePriceRace` surface.

### 6.6 Asset detail
- Big live price + change, chart with timeframes, stats grid, Buy / Sell.
- **Hosts:** `livePriceRace` (price shown when opening the order differs from the tapped price).

### 6.7 Order ticket
- Buy/Sell toggle, Market/Limit toggle, quantity stepper, (limit price), order summary, Review → confirm sheet → Place.
- Order lifecycle: pending → filled.
- **Hosts:** `limitValidation` (limit sell below market executes instantly with no warning; negative/zero qty accepted), `livePriceRace`, `roundingDrift` on est. total.

### 6.8 Portfolio
- Invested value (live), all-time P&L (green/red), allocation bar, holdings with live per-position value.
- **Hosts:** `pnlSign` (a loss shows as a gain — wrong sign), stale total after an order.

### 6.9 Card
- Card visual, Freeze toggle, online-payments toggle, limits, PIN, order physical card.
- **Hosts:** toggle state that doesn't persist / reads back inverted.

### 6.10 Auth gate
- Mock biometric prompt on launch / on entering sensitive flows.
- **Hosts:** gate that can be bypassed by backgrounding and returning.

---

## 7. Defect catalog (initial set)

Declare all of these in `DefectRegistry`. Each ships OFF at seed `00`.

| ID | Title | Feature | Correct behavior it violates | Type |
|---|---|---|---|---|
| `roundingDrift` | Conversion rounds wrong into history | Exchange / Order | Displayed value and stored value are the same, correctly rounded (Decimal). | deterministic |
| `doubleCharge` | Rapid double-tap sends twice | Transfer | Confirm is idempotent; one tap = one transaction. | race |
| `staleBalance` | Dashboard shows pre-transfer balance | Home | Balance reflects latest state after any mutation. | deterministic (timing) |
| `pnlSign` | Loss displayed as gain | Portfolio | P&L sign matches actual gain/loss. | deterministic |
| `livePriceRace` | Order price ≠ tapped price | Markets / Order | Confirmation price equals the price acted on. | race |
| `limitValidation` | Bad limit orders accepted silently | Order | Limit sell below market warns; qty must be > 0. | deterministic |
| `localeParse` | `1,000.50` parsed as `1.00050` | Exchange / Transfer | Amounts parse correctly under the active locale. | deterministic |
| `paginationDup` | Transaction duplicated after Load more | Transactions | Each transaction appears once. | deterministic |
| `cardToggleInvert` | Freeze toggle reads back inverted | Card | Toggle state persists and reads back correctly. | deterministic |
| `authBypass` | Gate skipped after backgrounding | Auth | Sensitive screens always require the gate. | deterministic |

For each defect, the reference suite gets one test that fails when it's active and passes at seed `00`.

---

## 8. Suggested project structure

```
Sandbank/
├── App/
│   ├── SandbankApp.swift          // entry; reads seed from launch args/env
│   ├── RootView.swift             // tab shell + auth gate
│   └── TabBarView.swift
├── DesignSystem/
│   ├── Colors.swift               // tokens from §9
│   ├── Typography.swift
│   └── Components/                // Card, Chip, PrimaryButton, LiveTicker, Sheet…
├── Core/
│   ├── A11y.swift                 // ALL accessibility identifiers (§5)
│   ├── Money/ Money.swift, Currency.swift   // Decimal-based
│   ├── Feed/ PriceFeed.swift      // seeded RNG, AsyncStream of ticks
│   ├── Backend/ MockBackend.swift // in-memory + configurable latency
│   └── Defects/
│       ├── DefectID.swift
│       ├── Defect.swift
│       ├── DefectRegistry.swift   // the single catalog
│       └── BuildConfig.swift      // seed → active defects
├── Models/ Account, Transaction, Asset, Holding, Order, Quote
└── Features/
    ├── Home/            HomeView.swift, HomeViewModel.swift
    ├── Transfer/
    ├── Exchange/
    ├── Transactions/
    ├── Markets/
    ├── AssetDetail/
    ├── Order/
    ├── Portfolio/
    └── Card/

SandbankUITests/                   // KassiOS reference suite
├── Support/  (Screen objects / KassiOS page DSL, launch helpers)
└── Defects/  (one test per DefectID)
```

---

## 9. Design system (from the prototype)

**Concept:** cool blue-black base (bank = trust) + warm sand-gold accent (the name / "sandbox"). Green/red are reserved strictly for gain/loss, so the brand accent is deliberately **not** green.

Colors:
```
--bg        #0E1218   deep blue-black background
--surface   #171C25   cards
--surface2  #1F2733   elevated
--line      #262F3D   hairline borders
--sand      #E9B45E   brand / primary actions
--gain      #34D399   gains only
--loss      #F87171   losses only
--text      #F4F1EA   warm off-white
--muted     #8B95A6   secondary text
```

Typography:
- Display / headings: **Space Grotesk** (used with restraint).
- Body / UI: **Inter** (or SF as fallback).
- Numbers / prices / balances: a **monospaced, tabular-figure** face (e.g. JetBrains Mono, or SF Mono). Tabular figures are mandatory for money and ticking prices so digits don't jump — this is both the "engineering tool" identity and a correctness detail.

Signature element: the **live ticker** — prices tick with a brief green/up or red/down color flash. This is also the primary surface for timing defects.

Motion & accessibility floor: respect Reduce Motion (ticker stops animating, values still update); visible focus; Dynamic Type friendly.

---

## 10. Build order (milestones)

1. **Scaffold** — Xcode project, design system tokens, tab shell, empty screens, `A11y.swift` stub, `BuildConfig` reading seed from launch args. All at seed `00`.
2. **Models + mock backend + price feed** — correct behavior only, no defects. Seeded RNG feed emitting ticks. Configurable latency on backend calls.
3. **Bank side** — Home, Transfer (+ confirmation sheet), Transactions, Exchange. Correct money math in `Decimal`.
4. **Trading side** — Markets (live), Asset detail (chart), Order ticket (market/limit lifecycle), Portfolio (live P&L).
5. **Card + auth gate.**
6. **Defect system** — implement `DefectRegistry` + all §7 defects as isolated, guarded injections. Verify seed `00` stays clean.
7. **Reference KassiOS suite** — screen objects + one test per defect (fails when active, passes at seed `00`), plus a naive-vs-robust pair for the race defects to demonstrate why the reliability layer matters.

Ship each milestone building and running before moving on.

---

## 11. Instructions for Claude Code

- **Keep defects isolated.** Never scatter `if buggy` through views. All defects flow through `Defects.isActive(_:)`, are declared in `DefectRegistry`, and change behavior/values only — never accessibility identifiers.
- **Seed 00 is sacred.** After any change, the app at seed `00` must remain fully correct and pass the reference suite.
- **Locators from `A11y.swift` only.** No inline identifier string literals in views.
- **`Decimal` for money.** The single exception is the `roundingDrift` defect, which deliberately routes through `Double` at its one injection point.
- **Deterministic randomness.** All randomness derives from the build seed so runs reproduce. Race defects are tuned probabilities, not raw randomness.
- **Real content, no lorem.** Use the concrete data from the prototype (accounts, tickers AAPL/TSLA/NVDA/BTC/ETH/MSFT, sample transactions).
- **Small, reviewable commits per milestone.** State assumptions inline when the spec is silent; don't invent new features.
- When unsure whether something is "a bug to plant" or "a bug to fix," check §2: production paths are always correct; planted bugs live only in the registry-guarded overrides.

---

## 12. Definition of done (v1)

- App builds and runs on iOS 17+ simulator.
- At seed `00`: every screen behaves correctly; reference suite is green.
- Each defect in §7 is implemented, isolated, and toggled purely by seed.
- Reference KassiOS suite: one catching test per defect, plus at least one naive-vs-robust demonstration on a race defect.
- The build badge shows the active seed on-screen.
- No third-party dependencies in the app target; KassiOS only in the UI-test target.
