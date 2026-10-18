# Project Master Context: Lifecore (Quantified Self Health Data Warehouse)

> **File Purpose:** Single Source of Truth for AI agents and developers. Contains the full project description, domain mathematics, architecture, current code status, AI prompts rules, and development roadmap. **Do not search other files redundantly — all critical information is here.**

---

## 1. High-Level Vision

* **Project Name:** Lifecore (Quantified Self Health & Nutrition Data Warehouse)
* **Repository:** `calories-bot-mvp` (rename to `lifecore` is planned)
* **Main Goal:** Modular, scalable ecosystem for collecting, aggregating, and correlating nutrition, body composition, training, and sleep data — owned entirely by the user.

**Core Principles:**
1. **Frictionless Input:** Photo or short text description, not manual weighing. Maximum 5 seconds per meal entry.
2. **Data Ownership:** All data in private PostgreSQL (Supabase). No vendor lock-in.
3. **Modularity:** Each layer (Ingestion, Storage, Processing, AI, Presentation) is independent.
4. **AI Precision:** Strict prompt engineering, structured JSON output, cooking-weight correction, deficit buffer.
5. **Evidence-based Insights:** AI receives pre-computed statistical facts from the math engine, not raw tables.

---

## 2. Domain Core & Physiological Math

### 2.1. Daily Weight "Water Noise" vs Real Trend

Raw daily weight reflects water balance, not real fat/muscle change:
- **Glycogen water binding:** 1g glycogen holds ~3g water → carb spike = next-day weight spike, not fat.
- **Muscle micro-inflammation:** Intense cardio/lifting → muscles accumulate fluid for 24–72h recovery.
- **Cortisol & stress:** Extreme deficit or sleep debt raises cortisol → kidney water retention.
- **BIA scale limitations:** Smart scales measure lower-body current resistance; upper body is algorithmically approximated.

> **Solution:** 7–14 day rolling average to filter water noise and detect real long-term trend.

---

### 2.2. Macronutrient Quality & Absorption Kinetics

A calorie is not just a calorie:
- **Thermic Effect of Food (TEF):** Protein 20–30%, Carbs 5–10%, Fats 0–3%. Whole meat has higher TEF than processed sausages.
- **Absorption kinetics:** Liquid/ultra-processed → rapid glucose spike, hunger returns quickly. Solid/whole foods → slow digestion, sustained satiety.
- **Food matrix & sodium:** Ultra-processed food contains hidden sodium → water retention 24–48h.

#### Mandatory Food Tagging Taxonomy
Every meal must be tagged:
- `whole_food` — natural, minimally processed (eggs, potatoes, chicken fillet, vegetables)
- `ultra_processed` — industrial fast food, chips, candy, sausages
- `solid` — solid food form
- `liquid` — soup, smoothie, shake, drink
- `fast_absorbing` — sweets, refined carbs, liquid whey isolate
- `slow_absorbing` — whole meat, legumes, whole grains, eggs
- `high_sodium` — salty sauces, cured meats, fast food, pickles

---

### 2.3. Recovery Biomarkers (HRV, RHR, VO2Max)

Key metrics from Apple Watch used by the Coach:

| Metric | What it means | How it changes |
|---|---|---|
| **HRV SDNN (ms)** | Autonomic nervous system resilience | ↑ = well recovered. ↓ = fatigue/stress/overtraining |
| **RHR (bpm)** | Resting Heart Rate | ↓ = better fitness. ↑ = infection/overtraining |
| **VO2 Max** | Aerobic capacity ceiling | Improves with consistent cardio volume |

**Sasha's baseline (Oct 2026):**
- HRV avg: ~102 ms (excellent for age 24)
- RHR: ~49 bpm (athletic bradycardia)
- VO2 Max: ~44.35 (improved from 37.73 in Feb 2026 = +17.5%)

**Coach alert thresholds:**
- HRV drops >15% below personal baseline → 🔴 STOP / RECOVERY
- RHR >3 bpm above baseline → 🟡 Reduce intensity
- Sleep <6h + HRV↓ simultaneously → 🔴 No hard workout

---

### 2.4. Lifestyle Activity & NEAT (Non-Exercise Activity Thermogenesis)

Physical activity is not limited to structured workouts:
- **NEAT Impact:** Daily errands, shopping mall walking, or active city commutes often accumulate 8,000–14,000 steps and burn 300–600 active kcal without a formal workout.
- **Coach Intelligence:** If the Coach only evaluates formal workouts, it risks misinterpreting a high-NEAT day as a sedentary day, falsely projecting a smaller caloric deficit and misdiagnosing recovery fatigue.
- **Source of Truth:** **Apple Health / Apple Fitness is the Canonical Primary Source of Truth** for all activity and workouts because Apple Watch passively and automatically logs every heartbeat, step, and exercise session directly to HealthKit. Strava is strictly a secondary export/social channel.
- **Storage:** Daily total steps, active energy burned, and distance are stored in `daily_metrics`.

