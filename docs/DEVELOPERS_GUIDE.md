# ChaosBank-iOS — Developer's Guide

Everything you need to **build, run, test, and extend** the app. For the *why* behind
the structure, read [ARCHITECTURE.md](ARCHITECTURE.md) first; to use the app as a QA
fixture, read [USER_GUIDE.md](USER_GUIDE.md).

---

## 1. Prerequisites

| Tool | Version |
|---|---|
| Xcode | 26+ |
| iOS simulator | 17+ (e.g. iPhone 17) |
| Python 3 | for the coverage gate + catalog checker (stdlib only) |

If `xcode-select -p` points at the Command Line Tools, prefix build/test commands with
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` (or `sudo xcode-select -s`).

No package manager, no CocoaPods/SPM dependencies in the app target.

---

## 2. Build & run

```bash
open ChaosBank.xcodeproj          # then ⌘R
```

or from the command line:

```bash
xcodebuild -project ChaosBank.xcodeproj -scheme ChaosBank \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Launch a specific scenario on a booted simulator:

```bash
xcrun simctl launch <device> VadimToptunov.ChaosBank -ChaosBankProfile flaky
```

### Build configurations & schemes (distributable per-defect builds)

Beyond runtime launch args, there is a **build configuration + shared scheme per
profile** (`Flaky`, `UI`, `Validation`, `Accessibility`, `State`, `Localization`,
`Security`, `Network`, `Beginner`, `Middle`, `Senior`, `All`). Each is Debug-based, sets
a compile flag (`CHAOSBANK_PROFILE_*`), a distinct bundle id (`…ChaosBank.flaky`) and
display name, so it installs alongside the clean build with its own icon label.
`Debug`/`Release` (scheme `ChaosBank`) stay clean and host the unit tests.

```bash
xcodebuild -project ChaosBank.xcodeproj -scheme ChaosBank -configuration Flaky \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

---

## 3. Tests & coverage

Run the unit suite:

```bash
xcodebuild test -project ChaosBank.xcodeproj -scheme ChaosBank \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Run the **coverage gate** (this is what CI runs — always run it locally before pushing):

```bash
Scripts/coverage.sh 95           # DEST env overrides the simulator
```

`coverage.sh` runs the tests with coverage, then computes **logic-layer** coverage with
`xccov`, excluding UI/app/network files via the `EXCLUDE` regex in the script (SwiftUI
`View` bodies, `ChaosBankApp`, `ChaosBankScreen`, `AuthViews`, `WebLoginView`,
components, `A11y`, `Colors`, `BuildBadge`, `LivePriceService`). These are not executed
by host unit tests and belong to instrumented/reference suites. The floor is 95%; the
logic layer sits around 97%.

> **Standing rule:** never push iOS without a green `Scripts/coverage.sh` locally — the
> CI gate is identical and a red run there is avoidable.

### The test pattern

Every regression test asserts the same thing on `clean` and under the defect:

```swift
func testStaleBalanceRefreshesOnClean() async {
    Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
    // … assert balance refreshes after a transfer (passes)
}

func testStaleBalanceKeepsOldValueWhenActive() async {
    Defects.configure(BuildConfig(seed: 0, activeDefects: [.staleBalance], label: "t"))
    // … assert Home keeps the pre-transfer balance (this is the bug)
}
```

Always restore `clean` in `tearDown` so tests don't leak config into each other.

---

## 4. Adding a new defect (the full recipe)

