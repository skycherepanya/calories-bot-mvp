# Lifecore 3.0 Specification: Advanced Physiological Engine, Overnight Vitals, Illness Prodrome Detection, Time-Lagged Correlations & UI 3.0 Redesign

> **Document Status:** Approved Architectural Specification (Phase 3)  
> **Date:** 2026-10-21  
> **Target Platform:** Native iOS (Swift 6, SwiftUI, Swift Charts, HealthKit, SwiftData) + Supabase PostgreSQL

---

## 1. Executive Summary & Objectives

**Lifecore 3.0 (Phase 3)** elevates the platform's deterministic mathematical core and visual interface to match and exceed leading sports science and digital health systems (**Garmin Firstbeat Analytics**, **Bevel 2.0**, **Stanford NightSignal**, and **Apple Watch Vitals**).

### Core Objectives:
1. **5-Metric Overnight Vitals & Hybrid RMSSD:** Expand HealthKit ingestion with `appleSleepingWristTemperature`, `oxygenSaturation` ($\text{SpO}_2$), `respiratoryRate`, `vo2Max`, and raw beat-to-beat `HKHeartbeatSeriesSample` to compute artifact-filtered $\text{RMSSD}$ with log-transformed 60-day Z-score normalization ($\ln\text{RMSSD}$ / $\ln\text{SDNN}$).
2. **Pre-Symptomatic Illness Prodrome Detection (NightSignal + Apple Vitals Confluence):** Deterministically distinguish standard post-workout sympathetic fatigue (1 outlier, normal temperature) from viral/inflammatory prodrome ($\ge 3$ nocturnal outliers or wrist temperature elevation $\Delta T \ge +0.40^\circ\text{C}$ paired with RHR/HRV/Respiratory shifts) 24–48 hours prior to overt symptoms.
3. **Garmin Firstbeat Workload & Energy Math:** Implement **Banister's Training Impulse (TRIMP)**, **Exponentially Weighted Moving Average (EWMA) Acute-to-Chronic Workload Ratio (ACWR)** ($7\text{d}$ vs $28\text{d}$, sweet spot $0.80\text{--}1.30$), **Continuous 24h Body Battery / Energy Bank (0–100%)**, and **Sleep Debt / Circadian Consistency**.
4. **Confounder-Controlled Time-Lagged Correlation Engine ($T+0, T+1, T+2$):** Automatically discover personal physiological patterns across multi-day lags using Point-Biserial ($r_{pb}$) and Pearson ($r$) correlations while filtering out high-strain workout confounders.
5. **Lifecore UI 3.0 (Liquid Glass Dark & Technical Debt Polish):** Introduce `LifecoreDesignSystem` (translucent glass cards, specular borders, semantic glow pills), `OvernightVitalsCard`, `EnergyBankCard`, `CorrelationInsightsCard`, `AthleteProfileStore` (eliminating hardcoded BMR/HR/Move constants), and bidirectional Supabase-to-SwiftData hydration.

---

## 2. Mathematical & Physiological Specifications

### 2.1. Beat-to-Beat RMSSD & Logarithmic Z-Score Normalization
Raw HRV values (ms) exhibit a right-skewed log-normal distribution. Furthermore, Apple Health's default `heartRateVariabilitySDNN` blends sympathetic and parasympathetic influences.
1. **Artifact-Filtered Beat-to-Beat RMSSD (`HKHeartbeatSeriesSample`):**
   - Extract consecutive nocturnal R-R intervals ($RR_i$ in ms) where `precededByGap == false` and $330\text{ ms} \le RR_i \le 2000\text{ ms}$.
   - **Kubios / Bevel 20% Ectopic Filter:** Reject successive pairs where $\frac{|RR_{i+1} - RR_i|}{RR_i} > 0.20$.
   - Compute Root Mean Square of Successive Differences:
     $$\text{RMSSD} = \sqrt{\frac{1}{N-1} \sum_{i=1}^{N-1} (RR_{i+1} - RR_i)^2}$$
   - **Fallback:** If overnight `HKHeartbeatSeriesSample` is unavailable on a given night, fall back to nocturnal `heartRateVariabilitySDNN`.
