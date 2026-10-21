# Phase 2.6: Local Storage & Cloud Backup (SwiftData + Supabase Sync + LogMealIntent) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish local-first persistence with SwiftData for nutrition and workout analyses, direct REST synchronization to Supabase PostgreSQL, and voice/shortcut meal logging via `LogMealIntent`.

**Architecture:** 
- **Local Persistence (SwiftData):** Strictly two domain models: `MealEntity` and `WorkoutAnalysisEntity`. (HealthKit remains the canonical single source of truth for raw biometrics, sleep architecture, and activity totals without duplicate local storage).
- **Cloud Warehouse (Supabase REST API):** Direct Swift client (`SupabaseSyncService`) communicating with Supabase PostgreSQL tables (`meals`, `workout_analyses`, `daily_metrics`, `sleep_logs`) with offline resilience.
- **System Integration (AppIntents):** `LogMealIntent` integrating Siri, Action Button, and Shortcuts for hands-free nutrition capture.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, AppIntents, HealthKit, Supabase PostgreSQL REST API.

**Spec:** [docs/ROADMAP.md](file:///Users/skycherepanya/Developer/GitHub/calories-bot-mvp/docs/ROADMAP.md) (Phase 2, Step 2.6), [docs/DATABASE.md](file:///Users/skycherepanya/Developer/GitHub/calories-bot-mvp/docs/DATABASE.md) (`meals` and `workout_analyses`), [PROJECT_KNOWLEDGE.md](file:///Users/skycherepanya/Developer/GitHub/calories-bot-mvp/PROJECT_KNOWLEDGE.md) (Section 3.2 & Section 4).

## Global Constraints
- **Token Economy:** All documentation, code, variable names, and comments strictly in concise English.
- **Ukrainian Output:** User-facing notifications, Siri dialogs, and labels strictly in Ukrainian.
- **Lean SwiftData (Zero HealthKit Duplication):** Strictly create `MealEntity` and `WorkoutAnalysisEntity`. Do NOT duplicate sleep or steps in SwiftData.
- **Deficit Buffer (+12.5%):** Ensure `MealEntity.kcal` persists the buffered calories (`kcal_final = round(kcal_exact * 1.125)`).
- **4-Hour Dietary Day Shift:** All records enforce `dietaryDate` with 04:00 AM cutoff.
- **Offline Resilience:** If offline, local operations complete instantly and mark `syncedToCloud = false`.

---

### Task 1: SwiftData Domain Models (`Core/Storage/SwiftDataModels.swift`)
- Create `ios/Lifecore/Lifecore/Lifecore/Core/Storage/SwiftDataModels.swift` defining:
  - `@Model final class MealEntity`:
    - `id: UUID` (unique)
    - `name: String`
    - `kcal: Double` (stores final kcal with +12.5% buffer)
    - `proteinG: Double`
    - `fatG: Double`
    - `carbsG: Double`
    - `weightG: Double?`
    - `confidence: Double?`
    - `tags: [String]`
    - `micronutrientsJson: String?`
    - `aminoAcidsJson: String?`
    - `dietaryDate: String` (YYYY-MM-DD, 04:00 AM cutoff)
    - `createdAt: Date`
    - `isOptimisticPending: Bool`
    - `syncedToCloud: Bool`
    - `remoteId: Int64?`
    - Helpers: conversion from/to `MealRecord` and `MealNutrition`.
  - `@Model final class WorkoutAnalysisEntity`:
    - `id: UUID` (unique)
    - `workoutUUID: UUID` (HealthKit workout identifier)
    - `workoutType: String`
    - `startedAt: Date`
    - `distanceMeters: Double`
    - `durationSeconds: Double`
    - `avgPaceSecPerKm: Double?`
    - `avgHeartRate: Double?`
    - `maxHeartRate: Double?`
    - `elevationGainMeters: Double?`
    - `efficiencyFactor: Double?`
    - `cardiacDriftPercentage: Double?`
    - `splitsJson: String` (serialized array of `Split1km`)
    - `lapsJson: String` (serialized array of `IntervalLap`)
    - `aiCoachReport: String?`
    - `createdAt: Date`
    - `updatedAt: Date`
    - `syncedToCloud: Bool`
    - Helpers: conversion from/to `WorkoutAnalysisResult`.

### Task 2: Configure SwiftData Container in `LifecoreApp.swift`
- In `ios/Lifecore/Lifecore/Lifecore/App/LifecoreApp.swift`:
  - Attach `.modelContainer(for: [MealEntity.self, WorkoutAnalysisEntity.self])` to the root `WindowGroup`.
  - Provide a shared `ModelContainer` accessor for background services and intents.

### Task 3: Refactor `MealStorageService.swift` to use SwiftData
- Upgrade `MealStorageService.swift`:
  - Initialize with SwiftData `ModelContext` / `ModelContainer`.
  - Migrate any existing meals from `UserDefaults` into SwiftData on first run.
  - Expose published list of meals synced with SwiftData queries.
  - Implement `insertOptimisticPending`, `resolvePending`, `addMeal`, and `deleteMeal` with SwiftData mutations.

### Task 4: SwiftData Caching in `WorkoutDetailView` & `CoachReportView`
- In `WorkoutDetailView.swift`:
  - Check SwiftData for existing `WorkoutAnalysisEntity` for the current workout UUID before querying raw telemetry or Gemini.
  - If cached analysis exists, load splits, laps, EF, and AI coach report instantly (<5ms).
  - When new analysis is computed or refreshed, save or update `WorkoutAnalysisEntity` in SwiftData.
- In `CoachReportView.swift`:
  - Read existing cached report from `WorkoutAnalysisEntity` if available.
  - Update `WorkoutAnalysisEntity.aiCoachReport` when new report is generated.

### Task 5: Supabase Database Migration `006_workout_analyses.sql`
- Create `supabase/migrations/006_workout_analyses.sql`:
  - Table `public.workout_analyses` with `id UUID`, `user_id BIGINT`, `healthkit_workout_uuid TEXT UNIQUE`, metric columns, `splits_json JSONB`, `laps_json JSONB`, `ai_coach_report TEXT`, timestamps.
  - Indexes on `user_id`, `healthkit_workout_uuid`, `started_at DESC`.
  - Push migration to remote database via `supabase db push`.

### Task 6: Direct Cloud Sync Service (`Core/Storage/SupabaseSyncService.swift`)
- Create `ios/Lifecore/Lifecore/Lifecore/Core/Storage/SupabaseSyncService.swift`:
  - Supabase REST client using standard URLSession and Supabase API keys.
  - `syncPendingMeals()`: fetches unsynced `MealEntity` rows and POSTs to `/rest/v1/meals`, updates `syncedToCloud = true`.
  - `syncWorkoutAnalysis(entity:)`: upserts `WorkoutAnalysisEntity` to `/rest/v1/workout_analyses`.
  - `syncTelemetry(dailyActivity:sleepLog:workout:)`: sends daily summary directly to `/rest/v1/daily_metrics` and `/rest/v1/sleep_logs`.
  - Offline handling: silent retry on failure, non-blocking background queue.
  - Update `TodayView.swift` to use `SupabaseSyncService.shared` for cloud sync.

### Task 7: AppIntent Food Logging (`Intents/LogMealIntent.swift`)
- Create `ios/Lifecore/Lifecore/Lifecore/Intents/LogMealIntent.swift`:
  - Conforms to `AppIntent`, `ProvidesDialog`.
  - Parameter `@Parameter(title: "Meal Description") var mealDescription: String`.
  - Siri prompt: "Що ти з'їв?" / "Log Meal in Lifecore".
  - Creates optimistic meal card in `MealStorageService` with current `dietaryDate`.
  - Asynchronously calls `GeminiService.shared.analyzeFood` in background.
  - Writes back to HealthKit and triggers `SupabaseSyncService`.
  - Register in `LifecoreShortcutsProvider`.

### Task 8: Verification, Test Suite & Documentation
- Build project using `xcodebuild` with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` to ensure zero compile errors.
- Create verification test in `MathEngineVerification.swift` or dedicated storage test ensuring SwiftData operations and serialization work reliably.
- Update `docs/ROADMAP.md`, `PROJECT_KNOWLEDGE.md`, `docs/DATABASE.md`, `CHANGELOG.md`.
- Commit and push to `origin/main`.
