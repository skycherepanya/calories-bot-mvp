# Lifecore v3.1 Design Spec: Self-Learning Adaptive Physiology Engine & Complete Liquid Glass Bento UI Overhaul

**Date:** 2026-10-21  
**Version:** Lifecore v3.1 (Phase 3.1)  
**Target Platform:** Native iOS (Swift 6, SwiftUI, Swift Charts, HealthKit, SwiftData, Supabase Sync)  
**Execution Profile:** Optimized for high token efficiency and deterministic step-by-step execution by Gemini Flash 3.8.

---

## 1. Executive Summary & Architectural Goals

Phase 3.0 introduced the 5-metric Overnight Vitals corridor, Banister TRIMP, EWMA ACWR, 24h Energy Bank, and Time-Lagged Correlations ($T+0, T+1, T+2$). However, Phase 3.0 left two critical gaps:
1. **Static Heuristic Constants:** Recovery weights, TRIMP battery drain (`0.32`), sodium-water response, and BMR (`1750 kcal`) were static rather than self-calibrating to the athlete's real physiological response over time.
2. **Fragmented UI:** New cards were appended on top of legacy Phase 2 flat cards (`Color(red: 0.09, green: 0.10, blue: 0.14)`), resulting in duplicate HRV/RHR displays on `TodayView`, mixed English/Ukrainian strings, an 8-card vertical scroll wall on `TodayView`, a 5-chart scroll wall on `TrendsView`, and untouched `WorkoutsView` / `NutritionView`.

**Lifecore v3.1** resolves both gaps through:
1. **`AdaptivePhysiologyEngine.swift`:** A 4-loop on-device mathematical self-learning engine (Bayesian Shrinkage, MacroFactor-style Dynamic TDEE expenditure, Ridge OLS $\beta$-Sensitivity Regression, and 60d EWMA Corridors + 1-Tap RPE weight calibration).
2. **Complete Liquid Glass Bento UI Overhaul:** Unified dark glass aesthetic (`.lifecoreGlassCard()`), zero card duplication, 2-column Bento layout on `TodayView`, Segmented Glass Switcher on `TrendsView`, and 100% Ukrainian localization across all 4 tabs (`Today`, `Workouts`, `Nutrition`, `Trends`).

---

## 2. Self-Learning Mathematical Engine (`AdaptivePhysiologyEngine.swift`)

### 2.1. Loop 1: Bayesian Shrinkage & Model Confidence (`confidencePct`)
To prevent overfitting during cold-start ($N < 14$ days) while converging to 100% personalized physiology as history accumulates, every learned parameter $\theta_{\text{learned}}$ blends the athlete's prior $\theta_{\text{prior}}$ (`AthleteProfile`) with the empirical estimate $\hat{\theta}_{\text{data}}$:
$$w_N = \frac{N}{N + \kappa}, \quad \kappa = 14.0$$
$$\theta_{\text{learned}} = (1 - w_N)\cdot \theta_{\text{prior}} + w_N \cdot \hat{\theta}_{\text{data}}$$
* **Model Confidence Score (`confidencePct: Int`):**
  $$\text{Confidence\%} = \min\left(99, \text{round}\left(100 \cdot \frac{N}{N + 10}\right)\right)$$
  Exposed in UI badges to show how deeply the engine has adapted to the athlete.

### 2.2. Loop 2: MacroFactor-Style Adaptive Metabolism (`DynamicTDEEResult`)
Replaces static `bmrKcalPerDay` (`1750 kcal`) with continuous expenditure calibration over a 14-day rolling window of `DailyJoinedPhysiologyRecord`:
1. **Trend Weight Slope ($\Delta W_{\text{trend}} / \text{day}$):** Computed from 7d/14d exponentially smoothed weight to eliminate extracellular water noise.
2. **Empirical Expenditure ($\widehat{\text{TDEE}}_{\text{data}}$):** Using tissue energy density $\rho_{\text{tissue}} = 7700\text{ kcal/kg}$:
   $$\widehat{\text{TDEE}}_{\text{data}} = \overline{\text{Kcal}}_{\text{in, 14d}} - 7700.0 \cdot \frac{W_{\text{trend}, t} - W_{\text{trend}, t-d}}{d}$$
3. **Bayesian Effective BMR & TDEE:**
   $$\widehat{\text{BMR}}_{\text{data}} = \widehat{\text{TDEE}}_{\text{data}} - \overline{\text{NEAT}}_{14d} - \overline{\text{WorkoutKcal}}_{14d}$$
   $$\text{BMR}_{\text{learned}} = \text{clamp}\Big((1 - w_N)\cdot \text{BMR}_{\text{prior}} + w_N \cdot \widehat{\text{BMR}}_{\text{data}},\; 1350,\; 2450\Big)$$
   $$\text{AdaptiveTargetKcal} = \text{BMR}_{\text{learned}} + \text{TodayNEAT} + \text{TodayWorkoutKcal} - \text{TargetDeficitKcal}$$
4. **Metabolic Adaptation Delta (`metabolicAdaptationKcal`):** $\text{BMR}_{\text{learned}} - \text{BMR}_{\text{prior}}$ (e.g., `-85 kcal` during prolonged cut or `+110 kcal` during high-flux training).

