# ChaosBank-iOS — Architecture

This document explains **how the app is built** and, above all, **how known defects
are injected without corrupting the correct baseline**. If you only read one design
section, read [The defect-injection model](#the-defect-injection-model).

> Companion docs: [DIAGRAMS.md](DIAGRAMS.md) (UML for the sections below),
> [DEVELOPERS_GUIDE.md](DEVELOPERS_GUIDE.md) (how to build, test and extend),
> [USER_GUIDE.md](USER_GUIDE.md) (how to drive the app as a QA fixture),
> [CONTRIBUTING.md](../CONTRIBUTING.md) (workflow + the 1:1 parity contract with
> [ChaosBank-Android](https://github.com/VadimToptunov/ChaosBank-Android)).

---

## 1. What this app is

ChaosBank is a **deliberately-buggy neobank + broker** used as a controlled practice
range for mobile QA / SDET automation. It looks and behaves like a real fintech
product (a Revolut/Robinhood-style hybrid), but every "bug" is a **named, switchable
defect** that can be turned on or off at launch or live. The clean build is a real,
correct app; defects are opt-in overlays.

- **Platform:** iOS 17+, SwiftUI, Swift concurrency (`@MainActor`, actors).
- **Toolchain:** Xcode 26+.
- **Dependencies:** none in the app target (Foundation / SwiftUI / WebKit only).
- **Determinism:** all randomness derives from a build seed (see [§6](#6-determinism--seeding)).

---

## 2. Layered structure

The codebase is split into a **logic layer** (pure, host-testable, correctness-owning)
and a **UI layer** (SwiftUI views). Defects live in the logic layer behind guards; the
UI layer only renders and never decides correctness.

```
ChaosBank/
├── App/            @main scene, RootView, tab shell, auth flow, launch options
│   ├── ChaosBankApp.swift     entry point + .onOpenURL deep-link glue
│   ├── RootView.swift         auth gate ⇄ TabBarView
│   ├── TabBarView.swift       Home / Markets / Portfolio / Card
│   ├── AuthFlow.swift         the login → OTP → passcode → biometric ladder
│   ├── LaunchOptions.swift    non-defect test/demo affordances
│   ├── DeepLink*.swift        chaosbank:// routing
│   ├── LocaleSettings.swift   RTL / locale dev toggles
│   ├── KycStore / NotificationStore / TemplateStore  small stateful stores
├── Core/                      ← the logic layer; correctness lives here
│   ├── A11y.swift             ALL accessibility identifiers (single source)
│   ├── Defects/               DefectID, Defect, categories, registry, profiles, BuildConfig, Defects
│   ├── Money/                 Decimal money, Currency, FX, AmountParser, LocaleFormat, LoanCalc
│   ├── Feed/                  seeded PriceFeed + live Yahoo source + MarketStore
│   ├── Backend/               in-memory MockBackend actor + BackendScenario + NetworkCondition
│   ├── Exercises/             machine-readable exercise catalog (source of exercises.json)
│   ├── SeededRNG.swift        SplitMix64 deterministic RNG
│   └── TokenStore.swift       session-token storage (Keychain vs UserDefaults defect)
├── DesignSystem/              color/type tokens + components (LiveTicker, Sparkline…)
├── Models/                    Account, Transaction, Asset, Quote, Holding, Order, SeedData
└── Features/                  one folder per screen: View + ViewModel
```

Each feature follows **MVVM**: a `*View.swift` (SwiftUI, dumb) plus a `*ViewModel.swift`
(`@Observable @MainActor`, holds state and calls the backend). View models are the main
unit-test surface; views are covered by instrumented/reference suites.

---

## 3. The defect-injection model

**The single most important rule: production logic is always written correctly.**
Money math, order pricing, balance updates — the reference implementation is the
correct one. A defect is never baked into the core; it is injected at an explicit,
guarded point behind one query:

```swift
if Defects.isActive(.doubleCharge) {
    // small, isolated buggy override
}
```

`Defects` is the only surface a guard touches:

```swift
@MainActor
enum Defects {
    private(set) static var config = BuildConfig(seed: 0, activeDefects: [], label: "clean")
    static func configure(_ config: BuildConfig) { self.config = config }
    static func isActive(_ id: DefectID) -> Bool { config.activeDefects.contains(id) }
    static var seed: Int { config.seed }
}
```

Design consequences that tests rely on:

| Property | Why it holds |
|---|---|
| **Clean build is correct** | `clean` profile = empty `activeDefects`; every guard's `else` path is the reference implementation. |
| **Regression training works** | A test passes on `clean`, then fails when its defect is active — proving it catches the regression. |
| **Locators never move** | A defect changes *behavior or values*, never the accessibility-identifier surface. Every identifier is a constant in [`Core/A11y.swift`](../ChaosBank/Core/A11y.swift). |
| **One switch, many builds** | The same binary becomes any bug set via config — no `#if` scattered through features. |

### Defect model types

- **`DefectID`** — a `CaseIterable`, `String`-raw-valued enum; every defect is one case
  (e.g. `.roundingDrift`). The raw value is the stable public name used in
  `exercises.json`, launch args, and cross-platform parity.
- **`DefectCategory`** — money, validation, localization, state, concurrency, ui,
  accessibility, security, network, performance (10 categories).
- **`Defect`** — descriptive metadata for one id: `title`, `category`, `feature`,
  `violates` (the requirement it breaks), severity.
- **`DefectRegistry`** — the id → `Defect` table, plus `defects(forSeed:)` which maps a
  numeric seed to a defect bundle.
- **`BugProfile` / `BugProfiles`** — named bundles (`clean`, category profiles, `flaky`,
  difficulty bundles, `all`), each with a pinned seed.

---

## 4. Build/config resolution

A run is described by a **`BuildConfig`** (`seed`, `activeDefects`, `label`,
`priceSource`). `BuildConfig.resolve()` computes it once at launch from four sources,
in strict precedence (highest first):

1. `-ChaosBankDefects a,b,c` — explicit defect list → label `custom`.
2. `-ChaosBankProfile <id>` / `CHAOSBANK_PROFILE` — a named profile.
3. `-ChaosBankSeed <n>` / `CHAOSBANK_SEED` — numeric seed mapping.
4. `BuildConfig.bakedDefaultProfile` — the profile compiled into this **build
   configuration** (via `SWIFT_ACTIVE_COMPILATION_CONDITIONS`, e.g.
   `CHAOSBANK_PROFILE_FLAKY`), read in exactly one place.
5. `clean`.

A `-ChaosBankSeed` still overrides a profile's RNG seed when both are set. This is why
the same catalog is reachable three ways — runtime args for CI/dev, and baked build
configurations for distributable per-defect apps that install side-by-side with their
own icon label.

**Launch affordances** (`LaunchOptions`) are separate and **never change product
behavior** — they only skip the auth ladder or deep-link a tab so a test/screenshot can
start where it needs to (`-ChaosBankStartUnlocked`, `-ChaosBankTab`, `-ChaosBankShowDev`,
`-ChaosBankShowWebLogin`).

---

## 5. The exercise catalog pipeline

Every defect has exactly one **exercise** — a self-contained task telling a tester what
to automate, what the clean vs buggy outcome is, and which locators to use.

```
DefectRegistry (metadata)  ┐
Exercises.specs (guidance) ┼──▶ Exercises.all ──▶ Exercises.json() ──▶ exercises.json
DefectID.allCases (order)  ┘                                              ▲
                                                                          │
                                    exercises.schema.json + check_exercises.py (CI gate)
```

- **Source of truth:** [`Core/Exercises/Exercise.swift`](../ChaosBank/Core/Exercises/Exercise.swift).
  `Exercises.all` walks `DefectID.allCases`, pulls title/category/feature/`violates`
  from the registry, merges per-defect guidance (`difficulty`, `task`,
  `expectedClean`, `expectedBuggy`, `keyLocators`), and assigns a stable id
  `IOS-<CATCODE>-NN` (per-category counter).
- **Export:** `Exercises.json()` serializes with sorted keys → `exercises.json`.
  Because ids are generated per-category, they **must** be regenerated (never
  hand-edited) — see the regeneration flow in [DEVELOPERS_GUIDE.md](DEVELOPERS_GUIDE.md#regenerating-exercisesjson).
- **Validation:** [`exercises.schema.json`](../exercises.schema.json) +
  [`Scripts/check_exercises.py`](../Scripts/check_exercises.py) validate structure and
  enforce **cross-platform parity** — the set of defect names here must equal the set in
  ChaosBank-Android. This runs first in CI.

---

## 6. Determinism & seeding

- **`SeededRNG`** (SplitMix64) drives the price walk and race-condition coin flips, so a
  given seed reproduces the same run. The build badge always shows the active
  profile/seed on screen.
- **Money is `Decimal` everywhere.** The single exception is the `roundingDrift` defect,
  which deliberately routes one calculation through `Double`.
- **The one intentional non-determinism** is the opt-in **live** price feed
  (`-ChaosBankPriceSource live`), which fetches real quotes from the public Yahoo
  Finance endpoint. It is off by default so reference defects stay reproducible.

---

## 7. Backend & networking model

`MockBackend` is an `actor` (serialized access) holding the in-memory bank/broker state.
`BackendScenario` seeds it; `NetworkCondition` (normal / offline / slow / flaky) models
reliability stressors. Networking defects (`retryDuplicate`, `slowResponseRace`,
`timeoutAsSuccess`, `staleOfflineBalance`, `offlineBannerMissing`) are injected inside
the backend/scenario layer, not in views.

---

## 8. Testing & coverage philosophy

- **Unit tests target the logic layer** (Core, Models, view models, backend) with XCTest.
  The canonical pattern: one assertion that **passes on `clean` and fails when the
  defect is active**.
- **Coverage gate:** [`Scripts/coverage.sh`](../Scripts/coverage.sh) computes
  *logic-layer* coverage via `xccov`, excluding SwiftUI `View` bodies, the app scene, and
  the live network service (they belong to instrumented/reference suites). CI enforces a
  95% floor; the logic layer sits at ~97%.

See [DEVELOPERS_GUIDE.md](DEVELOPERS_GUIDE.md#tests--coverage) for commands and the
exclusion list rationale.
