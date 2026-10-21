# Lifecore 2.0 Development Roadmap

> **Master Evolution Plan:** Transitioning from the Version 1.0 Telegram MVP to the **Native iOS-First & Athletic Performance Platform**.

---

## 🏛️ Phase 1 — Telegram Bot MVP & Data Foundations (Completed / Deprecated)

- [x] **1.1. Food Photo Recognition:** Gemini Vision food parsing with macronutrient extraction.
- [x] **1.2. Food Taxonomy:** Quality tags (`whole_food`, `solid`, `liquid`, `fast_absorbing`, `ultra_processed`, `high_sodium`).
- [x] **1.3. Micronutrient Estimation:** Fiber, sodium, potassium, and amino acid estimation (`bcaa_g`, `leucine_g`).
- [x] **1.4. Deficit Buffer (+12.5%):** Guaranteed caloric buffer (`kcal * 1.125`).
- [x] **1.5. 4-Hour Day Shift:** Dietary reset at 04:00 AM instead of midnight.
- [x] **1.6. Supabase Cloud Database:** Relational tables: `meals`, `body_measurements`, `daily_metrics`, `sleep_logs`, `workouts`.
- [x] **1.7. Historical Data Ingestion:** Uploaded multi-year archive (410 workouts, 1044 sleep logs, 1279 daily metrics).
- [x] **1.8. Ingestion Webhook:** Deployed `ingest-health` Supabase Edge Function with secret authentication.
- [x] **1.9. Initial Swift AppIntent:** Created initial `ios/Lifecore/` Swift package for Apple Health telemetry push.

---

## 🚀 Phase 2 — Native iOS-First Platform & Four Feature Views (Active / Current Focus)

### 2.1. Foundation: HealthKit Reader & Deterministic Math Engine
- [x] HealthKit async statistics queries for sleep architecture (`asleepDeep`, `asleepREM`, `asleepCore`, `awake`).
- [x] HealthKit morning autonomic biomarker queries (HRV SDNN, resting heart rate RHR).
- [x] Pure NEAT isolation formula: $\text{NEAT} = \max(0, \text{daily\_active\_kcal} - \sum \text{workout\_kcal})$.
- [x] `WorkoutTelemetryExtractor.swift`: query raw `HKQuantitySeriesSample` for continuous distance, HR, altitude, cadence.
- [x] `WorkoutMathEngine.swift`:
  - 1km auto-splits (duration, pace, average HR, max HR, $\Delta h$ elevation, cadence).
  - Structured interval laps from `HKWorkoutActivity` (work pace, rest HR recovery drop).
  - Efficiency Factor ($EF = \text{Speed} / \text{Avg HR}$) and Aerobic Decoupling / Cardiac Drift %.
  - Historical benchmark comparison against last 3 similar sessions.
- [x] `ReadinessCalculator.swift`: Recovery score (0-100%), Cardiovascular Strain, and 7d/14d rolling weight averages.
- [x] Standalone deterministic math verification suite (`MathEngineVerification.swift`, 6/6 tests passing).

### 2.2. View 1: Today View (Readiness, Strain & Caloric Balance)
- [x] Initial single-page dashboard scaffold.
- [x] Refactor into dedicated `Features/Today/TodayView.swift` within `MainTabView.swift`.
- [x] Interactive Bevel-style rings:
  - **Readiness Ring:** 0-100% composite score from HRV z-score, RHR delta, and deep/REM sleep duration.
  - **Strain Ring:** Cardiovascular load computed from HR zones + isolated NEAT (0-21 WHOOP scale & 0-100%).
  - **Nutrition Ring:** Caloric balance progress vs daily targets with deficit buffer applied.
