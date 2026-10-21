# Lifecore 2.0: Native iOS-First & Athletic Performance Platform

**Lifecore** is a personal, native Quantified Self health and endurance platform. Built with **Swift 6, SwiftUI, HealthKit, and Supabase**, the system integrates high-frequency physiological telemetry from Apple Watch, camera-based nutrition tracking, on-device deterministic sports mathematics, and Gemini AI to deliver elite endurance coaching without vendor lock-in.

---

## ⚡ Key Capabilities (Lifecore 2.0)

### 🍏 Native iOS Application (`ios/Lifecore/`)
* **Bevel 2.0 + Apple Vitals Dashboard (UI 3.0):** Liquid Glass Dark interface presenting daily Readiness, Cardiovascular Strain (with EWMA ACWR), 24h Body Battery / Energy Bank, and Caloric Balance at a glance.
* **5-Metric Overnight Vitals & Illness Radar:** Direct on-device queries (<5ms) for sleep architecture, beat-to-beat HRV RMSSD (`HKHeartbeatSeriesSample`) + $\ln(\text{SDNN})$, sleeping RHR, sleeping wrist temperature ($\Delta T^\circ\text{C}$), blood oxygen ($\text{SpO}_2\%$), respiratory rate, and $\text{VO}_2\text{max}$. Uses Stanford NightSignal + Apple Vitals confluence to detect pre-symptomatic viral prodrome 24–48h early while avoiding single-metric alarmism.
* **Time-Lagged Correlation Engine ($T+0, T+1, T+2$):** Deterministic Point-Biserial ($r_{pb}$) and Pearson ($r$) correlation hub linking sodium to water weight spikes, pre-run carbohydrates to cardiac drift %, and late/UPF meals to overnight HRV recovery (with high-TRIMP confounder filtering).
* **1-Tap & Automated Sync:** `LifecoreSyncIntent` & `LogMealIntent` integrate with iOS Shortcuts, Action Button, Siri, and bidirectional Supabase cloud hydration.

### 🏃 Athletic Split Telemetry & Running Engine
* **Kilometer-by-Kilometer Splits:** Granular analysis of every kilometer (pace, average heart rate, elevation gain/loss $\Delta h$, cadence).
* **Cardiac Drift & Decoupling ($EF$):** Deterministic evaluation of aerobic decoupling ($\Delta EF$) between the first and second half of runs to detect cardiovascular fatigue, dehydration, and glycogen depletion.
* **Pure NEAT Isolation:** Mathematical extraction of non-exercise activity thermogenesis ($\text{NEAT} = \max(0, \text{daily\_active\_kcal} - \sum \text{workout\_kcal})$) avoiding duplicate calorie counting.

### 🤖 AI Athletic Performance Analyst (70 / 15 / 15)
* **70% Workout Execution:** Granular breakdown of pacing stability, heart rate spikes on hills, and cardiovascular efficiency.
* **15% Historical Benchmark:** Objective comparison against past similar endurance sessions.
* **15% Physiological Root Causes:** Explaining performance deltas through sleep stages, autonomic recovery (HRV/RHR), and nutritional glycogen reserves.
* **Actionable Directive:** 1 concrete, non-medical training instruction for the next 24 hours.

### 📸 Frictionless Nutrition Logging
* **Vision-Based Food Recognition:** Camera capture powered by Gemini Vision with automated portion estimation and macronutrient breakdown.
* **Guaranteed Deficit Buffer (+12.5%):** Automatically multiplies calculated calories by ×1.125 to protect the user's caloric deficit.
* **4-Hour Dietary Day Shift:** The dietary date resets at 04:00 AM, correctly attributing late-night meals to the preceding physiological cycle.

---

## 🏗️ 4-Layer On-Device Architecture

```
┌────────────────────────────────────────────────────────┐
│  Layer 1: Canonical Source of Truth (Apple HealthKit)  │
│  Apple Watch Ultra & iPhone 16 Pro (<5ms direct query) │
│  Sleep Stages • HRV SDNN • Sleeping RHR • Series Data  │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│  Layer 2: Swift Deterministic Math & Telemetry Engine  │
│  Readiness (0-100%) • Strain • Pure NEAT Isolation     │
│  1km Auto-Splits • Laps • EF • Cardiac Drift % • GAP   │
│  7d / 14d Rolling Weight Averages (Water Noise Filter) │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│  Layer 3: Local Persistence & Cloud Synchronization    │
│  SwiftData (Local-First Offline Storage)               │
│  ▲                                                     │
│  └──► Async Backup: Supabase (meals, workout_analyses) │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│  Layer 4: Presentation & AI Athletic Intelligence      │
│  SwiftUI Bevel-Style Dashboard (Today, Workouts, etc.) │
│  Gemini Vision Food Parser (+12.5% buffer, tags)       │
│  AI Athletic Performance Analyst (70 / 15 / 15)        │
└────────────────────────────────────────────────────────┘
```

---

## 📁 Repository Structure

