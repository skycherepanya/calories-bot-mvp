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

## 3. Current Implementation (iOS-First)

The architecture is centered on the native iOS application, backed by Supabase for cloud sync.

### 3.1. Native iOS Application (`ios/Lifecore/`) — Primary
* **Framework:** SwiftUI, Swift 6 concurrency, Swift Charts, HealthKit, SwiftData.
* **Core Components:**
  - [`HealthKitManager.swift`](./ios/Lifecore/Lifecore/Lifecore/HealthKitManager.swift): Direct interface to HealthStore (`HKStatisticsQuery`, `HKSampleQuery`, `HKWorkoutRouteQuery`). Pulls sleep stages, HRV, RHR, steps, and workouts.
  - `WorkoutTelemetryEngine.swift`: Parses raw HealthKit samples into kilometer splits, computes $EF$, cardiac drift %, and hill impact.
  - [`HealthPayload.swift`](./ios/Lifecore/Lifecore/Lifecore/HealthPayload.swift): Strongly typed `Codable` structs for local persistence and cloud sync.
  - [`LifecoreAPIService.swift`](./ios/Lifecore/Lifecore/Lifecore/LifecoreAPIService.swift): URLSession networking service syncing payloads with Supabase.
  - [`LifecoreSyncIntent.swift`](./ios/Lifecore/Lifecore/Lifecore/LifecoreSyncIntent.swift): AppIntent exposing 1-tap and automated background synchronization to iOS.
  - **SwiftUI Views (Bevel-Style Dashboard):**
    - `TodayView`: Rings for Readiness, Strain, and Nutrition balance.
    - `WorkoutDetailView`: Split-by-split interactive table, pace/HR charts, hill elevation profile.
    - `FoodLogView`: On-device photo capture, optimistic UI, nutrition macro breakdown.
    - `TrendsView`: 7-day and 14-day rolling body weight trends.

---

### 3.2. Cloud Storage & Synchronization (Supabase PostgreSQL)
* **Purpose:** Multi-device synchronization, long-term historical warehouse, and AI prompt context preparation.
* **Active Edge Functions (`supabase/functions/`):**
  - `ingest-health`: Webhook for ingesting encrypted payloads from `LifecoreSyncIntent` / Apple Shortcuts.
* **Database Tables (Active):**
  - `meals`: individual food logs with micronutrients and tags.
  - `body_measurements`: morning weigh-ins and BIA metrics.
  - `daily_metrics`: daily steps, active energy, isolated NEAT, rolling averages.
  - `sleep_logs`: sleep phases, nightly HRV SDNN, and sleeping RHR.
  - `workouts`: sessions with cached `splits JSONB`, total elevation gain, and primary training flags.

---

### 3.3. Legacy Systems (Deprecated)
The following components belong to Version 1.0 (Telegram MVP) and are maintained in a **Legacy / Deprecated** status:
* **Node.js Long-Polling:** `index.js`, `handlers/`, `utils/`.
* **Deno Telegram Bot Webhook:** `supabase/functions/telegram-bot/index.ts`.
* *Note:* Agents are NOT required to maintain feature parity with these legacy components.

---

## 4. Database Schema (Supabase PostgreSQL)

```sql
-- 1. Meals & Nutrition
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
    dietary_date DATE NOT NULL,         -- 4-hour day shift
    telegram_file_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Daily Summary & Rolling Metrics
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

-- 3. Sleep & Autonomic Telemetry
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

-- 4. Workouts & Splits Cache
CREATE TABLE workouts (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    workout_type TEXT NOT NULL,         -- 'running', 'strength', 'cycling', etc.
    source TEXT DEFAULT 'apple_health',
    started_at TIMESTAMPTZ NOT NULL,
    duration_min NUMERIC(5, 1) NOT NULL,
    distance_km NUMERIC(6, 2),
    active_kcal NUMERIC(6, 1),
    avg_pace_min_km NUMERIC(5, 2),
    avg_heart_rate NUMERIC(4, 1),
    max_heart_rate NUMERIC(4, 1),
    elevation_gain_m NUMERIC(6, 1),
    is_primary_training BOOLEAN DEFAULT FALSE,
    has_splits BOOLEAN DEFAULT FALSE,
    splits JSONB DEFAULT '[]',          -- Cached 1km split telemetry array
    raw_data JSONB DEFAULT '{}',
    dietary_date DATE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 5. AI Prompt Engineering Specifications

### 5.1. Food Recognition Prompt Rules
1. **Deficit Buffer (+12.5%):** Automatically apply `kcal = raw_kcal * 1.125`. Keep protein, fat, and carbs exact.
2. **Portion Calibration:** Base estimates on standard plate diameters (24–26 cm).
3. **Cooked vs Raw Weight:** Always output calculated values based on COOKED weights for starches (pasta, rice, grains).
4. **Taxonomy & Micronutrients:** Always output 2–4 mandatory quality tags, along with estimations for fiber, sodium, potassium, and leucine (for protein sources).
5. **Format:** Output STRICT, valid JSON adhering to the target schema.

---

### 5.2. AI Coach Prompt Rules — Athletic Performance Analyst (70 / 15 / 15)

The AI Coach is configured with the persona of an **Elite Endurance & Strength Performance Analyst**:

```
Role: Elite Athletic Performance Coach & Sports Physiologist.
Audience: Experienced endurance runner & calisthenics athlete.
Tone: Concise, objective, analytical, authoritative. No fluff, no wellness platitudes.
```

#### Output Structure:
1. **🏃 АНАЛІЗ ТРЕНУВАННЯ (70% обсягу):**
   - Розбір кілометрових сплітів: стабільність темпу, пульсова вартість швидкості.
   - Реакція на профіль рельєфу: як серце реагувало на підйоми ($\Delta h$) і чи відновлювався пульс на спусках.
   - Аеробне розщеплення (Cardiac Drift %): чи поплив пульс у другій половині дистанції при збереженні темпу.
2. **⚖️ ПОРІВНЯННЯ З БЕНЧМАРКОМ (15% обсягу):**
   - Порівняння з нещодавніми аналогічними тренуваннями (темп при тому ж пульсі, динаміка пульсових зон).
3. **🧬 ФІЗІОЛОГІЧНИЙ КОНТЕКСТ (15% обсягу):**
   - Пояснення причин просадки або успіху на дистанції через метрики відновлення (RHR, HRV, фази сну) та баланс глікогену (вуглеводи напередодні).
4. **🎯 ДІЯ НА НАСТУПНІ 24 ГОДИНИ:**
   - Рівно 1 чітка, тактична спортивна рекомендація (наприклад, тип наступного бігу, відновлювальний протокол або цільовий прийом вуглеводів).
