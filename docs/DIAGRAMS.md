# ChaosBank-iOS — UML Diagrams

Mermaid diagrams (render natively on GitHub). They complement
[ARCHITECTURE.md](ARCHITECTURE.md); the prose there is authoritative if the two ever
drift.

---

## 1. Package / layer diagram

The logic layer owns correctness; the UI layer only renders. Defects are injected in the
logic layer behind a single query surface.

```mermaid
flowchart TD
    subgraph App["App (shell)"]
        ChaosBankApp --> RootView --> TabBarView
        RootView --> AuthFlow
        ChaosBankApp -. onOpenURL .-> DeepLink
        LaunchOptions
    end

    subgraph Features["Features (MVVM)"]
        View["*View (SwiftUI)"] --> ViewModel["*ViewModel (@Observable @MainActor)"]
    end

    subgraph Core["Core (logic layer — correctness)"]
        Defects["Defects.isActive(.x)"]
        DefectsPkg["Defects/ (ID, Registry, Profiles, BuildConfig)"]
        Money["Money/ (Decimal, FX, LocaleFormat, LoanCalc)"]
        Backend["Backend/ (MockBackend actor, Scenario, NetworkCondition)"]
        Feed["Feed/ (seeded PriceFeed + live Yahoo)"]
        Exercises["Exercises/ (catalog → exercises.json)"]
        A11y["A11y.swift (all locators)"]
        RNG["SeededRNG (SplitMix64)"]
    end

    Models[("Models + SeedData")]

    ViewModel --> Backend
    ViewModel --> Defects
    ViewModel --> Money
    View --> A11y
    Defects --> DefectsPkg
    Backend --> Models
    Feed --> RNG
    DefectsPkg --> Exercises
    App --> Features
    Features --> Core
```

---

## 2. Defect-system class diagram

How a defect is described, bundled, resolved, and surfaced to a guard.

```mermaid
classDiagram
    class Defects {
        <<enum, @MainActor>>
        +config: BuildConfig
        +configure(BuildConfig)
        +isActive(DefectID) Bool
        +seed: Int
    }
    class BuildConfig {
        <<struct>>
        +seed: Int
        +activeDefects: Set~DefectID~
        +label: String
        +priceSource: PriceSourceKind
        +bakedDefaultProfile: String?$
        +resolve() BuildConfig$
    }
    class DefectID {
        <<enum : String, CaseIterable>>
        roundingDrift
        doubleCharge
        staleBalance
        … (119 cases)
    }
    class DefectCategory {
        <<enum>>
        money, validation, localization
        state, concurrency, ui
        accessibility, security, network, performance
    }
    class Defect {
        <<struct>>
        +id: DefectID
        +title: String
        +category: DefectCategory
        +feature: String
        +violates: String
    }
    class DefectRegistry {
        <<enum>>
        +defect(DefectID) Defect$
        +defects(forSeed:Int) Set~DefectID~$
    }
    class BugProfile {
        <<struct>>
        +id: String
        +seed: Int
        +defects: Set~DefectID~
    }
    class BugProfiles {
        <<enum>>
        +profile(id:String) BugProfile?$
    }
    class Exercise {
        <<struct, Codable>>
        +id: String
        +defects: [String]
        +task, expectedClean, expectedBuggy
        +keyLocators: [String]
    }
    class Exercises {
        <<enum>>
        +all: [Exercise]$
        +json() String$
    }

    Defects --> BuildConfig
    BuildConfig --> DefectID
    BuildConfig ..> BugProfiles : resolve()
    Defect --> DefectID
    Defect --> DefectCategory
    DefectRegistry --> Defect
    BugProfile --> DefectID
    BugProfiles --> BugProfile
    Exercises --> Exercise
    Exercises ..> DefectRegistry : metadata
    Exercises ..> DefectID : allCases
```

---

## 3. Launch — config resolution

`BuildConfig.resolve()` runs once at launch. Precedence: explicit defects → profile →
seed → baked build configuration → clean.

```mermaid
sequenceDiagram
    participant OS
    participant App as ChaosBankApp
    participant BC as BuildConfig.resolve()
    participant BP as BugProfiles
    participant DR as DefectRegistry
    participant D as Defects

    OS->>App: launch (args / env / compile flags)
    App->>BC: resolve(defaults, environment)
    alt -ChaosBankDefects a,b,c
        BC->>BC: parse list → activeDefects (label "custom")
    else -ChaosBankProfile id (or baked)
        BC->>BP: profile(id)
        BP-->>BC: BugProfile(defects, seed)
    else -ChaosBankSeed n
        BC->>DR: defects(forSeed: n)
        DR-->>BC: Set~DefectID~
    else nothing
        BC->>BC: clean (empty set)
    end
    BC-->>App: BuildConfig(seed, activeDefects, label, priceSource)
    App->>D: configure(config)
    Note over D: every guard now reads this config
```

---

## 4. A guarded defect at runtime (`doubleCharge`)

The reference path is the `else`; the defect is a small isolated override. Locators are
unchanged either way, so the same test finds the same elements.

```mermaid
sequenceDiagram
    actor Tester
    participant TV as TransferView
    participant VM as TransferViewModel
    participant D as Defects
    participant MB as MockBackend (actor)

    Tester->>TV: double-tap Confirm (transfer.confirmButton)
    TV->>VM: confirm()
    VM->>D: isActive(.doubleCharge)?
    alt clean (default / correct)
        D-->>VM: false
        VM->>MB: transfer(idempotencyKey: K)
        VM->>MB: transfer(idempotencyKey: K)
        MB-->>VM: one transaction (K deduped)
    else doubleCharge active
        D-->>VM: true
        VM->>MB: transfer(newKey1)
        VM->>MB: transfer(newKey2)
        MB-->>VM: two transactions (double charge)
    end
    VM-->>TV: update home.totalBalance
```

---

## 5. Auth ladder — state machine

The login → OTP → passcode → biometric ladder, plus background re-lock and idle timeout.
Several security defects short-circuit specific edges (annotated).

```mermaid
stateDiagram-v2
    [*] --> WebLogin
    WebLogin --> OTP : credentials (WKWebView)
    OTP --> Passcode : correct code
    OTP --> OTP : wrong code (lockout after 3)
    Passcode --> Unlocked : 6-digit passcode
    Unlocked --> Passcode : background / idle timeout
    Passcode --> Unlocked : Face ID

    note right of Unlocked
        authBypass: skip re-lock on background
        sessionTimeoutDisabled: never idle-locks
        biometricUnlocksFromAnyStage: Face ID from WebLogin
        deepLinkSkipsAuth: chaosbank:// bypasses the gate
    end note
```

---

## 6. Exercise catalog + cross-platform parity pipeline

One source of truth (`Exercise.swift`) → `exercises.json` → validated and parity-checked
in CI against the Android sibling.

```mermaid
flowchart LR
    DR[DefectRegistry] --> EX[Exercises.all]
    SPEC[Exercises.specs] --> EX
    IDS[DefectID.allCases] --> EX
    EX -->|json| DUMP[testDumpExercisesCatalog]
    DUMP -->|regenerate_exercises.sh| JSON[(exercises.json)]

    subgraph CI["CI (ci.yml)"]
        JSON --> CHK[check_exercises.py]
        SCHEMA[(exercises.schema.json)] --> CHK
        SIB[("Android exercises.json @ main")] -. defect-name set .-> CHK
        CHK -->|structure OK + parity OK| PASS([green])
        CHK -->|dup id / drift| FAIL([red])
    end
```
