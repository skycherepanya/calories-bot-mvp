# Lifecore project knowledge

Updated: 2026-11-12. Current implementation is summarized in Section 3; source and checked-in migrations are authoritative. Historical algorithm descriptions below express intended behavior, not proof of correct integration, clinical validity or measured performance. Read the [audit](docs/audits/2026-11-12-architecture-and-product-audit.md) before implementation.

## 1. High-Level Vision & Architecture

* **Project Name:** Lifecore (Native iOS-First Quantified Self & Athletic Performance Platform)
* **Repository:** `calories-bot-mvp` (planned rename to `lifecore`)
* **Core Philosophy:** Personal on-device health and athletic intelligence platform. Lifecore combines continuous physiological telemetry from Apple Watch (Apple HealthKit), frictionless vision-based nutrition tracking, deterministic Swift telemetry math, and an elite AI Athletic Performance Analyst presented in an Apple Health & Bevel Daylight visual system (`Lifecore v3.3`).

### Core Architectural Principles:

1. **iOS-First, On-Device Architecture:** The primary user interface and processing engine is a native iOS application (`ios/Lifecore/`) built with Swift (current language mode 5.0), SwiftUI, Swift Charts, HealthKit, and SwiftData.
2. **Deterministic Math Engine vs AI Reasoning:** All mathematical calculations (1km splits, pace, cardiac drift, aerobic decoupling %, NEAT isolation, rolling averages, caloric buffers) are executed deterministically in Swift. The LLM (Gemini) is reserved strictly for qualitative synthesis, athletic pattern recognition, and causal explanation.
3. **HealthKit as Canonical Local Source of Truth:** Apple Health is the ground truth for all passive telemetry (continuous heart rate, sleep architecture, HRV SDNN, resting heart rate, steps, and workout sessions). All split-level workout data is parsed directly from HealthKit on-device without third-party API dependencies.
4. **Cloud Backup & Long-Term Storage (Supabase):** PostgreSQL in Supabase serves as a cloud persistence, backup, and historical synchronization warehouse.
5. **Frictionless Nutrition Logging:** Camera/photo food capture and estimated portions/macros. The required native +12.5% calorie buffer is not enforced in the live AI path; R5a repairs it. Capture latency is not verified.
6. **Athletic Coach (70 / 15 / 15):** The AI Coach is an elite endurance coach and athletic performance analyst, NOT a generic medical wellness bot. It focuses on how workouts were executed and uses biometric recovery only to explain performance deltas.

---

## 2. Domain Core & Physiological Math

### 2.1. Daily Weight "Water Noise" vs Real Trend

Raw daily weight reflects water balance fluctuations, not acute fat/muscle changes:

- **Glycogen Water Binding:** 1g of stored glycogen holds ~3–4g of water. A carbohydrate-dense day immediately causes a 1–2 kg weight spike on the scale, representing water, not adipose tissue.
- **Muscle Micro-Inflammation:** Intense endurance running or resistance training triggers local muscle micro-tears, causing fluid retention for 24–72 hours during repair.
- **Cortisol & Stress Response:** Caloric restriction, poor sleep, or high training load elevates cortisol, triggering antidiuretic fluid retention in kidneys.
- **Deterministic Solution:** Calculate a **7-day and 14-day rolling average** in the Swift engine to smooth water noise and track genuine body composition trends.

---

### 2.2. Macronutrient Quality & Absorption Kinetics

A calorie is not a homogeneous unit of energy:

- **Thermic Effect of Food (TEF):** Protein 20–30%, Carbohydrates 5–10%, Fats 0–3%. High-protein whole foods consume significant energy simply during digestive breakdown.
- **Absorption Kinetics:** Ultra-processed and liquid foods trigger sharp glycemic excursions and premature rebound hunger. Whole, solid foods sustain steady gastric emptying and long-term satiety.
- **Food Quality Taxonomy:**
  - `whole_food` — minimally processed, nutrient-dense (eggs, potatoes, lean meat, vegetables)
  - `ultra_processed` — industrial snacks, refined sweets, cured sausages, fast food
  - `solid` / `liquid` — physical structure affecting satiety kinetics
  - `fast_absorbing` / `slow_absorbing` — glycemic speed
  - `high_sodium` — induces osmotic water retention for 24–48 hours

