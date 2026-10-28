# Lifecore 3.4: Native iOS-First, Multilayer Health RAG & Conversational Analyst Platform

**Lifecore** is a personal, native Quantified Self health and endurance platform. Built with **Swift 6, SwiftUI, HealthKit, SwiftData, and Supabase**, the system integrates high-frequency physiological telemetry from Apple Watch, camera-based nutrition tracking, on-device deterministic sports mathematics, a self-learning adaptive physiological engine, deterministic training prescription, a 3-tier on-device Health Context Graph (RAG), and a Bevel-style conversational athletic analyst powered by Gemini AI without vendor lock-in.

---

## ⚡ Key Capabilities (Lifecore 3.4)

### 💬 Multilayer Health RAG & Conversational Analyst Engine (Phase 3.4)
* **3-Tier On-Device Health Context Graph (`LifecoreContextRAG`):**
  - **L1 (Acute 48h):** 1km splits, cardiac drift %, sleep stages, 5-metric Overnight Vitals deviations, and meals eaten within the last 48 hours.
  - **L2 (Contextual 30d):** EWMA ACWR strain envelope, dynamic TDEE slope, learned biological sensitivities ($\beta_{\text{Na}\to\text{H2O}}$, $\beta_{\text{LateMeal}\to\text{RHR}}$, etc.), and training prescription status.
  - **L3 (Episodic Longitudinal Memory):** SwiftData `AthleteMemoryEntity` indexed and retrieved via hybrid BM25 lexical token matching + semantic tags + 21-day exponential recency decay.
* **Effort-Normalized Benchmark Regimes (`WorkoutMathEngine`):** Classifies workout comparisons into 5 distinct regimes (`trueAerobicGain`, `higherIntensityEffort`, `easyRecoveryEffort`, `cardiacStrainDecoupling`, `steadyBaseline`), preventing effort-blind false praise.
* **Bevel Intelligence Conversational Coach (`LifecoreIntelligenceChatView`):** Multi-turn conversational analyst sheet with real-time RAG context bar, memory drawer, cited metric pills, and structured takeaway responses.
* **Hallmark Daylight Structured Cards (`CoachReportView`):** Completely replaces raw Markdown hashes (`###`) and repetitive templates with clean, strongly typed `StructuredWorkoutDebrief` cards, metric pills, follow-up chips, and non-blocking offline fallbacks.

### 🎯 Deterministic Adaptive Training Prescription Engine (Phase 3.2)
* **Inverse EWMA ACWR Load Budgeting:** Formulates analytical daily load budgets $\text{TRIMP} \in [0, 160]$ targeting progressive overload ratio $R_{\text{target}} = 1.08$ with high-acute-spike safety ceiling ($\le 45$ TRIMP if prior ACWR $>1.25$).
* **3-Gate Physiological Override State Machine:** Multi-metric gating across Overnight Vitals (`ImmuneSystemState`), Morning Body Battery ($<40\%$), 3-day caloric deficit ($< -650\text{ kcal/day}$), and median 3-run Cardiac Drift % ($>5.0\%$ duration consolidation vs $\le 3.5\%$ speed progression unlock).
* **Dynamic Pace & HR Zones Derived from $EF_{75}$:** Derives personalized pace and HR ceiling targets across Zones 1–5 from 30-day rolling 75th percentile Efficiency Factor ($EF_{75}$) and Heart Rate Reserve ($\text{HRR}$).
* **4-Archetype Polarized Rolling Stimulus Queue:** Manages non-destructive quality session deferral across `aerobicBasePlusStrides`, `cruiseThresholdIntervals`, `recoveryFlush`, and `progressiveQualityLongRun`, with 1-tap club/custom run recalculation and pre-workout carbohydrate prescription ($\beta_{\text{Carbs}\to\text{Drift}}$).

