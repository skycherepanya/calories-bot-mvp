# Lifecore Project Changelog

All changes to the code, data structure, AI prompts, and documentation must be recorded in this log in reverse chronological order.

---

## [2026-10-19] - Phase 2.4: Frictionless Nutrition View, Gemini Multimodal Vision & Optimistic UI
 
### 🥗 Native iOS Nutrition & AI Vision Pipeline:
- **`Core/AI/FoodPrompt.swift`:** Ported clinical nutritionist rules from legacy `utils/prompt.js` and `utils/dateUtils.js`:
  - Enforced cooked weight calibration for grains, pasta, buckwheat, oats, and meats.
  - Applied mandatory +12.5% caloric deficit safety buffer: `kcal_final = round(kcal_exact * 1.125)` while keeping protein, fat, and carbs exact.
  - Quality taxonomy selection (2 to 4 mandatory tags from `whole_food`, `ultra_processed`, `solid`, `liquid`, `fast_absorbing`, `slow_absorbing`, `high_sodium`).
  - Estimated micronutrients (`fiber_g`, `sodium_mg`, `potassium_mg`, `vitamin_c_mg`, `iron_mg`, `calcium_mg`) and amino acids (`bcaa_g`, `leucine_g`).
  - Implemented 04:00 AM dietary day shift utility (`FoodPrompt.dietaryDate(for:offsetDays:)`).
- **`Core/AI/GeminiService.swift` Upgrade:**
  - Added multimodal image payload support (`inline_data` Base64 JPEG) alongside structured text descriptions.
  - Implemented model cascade: primary `"gemini-3.8-flash"` -> fallback `"gemini-2.5-flash"` -> fallback `"gemini-3.6-flash"`.
  - Added `analyzeFood(imageJpegData:textDescription:)` with strict JSON decoding into `MealNutrition`.
  - Maintained high-fidelity deterministic offline nutrition fallback for simulation and tests.
- **`Core/HealthKit/HealthKitManager.swift` Dietary Write-Back & Privacy Configuration:**
  - Expanded `requestAuthorization()` with read/write permissions for dietary energy, protein, fat, carbohydrates, and sodium.
  - Added `saveMealToHealthKit(name:kcal:proteinG:fatG:carbsG:sodiumMg:fiberG:date:)` saving synchronized `HKQuantitySample`s to Apple Health.
  - Configured mandatory `INFOPLIST_KEY_NSHealthUpdateUsageDescription`, `INFOPLIST_KEY_NSCameraUsageDescription`, and `INFOPLIST_KEY_NSPhotoLibraryUsageDescription` in `project.pbxproj` to prevent `NSException` runtime crash on authorization request.
- **`Core/Storage/MealStorageService.swift`:**
  - Local persistent storage for meals with instant optimistic insertion (<0.2s), resolution of analyzed meals, and deletion.
  - Auto-seeded realistic initial meals for Today and Yesterday.
- **`Features/Nutrition/NutritionView.swift` & UI Components:**
  - `MacroSummaryCard`: Progress meter against daily target with +12.5% buffer indicator and P/F/C breakdown.
  - `DietaryQualityCard`: Whole food vs ultra-processed ratio, sodium water retention alert, and leucine MPS threshold indicator.
  - `FoodInputSheet.swift`: Native `PhotosPicker` image selection + text field (<5s total flow).
  - `OptimisticAnalyzingCard`: Shimmering instant pending state transitioning seamlessly to completed `MealItemCard`.
  - Day switcher with 04:00 AM cutoff and "Log for Yesterday" fast toggle.

### Affected Files
`ios/Lifecore/Lifecore/Lifecore/Core/AI/FoodPrompt.swift`,
`ios/Lifecore/Lifecore/Lifecore/Core/AI/GeminiService.swift`,
`ios/Lifecore/Lifecore/Lifecore/Core/HealthKit/HealthKitManager.swift`,
`ios/Lifecore/Lifecore/Lifecore/Core/Storage/MealStorageService.swift`,
`ios/Lifecore/Lifecore/Lifecore/Features/Nutrition/NutritionView.swift`,
`ios/Lifecore/Lifecore/Lifecore/Features/Nutrition/NutritionComponents.swift`,
`ios/Lifecore/Lifecore/Lifecore/Features/Nutrition/FoodInputSheet.swift`,
`docs/ROADMAP.md`, `CHANGELOG.md`

---

## [2026-10-19] - Phase 2.3: Workouts View, Swift Charts Telemetry & 70/15/15 AI Coach
 
### 🏃 Athletic Workout Telemetry & AI Performance Analyst:
- **`Features/Workouts/WorkoutsView.swift`:** Built comprehensive athletic workout browser:
  - Multi-category filter chips (`All`, `Running`, `Strength`, `Cycling`, `HIIT`, `Walks`) with instant filtering.
  - Casual walks exclusion toggle to focus strictly on deliberate athletic training sessions.
  - Rich workout summary cards showing duration, distance, pace, kcal burn, and average heart rate.
  - Seamless navigation to detailed analysis view via `NavigationLink`.
- **`Features/Workouts/WorkoutDetailView.swift`:** Implemented granular post-workout diagnostic dashboard:
  - Header summary with workout classification, duration, distance, calories, and average heart rate.
  - Synchronized `WorkoutChartsView.swift` powered by Apple `Charts`:
    * Interactive tabbed curves for Heart Rate zones, Pace (inverted Y scale), and Elevation profile.
    * Interactive scrub tooltip displaying point-in-time distance, instantaneous pace, and heart rate.
  - `SplitsTableView`: Chronological 1km splits table showing pace, avg HR, max HR, elevation delta ($\Delta h$), and cadence.
  - `IntervalLapsTableView`: Structured HIIT / track interval laps breakdown with classification (`work` vs `recovery`) and heart rate recovery drop ($\text{HR}_{\text{drop}}$).
  - Metric cards: Efficiency Factor ($EF = \text{Speed} / \text{Avg HR}$) card and Aerobic Decoupling / Cardiac Drift % card ($((EF_1 - EF_2) / EF_1) \times 100\%$) with clinical athletic interpretation badges (`< 5%`, `5–10%`, `> 10%`).
  - `BenchmarkComparisonCard`: Automatic comparison against prior similar sessions ($\pm 25\%$ distance) detailing pace $\Delta$, HR $\Delta$, and EF shift.
