# Lifecore: Project Overview & Brainstorming Blueprint (v3.1)

> **Document Purpose:** High-density, self-contained architectural and physiological overview of the **Lifecore** platform. Authored specifically for rapid context ingestion, high-level ideation, architectural critique, and brainstorming with advanced AI models.

---

## 1. Executive Summary & Vision

* **What is Lifecore?**  
  **Lifecore** is an elite, native **iOS-First Quantified Self & Athletic Performance Platform**. Built with **Swift 6, SwiftUI, Swift Charts, HealthKit, SwiftData, and Supabase PostgreSQL**, it combines high-frequency autonomic biometrics from the Apple Watch, frictionless computer-vision nutrition tracking, deterministic sports physiology mathematics, and Google Gemini AI.

* **Core Problem Solved:**  
  Commercial wearable platforms enforce fragmented vendor lock-in:
  - **Whoop / Oura:** Charge recurring monthly subscriptions, operate black-box algorithms, and lack split-level workout pacing dynamics.
  - **Strava:** Focuses on social feeds and basic GPS splits, but ignores circadian recovery, sleep stages, and nutrition.
  - **MyFitnessPal:** Plagued by ads, tedious search flows, and inaccurate caloric estimates that ignore cooking state and hidden fats.
  - **Generic AI Chatbots:** Act like "anxious therapists" (e.g. screaming "STOP TRAINING!" if resting heart rate rises by 3 bpm).

* **The Lifecore Solution:**  
  A unified, private, on-device platform that reads canonical Apple HealthKit telemetry in <5ms, runs clinical-grade deterministic math natively in Swift, provides a 5-second camera meal logging pipeline, and deploys Gemini as an objective **Athletic Performance Analyst (70% workout telemetry / 15% historical benchmarks / 15% physiological root causes & actionable 24h plan)**.

---

## 2. Core Architectural Principles

1. **Local-First & HealthKit as Ground Truth:**  
   Apple Health on iOS is the canonical source of truth for all passive biometric data (continuous heart rate, R-R intervals, sleep stages, wrist temperature, steps, workouts). No intermediate third-party servers are required for daily operations.
2. **Deterministic Math Before AI Synthesis:**  
   Zero arithmetic, baseline corridor modeling, or statistical correlations are delegated to the LLM. Swift executes 100% of the mathematical calculations; Gemini is fed pre-calculated, verified metrics strictly for qualitative athletic reasoning.
3. **Self-Learning Adaptive Physiology (Phase 3.1):**  
   The system continuously learns the user's specific biology through Bayesian shrinkage, dynamic energy expenditure tracking (MacroFactor-style), and online Ridge regression for individual habit sensitivities.
4. **Guaranteed Deficit Discipline (+12.5%):**  
   To safeguard caloric deficit during fat loss, all food calories are multiplied by $\times 1.125$ to buffer against hidden cooking oils and portion variance.
5. **04:00 AM Dietary Day Shift:**  
   The physiological day resets at 04:00 AM (`shiftHours = 4`). Post-midnight snacks, workouts, and sleep cycles belong to the preceding day's biological cycle.
6. **Bidirectional Dietary Synchronization:**  
   Logged meals write back directly to Apple HealthKit with unique metadata keys (`LifecoreMealID`). In-place deletion and undo restoration maintain strict parity across local SwiftData, Apple Health, and Supabase.

---

## 3. High-Leverage Mathematical & Physiological Engines

All engines are authored in Swift 6 concurrency under `Lifecore/Core/MathEngine/`:

### 3.1. 5-Metric Overnight Vitals & Pre-Symptomatic Illness Radar (`VitalsAndIllnessEngine.swift`)
* **Biomarkers Captured Passively (Overnight):**
  1. **Beat-to-Beat HRV:** Raw `HKHeartbeatSeriesSample` parsed through a Kubios-style 20% ectopic beat artifact filter to derive $\text{RMSSD}$, falling back to log-transformed $\ln(\text{SDNN})$:
     $$Z_{\text{HRV}} = \frac{\ln\text{HRV}_t - \mu_{\ln, 60d}}{\max(0.06, \sigma_{\ln, 60d})}$$
  2. **Sleeping RHR:** Nocturnal heart rate baseline.
  3. **Sleeping Wrist Temperature ($\Delta T^\circ\text{C}$):** Basal skin temperature deviation from baseline.
  4. **Sleeping Respiratory Rate:** Overnight breaths per minute.
  5. **Blood Oxygen ($\text{SpO}_2\%$):** Overnight arterial oxygen saturation.
