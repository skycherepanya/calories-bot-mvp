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

### 2.4. Recovery Biomarkers (Autonomic Regulation)

Key autonomic telemetry captured by Apple Watch:

| Biomarker | Physiological Role | Athletic Significance |
|---|---|---|
| **HRV SDNN (ms)** | Autonomic nervous system variability | Higher = parasympathetic readiness. Acute drops = systemic fatigue or immune stress |
| **RHR (bpm)** | Sleeping Resting Heart Rate | Athletic baseline: ~49 bpm. Sustained elevations (>4–5 bpm) signal incomplete recovery |
| **Sleep Architecture** | Deep (cellular/tissue repair) & REM (neural recovery) | $\ge 1.2\text{h}$ Deep and $\ge 1.5\text{h}$ REM required for heavy training volume |

> **Athletic Guardrail Policy:** Normal day-to-day RHR variations ($\pm 2\text{--}4\text{ bpm}$) are standard athletic adaptations, NOT medical emergencies. The AI Coach must NEVER panic or issue premature "STOP / CANCEL TRAINING" alarms unless multiple severe biomarkers converge (e.g. HRV down >25% + acute fever/infection symptoms).

---

### 2.5. Dietary Date Convention
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
    │   └── MainTabView.swift             # 4-tab navigation (Today, Workouts, Nutrition, Trends)
    ├── Core/
    │   ├── HealthKit/
    │   │   ├── HealthKitManager.swift    # Queries raw biometrics, daily totals, sleep stages
    │   │   └── WorkoutTelemetryExtractor.swift # Extracts HKQuantitySeriesSample (HR, GPS, Altitude, Cadence)
    │   ├── MathEngine/
    │   │   ├── ReadinessCalculator.swift # Recovery score (0-100%), Strain score, Pure NEAT, rolling averages
    │   │   └── WorkoutMathEngine.swift   # 1km auto-splits, interval laps, EF, cardiac drift %, GAP, benchmarks
    │   ├── AI/
    │   │   ├── GeminiService.swift       # Direct Google AI Studio client (Vision & Text models)
    │   │   ├── FoodPrompt.swift          # English system prompt for optimistic vision food parsing
    │   │   └── CoachPrompt.swift         # English system prompt for 70/15/15 athletic performance analyst
    │   └── Storage/
    │       ├── SwiftDataModels.swift     # Local-first @Model entities (MealEntity, WorkoutAnalysisEntity)
    │       ├── MealStorageService.swift  # SwiftData meal repository & optimistic state manager
    │       └── SupabaseSyncService.swift # Async cloud persistence for meals & workout_analyses
    ├── Features/
    │   ├── Today/                        # Dark-mode dashboard: Readiness, Strain, Nutrition rings
    │   ├── Workouts/                     # Workout list & granular split detail views with synchronized charts
    │   ├── Nutrition/                    # Camera capture, optimistic meal cards, macro breakdown
    │   └── Trends/                       # 7d/14d rolling weight trend (water noise filter), autonomic baselines (HRV/RHR corridor), aerobic efficiency (EF & drift) (TrendsView.swift, TrendsComponents.swift)
    └── Intents/
        ├── LogMealIntent.swift           # Fast Siri / Action button meal logger
        └── LifecoreSyncIntent.swift      # AppIntent for background and manual HealthKit sync
```

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

-- 3. Daily Summary & Rolling Metrics
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
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Sleep & Autonomic Telemetry
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
    rhr_bpm NUMERIC(4, 1),              -- Resting Heart Rate
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