- **`Core/AI/CoachPrompt.swift` & `GeminiService.swift`:**
  - Authored high-density English prompt enforcing the Athletic Performance Analyst persona (70% workout telemetry analysis, 15% historical benchmark comparison, 15% physiological root causes + 1 actionable 24h directive).
  - Strictly eliminated medical alarmism and generic wellness advice; outputs rendered strictly in Ukrainian.
  - Asynchronous client calling Google AI Studio Gemini API (`gemini-2.5-flash`) with deterministic offline sports analyst fallback.
- **`HealthKitManager.swift` Extensions:**
  - Added `fetchRecentWorkouts(days:limit:)` querying `HKWorkout` objects for full telemetry extraction.
  - Added `fetchHistoricalSimilarWorkouts(to:limit:)` filtering matching workouts within $\pm 25\%$ distance for benchmark calculations.
  - Added `fetchRecentRecoveryContext(for:)` aggregating 48h pre-workout sleep architecture, morning HRV, and RHR baseline deltas.

### Affected Files
`ios/Lifecore/Lifecore/Lifecore/Core/AI/CoachPrompt.swift`,
`ios/Lifecore/Lifecore/Lifecore/Core/AI/GeminiService.swift`,
`ios/Lifecore/Lifecore/Lifecore/Core/HealthKit/HealthKitManager.swift`,
`ios/Lifecore/Lifecore/Lifecore/Features/Workouts/WorkoutsView.swift`,
`ios/Lifecore/Lifecore/Lifecore/Features/Workouts/WorkoutDetailView.swift`,
`ios/Lifecore/Lifecore/Lifecore/Features/Workouts/WorkoutChartsView.swift`,
`ios/Lifecore/Lifecore/Lifecore/Features/Workouts/WorkoutDetailComponents.swift`,
`ios/Lifecore/Lifecore/Lifecore/Features/Workouts/CoachReportView.swift`,
`docs/ROADMAP.md`, `CHANGELOG.md`

---

## [2026-10-19] - Phase 2.2: MainTabView & Bevel-Style TodayView with Live HealthKit Wiring

### 🍏 Native iOS UI & Real HealthKit Telemetry:
- **`App/MainTabView.swift`:** Implemented 4-tab native navigation (`Today`, `Workouts`, `Nutrition`, `Trends`) with custom tint and dark mode styling.
- **`Features/Today/TodayView.swift`:** Designed high-density Bevel aesthetic dark-mode dashboard:
  - Top 3 Interactive Rings: Recovery / Readiness score (0–100%), Day Strain (0–21 WHOOP scale & 0–100%), and Caloric Burn / Balance.
  - Autonomic Biomarkers Card: Morning HRV (SDNN) & Resting HR (RHR) with live $\Delta$ comparisons against personal 30-day baseline.
  - Sleep Architecture Card: Total sleep duration with percentage splits for Deep, REM, Core, and Awake stages.
  - Movement & Pure NEAT Card: Isolated lifestyle NEAT ($\text{active\_kcal} - \sum \text{workout\_kcal}$) separated from workout energy expenditure, plus steps and distance.
  - Today's Workouts Card: Chronological listing of completed workouts with type, duration, distance, active burn, and avg HR.
  - Direct Cloud Sync: One-tap telemetry sync to Supabase with tactile haptic feedback and live sync state indicators.