### 🧠 Self-Learning Adaptive Physiology Engine (Phase 3.1)
* **Bayesian Shrinkage Prior-Blending:** Smoothly blends athlete baseline priors with empirical personal telemetry ($w_N = \frac{N}{N + 14}$), displaying live confidence percentage (0–99%).
* **MacroFactor-Style Dynamic TDEE & Adaptive BMR:** Continuously recalculates true daily energy expenditure and metabolic adaptation from 14-day smoothed weight slopes ($\Delta W_{\text{trend}} \times 7700\text{ kcal/kg}$) against logged caloric intake and isolated Pure NEAT.
* **Online Ridge OLS $\beta$-Sensitivities:** Quantifies personal biological response slopes: $\beta_{\text{Na}\to\text{H2O}}$ (kg water spike per 1g sodium), $\beta_{\text{TRIMP}\to\text{Battery}}$ (energy drain factor), $\beta_{\text{LateMeal}\to\text{RHR}}$ (+bpm nocturnal penalty), and $\beta_{\text{Carbs}\to\text{Drift}}$ (% cardiac drift mitigation).
* **60d EWMA Baseline Corridors & 1-Tap RPE Calibration:** Dynamic personal baseline envelope smoothing with simplex adjustments to `ReadinessWeightVector` when subjective athlete feedback diverges from predicted readiness.

### 🧬 Clinical-Grade Vitals & Pre-Symptomatic Illness Radar
* **5-Metric Overnight Vitals Corridor:** Direct on-device queries (<5ms) for sleep architecture, beat-to-beat HRV RMSSD (`HKHeartbeatSeriesSample` with 20% ectopic beat rejection) + $\ln(\text{SDNN})$, sleeping RHR, sleeping wrist temperature ($\Delta T^\circ\text{C}$), blood oxygen ($\text{SpO}_2\%$), respiratory rate, and $\text{VO}_2\text{max}$.
* **Stanford NightSignal + Apple Vitals Confluence:** Multi-metric state machine (`optimal`, `trainingFatigue`, `immuneWatch`, `illnessProdrome`) detects viral prodrome 24–48h before clinical symptoms without single-metric medical alarmism.
* **Continuous 24h Body Battery (0–100%):** Differential reserve trajectory combining overnight vagal recharge with daytime hourly drain (circadian + Pure NEAT + TRIMP + immune strain).

### 🏃 Athletic Split Telemetry & Running Engine
* **Kilometer-by-Kilometer Splits:** Granular analysis of every kilometer (pace, average heart rate, elevation gain/loss $\Delta h$, cadence).
* **Cardiac Drift & Decoupling ($EF$):** Deterministic evaluation of aerobic decoupling ($\Delta EF$) between the first and second half of runs to detect cardiovascular fatigue, dehydration, and glycogen depletion.
* **Pure NEAT Isolation:** Mathematical extraction of non-exercise activity thermogenesis ($\text{NEAT} = \max(0, \text{daily\_active\_kcal} - \sum \text{workout\_kcal})$) avoiding duplicate calorie counting.
* **Banister TRIMP & EWMA ACWR:** Exponential heart-rate impulse workload calculation and Acute (7d) vs Chronic (28d) ratio monitoring the $0.80\text{--}1.30$ sweet spot.

### 📸 Frictionless Nutrition & Bidirectional HealthKit Sync
* **Vision-Based Food Recognition:** Multi-model Gemini Vision cascade (`gemini-3.8-flash` $\to$ `gemini-2.5-flash` $\to$ `gemini-3.6-flash`) with automated portion estimation and macronutrient breakdown.
* **Guaranteed Deficit Buffer (+12.5%):** Automatically multiplies calculated calories by $\times 1.125$ to protect the user's caloric deficit.
* **4-Hour Dietary Day Shift:** The dietary date resets at 04:00 AM, correctly attributing late-night meals to the preceding physiological cycle.
* **Bidirectional Apple Health Sync:** Every logged meal writes back calories, protein, fat, carbs, fiber, and sodium tagged with metadata key `LifecoreMealID`. Supports instant in-place swipe deletion (`SwipeableMealCardContainer`), 5-second undo restoration, and two-tier zero-lag modal input (`FoodInputSheet`).

### 🤖 AI Athletic Performance Analyst (70 / 15 / 15)
* **70% Workout Execution:** Granular breakdown of pacing stability, heart rate spikes on hills, and cardiovascular efficiency.
* **15% Historical Benchmark:** Objective comparison against past similar endurance sessions.
* **15% Physiological Root Causes:** Explaining performance deltas through sleep stages, autonomic recovery (HRV/RHR), and nutritional glycogen reserves.
* **Actionable Directive:** 1 concrete, non-medical training instruction for the next 24 hours in Ukrainian.