---

### 2.5. Time-Lag Correlations (planned Phase 3)

Nutrition and exercise events affect body metrics with delays:
- **Lag T+1 / T+2:** Sodium/carb intake on day T → morning weight on T+1, T+2
- **Lag T+1:** Calorie deficit on day T → HRV drop on morning T+1
- **Lag T+1:** Running volume on day T → RHR on T+1 (overtraining signal)

Calculation: Pearson/Spearman correlation with lags $\Delta t \in \{1, 2, 3\}$, $p$-value $< 0.05$.

---

## 3. Current Implementation

Dual Architecture — all logic changes must be applied to **both** implementations simultaneously.

### 3.1. Node.js Process (Long Polling) — Development
**Entry Point:** [`index.js`](./index.js)
**Stack:** `node-telegram-bot-api`, `@google/generative-ai`, `@supabase/supabase-js`, `dotenv`, `exifreader`

**Handlers (`handlers/`):**
- [`photoHandler.js`](./handlers/photoHandler.js) — photo + document (EXIF date extraction), calls `generateMealJSON`, saves to `meals` with tags/micronutrients/amino_acids, returns macro card
- [`textHandler.js`](./handlers/textHandler.js) — routes `/stats`, `/w` (→ weightHandler), `/y`, or food text → `generateMealJSON`
- [`weightHandler.js`](./handlers/weightHandler.js) — `/w <weight>`, calculates delta from last measurement, saves to `body_measurements`
- [`callbackHandler.js`](./handlers/callbackHandler.js) — inline pagination buttons for stats (`stats_YYYY-MM-DD`)
- `coachHandler.js` 🔜 — `/coach`, `/workout`, `/sleep` commands

**Utils (`utils/`):**
**Utils (`utils/`):**
- [`gemini.js`](./utils/gemini.js) — `generateMealJSON(genAI, promptData)` with cascade fallback (`gemini-3.8-flash` → `gemini-2.5-flash` → `gemini-3.6-flash`)
- [`keyboard.js`](./utils/keyboard.js) — `MAIN_KEYBOARD` persistent bottom menu (will add 🏃 button in Phase 2)
- [`dateUtils.js`](./utils/dateUtils.js) — `getDietaryDate(date, offsetDays)` with `shiftHours = 4`; `getStatsMessage()` with aggregation
- [`prompt.js`](./utils/prompt.js) — system prompt for food recognition (tags, micronutrients, amino acids, ×1.125 buffer)
- `coachPrompt.js` 🔜 — `buildCoachContext(userId)` + `buildCoachPrompt(context)` for /coach

---

### 3.2. Supabase Edge Function (Webhook) — Production
**Path:** [`supabase/functions/telegram-bot/index.ts`](./supabase/functions/telegram-bot/index.ts)
**Stack:** Deno runtime, `@supabase/supabase-js@2`, `@google/generative-ai@0.1.1`, `exifreader@4.23.1`

**Features (full parity with Node.js):**
- Photo/document recognition with EXIF date extraction
- Commands: `/w`, `/y`, `/stats`, `/start`, `/coach` 🔜
- Persistent `MAIN_KEYBOARD`
- Automatic weight recognizer (30–350 number range)
- "Yesterday mode" via force_reply
- Gemini fallback chain (`gemini-3.8-flash` → `gemini-2.5-flash` → `gemini-3.6-flash`)
- Fault-tolerant `sendTg` with Markdown fallback to plain text
- `await handleUpdate(update)` before HTTP 200 OK (prevents Deno isolate freeze)

**`ingest-health` Edge Function** 🔜 — new function for iOS Shortcuts:
- Path: `supabase/functions/ingest-health/index.ts`
- Auth: `INGEST_SECRET` from Supabase Secrets (not JWT)
- Writes to `daily_metrics` (steps, active kcal, NEAT), `sleep_logs`, and `workouts`

---

### 3.3. Analytics Module (`Lifecore/`)
**Stack:** Python 3, `xml.etree.ElementTree`, `pandas`, `supabase-py`, `python-dotenv`

**Scripts:**
- `deep_health_analysis.py` — streams Apple Health XML (1.97 GB) → `daily_health_summary.json`
- `analyze_health.py` — HRV/RHR/Steps monthly trends
- `analyze_steps.py` — step double-counting check (iPhone vs Watch sources)
- `analyze_strava.py` — pace, distance, HR correlations from Strava CSV
- `sync_to_supabase.py` ✅ — bulk-upload `daily_health_summary.json` + `activities.csv` → Supabase with cross-source deduplication

**Reference prompts (`Lifecore/prompts/`):**
- `antigravity_health_assistant_prompt_sasha.md` — Sasha's personal AI coach profile (age 24, 175cm/76kg, running + calisthenics, goals: recomposition)
- `antigravity_health_assistant_prompt_vika.md` — Vika's profile (age 24, 170cm/68kg, beginner, fat loss)

---

## 4. Database Schema