---

### 2.3. Athletic Telemetry Math (Running & Workouts)

All running metrics are computed deterministically in the on-device Swift engine before being surfaced to UI charts or AI prompts:

1. **Kilometer Splits:**
   - Every workout is segmented into 1-kilometer increments:
     - `pace_min_km`: decimal minutes per km (e.g. $5.75 = 5:45\text{ min/km}$).
     - `avg_heart_rate`: average bpm within that kilometer window.
     - `elevation_diff_m`: elevation delta ($\Delta h = h_{\text{end}} - h_{\text{start}}$) capturing climbs and descents.
2. **Aerobic Decoupling & Cardiac Drift:**
   - Evaluates cardiovascular efficiency over time:
     $$
     \text{Efficiency Factor } (EF) = \frac{\text{Speed (m/min)}}{\text{Average Heart Rate (bpm)}}
     $$
   - **Cardiac Drift Percentage:**
     $$
     \text{Drift } (\%) = \left(\frac{EF_{\text{first half}} - EF_{\text{second half}}}{EF_{\text{first half}}}\right) \times 100\%
     $$
   - **Interpretation:**
     - $<5\%$: Superior aerobic conditioning, stable cardiac output.
     - $>5\text{--}8\%$: Aerobic decoupling (indicates dehydration, glycogen depletion, overheating, or autonomic fatigue).
3. **Lifestyle Activity & NEAT Isolation:**
   - Apple Health `active_kcal` is aggregate for the entire day and **already includes** formal workout calories.
   - Pure NEAT (lifestyle movement) is mathematically isolated:
     $$
     \text{NEAT}_{\text{kcal}} = \max(0, \text{daily\_active\_kcal} - \sum \text{workout\_kcal})
     $$

---

### 2.4. 5-Metric Overnight Vitals & Illness Prodrome Detection (Apple Vitals + Stanford NightSignal)

Key nocturnal biomarkers captured passively by Apple Watch:

| Biomarker                                                | HealthKit Identifier                                        | Physiological Role                                                       | Outlier Criterion (60d Corridor)                                              |
| -------------------------------------------------------- | ----------------------------------------------------------- | ------------------------------------------------------------------------ | ----------------------------------------------------------------------------- |
| **HRV (RMSSD / SDNN)**                             | `HKHeartbeatSeriesSample` / `.heartRateVariabilitySDNN` | Vagal parasympathetic tone (20% ectopic beat filter + $\ln$ transform) | $Z_{\text{HRV}} \le -1.35\sigma$                                            |
| **Sleeping RHR (bpm)**                             | `.restingHeartRate`                                       | Nocturnal cardiac baseline (~49 bpm)                                     | $\Delta\text{RHR} \ge +4.5\text{ bpm}$ or $Z_{\text{RHR}} \ge +1.6\sigma$ |
| **Wrist Temperature ($\Delta T^\circ\text{C}$)** | `.appleSleepingWristTemperature`                          | Nocturnal thermoregulation & immune response                             | $\Delta T \ge +0.40^\circ\text{C}$ (Warning at $+0.25^\circ\text{C}$)     |
| **Respiratory Rate (br/min)**                      | `.respiratoryRate`                                        | Sleeping ventilation effort (~14.2 br/min)                               | $\Delta\text{RR} \ge +1.8\text{ br/min}$                                    |
| **Blood Oxygen ($\text{SpO}_2\%$)**              | `.oxygenSaturation`                                       | Nocturnal capillary oxygenation (~98%)                                   | $\text{SpO}_2 < 95.0\%$ or $\Delta\text{SpO}_2 \le -2.0\%$                |
| **Sleep Architecture**                             | `.sleepAnalysis`                                          | Deep (cellular repair) & REM (neural recovery)                           | $< 1.2\text{h}$ Deep or $< 1.5\text{h}$ REM                               |