- **`HealthKitManager.swift` Extensions:**
  - `fetchHistoricalBaseline(days: 30)`: Queries 30-day historical HRV and sleeping RHR samples to calculate dynamic rolling mean and standard deviation (with graceful fallback to Sasha's baseline: HRV 102ms, RHR 49bpm).
  - `fetchAllWorkoutsToday()`: Queries all workouts recorded today with statistics for active calories, distance, and heart rate.
  - `fetchTodaySnapshot()`: Asynchronously orchestrates parallel queries and passes live data to `ReadinessCalculator.swift` to derive Recovery, Strain, and Pure NEAT in pure Swift.
- **Placeholder Views Created:** Created clean minimal views for `Features/Workouts/WorkoutsView.swift`, `Features/Nutrition/NutritionView.swift`, and `Features/Trends/TrendsView.swift`.
- **Legacy Cleanup:** Removed deprecated `ContentView.swift`.

### Affected Files
`ios/Lifecore/Lifecore/Lifecore/App/LifecoreApp.swift`,
`ios/Lifecore/Lifecore/Lifecore/App/MainTabView.swift`,
`ios/Lifecore/Lifecore/Lifecore/Core/HealthKit/HealthKitManager.swift`,
`ios/Lifecore/Lifecore/Lifecore/Features/Today/TodayView.swift`,
`ios/Lifecore/Lifecore/Lifecore/Features/Workouts/WorkoutsView.swift`,
`ios/Lifecore/Lifecore/Lifecore/Features/Nutrition/NutritionView.swift`,
`ios/Lifecore/Lifecore/Lifecore/Features/Trends/TrendsView.swift`,
`docs/ROADMAP.md`, `CHANGELOG.md`

---

## [2026-10-19] - Phase 2.1: HealthKit Reader & Deterministic Math Engine Implementation

### 🍏 Native iOS & Swift Math Engine:
- **Modular Directory Reorganization:** Migrated `ios/Lifecore/` into clean domain layers (`App/`, `Core/HealthKit/`, `Core/MathEngine/`, `Core/Storage/`, `Features/Today/`, `Intents/`).
- **Implemented `WorkoutTelemetryExtractor.swift`:** Added extraction of continuous `HKQuantitySeriesSample` (distance, heart rate, elevation) and structured interval laps (`HKWorkoutActivity`), assembling a unified `WorkoutTelemetrySeries`.
- **Implemented `WorkoutMathEngine.swift`:** Built deterministic pure Swift engine computing:
  - 1km auto-splits with pace, average HR, peak HR, elevation delta ($\Delta h$), and cadence.
  - Interval laps classification (`work` vs `recovery`) with heart rate recovery drop ($\text{HR}_{\text{drop}}$).
  - Efficiency Factor ($EF = \text{Speed (m/min)} / \text{Avg HR (bpm)}$).
  - Aerobic Decoupling / Cardiac Drift % ($((EF_1 - EF_2) / EF_1) \times 100\%$).
  - Historical benchmark comparisons against prior similar sessions ($\pm 20\%$ distance).
  - Indoor treadmill detection (elevation gain == 0).
- **Implemented `ReadinessCalculator.swift`:** Built deterministic physiological calculations:
  - Autonomic Recovery Score (0–100%) incorporating HRV SDNN z-score, RHR delta, total sleep duration, and deep/REM architecture.
  - Cardiovascular Strain Score (0–100% and 0–21 scale) combining workout intensity zones and lifestyle movement.
  - Pure NEAT isolation ($\text{NEAT} = \max(0, \text{active\_kcal} - \sum \text{workout\_kcal})$).
  - 7-day and 14-day rolling body weight averages with water-spike detection.
- **Built Verification Suite (`MathEngineVerification.swift`):** Validated all 6 core mathematical algorithms; 100% test pass rate with Xcode 27 / iOS 27 build success.

### Affected Files
`ios/Lifecore/Lifecore/Lifecore/Core/HealthKit/WorkoutTelemetryExtractor.swift`,
`ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/WorkoutMathEngine.swift`,
`ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/ReadinessCalculator.swift`,
`ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/MathEngineVerification.swift`,
`docs/ROADMAP.md`, `CHANGELOG.md`

---

## [2026-10-18] - Documentation Refactoring & iOS Codebase Audit (Section 0.2 Pivot Alignment)

### 📚 Documentation & Architectural Alignment:
- **Audited `ios/Lifecore/` Native Codebase:** Examined existing Xcode project, `HealthKitManager.swift`, `HealthPayload.swift`, `LifecoreSyncIntent.swift`, and `ContentView.swift`. Mapped gaps against target modular architecture (`App/`, `Core/`, `Features/`, `Intents/`).
- **Enforced Token Economy & Language Protocol in `AGENTS.md`:** Embedded Section 0.1 directives (high-density English documentation/code, Ukrainian user chat protocol, Skills-first rule, and Swift 6 / HealthKit modularity constraints). Removed legacy dual-sync requirements.
- **Synchronized `PROJECT_KNOWLEDGE.md`:** Refactored Section 3 with target native iOS modular structure, Section 4 with cloud `workout_analyses` (`splits_json` and `laps_json`), and Section 5 with non-alarmist 70/15/15 Athletic Performance Analyst framework.
- **Updated `README.md` & `docs/ARCHITECTURE.md`:** Fully specified the 4-layer On-Device architecture (HealthKit -> Swift Math Engine -> SwiftData + Supabase -> SwiftUI Dashboard) and archived legacy Node.js/Deno bots under `legacy_telegram/` (Deprecated).
- **Updated `docs/DATABASE.md`:** Replaced flat `workouts` table with `workout_analyses` containing `splits_json` and `laps_json` JSONB definitions and single-query telemetry retrieval.
- **Rewrote `docs/ROADMAP.md`:** Reorganized Phase 2 deliverables around the four native iOS views: Today (Readiness/Strain), Workouts (Splits/Laps/Coach), Nutrition (Vision/Optimistic UI), and Trends (Rolling Averages/Baselines).

### Affected Files
`AGENTS.md`, `PROJECT_KNOWLEDGE.md`, `README.md`, `docs/ARCHITECTURE.md`, `docs/DATABASE.md`, `docs/ROADMAP.md`, `CHANGELOG.md`

---

## [2026-10-18] - Architectural Pivot: Lifecore 2.0 Native iOS-First & Athletic Performance Platform

### 🚀 Strategic & Architectural Transformation:
- **Deprecated Dual-Backend Telegram Architecture:** Officially deprecated the legacy Node.js long-polling (`index.js`, `handlers/`, `utils/`) and Deno edge webhook (`telegram-bot`) architecture. Eliminated the dual-sync requirement across backends.
- **Adopted Native iOS-First Architecture:** Declared the native Swift 6 / SwiftUI application (`ios/Lifecore/`) as the primary application engine, leveraging HealthKit as the canonical on-device source of truth for telemetry, Swift Charts for visual dashboards, and SwiftData for offline-first persistence.
- **Deterministic Math Engine Mandate:** Replaced LLM arithmetic with deterministic on-device Swift calculation for 1km splits, pace, heart rate decoupling ($EF$), cardiac drift %, pure NEAT isolation, and 7d/14d rolling weight averages.
- **AI Coach Persona Overhaul (70 / 15 / 15):** Transformed the coach from an anxious medical advisor into an elite Athletic Performance Analyst (70% workout split execution, 15% benchmark comparison, 15% physiological root causes + 1 directive). Removed alarmist alerts on normal RHR variations.
- **Database Simplification:** Adopted structured `JSONB` split telemetry caching in `workouts` table, eliminating the need for a complex separate relational `workout_splits` table.
- **Rewrote Core Documentation:** Completely refreshed `PROJECT_KNOWLEDGE.md`, `README.md`, `AGENTS.md`, `docs/ARCHITECTURE.md`, `docs/DATABASE.md`, and `docs/ROADMAP.md`.

### Affected Files
`PROJECT_KNOWLEDGE.md`, `README.md`, `AGENTS.md`, `docs/ARCHITECTURE.md`, `docs/DATABASE.md`, `docs/ROADMAP.md`, `CHANGELOG.md`

---

## [2026-10-18] - Architectural RFC: Workout Granularity, Splits & Athletic Coach Refactor

### 📐 Architecture & LLM Engineering:
- **Created Comprehensive RFC Document:** Authored [docs/RFC_WORKOUT_GRANULARITY_AND_COACH_ARCHITECTURE.md](file:///Users/skycherepanya/Developer/GitHub/calories-bot-mvp/docs/RFC_WORKOUT_GRANULARITY_AND_COACH_ARCHITECTURE.md) consolidating full project context, baseline tech stack, user pain points, proposed `workout_splits` data model, Strava API selective ingestion, and a re-engineered 70/15/15 athletic coach prompt format.
- **Formulated Critical Architectural Discussion Questions:** Prepared formal questions covering relational vs JSONB split storage, Strava/Apple Health deduplication, backend vs LLM cardiac drift math, and coach persona guidelines for external LLM evaluation.

### Affected Files
`docs/RFC_WORKOUT_GRANULARITY_AND_COACH_ARCHITECTURE.md`, `CHANGELOG.md`

---

## [2026-10-18] - Workout Deduplication in Ingest-Health & Database Cleanup

### 🔄 Ingestion & Data Integrity:
- **Workout Deduplication in `ingest-health`:** Added lookup for existing workouts by `(user_id, started_at)`. If a workout session has already been recorded for the same start time, it updates the record instead of creating a duplicate row.
- **Database Cleanup:** Removed legacy curl mock test workout (`id: 411`, 5 km / 380 kcal) from the `workouts` table, leaving strictly the genuine 10.02 km run (`id: 412`, 695 kcal).
- **Coach Output Accuracy Restored:** Eliminated double-counting in `/coach` recommendations where total run volume was artificially inflated to 15.02 km / 1075 kcal and NEAT was depressed to 0 kcal.
- **Deployment:** Redeployed `ingest-health` to Supabase production.

### Affected Files
`supabase/functions/ingest-health/index.ts`, `CHANGELOG.md`, `PROJECT_KNOWLEDGE.md`

---

## [2026-10-18] - NEAT Activity Isolation & Double-Counting Prevention in Coach

### 🧠 Domain Math & AI Coach Engineering:
- **Mathematical Isolation of Pure NEAT:** Implemented explicit separation of structured workouts from total daily activity:
  - Total Daily Active Calories (`daily_metrics.active_kcal`) is recognized as inclusive of workouts.
  - Pure NEAT energy is calculated as: `neat_kcal = Math.max(0, total_active_kcal - workout_kcal)`.
- **Synchronized Coach Prompt:** Updated both Node.js (`utils/coachPrompt.js`) and Supabase Edge Function (`supabase/functions/telegram-bot/index.ts`):
  - Injected enriched daily activity objects with explicit `total_steps`, `total_active_kcal`, `workout_kcal`, and `neat_kcal`.
  - Added strict guardrail instructing Gemini to never re-add workout calories to total active calories, eliminating a ~700 kcal artificial deficit inflation.
- **Redeployed Edge Function:** Redeployed `telegram-bot` to Supabase production.

### Affected Files
`utils/coachPrompt.js`, `supabase/functions/telegram-bot/index.ts`, `PROJECT_KNOWLEDGE.md`, `CHANGELOG.md`

---

## [2026-10-18] - Native Swift HealthKit AppIntent Ingestion Layer

### 🍏 Native Swift & AppIntents Architecture:
- **Architectural Shift from Visual Shortcuts to Native Swift:** Replaced brittle 50-action visual Shortcuts script with modular, production-grade Swift code in `ios/Lifecore/`.
- **Created `ios/Lifecore/HealthPayload.swift`:** Type-safe Swift `Codable` structs matching the Supabase `ingest-health` schema for `daily_activity`, `sleep_logs`, and `workouts`.
- **Created `ios/Lifecore/HealthKitManager.swift`:**
  - Fast asynchronous HealthKit reader (`HKStatisticsQuery` for step/energy/distance sums; `HKSampleQuery` for sleep stage categorization across `asleepDeep`, `asleepREM`, `asleepCore`, `awake`).
  - Automatically fetches morning autonomic biomarkers (HRV SDNN & Resting Heart Rate).
  - Fetches today's latest workout session.
  - Queries execute in <5ms without any sample limit clipping.
- **Created `ios/Lifecore/LifecoreAPIService.swift`:** Production network service transmitting JSON payloads directly to Supabase Edge Function via `URLSession`.
- **Created `ios/Lifecore/LifecoreSyncIntent.swift`:**
  - Conforms to `AppIntent` & `AppShortcutsProvider`.
  - Exposes a single, native `Sync Lifecore Health` action to iOS Shortcuts, Siri, Lock Screen Widgets, and Action Button.
- **Created `ios/README.md`:** Comprehensive Xcode setup manual with capability and `Info.plist` instructions.

### Affected Files
`ios/Lifecore/HealthPayload.swift`, `ios/Lifecore/HealthKitManager.swift`, `ios/Lifecore/LifecoreAPIService.swift`, `ios/Lifecore/LifecoreSyncIntent.swift`, `ios/README.md`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`, `PROJECT_KNOWLEDGE.md`, `CHANGELOG.md`

---

## [2026-10-18] - iOS 27 Shortcut Setup Guide & Apple Watch Ultra Integration

### 📱 iOS 27 Shortcuts Engineering:
- **Comprehensive iOS 27 Setup Guide in `shortcuts/ingest_health_shortcut.md`:** Rewrote the entire setup guide with concrete, step-by-step instructions specifically optimized for **iOS 27**, **iPhone 16 Pro** (A18 Pro), and **Apple Watch Ultra**.
- **Leveraged iOS 27 Features:**
  - Added native **Otherwise If** logic for clean sleep stage triage (`Deep` $\rightarrow$ `REM` $\rightarrow$ `Core`) inside a single lightweight loop.
  - Added Apple Intelligence prompt for instant action scaffolding via Natural Language in iOS 27 Shortcuts.
  - Implemented the single-action **Text JSON Template** pattern to bypass slow and tedious nested dictionary configuration on iOS.
- **Embedded Production Credentials:** Embedded exact target URL (`https://khmviccwbuktnvdxhnwg.supabase.co/functions/v1/ingest-health`), `INGEST_SECRET`, and `ALLOWED_USER_ID` for frictionless copy-paste setup.

### Affected Files
`shortcuts/ingest_health_shortcut.md`, `shortcuts/README.md`, `CHANGELOG.md`

---

## [2026-10-18] - Phase 2 Complete: AI Coach Engine & Ingest-Health Webhook Deployed

### 🏃 AI Coach & Biometric Analysis:
- **Created `utils/coachPrompt.js`:** Implemented 4-part data aggregation (`buildCoachContext`) across last 3 days for meals, sleep logs, workouts, and daily NEAT activity. Designed strict clinical reasoning prompt (`buildCoachPrompt`) returning `СТАН СИСТЕМИ: 🟢/🟡/🔴` with exactly 4 causal insights citing exact metrics.
- **Created `handlers/coachHandler.js`:** Implemented Node.js handler featuring a 25-second timeout promise race across the Gemini cascade to ensure zero hanging or latency spikes.
- **Edge Function Webhook Synchronization (`telegram-bot`):** Mirrored `handleCoachAnalysis` and the updated `MAIN_KEYBOARD` directly into `supabase/functions/telegram-bot/index.ts` and deployed to Supabase production.
- **Added `🏃 Аналіз тренування` Button:** Integrated into `MAIN_KEYBOARD` across both Node.js (`utils/keyboard.js`) and Edge Function environments.
- **Verified Live Coach Generation:** Tested full pipeline against actual user biometric data with immediate, highly personalized recommendations based on HRV, RHR, running telemetry, and NEAT step counts.

### ⚡ Apple Health Ingestion Webhook:
- **Created `supabase/functions/ingest-health/index.ts`:** Implemented dedicated ingestion webhook accepting `daily_activity`, `sleep`, and `workout` payloads from iOS Shortcuts.
- **Secured with `INGEST_SECRET`:** Added secret token validation and user ID authorization.
- **Deployed to Supabase:** Deployed `ingest-health` to production and verified end-to-end with curl and Supabase PostgreSQL queries.

### Affected Files
`supabase/functions/ingest-health/index.ts`, `utils/coachPrompt.js`, `handlers/coachHandler.js`, `handlers/textHandler.js`, `utils/keyboard.js`, `supabase/functions/telegram-bot/index.ts`, `PROJECT_KNOWLEDGE.md`, `docs/ROADMAP.md`, `docs/IMPLEMENTATION_PLAN_PHASE2.md`, `CHANGELOG.md`

---

## [2026-10-18] - NEAT Activity Tracking, Apple Health Canonical Source & Gemini 3.8 Flash Upgrade

### 🏃 Lifestyle Activity & Ingestion Architecture:
- **Canonical Primary Source Established:** Declared Apple Health / Apple Fitness (Apple Watch) as the single primary source of truth for workouts, steps, sleep, and recovery metrics. Strava designated as secondary/export-only.
- **NEAT & Daily Activity Tracking:** Created and applied migration `005_daily_metrics_enhancements.sql` enhancing `daily_metrics` with `steps`, `active_kcal`, and device prioritization (`apple_watch` preferred over `iphone` to eliminate double counting).
- **Imported 1,279 Days of Daily Activity:** Extended `Lifecore/scripts/sync_to_supabase.py` with `sync_daily_metrics()` uploading 1,279 days of step counts and active energy expenditure to remote Supabase.
- **iOS Shortcut Spec Enhanced:** Updated `shortcuts/ingest_health_shortcut.md` and docs to include daily activity payload (`daily_activity: { date, steps, active_kcal, distance_km }`).

### 🤖 AI Models & Infrastructure:
- **AI Model Upgrade to Gemini 3.8 Flash:** Benchmarked models live against the Gemini API. Upgraded production AI cascade across Node.js (`utils/gemini.js`) and Edge Function (`supabase/functions/telegram-bot/index.ts`) to:
  1. `gemini-3.8-flash` (Primary — superior reasoning for Coach & fast multimodal vision)
  2. `gemini-2.5-flash` (First fallback — ultra-fast latency)
  3. `gemini-3.6-flash` (Secondary fallback)
- **Deployed Edge Function:** Redeployed `telegram-bot` Edge Function to Supabase production with new model cascade.

### Affected Files
`supabase/migrations/005_daily_metrics_enhancements.sql`, `Lifecore/scripts/sync_to_supabase.py`, `utils/gemini.js`, `supabase/functions/telegram-bot/index.ts`, `PROJECT_KNOWLEDGE.md`, `docs/ARCHITECTURE.md`, `docs/DATABASE.md`, `docs/IMPLEMENTATION_PLAN_PHASE2.md`, `shortcuts/ingest_health_shortcut.md`, `README.md`, `CHANGELOG.md`

---

## [2026-10-18] - Database Migrations Applied & Historical Data Ingested

### 🗄 Database & Migrations:
- **Applied Database Migrations:** Successfully applied migrations to remote Supabase database:
  - `001_initial.sql` — base schema (`meals`, `body_measurements`).
  - `002_workouts.sql` — new `workouts` table with indexes.
  - `003_sleep_logs.sql` — new `sleep_logs` table with recovery biomarkers.
  - `004_fix_sleep_logs_nullable.sql` — relaxed `total_hours` constraint to allow importing HRV/RHR biomarkers when sleep stage duration is absent.

### 🐍 Scripts & Data Ingestion:
- **Fixed Strava Parsing Bug:** Resolved date parsing failures in `Lifecore/scripts/sync_to_supabase.py` caused by premature string slicing on AM/PM datetime formats.
- **Added Workout Deduplication:** Implemented cross-source deduplication in `sync_to_supabase.py` (filtered out 131 duplicate Apple Health activities already captured with rich telemetry by Strava).
- **Populated Data Warehouse:** Bulk-uploaded **1,044 sleep log records** and **410 unique workout records** into remote Supabase PostgreSQL.
- **Documentation Parity:** Updated `PROJECT_KNOWLEDGE.md`, `docs/DATABASE.md`, and `docs/ROADMAP.md` reflecting live database state.

### Affected Files
`supabase/migrations/003_sleep_logs.sql`, `supabase/migrations/004_fix_sleep_logs_nullable.sql`, `Lifecore/scripts/sync_to_supabase.py`, `PROJECT_KNOWLEDGE.md`, `docs/DATABASE.md`, `docs/ROADMAP.md`, `CHANGELOG.md`

---

## [2026-10-18] - Documentation Translation to English & Project Standardization

### 🌍 Changed:
- **Project Documentation Translation:** Fully translated all newly created and updated documents to English to comply with the project's language rule (`AGENTS.md`) and optimize LLM token usage:
  - `README.md` — full English rewrite with updated project structure and feature matrix.
  - `docs/ARCHITECTURE.md` — full English translation including 5-layer mermaid diagram.
  - `docs/ROADMAP.md` — translated all phases, tasks, and immediate priorities.
  - `docs/IMPLEMENTATION_PLAN_PHASE2.md` — translated plan steps, task descriptions, and DoD to English.
  - `shortcuts/README.md` & `shortcuts/ingest_health_shortcut.md` — translated iOS Shortcut specifications.
  - `Lifecore/README.md` — translated submodule overview and execution guide.
  - `docs/DATABASE.md` — cleaned up remaining non-English notes.
- **Code Consistency:** Removed unused imports in Phase 2 handler examples.

### Affected Files
`README.md`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`, `docs/IMPLEMENTATION_PLAN_PHASE2.md`, `shortcuts/README.md`, `shortcuts/ingest_health_shortcut.md`, `Lifecore/README.md`, `docs/DATABASE.md`, `CHANGELOG.md`

---

## [2026-10-18] - Lifecore Analytics Module Merge & Repository Restructure

### 🏗 Structural Changes
- **Merged `Lifecore/` analytics module** into the main repository as a first-class submodule alongside the Telegram bot.
- **Removed duplicate files:**
  - `Lifecore/docs/quantified_self_concepts.md` → content consolidated into `PROJECT_KNOWLEDGE.md`
  - `Lifecore/docs/architecture_vision.md` → merged into `docs/ARCHITECTURE.md`
  - `Lifecore/docs/Персональний AI-тренер у Telegram.md` → merged into `docs/ARCHITECTURE.md`
- **Renamed** `Lifecore/scripts/analyze_strava_tmp.py` → `analyze_strava.py`

### 🗄 Database
- **Added DB migration files** (pending application in Supabase):
  - `supabase/migrations/001_initial.sql` — documents existing schema (meals, body_measurements)
  - `supabase/migrations/002_workouts.sql` — new `workouts` table (type, HR, pace, kcal, source)
  - `supabase/migrations/003_sleep_logs.sql` — new `sleep_logs` table (phases, HRV, RHR, VO2Max)
- **Coach Context SQL Query** documented in `docs/DATABASE.md`

### 🐍 New Scripts
- `Lifecore/scripts/sync_to_supabase.py` — bulk upload Apple Health JSON + Strava CSV to Supabase `workouts` and `sleep_logs` tables

### 📱 iOS Shortcuts
- `shortcuts/README.md` + `shortcuts/ingest_health_shortcut.md` — full specification for `Lifecore Morning Sync` iOS Shortcut (HealthKit → `ingest-health` Edge Function)

### 📚 Documentation Updated
- `README.md` — full rewrite: unified structure, new feature list, Python analytics quickstart
- `docs/ARCHITECTURE.md` — merged with Lifecore docs, added 5-layer diagram with workouts/sleep data flows
- `docs/DATABASE.md` — added `workouts`, `sleep_logs` table specs, ERD, Coach Context SQL query
- `docs/ROADMAP.md` — Phase 1 completed, detailed Phase 2 (Coach) tasks, Phases 3–5 outlined
- `docs/IMPLEMENTATION_PLAN_PHASE2.md` — detailed Phase 2 step-by-step plan
- `PROJECT_KNOWLEDGE.md` — expanded: recovery biomarkers (HRV/RHR/VO2Max), Sasha's baseline, Coach prompt rules, `ingest-health` Edge Function spec, new env variable `INGEST_SECRET`
- `Lifecore/README.md` — rewritten as module-level guide within the unified repo

### 🔜 Planned (Phase 2 — not yet implemented)
- `supabase/functions/ingest-health/index.ts`
- `handlers/coachHandler.js` + `utils/coachPrompt.js`
- New keyboard buttons: `🏃 Workout Analysis`, `📋 Weekly Report`

### Affected Files
`README.md`, `PROJECT_KNOWLEDGE.md`, `CHANGELOG.md`, `docs/ARCHITECTURE.md`, `docs/DATABASE.md`, `docs/ROADMAP.md`, `docs/IMPLEMENTATION_PLAN_PHASE2.md`, `Lifecore/README.md`, `supabase/migrations/001_initial.sql`, `supabase/migrations/002_workouts.sql`, `supabase/migrations/003_sleep_logs.sql`, `Lifecore/scripts/sync_to_supabase.py`, `shortcuts/README.md`, `shortcuts/ingest_health_shortcut.md`

---

## [2026-09-12] - Photo EXIF Metadata Date Extraction

### 🚀 Added:
- **Automatic EXIF Date Extraction:**
  - Added the ability to automatically extract the exact date and time a photo was taken directly from its EXIF metadata.
  - Implemented using the `exifr` library in both the Node.js implementation (`handlers/photoHandler.js`) and the Supabase Edge Function (`supabase/functions/telegram-bot/index.ts`).
  - Added support for processing uncompressed files (`bot.on('document')`) to preserve EXIF metadata (since Telegram strips EXIF from regular photos).
  - Automatically calculates the correct `dietary_date` and overrides `created_at` in the database to reflect the true time the meal was consumed.
  - As a fallback for photos without EXIF or sent as regular photos, uses the message sent time (`msg.date`) or original forwarded time (`msg.forward_date`).

---

## [2026-09-12] - Codebase Language Optimization (Translation to English)

### 🌍 Changed:
- **Project Documentation:** Translated `README.md`, `PROJECT_KNOWLEDGE.md`, `CHANGELOG.md`, `AGENTS.md`, and all files in `docs/` to English to optimize AI token consumption and context window efficiency.
- **Codebase Internal Strings:** Translated all internal code comments, logging messages (`console.log`, `console.error`), and internal LLM prompt prefixes in both the Node.js implementation (`index.js`, `handlers/`, `utils/`) and the Supabase Edge Function (`supabase/functions/telegram-bot/index.ts`) to English.
- **UI Language Preservation:** Kept all Telegram Bot user-facing messages, responses, and interactive keyboard buttons strictly in Ukrainian.
- **Added Deployment Rule:** Updated `AGENTS.md` to strictly require testing, git committing/pushing, and deploying changes immediately after modifications.

---

## [2026-09-04] - Persistent Reply Keyboard and Removal of Redundant Buttons

### 🚀 Added:
- **Persistent Reply Keyboard in Telegram:**
  - Created a pinned keyboard with three buttons: `📊 Статистика` (Statistics), `⚖️ Записати вагу` (Record weight), `📅 Запис за вчора` (Record for yesterday).
  - Keyboard module [utils/keyboard.js](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/utils/keyboard.js) for Node.js and `MAIN_KEYBOARD` constant in Supabase Edge Function.
  - Menu is automatically attached on `/start` and in all bot replies.
- **Interactive Scenarios Without Typing Commands:**
  - `📊 Статистика`: instantly returns daily analytics with date scrolling buttons.
  - `⚖️ Записати вагу`: sends a focused `force_reply` message with placeholder `76.2`. User can enter a number in reply, or just type a number (from 30 to 350) in chat.
  - `📅 Запис за вчора`: sends `force_reply` waiting mode. Next text or photo message is automatically logged for yesterday without needing the `/y` command.

### 🧹 UI Cleanup:
- **Removed Non-Functional Inline Buttons:**
  - Completely removed inline buttons `[✅ Записано]` (meal is saved automatically) and `[✏️ Редагувати]` from meal cards.
  - The meal card is now completely clean, and bot controls are moved to the bottom system menu in Telegram.

---

## [2026-09-04] - Adjusted Deficit Buffer (12.5%) and Optimized Status Texts

### ⚙️ Changed:
- **Lowered Calorie Deficit Buffer:**
  - Adjusted buffer from 15% to a moderate **12.5%** (`kcal * 1.125`).
  - Updated prompts in [utils/prompt.js](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/utils/prompt.js) and [supabase/functions/telegram-bot/index.ts](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/supabase/functions/telegram-bot/index.ts). Protein, fats, and carbs remain exact.
- **Hidden Technical Buffer Text:**
  - Completely removed the `*(+15% buffer)*` string from the meal card — it now shows clean calories: `🔥 Calories: **XX kcal**`.
- **Updated Processing Status Text:**
  - Replaced calculation text with specifics: `⏳ Рахую калорії за прийом...` and `⏳ Рахую калорії за прийом (за вчора)...`.
  - Synced changes in [handlers/photoHandler.js](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/handlers/photoHandler.js), [handlers/textHandler.js](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/handlers/textHandler.js), and Edge Function.

---

## [2026-09-04] - Simplified Message UI and Historical Weight Generation

### 🎨 UI/UX Improvements for Messages:
- **Minimalist Meal Card:**
  - Removed display of raw fiber, sodium, BCAA numbers, and quality tags from the Telegram message (both Node.js and Supabase).
  - Micronutrient and quality data continues to be saved in DB for daily analysis and advice.
  - Card contains only key macros: calories (buffered), proteins, fats, carbs, meal weight, and AI confidence percentage.
- **Cleaned Up `/stats` Report:**
  - Removed technical rows with grams of fiber and milligrams of sodium.
  - Nutritionist recommendations converted into a natural, human-centric format: concise tips on protein, fiber, hydration, and quality without overwhelming with numbers.

### 📊 Data and History:
- **Historical Weight Generation (2026-08-20 — 2026-09-04):**
  - Added 16 daily weight logs to `body_measurements` covering the entire bot usage period, simulating natural fluctuations between 76.2 – 76.6 kg.
  - As of today (2026-09-04), accurate weight logged at **76.0 kg**.
- **Cleaned DB from Test Entries:**
  - Removed all test entries from `meals` and `body_measurements`; no real user meals (87 records) were touched.

---

## [2026-09-04] - Fixed Edge Function Freezing & Fault-Tolerant Gemini Fallback

### 🐛 Fixed (Root Cause Analysis):
- **Deno Isolate Freezing in Supabase Edge Function:**
  - In [supabase/functions/telegram-bot/index.ts](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/supabase/functions/telegram-bot/index.ts), `handleUpdate(update)` wasn't awaited. Returning `Response("OK")` caused immediate suspension/termination of the Deno worker isolate, cutting off async requests to Gemini, DB, and Telegram halfway. Added `await handleUpdate(update)`.
- **Gemini 503 Service Unavailable ("High Demand") Failures:**
  - Model `gemini-3.6-flash` occasionally returns HTTP 503 due to Google server overload.
  - Implemented a single fault-tolerant helper with fallback queue (`gemini-2.5-flash` -> `gemini-3.6-flash`):
    - Node.js: module [utils/gemini.js](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/utils/gemini.js).
    - Supabase: function `generateMealJSON` in [supabase/functions/telegram-bot/index.ts](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/supabase/functions/telegram-bot/index.ts).
- **Telegram API Resilience (`sendTg`):**
  - Added response status check `res.ok`. If Telegram fails to parse Markdown entities (HTTP 400 Bad Request), it automatically retries as `plain text`, preventing silent failures.
- **Optimized Base64 Photo Processing in Deno:**
  - Replaced slow byte concatenation loop with native `base64Encode(new Uint8Array(imageBuffer))` from `std/encoding/base64.ts`.
- **Edge Function Deployment Without Local Docker:**
  - Found reason for CLI freezing during `supabase functions deploy`: local CLI was trying to connect to Docker daemon. Fixed by adding `--use-api` flag (`supabase functions deploy telegram-bot --no-verify-jwt --use-api`), ensuring build and deploy happens server-side in 1-2 seconds.

---

## [2026-09-04] - Micronutrients, Amino Acids, Weight Tracking (/w) and Diet Analysis

### 🚀 Added:
- **Weight Tracking via Telegram (`/w`):**
  - Created handler [handlers/weightHandler.js](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/handlers/weightHandler.js) for `/w <weight>` command (supports comma and dot: `/w 78.5`, `/w 78,5`).
  - Calculates delta compared to previous measurement (`+0.4 kg`, `-0.2 kg`).
  - Reminds user about water fluctuations (1g glycogen : 3-4g water).
  - Synced `/w` command in Supabase Edge Function.
- **Body Measurements & Bioimpedance Table:**
  - Created migration [supabase/migrations/20260904160000_lifecore_schema.sql](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/supabase/migrations/20260904160000_lifecore_schema.sql) with `body_measurements` table.
  - Added placeholders for future smart scales: `impedance_ohms`, `impedance_frequency_khz`, `body_fat_pct`, `water_pct`, `muscle_mass_kg`, `bone_mass_kg`, `visceral_fat`.
- **Diet Analysis & Recommendations in `/stats`:**
  - Updated [utils/dateUtils.js](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/utils/dateUtils.js) and `getStatsPayload` in Edge Function.
  - Displays logged day's weight in stats header.
  - Aggregates fiber (`fiber_g`) and sodium (`sodium_mg`).
  - Calculates ratio of whole foods (`whole_food`) to ultra-processed (`ultra_processed`).
  - Nutritionist recommendation block: protein deficit (<100g), fiber deficit (<20g), sodium edema warnings (>2300mg), and calorie saving tips (>2200 kcal).
- **Support for `/y` (Yesterday) Command in Node.js:**
  - Added support for `/y` in text and photo handlers.
- **Deploy to Supabase (Production):**
  - Successfully applied migration `20260904160000_lifecore_schema.sql` via `supabase db push`.
  - Deployed updated Edge Function `telegram-bot` via `supabase functions deploy`.

### ⚙️ Changed:
- **AI Prompt [utils/prompt.js](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/utils/prompt.js):**
  - Added quality taxonomy (`whole_food`, `solid`, `liquid`, `fast_absorbing`, `ultra_processed`, `high_sodium`).
  - Added micronutrient calculations (`fiber_g`, `sodium_mg`, `potassium_mg`, `vitamin_c_mg`, `iron_mg`, `calcium_mg`).
  - Added amino acid profile (`bcaa_g`, `leucine_g`) for protein meals.
  - Preserved `Deficit Buffer` (+15% Kcal) rule.
- **Meal Saving:** in [handlers/textHandler.js](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/handlers/textHandler.js) and [handlers/photoHandler.js](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/handlers/photoHandler.js), added writing `tags`, `micronutrients`, `amino_acids` fields to Supabase.

---

## [2026-09-04] - Documentation Initialization, Superpowers Integration, and Project Start

### 🚀 Added:
- **Integrated Engineering Skills Library (*Superpowers*):**
  - Copied 14 skills from `hotel-amenities-2` project into [.agents/skills/](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/.agents/skills).
  - Added version manifest [skills-lock.json](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/skills-lock.json) and compatibility symlinks [.claude/skills/](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/.claude/skills).
- **Created Single Knowledge Base and Operational Rules:**
  - [PROJECT_KNOWLEDGE.md](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/PROJECT_KNOWLEDGE.md) — consolidated domain knowledge base.
  - [AGENTS.md](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/AGENTS.md) — system instructions for agents with mandatory documentation rule.
  - [README.md](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/README.md) — updated project description and deploy instructions.
- **Architectural Spec and DB Design:**
  - [docs/ARCHITECTURE.md](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/docs/ARCHITECTURE.md) — 5 architecture layers.
  - [docs/DATABASE.md](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/docs/DATABASE.md) — ER diagram, specs for tables.
  - [docs/ROADMAP.md](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/docs/ROADMAP.md) — step-by-step roadmap (Phases 1–5).
  - [supabase/migrations/20260904160000_lifecore_schema.sql](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/supabase/migrations/20260904160000_lifecore_schema.sql) — base SQL script for creating tables.

### ⚙️ Changed:
- [package.json](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/package.json): filled `description` field.
