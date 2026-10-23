# Lifecore Project Instructions & Agent Guidelines

Welcome to the **Lifecore (Native iOS-First & Athletic Performance Platform)** project.

---

## 1. Mandatory Agent Operational Directives (Token Economy & Language Protocol)

### 1.1. English-Only Artifacts & Code (Token Economy)
* **All Documentation & Code:** Write all documentation (`PROJECT_KNOWLEDGE.md`, `AGENTS.md`, `README.md`, `docs/*.md`, `CHANGELOG.md`), code comments, commit messages, variable/type names, and AI system prompt instructions in concise, high-density English.
* **Density:** Avoid verbose prose, conversational filler, or redundant examples in markdown files to minimize context window usage.

### 1.2. Ukrainian User Chat Protocol
* **Chat Communication:** Communicate with the user in chat strictly in Ukrainian. Keep chat responses brief, technical, and action-oriented.
* **In-App AI Output:** In-app AI Coach reports and food labels generated for the end-user must be in Ukrainian, even though system prompt instructions and templates are authored in English.

### 1.3. Skills & AGENTS.md First
* Inspect `AGENTS.md` and check `.agents/skills/` before executing tasks or modifying code.
* Use `brainstorming` and `writing-plans` for new features; `test-driven-development` and `verification-before-completion` for implementation; `systematic-debugging` for bug fixes.

---

## 2. Architectural Constraints & Conventions (Native iOS-First)

### 2.1. iOS-First Architecture (`ios/Lifecore/`)
* **Primary Client & Engine:** Native iOS application built in Swift 6, SwiftUI, Swift Charts, HealthKit, and SwiftData.
* **Modular Structure:**
  - `Lifecore/App/`: `LifecoreApp.swift`, `MainTabView.swift`
  - `Lifecore/Core/HealthKit/`: `HealthKitManager.swift`, `WorkoutTelemetryExtractor.swift`
  - `Lifecore/Core/MathEngine/`: `ReadinessCalculator.swift`, `WorkoutMathEngine.swift`, `VitalsAndIllnessEngine.swift` (Phase 3), `TrainingLoadAndBatteryEngine.swift` (Phase 3), `CorrelationEngine.swift` (Phase 3), `AdaptivePhysiologyEngine.swift` (Phase 3.1 Self-Learning Engine), `TrainingPrescriptionEngine.swift` (Phase 3.2 Adaptive Training Prescription Engine)
  - `Lifecore/Core/UI/`: `LifecoreDesignSystem.swift` (Phase 3.1 Liquid Glass Bento Cockpit)
  - `Lifecore/Core/AI/`: `GeminiService.swift`, `FoodPrompt.swift`, `CoachPrompt.swift`
  - `Lifecore/Core/Storage/`: `SwiftDataModels.swift`, `AthleteProfileStore.swift` (Phase 3), `TrainingPlanModels.swift` (Phase 3.2), `MealStorageService.swift`, `SupabaseSyncService.swift`
  - `Lifecore/Features/`: `Today/`, `Workouts/`, `Nutrition/`, `Trends/`
  - `Lifecore/Intents/`: `LogMealIntent.swift`, `LifecoreSyncIntent.swift`
* **Legacy Backend Archived:** The Dual-Backend has been removed from `main` and safely archived in git tag `v1.0-telegram-archive`. The repository is strictly native iOS-First.
* **Cloud Storage & Sync:** Supabase PostgreSQL serves as bidirectional cloud backup and synchronization layer.

### 2.2. Strict Separation: Deterministic Math vs AI Reasoning
* **Swift Math Engine:** All deterministic calculations (1km splits, pace, heart rate decoupling / cardiac drift %, pure NEAT isolation, 7d/14d rolling weight averages, caloric deficit buffer, beat-to-beat RMSSD + $\ln\text{HRV}$ Z-scores, 5-metric Overnight Vitals confluence, Banister TRIMP, EWMA ACWR, 24h Body Battery, and $T+0/T+1/T+2$ statistical correlations $r, r_{pb}$) **MUST** be computed natively in Swift code.
* **Gemini AI Role:** AI models are reserved strictly for qualitative narrative reasoning, athletic pattern interpretation, and causal explanation over pre-calculated metrics. Never ask Gemini to calculate averages, correlations, or arithmetic.