#### Logarithmic HRV Normalization:

$$
\text{RMSSD} = \sqrt{\frac{1}{N-1}\sum_{i=1}^{N-1}(RR_{i+1}-RR_i)^2}, \quad Z_{\text{HRV}} = \frac{\ln(\text{HRV}_{\text{today}}) - \mu_{\ln, 60d}}{\max(0.06, \sigma_{\ln, 60d})}
$$

#### Multi-Metric Confluence State Machine (`ImmuneSystemState`):

* **`optimal` (0 outliers):** Full autonomic readiness.
* **`trainingFatigue` (1 outlier, $\Delta T < +0.30^\circ\text{C}$):** Normal day-to-day training adaptation or late-meal residue. Zero sickness alarm.
* **`immuneWatch` (2 outliers OR $[\Delta T \ge +0.30^\circ\text{C} \land \ge 1\text{ warning}]$):** Early systemic strain; cap intensity at Zone 1/2 ($\le 135\text{ bpm}$).
* **`illnessProdrome` ($\ge 3$ outliers OR $[\Delta T \ge +0.40^\circ\text{C} \land (\text{RHR} \lor \text{HRV} \lor \text{RR outlier})]$):** High-confidence viral/inflammatory prodrome signature 24–48h prior to clinical symptoms. Proactively overrides daily directive to rest and hydration.

---

### 2.5. Internal Workload (Banister TRIMP, EWMA ACWR) & Continuous Energy Bank (Garmin Firstbeat)

1. **Banister's Training Impulse (TRIMP):**
   $$
   \Delta\text{HR}_r = \frac{\text{HR}_{\text{avg}} - \text{HR}_{\text{rest}}}{\text{HR}_{\text{max}} - \text{HR}_{\text{rest}}}, \quad \text{TRIMP} = D_{\text{min}} \cdot \Delta\text{HR}_r \cdot 0.64 \cdot e^{1.92 \cdot \Delta\text{HR}_r}
   $$
2. **Exponentially Weighted Moving Average (EWMA) ACWR:**
   - Acute Load (7d fatigue, $\lambda_a = 2/8 = 0.25$): $L_{\text{acute}}(t) = 0.25 \cdot \text{TRIMP}_t + 0.75 \cdot L_{\text{acute}}(t-1)$
   - Chronic Load (28d fitness, $\lambda_c = 2/29 \approx 0.069$): $L_{\text{chronic}}(t) = \lambda_c \cdot \text{TRIMP}_t + (1 - \lambda_c) \cdot L_{\text{chronic}}(t-1)$
   - Workload Ratio: $\text{ACWR} = L_{\text{acute}} / \max(15.0, L_{\text{chronic}})$
     - **Sweet Spot:** $0.80 \le \text{ACWR} \le 1.30$ (optimal progressive overload without injury risk).
     - **Danger Zone:** $\text{ACWR} \ge 1.50$ (rapid load spike / soft-tissue injury risk).
3. **Continuous 24h Body Battery / Energy Bank (0–100%):**
   - Charges overnight via vagal tone ($Z_{\text{HRV}}$) and sleep architecture; drains hourly from 07:00 to 23:00 via basal circadian rhythm, Pure NEAT rate, workout TRIMP impulses, and immune strain multiplier.

---

### 2.6. Confounder-Controlled Time-Lagged Correlation Math ($T+0, T+1, T+2$)

* **Point-Biserial ($r_{pb}$) & Pearson ($r$) Lag Matrix:**
  - **Sodium ($\text{mg}$) / `high_sodium` (Day $T$) $\to$ Scale Water Spike $\Delta W = W_{\text{raw}} - W_{7d}$ ($T+1, T+2$):** Quantifies individual extracellular fluid retention sensitivity.
  - **Late Meal ($>21:30$) / `ultra_processed` (Day $T$) $\to$ Overnight HRV & RHR ($T+1$):** Computed strictly on non-heavy workout days ($\text{TRIMP}_T \le 130$) to prevent training fatigue confounding.
  - **Pre-Workout 24h Carbohydrates ($\text{g}$) (Day $T-1$) $\to$ Running Cardiac Drift % & Efficiency Factor ($EF$) (Day $T$).**

