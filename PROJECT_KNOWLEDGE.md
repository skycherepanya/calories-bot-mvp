# Project Master Context: Lifecore 2.0 (Native iOS-First & Athletic Performance Platform)

> **File Purpose:** Single Source of Truth for AI agents and developers. Contains the full project description, physiological mathematics, on-device Swift telemetry rules, AI coach prompt engineering, database schema, and roadmap. **Do not search other files redundantly — all critical information is consolidated here.**

---

## 1. High-Level Vision & Architecture

* **Project Name:** Lifecore (Native iOS-First Quantified Self & Athletic Performance Platform)
* **Repository:** `calories-bot-mvp` (planned rename to `lifecore`)
* **Core Philosophy:** Personal on-device health and athletic intelligence platform. Lifecore combines continuous physiological telemetry from Apple Watch (Apple HealthKit), frictionless vision-based nutrition tracking, deterministic Swift telemetry math, and an elite AI Athletic Performance Analyst.

### Core Architectural Principles:
1. **iOS-First, On-Device Architecture:** The primary user interface and processing engine is a native iOS application (`ios/Lifecore/`) built with Swift 6, SwiftUI, Swift Charts, HealthKit, and SwiftData.
2. **Deterministic Math Engine vs AI Reasoning:** All mathematical calculations (1km splits, pace, cardiac drift, aerobic decoupling %, NEAT isolation, rolling averages, caloric buffers) are executed deterministically in Swift. The LLM (Gemini) is reserved strictly for qualitative synthesis, athletic pattern recognition, and causal explanation.
3. **HealthKit as Canonical Local Source of Truth:** Apple Health is the ground truth for all passive telemetry (continuous heart rate, sleep architecture, HRV SDNN, resting heart rate, steps, and workout sessions). All split-level workout data is parsed directly from HealthKit on-device without third-party API dependencies.
4. **Cloud Backup & Long-Term Storage (Supabase):** PostgreSQL in Supabase serves as a cloud persistence, backup, and historical synchronization warehouse.
5. **Frictionless Nutrition Logging:** 5-second food capture via camera/photo, automated portion and macronutrient estimation with a guaranteed deficit buffer (+12.5% kcal).
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
     $$\text{Efficiency Factor } (EF) = \frac{\text{Speed (m/min)}}{\text{Average Heart Rate (bpm)}}$$
   - **Cardiac Drift Percentage:**
     $$\text{Drift } (\%) = \left(\frac{EF_{\text{first half}} - EF_{\text{second half}}}{EF_{\text{first half}}}\right) \times 100\%$$
   - **Interpretation:**
     - $<5\%$: Superior aerobic conditioning, stable cardiac output.
     - $>5\text{--}8\%$: Aerobic decoupling (indicates dehydration, glycogen depletion, overheating, or autonomic fatigue).
3. **Lifestyle Activity & NEAT Isolation:**
   - Apple Health `active_kcal` is aggregate for the entire day and **already includes** formal workout calories.
   - Pure NEAT (lifestyle movement) is mathematically isolated:
     $$\text{NEAT}_{\text{kcal}} = \max(0, \text{daily\_active\_kcal} - \sum \text{workout\_kcal})$$

---

### 2.4. 5-Metric Overnight Vitals & Illness Prodrome Detection (Apple Vitals + Stanford NightSignal)

Key nocturnal biomarkers captured passively by Apple Watch:

| Biomarker | HealthKit Identifier | Physiological Role | Outlier Criterion (60d Corridor) |
|---|---|---|---|
| **HRV (RMSSD / SDNN)** | `HKHeartbeatSeriesSample` / `.heartRateVariabilitySDNN` | Vagal parasympathetic tone (20% ectopic beat filter + $\ln$ transform) | $Z_{\text{HRV}} \le -1.35\sigma$ |
| **Sleeping RHR (bpm)** | `.restingHeartRate` | Nocturnal cardiac baseline (~49 bpm) | $\Delta\text{RHR} \ge +4.5\text{ bpm}$ or $Z_{\text{RHR}} \ge +1.6\sigma$ |
| **Wrist Temperature ($\Delta T^\circ\text{C}$)** | `.appleSleepingWristTemperature` | Nocturnal thermoregulation & immune response | $\Delta T \ge +0.40^\circ\text{C}$ (Warning at $+0.25^\circ\text{C}$) |
| **Respiratory Rate (br/min)** | `.respiratoryRate` | Sleeping ventilation effort (~14.2 br/min) | $\Delta\text{RR} \ge +1.8\text{ br/min}$ |
| **Blood Oxygen ($\text{SpO}_2\%$)** | `.oxygenSaturation` | Nocturnal capillary oxygenation (~98%) | $\text{SpO}_2 < 95.0\%$ or $\Delta\text{SpO}_2 \le -2.0\%$ |
| **Sleep Architecture** | `.sleepAnalysis` | Deep (cellular repair) & REM (neural recovery) | $< 1.2\text{h}$ Deep or $< 1.5\text{h}$ REM |