---

## 🏗️ 4-Layer On-Device Architecture

```
┌────────────────────────────────────────────────────────┐
│  Layer 1: Canonical Source of Truth (Apple HealthKit)  │
│  Apple Watch Ultra & iPhone 16 Pro (<5ms direct query) │
│  Sleep Stages • HRV SDNN/RMSSD • Wrist Temp • SpO2     │
│  Bidirectional Dietary Write-Back & Deletion Sync      │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│  Layer 2: Swift Deterministic Math & Adaptive Engine   │
│  TrainingPrescriptionEngine (Inverse EWMA, 3 Gates)    │
│  AdaptivePhysiologyEngine (Dynamic TDEE, Bayesian OLS) │
│  VitalsAndIllnessEngine (5-Metric NightSignal Radar)   │
│  TrainingLoadAndBatteryEngine (TRIMP, EWMA ACWR)       │
│  CorrelationEngine (T+0, T+1, T+2 Point-Biserial r)    │
│  WorkoutMathEngine (1km Auto-Splits, EF, Drift %)      │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│  Layer 3: Local Persistence & Cloud Synchronization    │
│  SwiftData (AthleteTrainingPlanState, Meals, Workouts) │
│  AthleteProfileStore & TrainingPlanStore               │
│  MealStorageService (Optimistic State & Undo Toast)    │
│  ▲                                                     │
│  └──► Async Warehouse: Supabase (001–007 Migrations)   │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│  Layer 4: Presentation & AI Athletic Intelligence      │
│  Liquid Glass Bento UI 3.2 (Cockpit, Horizon Deck)     │
│  TacticalPrescriptionCard (Today) & Rolling Deck       │
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
├── PROJECT_OVERVIEW.md        # High-density executive summary for AI brainstorming
├── ARCHITECTURAL_PIVOT_IOS_FIRST.md # Historical architectural pivot directive
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
│           │   ├── MathEngine/# ReadinessCalculator.swift, WorkoutMathEngine.swift,
│           │   │              # VitalsAndIllnessEngine.swift, TrainingLoadAndBatteryEngine.swift,
│           │   │              # CorrelationEngine.swift, AdaptivePhysiologyEngine.swift,
│           │   │              # TrainingPrescriptionEngine.swift,
│           │   │              # MathEngineVerification.swift (12 verification suites)
│           │   ├── UI/        # LifecoreDesignSystem.swift (Liquid Glass Bento Cockpit)
│           │   ├── AI/        # GeminiService.swift, FoodPrompt.swift, CoachPrompt.swift
│           │   └── Storage/   # SwiftDataModels.swift, AthleteProfileStore.swift, TrainingPlanModels.swift,
│           │                  # MealStorageService.swift, HealthPayload.swift, SupabaseSyncService.swift
│           ├── Features/
│           │   ├── Today/     # TodayView.swift, TacticalPrescriptionCard.swift, AthleteProfileSheet.swift
│           │   ├── Workouts/  # WorkoutsView.swift, RollingHorizonDeckView.swift, WorkoutDetailView.swift
│           │   ├── Nutrition/ # NutritionView.swift, FoodInputSheet.swift, NutritionComponents.swift
│           │   └── Trends/    # TrendsView.swift, TrendsComponents.swift, CorrelationInsightsCard.swift
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
│   ├── 05_training_prescription_flow.yaml # Tactical prescription card & rolling horizon deck
│   └── suite.yaml             # Master continuous regression test suite
│
├── .github/                   🤖 CI/CD Workflows
│   └── workflows/
│       └── e2e.yml            # Automated GitHub Actions Maestro simulator runner
│
├── docs/                      📚 Architecture & Technical Specifications
│   ├── ARCHITECTURE.md        # 4-layer on-device architecture specification (v3.1)
│   ├── DATABASE.md            # PostgreSQL cloud warehouse schema & data dictionary
│   ├── ROADMAP.md             # Native iOS-first development roadmap (Phase 1–4)
│   └── superpowers/
│       ├── specs/             # Architectural specifications (v3.0, v3.1 & Maestro E2E)
│       └── plans/             # Task-by-task implementation plans (Phase 2, Phase 3, v3.1 & E2E)
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