Every increment must keep both platforms **1:1** — add the same defect, with the same
`DefectId` name and behavior, to [ChaosBank-Android](https://github.com/VadimToptunov/ChaosBank-Android)
in the same change set. See [CONTRIBUTING.md](../CONTRIBUTING.md#the-11-parity-contract).

1. **Declare the id** — add a case to `Core/Defects/DefectID.swift`. The raw value is the
   public name (used in `exercises.json`, launch args, parity); keep it identical to the
   Android `DefectId`.
2. **Register metadata** — add a `Defect(...)` entry in `Core/Defects/DefectRegistry.swift`
   (title, category, feature, `violates`).
3. **Add locators if needed** — any new accessibility identifier goes in
   `Core/A11y.swift` (the single source). Reuse existing ids where possible; **never**
   change an id to express a defect.
4. **Inject the guard** — at the correct code path, wrap the buggy override:
   ```swift
   if Defects.isActive(.myNewDefect) { /* buggy */ } else { /* correct (default) */ }
   ```
   Keep it small and isolated; the `else` branch is the reference implementation.
5. **Write the exercise guidance** — add a `Spec` for the id in the `specs` map in
   `Core/Exercises/Exercise.swift` (difficulty, task, expectedClean, expectedBuggy,
   locators).
6. **Add tests** — a clean-pass + defect-fail pair in `ChaosBankTests/`.
7. **Regenerate the catalog** — see [§5](#5-regenerating-exercisesjson). Do **not**
   hand-edit `exercises.json`.
8. **Add to a profile (optional)** — if it belongs in a category/difficulty bundle, add
   it in `BugProfiles`.
9. **Verify** — `Scripts/coverage.sh 95` and `python3 Scripts/check_exercises.py exercises.json IOS`.
10. **README** — add a row to the defect table if it's noteworthy.

---

## 5. Regenerating `exercises.json`

Ids are generated per-category from `DefectID.allCases`, so **inserting a defect
renumbers its category** — you cannot hand-append an entry (doing so once produced a
duplicate `IOS-STA-03` that the parity checker later caught). Always regenerate from the
in-app catalog:

```bash
Scripts/regenerate_exercises.sh
```

This runs `FinalCoverageTests/testDumpExercisesCatalog`, captures the JSON it prints
between markers (the simulator sandbox can't write to the repo directly), writes
`exercises.json`, and validates it. `DEST` overrides the simulator.

---

## 6. Catalog validation & cross-platform parity

```bash
python3 Scripts/check_exercises.py exercises.json IOS \
  https://raw.githubusercontent.com/VadimToptunov/ChaosBank-Android/main/exercises.json
```

- **Structural/schema check (hard gate):** required keys, id pattern/prefix, unique ids,
  enum-valid category/difficulty, non-empty strings. Uses `jsonschema` if installed,
  else an equivalent stdlib check against [`exercises.schema.json`](../exercises.schema.json).
- **Parity check:** the set of all `defects` names here must equal the set in the Android
  repo's `main`. Skipped (not failed) if the sibling can't be fetched, so a network blip
  never reds CI; fails loudly on a real drift.

---

## 7. Continuous integration

[`.github/workflows/ci.yml`](../.github/workflows/ci.yml) on `macos-latest`:

1. **Validate catalog & parity** — `check_exercises.py` runs first (fails fast, pre-build).
2. Select the newest Xcode, pick an available iPhone simulator.
3. `./Scripts/coverage.sh 95` — build, test, enforce the logic-layer coverage floor.

---

## 8. Conventions

- **Smallest possible change.** No unrelated refactors, no fat comment blocks.
- **Locators are sacred.** New identifiers only in `A11y.swift`; never repurpose one to
  express a bug.
- **Money is `Decimal`.** The only `Double` money path is the `roundingDrift` defect.
- **Determinism.** Anything random must derive from `Defects.seed` via `SeededRNG`.
- **1:1 with Android.** Same defect names and behavior; regenerate both catalogs; keep
  the parity checker green.
- **Do not hand-edit `exercises.json`.**

### Glossary

| Term | Meaning |
|---|---|
| **Profile** | A named defect bundle (`clean`, `flaky`, `security`, `all`, …). |
| **Seed** | Numeric RNG seed; also maps to a defect bundle via `DefectRegistry`. |
| **Baked build** | A build configuration that compiles a profile in as the default. |
| **Exercise** | The tester-facing task for one defect (in `exercises.json`). |
| **Parity** | The invariant that iOS and Android expose the identical defect-name set. |
