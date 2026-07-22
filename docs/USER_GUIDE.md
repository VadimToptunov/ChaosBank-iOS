# ChaosBank-iOS — User Guide (for QA / SDET engineers)

This guide is for the person **using ChaosBank to practise or benchmark test
automation** — not for someone modifying the app (that's the
[Developer's Guide](DEVELOPERS_GUIDE.md)). It explains how to launch the app, turn
specific defects on and off, read the exercise catalog, and write a stable test that
proves it catches a regression.

---

## 1. The mental model

ChaosBank is a fully-working neobank + broker with a library of **named, switchable
defects** planted across every layer (UI, state, validation, localization, concurrency,
networking, security, accessibility, performance).

- **`clean` = a correct app.** With no defects active, everything behaves per spec and
  the full reference test suite passes.
- **A defect is a switch.** Turning one on changes *behavior or values* on a specific
  screen — but **never** the accessibility identifiers your tests locate. So a test you
  write against `clean` keeps finding its elements when a defect is active; it just
  starts *failing on the assertion*, which is exactly what a good regression test should
  do.
- **119 defects, each with an exercise.** Every defect has a matching, self-contained
  task in [`exercises.json`](../exercises.json).

---

## 2. Launching the app in a chosen state

There are three ways to control which defects are active — pick per situation.

### A. Launch arguments / environment (best for CI and ad-hoc runs)

Pass to a booted simulator:

```bash
# Turn on exactly the defects you want (highest precedence)
xcrun simctl launch <device> VadimToptunov.ChaosBank -ChaosBankDefects doubleCharge,roundingDrift

# …or a whole profile
xcrun simctl launch <device> VadimToptunov.ChaosBank -ChaosBankProfile security

# …or a numeric seed (maps to a defect bundle)
xcrun simctl launch <device> VadimToptunov.ChaosBank -ChaosBankSeed 7
```

Precedence (highest first): explicit `-ChaosBankDefects` → `-ChaosBankProfile` →
`-ChaosBankSeed` → the profile baked into the build → `clean`.

**Profiles:** `clean`; the category profiles `ui`, `validation`, `accessibility`,
`state`, `localization`, `security`, `network`; `flaky` (concurrency/races, seed-pinned);
difficulty bundles `beginner`, `middle`, `senior`; and `all`.

**Market data:** `-ChaosBankPriceSource live` uses real Yahoo Finance quotes (no key);
default `simulated` keeps runs reproducible.

**Test/demo affordances** (these never change product behavior — they just position you):

```bash
-ChaosBankStartUnlocked 1     # skip the auth ladder
-ChaosBankTab markets         # start on a tab: home|markets|portfolio|card
-ChaosBankShowDev 1           # auto-open the developer menu
-ChaosBankShowWebLogin 1      # auto-open the web login sheet
```

### B. In-app developer menu (best for exploring interactively)

**Long-press or triple-tap the build badge** (it always shows the active profile/seed).
From there you can switch profile/seed live, toggle individual defects, open the
**Exercises** browser, switch the network condition (normal/offline/slow/flaky), toggle
RTL/locale, and flip KYC — no relaunch.

### C. Baked builds (best for a fixed, shareable per-defect app)

Build a configuration such as **Flaky** to get a standalone app that defaults to that
profile and installs alongside the clean build with its own icon label
(**ChaosBank Flaky**). See [DEVELOPERS_GUIDE.md](DEVELOPERS_GUIDE.md#build-configurations--schemes-distributable-per-defect-builds).

---

## 3. The exercise catalog — your task list

[`exercises.json`](../exercises.json) has one entry per defect. Each is a complete brief:

```json
{
  "id": "IOS-CON-01",
  "title": "Rapid double-tap sends twice",
  "difficulty": "senior",
  "category": "concurrency",
  "feature": "Transfer",
  "defects": ["doubleCharge"],
  "launchArgument": "-ChaosBankDefects doubleCharge",
  "condition": "Idempotency of a submit action",
  "expectedClean": "Idempotent — one transaction.",
  "expectedBuggy": "Two transactions (double charge).",
  "task": "Rapidly double-tap Confirm; assert exactly one transaction / one debit.",
  "keyLocators": ["transfer.confirmButton", "home.totalBalance"]
}
```

| Field | Use it for |
|---|---|
| `launchArgument` | Paste-ready flag to activate exactly this defect. |
| `expectedClean` / `expectedBuggy` | The assertion boundary — clean must pass, buggy must fail. |
| `task` | What to automate. |
| `keyLocators` | The accessibility identifiers to target (stable across clean/buggy). |
| `difficulty` | `junior` / `middle` / `senior` — pick your level. |

The in-app **Developer → Exercises** browser lists the same catalog by difficulty and
can apply any exercise's defect(s) live.

---

## 4. Writing your first regression test (worked example)

Take exercise `IOS-STA-…` `staleBalance` ("dashboard shows the pre-transfer balance").

1. **Establish the clean baseline.** Launch with no defects, note the Home total
   (`home.totalBalance`), make a transfer, return Home — the balance should decrease.
   Write that as your assertion. It **passes**.
2. **Activate the defect.** Relaunch with `-ChaosBankDefects staleBalance` (from the
   exercise's `launchArgument`).
3. **Re-run the same test.** The locators still resolve; the assertion now **fails**
   because Home keeps the old balance. Your test just proved it catches the regression.
4. **Keep it stable.** Target only the `keyLocators`; don't assert on text that a defect
   might legitimately change elsewhere.

This clean-pass → buggy-fail loop is the whole point of the app; repeat it per exercise.

---

## 5. Feature tour (what you can automate)

- **Bank** — Home dashboard (currency-switchable balance, notifications bell), Transfer
  (confirmation sheet, idempotency, retry, saved templates, KYC gate), Exchange (live FX,
  fees), Transactions (search / filter / pagination).
- **Broker** — Markets (live ticking prices, sparklines), Asset detail, Order ticket
  (market/limit lifecycle), Portfolio (live P&L, allocation).
- **Card** — freeze / online-payments toggles, limits, PIN, virtual card.
- **Loans** — a loan calculator (advertised vs effective APR).
- **Auth ladder** — **web login** (a `WKWebView` sheet, reached via a web context, not
  native locators) → **OTP** (resend cooldown, expiry, auto-submit, lockout) → **6-digit
  passcode** → **Face ID** fallback, plus background re-lock and idle session timeout.
- **Sync playground** (dev menu) — a concurrent-increment counter for race exercises.

---

## 6. Guarantees you can rely on

- **Stable locators.** Every identifier is a constant in `Core/A11y.swift`; defects never
  move them.
- **Determinism.** With the default `simulated` price source, a given seed reproduces the
  same run (price walk, race coin-flips). Only `live` mode is intentionally
  non-deterministic.
- **Correct baseline.** `clean` passes the full reference suite; any failure there is a
  real bug, not a planted one.

---

## 7. FAQ

**Q: A locator disappeared when I turned on a defect.**
It shouldn't — defects change behavior/values, not identifiers. Check you're using the
id from `keyLocators`, and file it if a locator truly moved (that would be a defect in
the fixture itself).

**Q: My "flaky" test is flaky even on clean.**
Concurrency/timing exercises (`flakyAnimation`, races) are `senior` for a reason —
prefer explicit synchronization over `sleep`. The `flaky` profile is seed-pinned so the
*app* is reproducible; your waits must be robust.

**Q: Where's the authoritative defect list?**
[`exercises.json`](../exercises.json) (generated from the in-app catalog). The README has
a curated highlights table.