### 2.3. AI Coach Persona & Multi-Metric Illness Confluence Rules
* **70%:** Deep workout breakdown (1km splits, pace vs HR, elevation response, cardiac drift / aerobic decoupling).
* **15%:** Historical benchmark comparison against previous similar workouts (pace, HR, EF deltas, EWMA ACWR context).
* **15%:** Physiological root causes (sleep stages, 5-metric Overnight Vitals, time-lagged nutrition/carbohydrate correlations) explaining *why* performance shifted, plus **1 actionable athletic directive for the next 24h**.
* **Zero Single-Metric Medical Alarmism vs True Illness Confluence:**
  - Normal single-metric RHR variations ($\pm 2\text{--}4\text{ bpm}$) without fever or respiratory shift are treated as standard training adaptations (`trainingFatigue`).
  - Pre-symptomatic **Illness Prodrome (`illnessProdrome`)** alerts trigger strictly when $\ge 3$ of 5 nocturnal Vitals (HRV, RHR, Wrist Temp $\Delta T^\circ\text{C}$, Respiratory Rate, $\text{SpO}_2\%$) deviate simultaneously, or when $\Delta T \ge +0.40^\circ\text{C}$ converges with an autonomic shift (Stanford NightSignal + Apple Vitals rule).

### 2.4. Food Recognition & Nutrition Principles
* **Deficit Buffer (+12.5% kcal):** Strictly apply `kcal_final = round(kcal_exact * 1.125)`. Keep protein, fat, and carbs exact.
* **Portion & Cooked State:** Always estimate cooked values for grains, rice, pasta, and meat.
* **Tagging Taxonomy:** Mandatory quality tags (`whole_food`, `solid`, `liquid`, `fast_absorbing`, `ultra_processed`, `high_sodium`).
* **Dietary Date Convention:** Day shift occurs at **04:00 AM** (`shiftHours = 4`). Post-midnight meals and workouts belong to the previous calendar day.

---

## 3. Documentation Integrity Rule
> ⚠️ **STRICT RULE:** Any change in code, database, prompts, or configuration **MUST IMMEDIATELY** be reflected in the corresponding documentation before declaring a task complete.

1. **[CHANGELOG.md](file:///Users/skycherepanya/Developer/GitHub/calories-bot-mvp/CHANGELOG.md):** Record date, description of changes, and list of affected files.
2. **[PROJECT_KNOWLEDGE.md](file:///Users/skycherepanya/Developer/GitHub/calories-bot-mvp/PROJECT_KNOWLEDGE.md):** Keep Section 3 ("Current Implementation") and all technical sections synchronized with active code.
3. **[docs/ROADMAP.md](file:///Users/skycherepanya/Developer/GitHub/calories-bot-mvp/docs/ROADMAP.md):** Mark completed items (`[x]`) and keep upcoming phases accurate.
4. **[docs/DATABASE.md](file:///Users/skycherepanya/Developer/GitHub/calories-bot-mvp/docs/DATABASE.md):** Update schemas, JSONB structures, and table definitions.
5. **[docs/ARCHITECTURE.md](file:///Users/skycherepanya/Developer/GitHub/calories-bot-mvp/docs/ARCHITECTURE.md):** Update component diagrams and layer interactions.
6. **[README.md](file:///Users/skycherepanya/Developer/GitHub/calories-bot-mvp/README.md):** Keep setup instructions, structure, and capability summaries aligned.

---

## 4. Verification and Version Control Rule
1. **Verification:** Verify Swift code (`xcodebuild` / `swift build`), lints, and scripts before declaring completion.
2. **Commit:** Commit with conventional commit messages and push to `origin/main`.
3. **Deploy:** Apply database migrations to Supabase via Supabase CLI (`supabase db push`) when updating database schemas.