```
lifecore/
├── AGENTS.md                  # Token economy rules & agent instructions (English)
├── PROJECT_KNOWLEDGE.md       # Master Single Source of Truth (English)
├── ARCHITECTURAL_PIVOT_IOS_FIRST.md # Master architectural pivot directive
├── CHANGELOG.md               # Milestones & engineering log
│
├── ios/                       🍏 Primary Client: Native iOS App (Swift 6)
│   ├── README.md              # Capabilities & Xcode configuration guide
│   └── Lifecore/
│       ├── Lifecore.xcodeproj
│       └── Lifecore/
│           ├── App/           # LifecoreApp.swift, MainTabView.swift
│           ├── Core/
│           │   ├── HealthKit/ # HealthKitManager.swift, WorkoutTelemetryExtractor.swift
│           │   ├── MathEngine/# ReadinessCalculator.swift, WorkoutMathEngine.swift, VitalsAndIllnessEngine.swift, TrainingLoadAndBatteryEngine.swift, CorrelationEngine.swift
│           │   ├── UI/        # LifecoreDesignSystem.swift (Liquid Glass Dark, Glow Pills)
│           │   ├── AI/        # GeminiService.swift, FoodPrompt.swift, CoachPrompt.swift
│           │   └── Storage/   # SwiftDataModels.swift, AthleteProfileStore.swift, SupabaseSyncService.swift
│           ├── Features/      # Today/, Workouts/, Nutrition/, Trends/
│           └── Intents/       # LifecoreSyncIntent.swift, LogMealIntent.swift
│
├── scripts/                   🛠️ Developer Automation Scripts
│   └── run_e2e.sh             # 1-command build, simulator setup, and Maestro test runner
│
├── .maestro/                  🧪 End-to-End High-Leverage Maestro Test Suite
│   ├── config.yaml            # Maestro bundle configuration (com.skycherepanya.Lifecore)
│   ├── 01_profile_and_readiness.yaml # Today vitals & athlete profile calibration
│   ├── 02_nutrition_logging_and_undo.yaml # Nutrition quick presets & optimistic logging
│   ├── 03_workout_filtering_and_refresh.yaml # Workout activity filters & telemetry refresh
│   ├── 04_trends_adaptive_analytics.yaml # Trends analytical categories & adaptive engine
│   └── suite.yaml             # Master continuous regression test suite
│
├── .github/                   🤖 CI/CD Workflows
│   └── workflows/
│       └── e2e.yml            # Automated GitHub Actions Maestro simulator runner
│
├── docs/                      📚 Architecture & Technical Specifications
│   ├── ARCHITECTURE.md        # 4-layer on-device architecture specification
│   ├── DATABASE.md            # PostgreSQL cloud warehouse schema & data dictionary
│   ├── ROADMAP.md             # Native iOS-first development roadmap (Phase 1–4)
│   └── superpowers/
│       ├── specs/             # Architectural specifications (Lifecore 3.0 & Maestro E2E)
│       └── plans/             # Task-by-task implementation plans (Phase 2 & Phase 3 & E2E)
│
├── supabase/                  ☁️ Cloud Warehouse Layer (Supabase PostgreSQL)
│   └── migrations/            # SQL DDL migrations (001–007)
│
└── [Tag: v1.0-telegram-archive] 📦 Safely preserved legacy Telegram, Deno & Python code in Git history
```

---

## ⚙️ Setup & Development

### 1. iOS Application (Primary)
1. Open `ios/Lifecore/Lifecore/Lifecore.xcodeproj` in **Xcode 16+**.
2. Ensure **HealthKit** and **AppIntents** capabilities are assigned to your Apple Developer Team.
3. Build and run on a physical iPhone connected to an Apple Watch for live HealthKit telemetry.

### 2. End-to-End Testing (Maestro E2E)
The repository provides automated, deterministic UI tests using [Maestro](https://maestro.mobile.dev) covering core user journeys and physiological engines:
1. **Prerequisites:** Ensure Maestro CLI and Java 17+ are installed:
   ```bash
   curl -fsSL "https://get.maestro.mobile.dev" | bash
   brew install openjdk@17
   ```
2. **Run All E2E Tests (1-Command Automation):**
   ```bash
   ./scripts/run_e2e.sh
   ```
   *Automatically boots simulator, builds the app target, installs `Lifecore.app`, and runs `.maestro/suite.yaml`.*
3. **Run Specific Flow:**
   ```bash
   ./scripts/run_e2e.sh 01_profile_and_readiness.yaml
   ./scripts/run_e2e.sh 02_nutrition_logging_and_undo.yaml
   ./scripts/run_e2e.sh 03_workout_filtering_and_refresh.yaml
   ./scripts/run_e2e.sh 04_trends_adaptive_analytics.yaml
   ```

### 3. Cloud Synchronization (Supabase)
Direct on-device synchronization from native iOS (`SupabaseSyncService.swift`) into Supabase PostgreSQL:
- Supabase Project URL & Anon/Service Role Key configured in `ios/Lifecore/Lifecore/Core/Storage/SupabaseSyncService.swift` (or via environment/runtime configuration).
- Local-first architecture guarantees 100% offline functionality with async cloud persistence.
- To inspect or access historical v1.0 Telegram Bot & Deno Edge Function code: `git checkout v1.0-telegram-archive`.