- [x] Metric cards: Sleep stages breakdown (Deep, REM, Core, Awake), Autonomic Biomarkers (HRV & RHR with $\Delta$ vs 30-day baseline), Movement & Pure NEAT vs Workout breakdown, and Today's Workouts list.
- [x] Live HealthKit data pipeline: `fetchTodaySnapshot()` with 30-day dynamic baseline calculation (fallback to Sasha's baseline: HRV 102ms, RHR 49bpm).

### 2.3. View 2: Workouts View (Splits, Telemetry & 70/15/15 AI Coach)
- [x] Dedicated `Features/Workouts/WorkoutsView.swift`:
  - Athletic workout filtering (Running, Strength, Cycling, HIIT, Walks) and casual walks exclusion toggle.
- [x] `Features/Workouts/WorkoutDetailView.swift`:
  - Interactive 1km split table (Pace, HR, $\Delta h$, Cadence).
  - Structured interval laps section for HIIT / track sessions with HR recovery drop ($\text{HR}_{\text{drop}}$).
  - Synchronized Swift Charts (`WorkoutChartsView.swift`) displaying pace curves, heart rate zones, and elevation profile with interactive scrub tooltip.
  - Efficiency Factor ($EF$) and Aerobic Decoupling / Cardiac Drift % indicator cards.
- [x] AI Athletic Performance Analyst card (`Features/Workouts/CoachReportView.swift`):
  - On-demand Gemini analysis via `CoachPrompt.swift` & `GeminiService.swift`.
  - Strictly follows the **70 / 15 / 15** breakdown (Pacing Telemetry 70%, Benchmark 15%, Root Causes & 24h Directive 15%).
  - Zero medical alarmism; output in Ukrainian with deterministic offline fallback.

### 2.4. View 3: Nutrition View (Frictionless Vision & Optimistic UI)
- [x] Dedicated `Features/Nutrition/NutritionView.swift`:
  - Daily macronutrient summary card (Protein, Fat, Carbs, Total kcal) with +12.5% deficit buffer badge.
  - Dietary Quality Card: Whole Food vs Ultra-Processed ratio, sodium water retention warning, and leucine MPS threshold.
  - Chronological list of meals logged for the current dietary day (04:00 AM cutoff).
  - Date navigation (`<` / `>`) and "Log for Yesterday" fast toggle.
- [x] Photo picker & camera flow + quick text description (`FoodInputSheet.swift`, <5s total flow).
- [x] Optimistic UI: instant pending meal card insertion (<0.2s) in "Analyzing..." state via `MealStorageService.swift`.
- [x] Background vision processing: `GeminiService.swift` multimodal cascade (`gemini-3.8-flash` -> `gemini-2.5-flash` -> `gemini-3.6-flash`).
- [x] Automatic application of +12.5% caloric deficit buffer, cooked weight calibration, and taxonomy tags (`FoodPrompt.swift`).
- [x] Write-back to HealthKit dietary calories, protein, fat, carbs, and sodium via `HealthKitManager.swift`.

### 2.5. View 4: Trends View (Water Noise Filter & Longitudinal Baselines)
- [x] Dedicated `Features/Trends/TrendsView.swift` & `TrendsComponents.swift`:
  - **Body Weight Trend Chart:** Raw daily weigh-ins overlayed with 7-day and 14-day rolling averages (filtering water/glycogen noise) with acute water spike badge ($\ge 1.2$ kg jump).
  - **Autonomic Baseline Chart:** 30-day rolling baseline envelope ($\text{Mean} \pm 0.5\sigma$) for morning HRV SDNN and sleeping RHR.
  - **Aerobic Efficiency Trend:** Historical Efficiency Factor ($EF = \text{Speed} / \text{Avg HR}$) and cardiac drift / aerobic decoupling progression across running sessions.
  - **Interactive Controls:** 30d / 60d / 90d time range selector, interactive scrub tooltips (`.chartXSelection`), pull-to-refresh, and live HealthKit pipelines with high-fidelity realistic fallbacks.

### 2.6. Local Storage & Cloud Backup (SwiftData + Supabase)
- [ ] Local `@Model` entities (`MealEntity`, `WorkoutAnalysisEntity`, `DailyMetricEntity`, `SleepLogEntity`).
- [ ] Asynchronous cloud sync to Supabase `meals` and `workout_analyses` (`splits_json`, `laps_json`).
- [ ] `LogMealIntent.swift` for fast Siri / Action Button food capture.

---

## 📈 Phase 3 — Advanced Physiological Modeling & Time-Lags (Next)

### 3.1. Multi-Day Time-Lagged Correlations
- [ ] Quantify impact of sodium intake (Day T) on morning fluid retention (Day T+1, T+2).
- [ ] Quantify correlation between carbohydrate deficit and subsequent aerobic decoupling on endurance runs.
- [ ] Detect early overtraining signals via cumulative acute-to-chronic workload ratio (ACWR).

### 3.2. Automated Morning Briefing
- [ ] iOS Lock Screen Widget and notification at 08:00 AM:
  - Morning Readiness Score (HRV/RHR).
  - Recommended workout intensity for the day.
  - Target carbohydrate and hydration intake.

---

## ⌚️ Phase 4 — Hardware & Ecosystem Extensions (Future)

### 4.1. Bluetooth Smart Scale Integration
- [ ] CoreBluetooth background reader for direct scale weigh-ins (weight, impedance, body fat %).

### 4.2. WatchOS Native Companion App
- [ ] Dedicated Apple Watch complication and Action Button integration for instant readiness check and split tracking.
