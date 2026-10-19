# ARCHITECTURAL PIVOT: Lifecore 2.0 — Native iOS-First & Athletic Performance Platform

> Document Role: Master Architectural Directive & Single Source of Truth for refactoring the repository and documentation.
> Scope: Deprecates the v1.0 Dual Architecture (Node.js Long Polling + Deno Edge Telegram Bot + iOS Webhook Ingestion)[cite: 1, 2, 3] and transitions Lifecore to a unified Native iOS-First Architecture (ios/Lifecore/ — SwiftUI + HealthKit + SwiftData/Supabase + Gemini API)[cite: 1, 2, 3].

---

## 0. Mandatory Agent Operational Directives

### 0.1. Language, Token Economy & Skills Protocol (CRITICAL)
1. English-Only Artifacts & Code (Token Economy):
   - Write ALL documentation (PROJECT_KNOWLEDGE.md, AGENTS.md, README.md, docs/*.md, CHANGELOG.md)[cite: 1, 2], code comments, commit messages, variable names, and system prompts in concise, high-density English.
   - Avoid verbose explanations, filler prose, or redundant examples in markdown files to minimize context window and token usage[cite: 1].
2. Ukrainian User Chat Responses:
   - Communicate directly with the user in the chat strictly in Ukrainian. Keep chat replies brief, technical, and action-oriented.
   - Note: In-app AI Coach outputs and food names generated for the user must remain in Ukrainian[cite: 1, 3], even though the underlying system prompt instructions are written in English.
3. Skills & AGENTS.md First:
   - Before executing any plan or file modification, inspect AGENTS.md[cite: 2] and scan the workspace for agent configuration/skills directories (e.g., .agent/, .agents/, .claude/, or custom skills).
   - Actively leverage existing skills, workflows, and repo rules to maximize execution speed and prevent redundant file reads[cite: 1].

### 0.2. Documentation Refactoring Action Plan
Execute the following updates across the repository:
1. PROJECT_KNOWLEDGE.md[cite: 1, 2]:
   - Replace Section 3 (Current Implementation — Dual Architecture)[cite: 1] with the Native iOS Architecture (ios/Lifecore/)[cite: 2].
   - Update Section 5 (AI Prompts Rules)[cite: 1]: remove alarmist medical thresholds (STOP / RECOVERY on >15% HRV drop or >3 bpm RHR increase)[cite: 1, 3] and replace with the 70/15/15 Athletic Performance Analyst framework[cite: 3].
2. AGENTS.md[cite: 2]:
   - Remove the Dual Sync rule (no longer syncing Node.js handlers/ with Deno supabase/functions/telegram-bot/index.ts)[cite: 1, 2].
   - Enforce the Language & Token Economy Protocol (Section 0.1 above) and Swift 6 / SwiftUI / HealthKit modularity rules.
3. README.md & docs/ARCHITECTURE.md[cite: 2]:
   - Document the 4-layer On-Device architecture (HealthKit Source of Truth -> Swift Math & Telemetry Engine -> SwiftData + Supabase Cloud Backup -> SwiftUI Bevel-style Dashboard).
   - Move index.js, handlers/, utils/, and supabase/functions/telegram-bot/ to legacy_telegram/ (or mark as Deprecated)[cite: 1, 2].
4. docs/DATABASE.md & docs/ROADMAP.md[cite: 1, 2]:
   - Update schema to reflect local HealthKit querying + cloud storage only for meals[cite: 1] and workout_analyses (storing splits_json and laps_json as JSONB).
   - Rewrite roadmap around native iOS views (Today, Workouts, Nutrition, Trends).

---

## 1. Rationale for the Pivot

1. Eliminate Dual-Backend Friction: Maintaining identical logic in Node.js (index.js) and Deno Edge Functions (telegram-bot/index.ts)[cite: 1, 2, 3], plus pushing HealthKit data via ingest-health webhooks[cite: 1, 2, 3], created unnecessary maintenance overhead.
2. Bevel-Style Instant Visual UX: Reading walls of text via /coach in Telegram is slow and unintuitive[cite: 3]. A native SwiftUI app reads HealthKit in <5ms[cite: 1, 2] and renders instant Readiness/Strain rings, rolling weight charts, and interactive split tables.
3. Zero-Friction Workout Filtering (No Strava API Needed): Instead of deduplicating Apple Health and Strava API sessions in PostgreSQL to filter out casual walks or 5-min bike commutes[cite: 3], the iOS app reads all workouts directly from HealthKit:
   - All workouts contribute to daily calories and pure NEAT isolation[cite: 1, 3].
   - Only structured athletic sessions (Running, Strength/Calisthenics, Swimming, or user-selected workouts) are passed to the AI Athletic Analyst[cite: 1, 3].
4. Fix the "Anxious Doctor" AI Tone: Previous prompt rules forced the LLM to lecture the user about "warm baths", "meditation", and "critical exhaustion" whenever RHR rose by a few bpm[cite: 1, 3]. The new coach acts strictly as an Athletic Performance Analyst focused on pace, heart rate zones, elevation, and glycogen/recovery root causes[cite: 3].

---

## 2. Target Architecture: Lifecore 2.0 (Native iOS-First)

    [Apple Watch Ultra + iPhone 16 Pro (HealthKit)]
           | (Direct <5ms Read: Sleep, HRV, RHR, Steps, Weight, HR/GPS Series)
           v
    [Native iOS App: ios/Lifecore/]
      |-- 1. HealthKitManager: Queries raw biometrics, daily totals & workout series
      |-- 2. LifecoreMathEngine (Deterministic Swift Math):
      |      * Recovery Score (0-100%), Strain Score (0-100%), Pure NEAT Isolation
      |      * 7d & 14d Rolling Weight Averages (filters water noise)
      |      * Workout Slicing: 1km Metric Splits + Structured Interval Laps
      |      * Running Telemetry: Efficiency Factor (EF), Cardiac Drift %, GAP
      |-- 3. SwiftUI Presentation Layer (Dark-Mode Bevel-Style Dashboard)
      +-- 4. Gemini Direct AI Services:
             * Optimistic Food Vision Parser (x1.125 buffer, 04:00 AM shift, tags)
             * Athletic Performance Analyst (70/15/15 split & physiological analysis)
           |
           v (Async Cloud Backup)
    [Supabase PostgreSQL]
      |-- meals (Nutrition warehouse, tags, micronutrients, amino acids)
      +-- workout_analyses (Cached JSONB splits/laps + AI coach reports)

---

## 3. Domain Math & Physiological Engine (Swift)

All mathematical calculations MUST run deterministically in Swift before calling Gemini[cite: 1, 3].
User Profile Baseline (Sasha, 24yo, 175cm, ~76kg): HRV SDNN ~102 ms, RHR ~49 bpm, VO2Max ~44.35[cite: 1, 3].

### 3.1. Readiness, Strain & Pure NEAT Isolation (ReadinessCalculator.swift)
- Recovery Score (0-100%): Computed from morning HRV SDNN z-score vs. 30-day rolling baseline, overnight RHR delta, total sleep duration (target: 7.5h), and Deep/REM sleep share[cite: 1, 3].
- Pure NEAT Isolation (Double-Counting Prevention):
  Apple Health daily_active_kcal includes both lifestyle movement and recorded workouts[cite: 1, 3]. Isolate pure lifestyle movement using the formula:
  NEAT_kcal = max(0, daily_active_kcal - sum(all_workouts_active_kcal))[cite: 1, 3]
- Rolling Weight Trend: Raw daily weight fluctuates due to glycogen water binding (1g glycogen holds ~3g water), sodium intake, and post-exercise inflammation[cite: 1]. Compute 7-day and 14-day rolling averages to expose the true tissue trend[cite: 1, 2].

### 3.2. Granular Workout Telemetry (WorkoutTelemetryExtractor.swift & WorkoutMathEngine.swift)
For target workouts, extract HKQuantitySeriesSample (Heart Rate, Distance, Altitude/Elevation, Speed, Cadence) and HKWorkoutActivity:
1. splits_metric (1km Auto-Splits): Array of 1,000m segments containing km_index, duration_s, pace_min_km, avg_hr, max_hr, elevation_diff_m (+gain / -loss), avg_cadence[cite: 3].
2. laps_intervals (Manual / Structured Intervals): Extracted from HKWorkoutActivity to prevent 1km splits from averaging out high-intensity intervals and rest periods. Includes work pace, peak HR, and HR Recovery Drop during rest intervals.
3. Computed Running Metrics:
   - Efficiency Factor (EF):
     EF = Avg_Speed_m_per_min / Avg_HR_bpm[cite: 3]
   - Aerobic Decoupling / Cardiac Drift (%):
     Decoupling_Pct = ((EF_first_half - EF_second_half) / EF_first_half) * 100[cite: 3]
     (<5% = solid aerobic endurance; >5% = HR drift due to fatigue, heat, hills, or glycogen depletion)[cite: 3].
   - Historical Benchmark: Compare current workout against the last 3 similar workouts (distance +/- 20%) by computing deltas in pace, average HR, and EF[cite: 3].
   - Edge Cases: Tag indoor runs (elevation_gain == 0 / indoor workout flag) as indoor_treadmill (expect +3-5% natural cardiac drift due to lack of airflow). For calisthenics/strength, skip splits and evaluate duration, HR peaks, and daily protein/leucine intake[cite: 1, 2, 3].

---

## 4. Frictionless Nutrition Pipeline (<5 Seconds Rule)

1. Dietary Day Shift (04:00 AM): Meals logged between 00:00 and 03:59 count toward the previous day's dietary_date[cite: 1, 2, 3]. Support a "Log for Yesterday" toggle[cite: 1, 2].
2. Optimistic UI & Background Task: Taking a photo or entering text immediately inserts a local SwiftData card with status "Analyzing..." (<0.2s) and runs Gemini Vision inside a background task (UIApplication.beginBackgroundTask), allowing the user to lock the phone immediately.
3. Strict Gemini Food Prompt Rules (English Prompt -> JSON Output):
   - Scale & Cooked Weight: Estimate realistic portion sizes; always calculate grains, pasta, and meat using COOKED nutritional values[cite: 1].
   - Deficit Buffer (x1.125): kcal_final = round(kcal_exact * 1.125). Keep protein, fat, and carbs exact[cite: 1, 2, 3].
   - Mandatory Tags (2-4 per meal): whole_food, ultra_processed, solid, liquid, fast_absorbing, slow_absorbing, high_sodium[cite: 1, 2].
   - Micronutrients & Amino Acids: Estimate fiber_g, sodium_mg, potassium_mg, vitamin_c_mg, iron_mg, calcium_mg, bcaa_g, and leucine_g[cite: 1, 2].
   - Sync total macros and sodium back to Apple HealthKit and Supabase meals[cite: 1].

---

## 5. AI Athletic Performance Analyst (AthleticCoachPrompt.swift)

### 5.1. Strict Style & Anti-Nagging Constraints
- Persona: Elite Endurance & Functional Performance Analyst[cite: 3].
- Forbidden: Never sound like an anxious physician. Never suggest "warm baths", "breathing exercises", "meditation", or "stop training immediately" over normal physiological RHR/HRV fluctuations[cite: 3].
- Language Rule: Write system instructions in English (token economy); mandate output in Ukrainian[cite: 1, 3].

### 5.2. Post-Workout Analysis Structure (The 70 / 15 / 15 Rule)
Output strictly 3 concise sections in Ukrainian:
1. Split & Pacing Telemetry (70%): Analyze pacing strategy (negative/positive splits), exact kilometer or interval where cardiac drift (Decoupling %) occurred, HR response to elevation changes (elevation_diff_m), and HR recovery on downhills or rest intervals[cite: 3].
2. Historical Benchmark (15%): Compare current pace, HR, and EF against the 3 previous similar sessions (e.g., "6:10/km cost +5 bpm more than on Oct 4; EF dropped from 1.07 to 1.03")[cite: 3].
3. Physiological Root Cause & Next 24h Action (15%): Connect workout telemetry to the last 48h of sleep and nutrition data (e.g., "HR drift after km 7 correlates with yesterday's low carb intake (117g) and elevated overnight RHR (58 vs 49 bpm baseline)") + 1 specific athletic adjustment for the next 24h (target carb refill or tomorrow's HR zone)[cite: 3].

---

## 6. Target Repository Structure & Cloud Schema

    lifecore/
    |-- PROJECT_KNOWLEDGE.md          # Single Source of Truth (English)
    |-- AGENTS.md                     # Agent rules, Token Economy & Swift guidelines (English)
    |-- README.md                     # Project overview & Xcode setup (English)
    |-- ios/Lifecore/                 # PRIMARY NATIVE APP (SwiftUI)
    |   +-- Lifecore/
    |       |-- App/                  # LifecoreApp.swift, MainTabView.swift
    |       |-- Core/
    |       |   |-- HealthKit/        # HealthKitManager.swift, WorkoutTelemetryExtractor.swift
    |       |   |-- MathEngine/       # ReadinessCalculator.swift, WorkoutMathEngine.swift
    |       |   |-- AI/               # GeminiService.swift, FoodPrompt.swift, CoachPrompt.swift
    |       |   +-- Storage/          # SwiftDataModels.swift, SupabaseSyncService.swift
    |       |-- Features/             # Today/, Workouts/, Nutrition/, Trends/
    |       +-- Intents/              # LogMealIntent.swift, LifecoreSyncIntent.swift
    |-- supabase/migrations/          # SQL DDL for cloud backup
    |-- docs/                         # ARCHITECTURE.md, DATABASE.md, ROADMAP.md (English)
    +-- legacy_telegram/              # Archived Node.js & Deno Telegram bot code

### Supabase Cloud Backup Tables (docs/DATABASE.md)
1. meals: Existing schema (id, user_id, meal_name, kcal, protein, fat, carbs, weight_g, confidence, tags, micronutrients, amino_acids, dietary_date, created_at)[cite: 1].
2. workout_analyses (Replaces flat workouts + workout_splits join overhead):

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
        splits_json JSONB NOT NULL,
        laps_json JSONB,
        ai_coach_report TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW()
    );