---

### 2.7. Self-Learning Adaptive Physiology Engine (Lifecore v3.1)

* **Bayesian Shrinkage ($w_N = \frac{N}{N + 14}$):** Smoothly blends athlete priors (`AthleteProfile`) with empirical personal parameters as historical days $N$ accumulate, reporting live `confidencePct` (0–99%).
* **MacroFactor-Style Adaptive Metabolism (`computeDynamicTDEE`):** Continuously recalibrates effective BMR and TDEE from 14-day exponentially smoothed weight slope ($\Delta W_{\text{trend}} \times 7700\text{ kcal/kg}$) against logged caloric intake and isolated Pure NEAT.
* **Online Ridge OLS $\beta$-Sensitivities:** Learns personal response slopes: $\beta_{\text{Na}\to\text{H2O}}$ (kg water per 1g sodium), $\beta_{\text{TRIMP}\to\text{Battery}}$ (hourly drain factor), $\beta_{\text{LateMeal}\to\text{RHR}}$ (+bpm overnight penalty), and $\beta_{\text{Carbs}\to\text{Drift}}$ (% cardiac drift per 100g carbs).
* **60d EWMA Corridors & 1-Tap RPE Weight Calibration:** Updates nocturnal Vitals baselines via 60-day EWMA and adjusts `ReadinessWeightVector` via bounded simplex steps when subjective RPE feedback diverges from predicted Readiness.

---

### 2.8. Deterministic Adaptive Training Prescription Engine (Lifecore v3.2)

* **Inverse EWMA ACWR Load Budgeting:** Computes daily target $\text{TRIMP}_{\text{budget}} \in [0, 160]$ to maintain progressive overload ($R_{\text{target}} = 1.08$) without injury spikes.
* **3-Gate Physiological Override State Machine:** Modulates target TRIMP and intensity ceiling via Overnight Vitals (`ImmuneSystemState`), Morning Body Battery ($<40\%$), 3-day caloric deficit ($< -650\text{ kcal/day}$), and median 3-run Cardiac Drift % vs $\Delta EF_{30d}$.
* **Dynamic $EF_{75}$ Pace & HR Zone Derivation:** Automatically derives target paces ($\text{sec/km}$) and HR caps for Zones 1–5 from the athlete's 30-day rolling 75th percentile Efficiency Factor ($EF_{75}$) and Heart Rate Reserve ($\text{HRR}$).
* **4-Archetype Rolling Stimulus Queue:** Cycles through `aerobicBasePlusStrides`, `cruiseThresholdIntervals`, `recoveryFlush`, and `progressiveQualityLongRun`, deferring quality sessions non-destructively when fatigued and prescribing pre-run carbohydrates ($\beta_{\text{Carbs}\to\text{Drift}}$).

---

### 2.9. Hierarchical Health RAG & Multi-Layered Conversational Analyst (Lifecore v3.4)

* **Effort-Normalized Benchmark Regimes (`BenchmarkRegime`):** Solves effort-blind benchmark comparisons. When an athlete runs $-89.7\text{ s/km}$ faster at $+27.0\text{ bpm}$ higher HR, the engine classifies it as `.higherIntensityEffort` (working in a higher aerobic/threshold zone with efficiency assessment) rather than misinterpreting it as low-effort aerobic gain (`.trueAerobicGain`).
* **3-Tier Context Graph (`LifecoreContextRAG.swift`):**
  - **Tier L1 (Acute 48h Slice):** Split telemetry, 48h meals (calories, carbs, protein, fat, sodium, late meal timing), overnight Vitals corridor, and Body Battery.
  - **Tier L2 (Mesocycle 30d Dossier):** EWMA ACWR, $EF_{75}$, learned $\beta$-sensitivities ($\beta_{\text{Carbs}\to\text{Drift}}$, $\beta_{\text{LateMeal}\to\text{RHR}}$, $\beta_{\text{Na}\to\text{H2O}}$), and tactical prescription queue.
  - **Tier L3 (Episodic Memory RAG):** SwiftData `AthleteMemoryEntity` ranked via deterministic Hybrid BM25 ($0.45$) + Tag Overlap ($0.35$) + 21-day Recency Decay ($0.20$, $\lambda = \frac{\ln 2}{21.0}$) algorithm.