### 2.3. Loop 3: Online Ridge OLS $\beta$-Sensitivity Slopes (`LearnedSensitivities`)
Computes physical slope coefficients $\beta = \frac{\sum (x_i - \bar{x})(y_i - \bar{y})}{\sum (x_i - \bar{x})^2 + \lambda}$ ($\lambda = 1.5$ L2 stabilization) shrunk toward physiological priors:
1. **$\beta_{\text{Na}\to\text{H2O}}$ (`sodiumWaterKgPerGram`):** $\text{kg}$ morning extracellular water shift per $+1000\text{ mg}$ sodium above baseline (Prior: `+0.32 kg / 1000mg`). Used in `NutritionView` and `TodayView` to predict tomorrow's scale water spike.
2. **$\beta_{\text{TRIMP}\to\text{Battery}}$ (`trimpBatteryDrainFactor`):** Battery % drained per 1 unit of Banister TRIMP, calibrated against next-morning HRV drop (Prior: `0.32`). Fed directly into `TrainingLoadAndBatteryEngine.computeEnergyBankTimeline`.
3. **$\beta_{\text{LateMeal}\to\text{RHR}}$ (`lateMealRhrPenaltyBpm`):** Overnight RHR elevation (bpm) following meals after 21:30 on non-heavy training days (Prior: `+3.1 bpm`).
4. **$\beta_{\text{Carbs}\to\text{Drift}}$ (`carbCardiacDriftSlopePctPer100g`):** Change in running Cardiac Drift % per $+100\text{ g}$ prior-day carbohydrates (Prior: `-1.8% / 100g`).

### 2.4. Loop 4: 60-Day EWMA Dynamic Vitals Corridors & 1-Tap RPE Weight Calibration
1. **Dynamic 60d EWMA Baseline (`computeDynamicVitalsBaseline`):** Updates `NocturnalVitalsBaseline` (`hrvMeanMs`, `hrvStdDevMs`, `rhrMeanBpm`, `rhrStdDevBpm`, `wristTempMeanCelsius`, `respiratoryRateMeanBpm`, `spo2MeanPct`) using $\lambda_{60} = \frac{2}{60 + 1}$ so the corridor shifts automatically as fitness improves.
2. **1-Tap RPE Feedback (`RPECalibrationFeedback: Int` = `-1` worse, `0` accurate, `+1` better):**
   Adjusts personalized Readiness component weights $(w_{\text{hrv}}, w_{\text{rhr}}, w_{\text{sleep}}, w_{\text{arch}})$ via bounded simplex step ($\eta = 0.015$, clamped to $[0.10, 0.55]$, normalized to $\sum w_i = 1.0$) persisted in `AthleteProfileStore`.

---

## 3. Complete Liquid Glass UI v3.1 Overhaul (All 4 Tabs)

### 3.1. `MainTabView.swift`
* Full Ukrainian tab bar labels: `"Сьогодні"`, `"Тренування"`, `"Харчування"`, `"Тренди"`.

### 3.2. `TodayView.swift` (Bento Cockpit — Zero Duplication)
* **Removes** the duplicate `autonomicCard` (HRV and RHR are already in `OvernightVitalsCard`).
* **Replaces** legacy flat cards with 5 cohesive Liquid Glass blocks:
  1. **`HeroReadinessCockpitCard`:** 3 neon rings (`Відновлення`, `Навантаження`, `Адаптивні Калорії`) + **Self-Learning Status Pill** (`"Адаптивне ядро • \(confidencePct)% • BMR \(Int(learnedBmr)) ккал"`) + **1-Tap RPE Calibration Row** (`"Самопочуття: Нижче / Точно / Вище"`).
  2. **`OvernightVitalsCard`:** 5-pillar nocturnal corridor driven by the learned 60-day EWMA baseline.
  3. **`EnergyBankCard`:** 24h battery timeline driven by the learned `trimpBatteryDrainFactor`.
  4. **`SleepAndMetabolismBentoGrid`:** 2-column (or compact stacked glass) Bento layout combining **Архітектура Сну** (Deep/REM/Sleep Debt) and **Чистий NEAT & Адаптивний TDEE** (using `learnedBmrKcal` and `metabolicAdaptationKcal` instead of hardcoded `1750`).
  5. **`TodayWorkoutsGlassCard` & `CoachInsightBanner`:** Ukrainian glass session list and AI Coach drawer.

### 3.3. `TrendsView.swift` & `TrendsComponents.swift` (Segmented Analytics Hub)
* Adds a **Segmented Glass Category Switcher (`TrendsCategory`)** at the top of `TrendsView`:
  - `.adaptation` (**`"Адаптація"`**): New **`AdaptiveEngineStatusCard`** (displays learned TDEE, $\beta_{\text{Na}}$, $\beta_{\text{TRIMP}}$, Readiness weights, and Model Confidence) + `CorrelationInsightsCard`.
  - `.workload` (**`"Навантаження"`**): `ACWRWorkloadTrendCard`.
  - `.body` (**`"Тіло & Вага"`**): Redesigned Liquid Glass `WeightTrendCard` (Ukrainian labels + water spike badge).
  - `.cardio` (**`"Кардіо & ВНС"`**): Redesigned Liquid Glass `AutonomicTrendCard` & `AerobicEfficiencyTrendCard` (100% Ukrainian labels + `.lifecoreGlassCard()`).

### 3.4. `WorkoutsView.swift` & `NutritionView.swift` + `NutritionComponents.swift`
* **`WorkoutsView.swift`:** Navigation title `"Тренування"`, `.lifecoreGlassCard()` on every workout card and toggle bar, plus live **Banister TRIMP badge** (`TRIMP \(Int(trimp))`) computed on each row.
* **`NutritionView.swift` & `NutritionComponents.swift`:** Navigation title `"Харчування"`, `"Зміна доби о 04:00"`, `.lifecoreGlassCard()` on `MacroSummaryCard`, `DietaryQualityCard`, and meal rows. `MacroSummaryCard` connects to `AthleteProfileStore` + `AdaptivePhysiologyEngine` to display **Adaptive Target Kcal** and a **Tomorrow Water Retention Forecast Pill** based on today's sodium and learned $\beta_{\text{Na}\to\text{H2O}}$.