* **Stanford NightSignal + Apple Vitals Confluence State Machine:**
  - `optimal` (0 outliers): Full recovery.
  - `trainingFatigue` (1 outlier, $\Delta T < +0.30^\circ\text{C}$): Standard training adaptation. **Zero medical alarmism.**
  - `immuneWatch` (2 outliers OR $[\Delta T \ge +0.30^\circ\text{C} \land \ge 1\text{ warning}]$): Early systemic strain; cap intensity at Zone 1/2.
  - `illnessProdrome` ($\ge 3$ outliers OR $[\Delta T \ge +0.40^\circ\text{C} \land (\text{RHR} \lor \text{HRV} \lor \text{RR outlier})]$): High-confidence viral prodrome detection 24–48h before clinical symptoms appear.

### 3.2. Garmin Firstbeat Workload Math & Energy Bank (`TrainingLoadAndBatteryEngine.swift`)
* **Banister TRIMP:** Exponential internal cardiovascular load:
  $$\Delta\text{HR}_r = \frac{\text{HR}_{\text{avg}} - \text{HR}_{\text{rest}}}{\text{HR}_{\text{max}} - \text{HR}_{\text{rest}}}, \quad \text{TRIMP} = D_{\text{min}} \cdot \Delta\text{HR}_r \cdot 0.64 \cdot e^{1.92 \cdot \Delta\text{HR}_r}$$
* **EWMA ACWR (Acute-to-Chronic Workload Ratio):**
  - Acute Load (7d fatigue, $\lambda_a = 2/8 = 0.25$): $L_{\text{acute}}(t) = 0.25 \cdot \text{TRIMP}_t + 0.75 \cdot L_{\text{acute}}(t-1)$
  - Chronic Load (28d fitness, $\lambda_c = 2/29 \approx 0.069$): $L_{\text{chronic}}(t) = \lambda_c \cdot \text{TRIMP}_t + (1 - \lambda_c) \cdot L_{\text{chronic}}(t-1)$
  - Sweet spot: $0.80 \le \text{ACWR} \le 1.30$ (progressive overload without injury spike).
* **Continuous 24h Body Battery (0–100%):**
  Recharges overnight based on vagal tone ($\ln\text{RMSSD}$) and Deep/REM sleep efficiency; drains hourly during the day based on circadian baseline, Pure NEAT rate, workout TRIMP, and immune strain.

### 3.3. Self-Learning Adaptive Physiology Engine (`AdaptivePhysiologyEngine.swift` — Phase 3.1)
Four dynamic feedback loops that continuously personalize the app:
1. **Bayesian Shrinkage:** Blends athlete priors with empirical biometrics ($w_N = \frac{N}{N + 14}$) and outputs a live model confidence score (0–99%).
2. **MacroFactor Dynamic TDEE & Adaptive BMR:** Determines true expenditure by comparing 14-day smoothed weight slopes ($\Delta W_{\text{trend}} \times 7700\text{ kcal/kg}$) with logged intake and isolated Pure NEAT.
3. **Online Ridge OLS $\beta$-Sensitivities:** Quantifies individual response slopes:
   - $\beta_{\text{Na}\to\text{H2O}}$: Scale water weight spike per 1g sodium above baseline.
   - $\beta_{\text{TRIMP}\to\text{Battery}}$: Hourly energy drain per TRIMP unit.
   - $\beta_{\text{LateMeal}\to\text{RHR}}$: Overnight resting heart rate penalty (+bpm) from meals after 21:30.
   - $\beta_{\text{Carbs}\to\text{Drift}}$: Aerobic decoupling / cardiac drift reduction per 100g pre-run carbohydrates.
4. **60d EWMA Corridors & 1-Tap RPE Calibration:** Simplex weight adjustment on `ReadinessWeightVector` when subjective athlete check-in diverges from calculated readiness.

### 3.4. Running Pacing & Decoupling Telemetry (`WorkoutMathEngine.swift`)
* **1km Auto-Splits:** Slices workout telemetry into exact 1000m windows (pace, avg HR, max HR, elevation $\Delta h$, cadence).
* **Efficiency Factor ($EF$) & Cardiac Drift %:**
  $$EF = \frac{\text{Speed (m/min)}}{\text{Average HR (bpm)}}, \quad \text{Drift } (\%) = \left(\frac{EF_{\text{half 1}} - EF_{\text{half 2}}}{EF_{\text{half 1}}}\right) \times 100\%$$
* **Pure NEAT Isolation:**
  $$\text{NEAT}_{\text{kcal}} = \max(0, \text{daily\_active\_kcal} - \sum \text{workout\_kcal})$$

### 3.5. Time-Lagged Multi-Day Correlations (`CorrelationEngine.swift`)
* Computes Point-Biserial ($r_{pb}$) and Pearson ($r$) correlations across $T+0, T+1, T+2$ days.
* Filters out high-TRIMP days ($\text{TRIMP} > 130$) to isolate nutritional impacts (sodium, late meals, alcohol, UPF) from physical exercise exhaustion.