* **Structured Hallmark Daylight Debrief (`StructuredWorkoutDebrief`):** Eliminates raw Markdown `###` and emojis. Renders native Hallmark Daylight cards with tabular metric pills, execution analysis ($70\%$), benchmark dynamics ($15\%$), and root cause + 24h actionable directive ($15\%$).
* **Conversational Analyst (`LifecoreIntelligenceChatView.swift`):** Bevel Intelligence-style multi-turn chat accessible from `WorkoutDetailView` and `TodayView` that quotes exact dossier metrics and automatically extracts new athlete facts (`extractedMemoryFactUk`) into episodic memory.

---

### 2.10. Dietary Date Convention

* The dietary day shifts at **04:00 AM** (`shiftHours = 4`), not midnight.
* Meals and post-midnight workouts before 04:00 belong to the previous dietary day by project convention. Current workout queries are inconsistent; R2/R3 correct them. Sleep requires its own bounded episode and explicit attribution.

---

## 3. Current Implementation (audited 2026-11-12)

### 3.1. Platform and component boundaries

Project: `ios/Lifecore/Lifecore/Lifecore.xcodeproj`. Source: `ios/Lifecore/Lifecore/Lifecore/`. Deployment floor: iOS 27.0. Language mode: Swift 5.0. Verified toolchain: Xcode 27.1. Swift 6 migration is a proposed explicit gate.

- `App/`: lifecycle, Debug verification logging, four-tab shell, forced-light appearance.
- `Core/HealthKit/`: queries and workout extraction. Missing/sparse data can currently trigger synthetic fallbacks; episode freshness and split start timing need correction.
- `Core/MathEngine/`: deterministic readiness, workouts, vitals, workload/battery, correlations, adaptive physiology and prescription. Several production call sites supply fabricated or incomplete inputs.
- `Core/Storage/`: SwiftData meals, workout analyses, training plan and athlete memories; UserDefaults profile; direct Supabase REST. Save failures can be hidden; no durable revisioned outbox exists.
- `Core/AI/`: food/report/chat provider, prompts and RAG. Nutrition buffer/validation, fabricated fallback responses and mislabeled evidence windows are open defects.
- `Core/UI/` and `Features/`: Daylight style and Today/Workouts/Nutrition/Trends. Views currently perform independent queries/history joins; prescriptions can disagree between tabs.
- `Intents/`: food and sync entry points; failure dialogs/durable retry require repair.

### 3.2. Verification evidence

Baseline `3e6b998` builds for iOS Simulator with Xcode 27.1, with actor-isolation/deprecation warnings. `xcodebuild test` exits 66: scheme lacks a test action. Thirteen Debug startup verification groups only print results; they are not an enforced test suite. Five Maestro flows mostly check visibility/navigation, not persistent outcomes. Shell syntax check passed. Isolated Swift probes reproduced specific math/decoder defects; see the audit. No new simulator visual, device, clinical or production database verification was performed.

### 3.3. Persistence and cloud limitations

Current cloud behavior is upload plus capped empty-store hydration (60 meals/30 analyses), not complete bidirectional convergence. Workout restore keys do not match uploaded SQL fields; optional meal metadata is lost. Meal retries lack a stable remote conflict key, deletions lack tombstones, and old acknowledgments can clear newer dirty data. Persistent-store initialization can fall back to memory, and legacy migration can discard its backup after save failure.

The application includes a reversible bundled AI credential and shared cloud identity. Values must not be copied into documentation. A publishable Supabase key is public configuration; deployed authorization policies remain unverified. See R6–R8 and [database reference](docs/DATABASE.md).

