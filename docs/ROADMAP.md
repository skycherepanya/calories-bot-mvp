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
- [x] Lean SwiftData `@Model` entities (`MealEntity`, `WorkoutAnalysisEntity`):
  - Strictly limited to nutrition and workout analysis to prevent duplication of raw HealthKit data (sleep & daily metrics are read directly from Apple Health in <5ms).
  - Preserves +12.5% deficit buffer discipline and 04:00 AM dietary date offset.
- [x] `WorkoutStorageService` & `MealStorageService`:
  - Instant offline hydration of 1km splits, interval laps, EF, and AI coach reports.
  - Seamless migration from UserDefaults to SwiftData.
- [x] Direct asynchronous cloud sync (`SupabaseSyncService.swift`):
  - Cloud warehouse persistence to Supabase `meals` and `workout_analyses` tables.
  - Supabase SQL migration `006_workout_analyses.sql` applied.
  - Direct REST upload of daily metrics & sleep logs with offline queue.
- [x] `LogMealIntent.swift` & `LifecoreShortcutsProvider`:
  - Hands-free Siri, Action Button, and Shortcuts meal capture with instant optimistic response.

---

## 📈 Phase 3 — Advanced Physiological Intelligence, Overnight Vitals, Illness Prodrome & UI 3.0 (Active / Next Focus)