#### Logarithmic HRV Normalization:
$$\text{RMSSD} = \sqrt{\frac{1}{N-1}\sum_{i=1}^{N-1}(RR_{i+1}-RR_i)^2}, \quad Z_{\text{HRV}} = \frac{\ln(\text{HRV}_{\text{today}}) - \mu_{\ln, 60d}}{\max(0.06, \sigma_{\ln, 60d})}$$

#### Multi-Metric Confluence State Machine (`ImmuneSystemState`):
* **`optimal` (0 outliers):** Full autonomic readiness.
* **`trainingFatigue` (1 outlier, $\Delta T < +0.30^\circ\text{C}$):** Normal day-to-day training adaptation or late-meal residue. Zero sickness alarm.
* **`immuneWatch` (2 outliers OR $[\Delta T \ge +0.30^\circ\text{C} \land \ge 1\text{ warning}]$):** Early systemic strain; cap intensity at Zone 1/2 ($\le 135\text{ bpm}$).
* **`illnessProdrome` ($\ge 3$ outliers OR $[\Delta T \ge +0.40^\circ\text{C} \land (\text{RHR} \lor \text{HRV} \lor \text{RR outlier})]$):** High-confidence viral/inflammatory prodrome signature 24–48h prior to clinical symptoms. Proactively overrides daily directive to rest and hydration.

---

### 2.5. Internal Workload (Banister TRIMP, EWMA ACWR) & Continuous Energy Bank (Garmin Firstbeat)

1. **Banister's Training Impulse (TRIMP):**
   $$\Delta\text{HR}_r = \frac{\text{HR}_{\text{avg}} - \text{HR}_{\text{rest}}}{\text{HR}_{\text{max}} - \text{HR}_{\text{rest}}}, \quad \text{TRIMP} = D_{\text{min}} \cdot \Delta\text{HR}_r \cdot 0.64 \cdot e^{1.92 \cdot \Delta\text{HR}_r}$$
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

### 2.8. Dietary Date Convention
* The dietary day shifts at **04:00 AM** (`shiftHours = 4`), not midnight.
* Meals, post-midnight workouts, and sleep cycles occurring between 00:00 and 03:59 AM belong to the physiological cycle of the preceding calendar day.

---

## 3. Current Implementation (Native iOS-First)

The system is centered on the native iOS application (`ios/Lifecore/`), with Supabase PostgreSQL as an asynchronous cloud backup and long-term synchronization warehouse.

### 3.1. Native iOS Architecture (`ios/Lifecore/`)
Built with **Swift 6 concurrency, SwiftUI, Swift Charts, HealthKit, and SwiftData**:

```
ios/Lifecore/
└── Lifecore/
    ├── App/
    │   ├── LifecoreApp.swift             # App lifecycle, SwiftData container setup
    │   └── MainTabView.swift             # 4-tab navigation (Сьогодні, Тренування, Харчування, Тренди)
    ├── Core/
    │   ├── HealthKit/
    │   │   ├── HealthKitManager.swift    # Queries raw biometrics, 5-metric Vitals, R-R Heartbeat series, sleep stages
    │   │   └── WorkoutTelemetryExtractor.swift # Extracts HKQuantitySeriesSample (HR, GPS, Altitude, Cadence)
    │   ├── MathEngine/
    │   │   ├── ReadinessCalculator.swift # Recovery score (0-100%), Strain score, Pure NEAT, rolling averages
    │   │   ├── WorkoutMathEngine.swift   # 1km auto-splits, interval laps, EF, cardiac drift %, GAP, benchmarks
    │   │   ├── VitalsAndIllnessEngine.swift # (Phase 3) 20% R-R filter, ln(RMSSD), 5-metric Vitals & Illness Prodrome
    │   │   ├── TrainingLoadAndBatteryEngine.swift # (Phase 3) Banister TRIMP, EWMA ACWR (7d/28d), 24h Body Battery
    │   │   ├── CorrelationEngine.swift   # (Phase 3) Multi-day time-lagged (T+0, T+1, T+2) r_pb & Pearson r engine
    │   │   └── AdaptivePhysiologyEngine.swift # (Phase 3.1) Bayesian shrinkage, Dynamic TDEE, Ridge OLS β-slopes, 60d EWMA
    │   ├── UI/
    │   │   └── LifecoreDesignSystem.swift # (Phase 3.1) Liquid Glass Bento Cockpit, AdaptiveEngineBadgeBar, RPE calibration
    │   ├── AI/
    │   │   ├── GeminiService.swift       # Direct Google AI Studio client (Vision & Text models)
    │   │   ├── FoodPrompt.swift          # English system prompt for optimistic vision food parsing
    │   │   └── CoachPrompt.swift         # English system prompt for athletic performance analyst + Vitals/ACWR context
    │   └── Storage/
    │       ├── SwiftDataModels.swift     # Local-first @Model entities (MealEntity, WorkoutAnalysisEntity)
    │       ├── AthleteProfileStore.swift # (Phase 3) Editable physiological & macro calibration store
    │       ├── MealStorageService.swift  # SwiftData meal repository & optimistic state manager
    │       └── SupabaseSyncService.swift # Bidirectional cloud persistence for meals, workout_analyses & vitals
    ├── Features/
    │   ├── Today/                        # Dark-mode dashboard: Rings, 5-Pill Overnight Vitals, Illness Radar, 24h Energy Bank
    │   ├── Workouts/                     # Workout list & granular split detail views with synchronized charts
    │   ├── Nutrition/                    # Camera capture, optimistic meal cards, macro breakdown
    │   └── Trends/                       # 7d/14d weight trend, autonomic baselines, EF/drift, Time-Lagged Correlations & ACWR
    └── Intents/
        ├── LogMealIntent.swift           # Fast Siri / Action button meal logger
        └── LifecoreSyncIntent.swift      # AppIntent for background and manual HealthKit sync
```