### 3.4. Redesign status and execution

The user selected calm native iOS with clear hierarchy and minimal noise. The [design spec](docs/superpowers/specs/2026-11-12-native-redesign-design.md) and [20-task execution plan](docs/superpowers/plans/2026-11-12-native-redesign.md) are complete planning artifacts, not implemented features. Tasks establish tests/contracts, repair data and persistence, then migrate each screen and perform release verification. Existing engines remain native; no backend rewrite is proposed. Only verified tasks may be marked complete.

Legacy Telegram code remains archived in `v1.0-telegram-archive`; dual-backend maintenance is not part of the active architecture.

## 4. Cloud Database Schema

Use [docs/DATABASE.md](docs/DATABASE.md) and `supabase/migrations/` instead of duplicated illustrative DDL. Checked-in schema and deployed state are distinct; no migration was applied during this audit.

Known mismatches: `weight_g` is NOT NULL in SQL but optional locally; SQL confidence convention is 0–100; `daily_metrics` uniqueness is `(user_id, metric_date)` and sleep uniqueness is `(user_id, sleep_date)`. No checked-in migration defines `neat_kcal`, although the client uploads it. Numbered migrations alter `daily_metrics` before its timestamped creation file on a fresh sequential replay. R7 must reconcile migration history and DTOs without rewriting already-applied versions blindly.

---

## 5. AI Prompt Engineering Specifications

### 5.1. Food Recognition Prompt Rules (Vision Model)

* **System Prompt Language:** Authored in high-density English (Token Economy).
* **User Output Language:** Meal names and descriptions returned in Ukrainian.
* **Deficit Buffer (+12.5%):** Strictly calculate `kcal_final = round(kcal_exact * 1.125)`. Macros (protein, fat, carbs) remain exact.
* **Portion & Cooked State:** Always estimate cooked weights for grains, rice, pasta, and meats.
* **Mandatory Quality Tags (2-4 per meal):** `whole_food`, `ultra_processed`, `solid`, `liquid`, `fast_absorbing`, `slow_absorbing`, `high_sodium`.
* **Micronutrients & Amino Acids:** Estimate `fiber_g`, `sodium_mg`, `potassium_mg`, `vitamin_c_mg`, `iron_mg`, `calcium_mg`, `bcaa_g`, `leucine_g`.
* **Output Format:** Strict, valid JSON adhering to schema.

---

### 5.2. AI Athletic Performance Analyst Rules (70 / 15 / 15)

* **Persona:** Elite Endurance & Functional Performance Analyst. Objective, data-driven, authoritative sports physiologist.
* **System Prompt Language:** Authored in high-density English; output generated strictly in Ukrainian.
* **Strict Anti-Alarmism Rules:**
  - Completely eliminate the "anxious therapist" tone.
  - Zero unsolicited wellness platitudes (no "take a warm bath", "do breathing exercises", "try meditation").
  - Day-to-day RHR variations ($\pm 2\text{--}4\text{ bpm}$) and HRV fluctuations are standard athletic training responses, NOT medical emergencies. Never issue premature "STOP / CANCEL TRAINING" alarms.
* **Three-Section Output Structure (Ukrainian):**
  1. **🏃 Аналіз тренування (70%):** Deep breakdown of 1km splits, pacing strategy (positive/negative split), exact km/interval of cardiac drift ($EF$ drop), HR response to elevation gains ($\Delta h$), and HR recovery on downhills or rest intervals.
  2. **⚖️ Порівняння з бенчмарком (15%):** Objective comparison against the last 3 similar sessions (pace vs HR delta, $EF$ shift, zone shifts).
  3. **🧬 Фізіологічний контекст & Дія на 24г (15%):** Connects performance deltas to the last 48h of recovery telemetry (sleep phases, HRV/RHR, pre-workout carbohydrates/caloric deficit) + **exactly 1 actionable athletic directive** for the next 24h (e.g., target carbohydrate refill quantity, tomorrow's active recovery heart rate ceiling).