2. **Log-Transformed 60-Day Z-Score:**
   $$\ln(\text{HRV}_t), \quad \mu_{\ln, 60d} = \frac{1}{K}\sum_{k=1}^{K} \ln(\text{HRV}_k), \quad \sigma_{\ln, 60d} = \sqrt{\frac{1}{K}\sum_{k=1}^{K} (\ln(\text{HRV}_k) - \mu_{\ln, 60d})^2}$$
   $$Z_{\text{HRV}} = \frac{\ln(\text{HRV}_{\text{today}}) - \mu_{\ln, 60d}}{\max(0.06, \sigma_{\ln, 60d})}$$

---

### 2.2. 5-Metric Overnight Vitals Corridor & Illness Prodrome State Machine
Evaluates 5 nocturnal biomarkers against rolling personal baselines:

| Pillar | HealthKit Identifier | Warning Threshold | Outlier Threshold |
|---|---|---|---|
| **1. HRV** | `HKHeartbeatSeriesSample` / `.heartRateVariabilitySDNN` | $Z_{\text{HRV}} \le -0.85\sigma$ | $Z_{\text{HRV}} \le -1.35\sigma$ |
| **2. Sleeping RHR** | `.restingHeartRate` | $\Delta\text{RHR} \ge +2.8\text{ bpm}$ | $\Delta\text{RHR} \ge +4.5\text{ bpm}$ or $Z_{\text{RHR}} \ge +1.6\sigma$ |
| **3. Wrist Temp** | `.appleSleepingWristTemperature` | $\Delta T \ge +0.25^\circ\text{C}$ | $\Delta T \ge +0.40^\circ\text{C}$ |
| **4. Resp. Rate** | `.respiratoryRate` | $\Delta\text{RR} \ge +1.0\text{ br/min}$ | $\Delta\text{RR} \ge +1.8\text{ br/min}$ |
| **5. Blood Oxygen** | `.oxygenSaturation` | $\text{SpO}_2 < 96.0\%$ | $\text{SpO}_2 < 95.0\%$ or $\Delta\text{SpO}_2 \le -2.0\%$ |

#### Confluence Classification Rules (`ImmuneSystemState`):
* **`optimal` (0 outliers):** All 5 nocturnal pillars inside corridor. Full readiness.
* **`trainingFatigue` (1 outlier, $\Delta T < +0.30^\circ\text{C}$):** Isolated autonomic shift without thermal or respiratory anomaly. Classified as normal training adaptation or late-meal effect (Zero Medical Alarmism).
* **`immuneWatch` (2 outliers OR $[\Delta T \ge +0.30^\circ\text{C} \land \ge 1\text{ warning}]$):** Early systemic strain or mild dehydration. Recommends capping intensity at Zone 1/2 ($\le 135\text{ bpm}$).
* **`illnessProdrome` ($\ge 3$ outliers OR $[\Delta T \ge +0.40^\circ\text{C} \land (\text{RHR outlier} \lor \text{HRV outlier} \lor \text{RR outlier})]$):** High-probability viral prodrome or systemic inflammation signature. Proactively overrides training recommendations to complete rest, hydration, and recovery.

---

### 2.3. Banister TRIMP, EWMA ACWR & Continuous Body Battery
1. **Banister's Training Impulse (TRIMP):**
   $$\Delta\text{HR}_{\text{ratio}} = \frac{\text{HR}_{\text{avg}} - \text{HR}_{\text{rest}}}{\text{HR}_{\text{max}} - \text{HR}_{\text{rest}}}, \quad \text{TRIMP} = D_{\text{min}} \cdot \Delta\text{HR}_{\text{ratio}} \cdot 0.64 \cdot e^{1.92 \cdot \Delta\text{HR}_{\text{ratio}}}$$