> **Master Spec:** [`docs/superpowers/specs/2026-10-21-lifecore-v3-physiological-engine-and-ui-design.md`](file:///Users/skycherepanya/Developer/GitHub/calories-bot-mvp/docs/superpowers/specs/2026-10-21-lifecore-v3-physiological-engine-and-ui-design.md)  
> **Master Implementation Plan:** [`docs/superpowers/plans/2026-10-21-phase-3-physiological-engine-vitals-and-ui-v3.md`](file:///Users/skycherepanya/Developer/GitHub/calories-bot-mvp/docs/superpowers/plans/2026-10-21-phase-3-physiological-engine-vitals-and-ui-v3.md)

### 3.1. Overnight Vitals Corridor & Pre-Symptomatic Illness Detection (Apple Vitals + NightSignal)
- [x] Expand `HealthKitManager` to query `appleSleepingWristTemperature` ($\Delta T^\circ\text{C}$), `oxygenSaturation` ($\text{SpO}_2\%$), `respiratoryRate` ($\text{br/min}$), `vo2Max`, and raw beat-to-beat `HKHeartbeatSeriesSample`.
- [x] Implement Bevel/Kubios 20% ectopic beat artifact filter and beat-to-beat $\text{RMSSD}$ calculation with fallback to log-transformed $\ln(\text{SDNN})$ and 60-day rolling Z-score ($Z_{\text{HRV}}$).
- [x] Build `VitalsAndIllnessEngine.swift` with 5-metric nocturnal corridor evaluation and multi-metric confluence state machine (`optimal`, `trainingFatigue`, `immuneWatch`, `illnessProdrome`) to detect viral/inflammatory prodrome 24–48h before symptoms while preventing single-metric alarmism.

### 3.2. Garmin Firstbeat Workload Math (Banister TRIMP, EWMA ACWR & Continuous Energy Bank)
- [x] Implement `TrainingLoadAndBatteryEngine.swift`:
  - **Banister TRIMP:** Exponential heart-rate reserve impulse ($\text{TRIMP} = D \cdot \Delta\text{HR}_r \cdot 0.64 \cdot e^{1.92 \cdot \Delta\text{HR}_r}$).
  - **EWMA ACWR:** Exponentially Weighted Moving Average Acute (7d, $\lambda_a = 2/8$) vs Chronic (28d, $\lambda_c = 2/29$) Workload Ratio with $0.80\text{--}1.30$ sweet-spot classification.
  - **Continuous 24h Body Battery / Energy Bank (0–100%):** Differential reserve trajectory combining sleep recharge ($\ln\text{RMSSD}$ + Deep/REM efficiency) and daytime hourly drain (basal circadian + Pure NEAT + workout TRIMP + immune strain).
  - **Sleep Bank & Consistency:** Cumulative 7-day Sleep Debt and 14-day circadian bedtime/wake alignment score.

### 3.3. Confounder-Controlled Time-Lagged Correlation Engine ($T+0, T+1, T+2$)
- [x] Implement `CorrelationEngine.swift` computing Point-Biserial ($r_{pb}$) and Pearson ($r$) correlations across multi-day lags with high-TRIMP confounder filtering:
  - Quantify impact of sodium intake ($\text{mg}$) and `high_sodium` meals (Day $T$) on extracellular water weight retention ($\Delta W = W_{\text{raw}} - W_{7d}$ on Days $T+1, T+2$).
  - Quantify correlation between 24h pre-workout carbohydrate availability and running Cardiac Drift % / Efficiency Factor ($EF$).
  - Quantify impact of late meals ($>21:30$) and `ultra_processed` ratio on overnight HRV suppression and RHR elevation (filtering out days with $\text{TRIMP} > 130$).
  - Quantify impact of `whole_food` dominance and leucine ($\ge 3\text{g}$) on 48h autonomic recovery velocity.

### 3.4. Lifecore UI 3.0 Redesign (Liquid Glass Dark) & Technical Debt Polish
- [x] Create `LifecoreDesignSystem.swift` (Liquid Glass Dark translucent surfaces, 1px top-edge specular gradient borders, semantic status glow pills, smooth `.numericText()` transitions).
- [x] Create `AthleteProfileStore.swift` & `AthleteProfileSheet.swift` to replace hardcoded BMR (`1750 kcal`), Active Move (`650 kcal`), Max HR, and macro constants with user-editable calibration and `hybridRMSSD` / `appleSDNN` toggle.
- [x] Upgrade `SupabaseSyncService.swift` + SQL migration `007_lifecore_v3_vitals_and_correlations.sql` with bidirectional cloud-to-SwiftData hydration (`pullHistoricalDataIfNeeded()`).
- [x] Upgrade `TodayView.swift` with `OvernightVitalsCard` (5-pill Vitals corridor + Illness Prodrome Radar banner) and `EnergyBankCard` (24h Body Battery curve).
- [x] Upgrade `TrendsView.swift` with `CorrelationInsightsCard` (ranked personal habits/nutrition impacts with $r$ and $T+1/T+2$ badges) and `ACWRWorkloadTrendCard`.
- [x] Inject Overnight Vitals confluence state, EWMA ACWR, and personal correlation insights into `CoachPrompt.swift`.

### 3.5. Phase 3.1 (Lifecore v3.1) — Self-Learning Adaptive Physiology Engine & Complete Liquid Glass Bento UI Overhaul (Active Focus)
> **v3.1 Spec:** [`docs/superpowers/specs/2026-10-21-lifecore-v3-1-adaptive-engine-and-ui-overhaul-design.md`](file:///Users/skycherepanya/Developer/GitHub/calories-bot-mvp/docs/superpowers/specs/2026-10-21-lifecore-v3-1-adaptive-engine-and-ui-overhaul-design.md)  
> **v3.1 Plan:** [`docs/superpowers/plans/2026-10-21-phase-3-1-adaptive-engine-and-ui-overhaul.md`](file:///Users/skycherepanya/Developer/GitHub/calories-bot-mvp/docs/superpowers/plans/2026-10-21-phase-3-1-adaptive-engine-and-ui-overhaul.md)
- [ ] **AdaptivePhysiologyEngine (`AdaptivePhysiologyEngine.swift`):**
  - Loop 1: Bayesian Shrinkage ($w_N = \frac{N}{N+14}$) & Model Confidence score (`confidencePct` 0–99%).
  - Loop 2: MacroFactor-style Dynamic TDEE & Adaptive BMR calibration ($\Delta W_{\text{trend, 14d}} \times 7700\text{ kcal/kg}$ vs caloric intake and Pure NEAT).
  - Loop 3: Online Ridge OLS $\beta$-Sensitivities ($\beta_{\text{Na}\to\text{H2O}}$ kg water per 1g sodium, $\beta_{\text{TRIMP}\to\text{Battery}}$ drain factor, $\beta_{\text{LateMeal}\to\text{RHR}}$ penalty, $\beta_{\text{Carbs}\to\text{Drift}}$ slope).
  - Loop 4: 60-day EWMA dynamic Vitals baseline corridors + 1-Tap RPE subjective feedback weight calibration (`ReadinessWeightVector`).
- [ ] **Complete Liquid Glass Bento UI v3.1 Overhaul (All 4 Tabs):**
  - `MainTabView.swift`: 100% Ukrainian tab labels (`Сьогодні`, `Тренування`, `Харчування`, `Тренди`).
  - `TodayView.swift`: Remove duplicate `autonomicCard`, integrate `AdaptiveEngineBadgeBar` & `RPEQuickCalibrationRow` into Hero Cockpit, convert Sleep + Pure NEAT + Adaptive TDEE into Liquid Glass Bento cards, replace hardcoded `1750` BMR with `learnedBmrKcal`.
  - `TrendsView.swift` & `TrendsComponents.swift`: Add Segmented Glass Category Switcher (`Адаптація`, `Навантаження`, `Тіло & Вага`, `Кардіо & ВНС`), add `AdaptiveEngineStatusCard`, upgrade all legacy trend cards to `.lifecoreGlassCard()`.
  - `WorkoutsView.swift`, `NutritionView.swift` & `NutritionComponents.swift`: Full Liquid Glass styling, 100% Ukrainian localization, live Banister TRIMP badges on workout rows, and Tomorrow Sodium Water Retention Forecast in Nutrition.

### 3.6. Automated Morning Briefing & Lock Screen Widgets
- [ ] iOS WidgetKit Lock Screen & Home Screen widgets displaying Morning Readiness, 5-Metric Vitals status, Energy Bank %, and daily target directive.

---

## ⌚️ Phase 4 — Hardware & Ecosystem Extensions (Future)

### 4.1. Bluetooth Smart Scale Integration
- [ ] CoreBluetooth background reader for direct scale weigh-ins (weight, impedance, body fat %).

### 4.2. WatchOS Native Companion App
- [ ] Dedicated Apple Watch complication and Action Button integration for instant readiness check and split tracking.