### Currently in DB (✅ Applied)

**`meals`** — individual meals
```sql
id, user_id, meal_name, kcal, protein, fat, carbs, weight_g, confidence,
tags TEXT[], micronutrients JSONB, amino_acids JSONB,
dietary_date DATE, telegram_file_id TEXT, created_at TIMESTAMPTZ
```

**`body_measurements`** — weight measurements
```sql
id, user_id, weight_kg, dietary_date, measured_at,
impedance_ohms, impedance_frequency_khz, body_fat_pct, water_pct,
muscle_mass_kg, bone_mass_kg, visceral_fat,
source TEXT DEFAULT 'telegram_w', created_at
```

**`workouts`** — physical activity (Migration 002)
```sql
id, user_id, workout_type TEXT, source TEXT,
started_at TIMESTAMPTZ, duration_min, distance_km, avg_heart_rate,
max_heart_rate, active_kcal, avg_pace_min_km, elevation_m,
notes TEXT, raw_data JSONB, dietary_date DATE, created_at
```

**`sleep_logs`** — nightly sleep + biomarkers (Migrations 003 & 004)
```sql
id, user_id, source TEXT, sleep_date DATE UNIQUE(user_id, sleep_date),
total_hours, deep_hours, rem_hours, core_hours, awake_hours,
hrv_avg_ms, rhr_bpm, vo2max, created_at
```

**`daily_metrics`** — lifestyle activity, steps, active energy & rolling metrics (Migrations 20260904160000 & 005)
```sql
id, user_id, metric_date DATE UNIQUE(user_id, metric_date),
steps INTEGER, active_kcal NUMERIC, distance_km NUMERIC,
morning_weight_kg NUMERIC, body_fat_pct NUMERIC, water_pct NUMERIC,
sleep_hours NUMERIC, deep_sleep_hours NUMERIC, rem_sleep_hours NUMERIC,
resting_hr NUMERIC, hrv_ms NUMERIC, rolling_avg_weight_7d NUMERIC,
rolling_avg_weight_14d NUMERIC, source TEXT DEFAULT 'apple_health', created_at
```

Full DDL: see [`docs/DATABASE.md`](./docs/DATABASE.md) and [`supabase/migrations/`](./supabase/migrations/).

---

## 5. AI Prompts Rules (Critical)

### Food Recognition Prompt Rules
1. **Scale calibration:** Don't assume massive restaurant portions. Analyze plate size.
2. **Cooked vs Raw:** Rice, pasta, buckwheat, oats — always calculate on COOKED weight.
3. **Deficit Buffer:** `kcal_final = kcal_exact * 1.125`. Protein/fat/carbs stay exact.
4. **Tags:** Always return 2–4 tags from the taxonomy.
5. **Micronutrients:** Always estimate: `fiber_g`, `sodium_mg`, `potassium_mg`, `vitamin_c_mg`, `iron_mg`, `calcium_mg`.
6. **Amino acids:** For protein meals, estimate `bcaa_g` and `leucine_g`.
7. **Response format:** ONLY valid JSON, no markdown wrappers.

### Coach Prompt Rules (Phase 2)
1. Analyze ONLY from the provided data — no generic internet advice.
2. Start every response with: `СТАН СИСТЕМИ: 🟢/🟡/🔴`.
3. Max 4 insights — each: fact → physiological reason → specific recommendation.
4. If HRV < personal baseline by >15% OR RHR > baseline by >3 bpm → mandatory `СТОП / ВІДНОВЛЕННЯ`.
5. Always cite exact numbers from the context in each insight.
6. Response language: Ukrainian, no motivational fluff.

---

## 6. Environment Variables

Required for local and Supabase execution:
```env
TELEGRAM_BOT_TOKEN="BotFather token"
ALLOWED_USER_ID="numeric Telegram ID of authorized user"
GEMINI_API_KEY="Google AI Studio key"
SUPABASE_URL="https://xxxxxxxxxxxx.supabase.co"
SUPABASE_KEY="anon or service_role Supabase key"
```

Additional for `ingest-health` Edge Function (set via `supabase secrets set`):
```
INGEST_SECRET="random secret for iOS Shortcut auth"
```

---

## 7. Operational Directives (AI Agent Rules)

1. **Context Economy:** All information is in this file and `docs/`. Don't search other files redundantly.
2. **Dual Sync:** Any logic change in Node.js `handlers/` MUST be mirrored in Edge Function `index.ts`.
3. **Deficit Discipline:** Keep ×1.125 buffer unless user explicitly asks to change.
4. **JSON Format:** Never change the food prompt output format — it will break DB inserts.
5. **Tag Completeness:** Whenever updating the AI prompt, always retrieve the full `tags` array.
6. **Self-Updating Docs:** No change is complete without updating: `CHANGELOG.md`, `docs/ROADMAP.md`, and relevant docs.
7. **Test → Commit → Deploy:** After changes: verify locally, `git commit + push`, deploy Edge Function.