> **Phase 3 Architectural Spec & Implementation Plan:**
> - **Spec:** [`docs/superpowers/specs/2026-10-21-lifecore-v3-physiological-engine-and-ui-design.md`](file:///Users/skycherepanya/Developer/GitHub/calories-bot-mvp/docs/superpowers/specs/2026-10-21-lifecore-v3-physiological-engine-and-ui-design.md)
> - **Plan:** [`docs/superpowers/plans/2026-10-21-phase-3-physiological-engine-vitals-and-ui-v3.md`](file:///Users/skycherepanya/Developer/GitHub/calories-bot-mvp/docs/superpowers/plans/2026-10-21-phase-3-physiological-engine-vitals-and-ui-v3.md)

---

### 3.2. Cloud Storage & Synchronization (Supabase PostgreSQL)
* **Role:** Asynchronous backup, historical cold storage (10+ years), and multi-device warehouse.
* **Synchronization Pipeline:** Direct native iOS client (`SupabaseSyncService.swift`) connecting to Supabase PostgreSQL REST endpoints. No intermediary Edge Functions.
* **Active Tables:** `meals` (nutrition logs), `workout_analyses` (cached JSONB splits & laps + AI reports), `daily_metrics`, `sleep_logs`, `body_measurements`.

---

### 3.3. Legacy Telegram Architecture (Archived in Git Tag)
All Version 1.0 components (Node.js Telegram bot, Deno edge functions, shortcuts, and legacy Python scripts) have been permanently deleted from the active tree and safely archived in git tag **`v1.0-telegram-archive`**:
* **Tag:** `v1.0-telegram-archive`
* **Historical Contents:** `index.js`, `handlers/`, `utils/`, `shortcuts/`, `supabase/functions/`, `Lifecore/scripts/`.
* **Policy:** Dual-backend maintenance is 100% discontinued. The repository is purely iOS-First.

---

## 4. Cloud Database Schema (Supabase PostgreSQL)

```sql
-- 1. Meals & Nutrition Warehouse
CREATE TABLE meals (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    meal_name TEXT NOT NULL,
    kcal NUMERIC(6, 1) NOT NULL,        -- Includes +12.5% deficit buffer
    protein NUMERIC(5, 1) NOT NULL,
    fat NUMERIC(5, 1) NOT NULL,
    carbs NUMERIC(5, 1) NOT NULL,
    weight_g NUMERIC(6, 1),
    confidence NUMERIC(3, 2),
    tags TEXT[],                        -- Taxonomy tags
    micronutrients JSONB DEFAULT '{}',  -- Fiber, sodium, potassium, etc.
    amino_acids JSONB DEFAULT '{}',     -- BCAA, leucine
    dietary_date DATE NOT NULL,         -- 04:00 AM day shift
    telegram_file_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Workout Analyses (Replaces flat workouts table to eliminate relational join overhead)
CREATE TABLE IF NOT EXISTS workout_analyses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id BIGINT NOT NULL,
    healthkit_workout_uuid TEXT UNIQUE NOT NULL,
    workout_type TEXT NOT NULL,
    started_at TIMESTAMPTZ NOT NULL,
    distance_km NUMERIC(6, 2),
    duration_min NUMERIC(6, 2),
    avg_pace_min_km NUMERIC(5, 2),
    avg_hr NUMERIC(5, 1),
    max_hr NUMERIC(5, 1),
    elevation_gain_m NUMERIC(6, 1),
    efficiency_factor NUMERIC(5, 3),
    aerobic_decoupling_pct NUMERIC(5, 2),
    splits_json JSONB NOT NULL,         -- Array of 1km split metrics (pace, HR, Δh, cadence)
    laps_json JSONB,                    -- Structured interval laps from HKWorkoutActivity
    ai_coach_report TEXT,               -- Stored 70/15/15 performance analyst narrative
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Daily Summary, EWMA ACWR & Body Battery (Phase 2 & 3)
CREATE TABLE daily_metrics (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    metric_date DATE NOT NULL UNIQUE,
    steps INTEGER,
    active_kcal NUMERIC(6, 1),          -- Total daily active kcal from HealthKit
    neat_kcal NUMERIC(6, 1),            -- Isolated NEAT (active_kcal - workout_kcal)
    distance_km NUMERIC(5, 2),
    morning_weight_kg NUMERIC(5, 2),
    rolling_avg_weight_7d NUMERIC(5, 2),
    rolling_avg_weight_14d NUMERIC(5, 2),
    trimp_score NUMERIC(6, 1),          -- Banister's Training Impulse
    ewma_acute_load NUMERIC(6, 1),      -- 7d EWMA Acute Load (λ = 2/8)
    ewma_chronic_load NUMERIC(6, 1),    -- 28d EWMA Chronic Load (λ = 2/29)
    acwr_ratio NUMERIC(4, 2),           -- Acute-to-Chronic Workload Ratio (0.8-1.3 sweet spot)
    body_battery_wake INTEGER,          -- Morning Energy Bank 0-100%
    body_battery_min INTEGER,           -- End-of-day Energy Bank 0-100%
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Sleep, 5-Metric Overnight Vitals & Immune State (Phase 2 & 3)
CREATE TABLE sleep_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    sleep_date DATE NOT NULL UNIQUE,
    total_hours NUMERIC(4, 2) NOT NULL,
    deep_hours NUMERIC(4, 2),
    rem_hours NUMERIC(4, 2),
    core_hours NUMERIC(4, 2),
    awake_hours NUMERIC(4, 2),
    hrv_avg_ms NUMERIC(5, 1),           -- Nightly HRV SDNN
    hrv_rmssd_ms NUMERIC(5, 1),         -- Beat-to-beat RMSSD (20% artifact filtered)
    rhr_bpm NUMERIC(4, 1),              -- Resting Heart Rate
    wrist_temp_delta_c NUMERIC(4, 2),   -- Sleeping wrist temperature delta °C
    spo2_pct NUMERIC(4, 1),             -- Nocturnal SpO2 %
    respiratory_rate NUMERIC(4, 1),     -- Sleeping breaths/min
    sleep_efficiency_pct NUMERIC(4, 1), -- Asleep / Time-in-Bed %
    immune_state TEXT DEFAULT 'optimal',-- optimal | training_fatigue | immune_watch | illness_prodrome
    vo2max NUMERIC(4, 1),
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

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