2. **Exponentially Weighted Moving Average (EWMA) ACWR:**
   - Acute Load ($\lambda_a = 2 / (7 + 1) = 0.25$):
     $$L_{\text{acute}}(t) = \text{TRIMP}_t \cdot 0.25 + L_{\text{acute}}(t-1) \cdot 0.75$$
   - Chronic Load ($\lambda_c = 2 / (28 + 1) \approx 0.069$):
     $$L_{\text{chronic}}(t) = \text{TRIMP}_t \cdot \lambda_c + L_{\text{chronic}}(t-1) \cdot (1 - \lambda_c)$$
   - Ratio & Zones:
     $$\text{ACWR} = \frac{L_{\text{acute}}(t)}{\max(15.0, L_{\text{chronic}}(t))}$$
     - $< 0.80$: `undertraining`
     - $0.80\text{--}1.30$: `sweetSpot` (Optimal progressive overload)
     - $1.31\text{--}1.49$: `caution` (Rapid ramp rate)
     - $\ge 1.50$: `dangerSpike` (Overreaching / soft-tissue injury risk)
3. **Continuous 24h Energy Bank (Body Battery 0–100%):**
   - Morning wake reserve $E_{\text{wake}} = \text{clamp}(\text{round}(0.78 \cdot \text{RecoveryScore} + 22.0 \cdot \text{SleepRatio}), 25, 100)$.
   - Hourly drain from 07:00 to 23:00 combines basal circadian rhythm, Pure NEAT rate, workout TRIMP impulses at their exact hour, and an immune drain multiplier if `immuneState` is elevated.

---

### 2.4. Confounder-Controlled Time-Lagged Correlation Engine ($T+0, T+1, T+2$)
Computes statistical relationships across historical joined daily records (`DailyJoinedPhysiologyRecord`) when sample size $n \ge 6$:
1. **Sodium ($\text{mg}$) / `high_sodium` (Day $T$) $\to$ Morning Water Spike $\Delta W = W_{\text{raw}} - W_{7d}$ (Day $T+1$):** Pearson $r$ and mean kg water retention delta.
2. **Ultra-Processed / Late Meal after 21:30 (Day $T$) $\to$ Overnight HRV & RHR (Day $T+1$):** Point-Biserial $r_{pb}$ computed **exclusively on non-heavy training days ($\text{TRIMP}_T \le 130$)** to eliminate high-strain confounding.
3. **Pre-Workout 24h Carbohydrate Intake ($\text{g}$) (Day $T-1$) $\to$ Running Cardiac Drift % & Efficiency Factor (Day $T$):** Evaluates glycogen protection against late-run heart rate decoupling.
4. **Whole Food Ratio ($\ge 80\%$) & Leucine ($\ge 3\text{g}$) (Day $T$) $\to$ Deep Sleep & HRV Recovery Velocity (Day $T+1$).**

---

## 3. UI 3.0 Redesign & Technical Debt Resolution

1. **Liquid Glass Dark Design System (`LifecoreDesignSystem.swift`):**
   - Replaces flat dark cards with translucent layered surfaces, 1px top-edge specular gradient strokes, animated status pills, and smooth numeric transitions.
2. **`AthleteProfileStore` & `AthleteProfileSheet`:**
   - Centralizes all physiological and nutritional constants (Weight, Height, Age, Max HR, RHR/HRV/Temp/SpO2/Resp baselines, BMR, Active Move Goal, Daily Kcal/Macro targets, and HRV method toggle `hybridRMSSD` vs `appleSDNN`).
3. **Two-Way Cloud Hydration (`SupabaseSyncService.pullHistoricalDataIfNeeded()`):**
   - Restores historical `meals` and `workout_analyses` from Supabase PostgreSQL into local `SwiftData` on fresh installs.
4. **New UI 3.0 Components:**
   - **TodayView 3.0:** Adds `OvernightVitalsCard` (5-metric Apple Vitals corridor + Illness Prodrome Radar banner), `EnergyBankCard` (24h Body Battery curve + Sleep Debt), and ACWR status badge on Strain ring.
   - **TrendsView 3.0:** Adds `CorrelationInsightsCard` (ranked personal habits/nutrition impacts with $r$ and time-lag badges) and `ACWRWorkloadTrendCard` (Acute vs Chronic EWMA curves with $0.8\text{--}1.3$ sweet-spot band).