---

## 4. UI/UX Architecture: Liquid Glass Bento Cockpit

The app employs an ultra-modern **Liquid Glass Dark (UI 3.1)** design system built in SwiftUI (`LifecoreDesignSystem.swift`):
- Translucent dark glass surfaces with 1px specular top-edge gradient highlights.
- Semantic glow status pills (green, yellow, red, orange, purple).
- **Four Dedicated Tabs:**
  1. **`Сьогодні` (Today):** Hero Cockpit, `AdaptiveEngineBadgeBar` (live confidence % & learned BMR), `RPEQuickCalibrationRow` (1-tap feedback), interactive Readiness & Strain rings, 5-Pill Overnight Vitals bar, Illness Prodrome Radar banner, 24h Body Battery curve, Sleep Architecture Bento, and Pure NEAT card.
  2. **`Тренування` (Workouts):** Activity filters (Running, Strength, Cycling, HIIT), live Banister TRIMP badges, granular 1km auto-splits and interval laps, synchronized Swift Charts (pace, HR, elevation profile), and the AI Coach Report.
  3. **`Харчування` (Nutrition):** Daily macro summary with +12.5% buffer indicator, Whole Food vs Ultra-Processed ratio, Tomorrow Sodium Water Retention Forecast, gesture-driven swipe-to-delete with in-place confirmation, and two-tier zero-lag input modal (`FoodInputSheet`).
  4. **`Тренди` (Trends):** Segmented Glass Switcher (`Адаптація`, `Навантаження`, `Тіло & Вага`, `Кардіо & ВНС`), Adaptive Engine Status card, 7d/14d rolling body weight averages (water noise filter), 30d/60d autonomic envelopes, and the Time-Lagged Correlations Hub.

---

## 5. Verification & Testing Infrastructure

* **11/11 Mathematical Verification Suites (`MathEngineVerification.swift`):**  
  Standalone, deterministic verification suite covering 1km splits, EF, cardiac drift, Pure NEAT, rolling weights, recovery score, SwiftData models, Overnight Vitals, TRIMP/ACWR/Body Battery, time-lagged correlations, and adaptive physiology.
* **Maestro E2E Testing Suite (`.maestro/`):**  
  High-leverage, deterministic UI automation tests verifying state persistence, modal dismissals, and calculations directly in the iOS simulator:
  - `01_profile_and_readiness.yaml`: Today cards & athlete profile calibration.
  - `02_nutrition_logging_and_undo.yaml`: Fast food preset logging & undo toast.
  - `03_workout_filtering_and_refresh.yaml`: Athletic category filters & telemetry refresh.
  - `04_trends_adaptive_analytics.yaml`: Analytical tabs & adaptive engine rendering.
  - `scripts/run_e2e.sh`: 1-command build, simulator setup, and automated execution.
  - `.github/workflows/e2e.yml`: Automated CI workflow on macOS.

---

## 6. Strategic Horizons & Brainstorming Prompts (For AI Partner)

Use these topics to guide discussions, feature ideation, and architectural enhancements:

1. **WidgetKit & Live Activities (Phase 3.7):**  
   - What is the optimal data hierarchy for a Lock Screen widget (Readiness score vs Vitals Prodrome pill vs Energy Bank %)?  
   - How can an interactive Dynamic Island or Live Activity track real-time cardiac drift or aerobic decoupling during active outdoor workouts?

2. **Native watchOS Companion App (Phase 4.2):**  
   - Should the Apple Watch app run independent workout sessions with live audio feedback (e.g., alert when aerobic decoupling exceeds 5%), or act primarily as a passive glanceable complications provider?

3. **Smart Scale & Body Composition Hardware (Phase 4.1):**  
   - How should multi-frequency bioimpedance data (extracellular water vs lean mass) integrate with the Adaptive Physiology Engine to further isolate glycogen/sodium water spikes from adipose changes?

4. **Predictive Performance & Event Taper Modeling:**  
   - How can we extend Banister TRIMP and EWMA ACWR into forward-looking simulations to prescribe the exact mileage reduction taper for an athlete targeting a marathon PB on a specific race date?

5. **Dynamic Nutrition Prescriptions:**  
   - Instead of static caloric goals, how can the AI Coach prescribe dynamic pre-run carbohydrate timing and quantities based on the scheduled workout's estimated TRIMP and the athlete's personal $\beta_{\text{Carbs}\to\text{Drift}}$ coefficient?

---

*Lifecore — Engineered for high-performance quantified endurance athletes.*
