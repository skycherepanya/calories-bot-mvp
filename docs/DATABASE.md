# Lifecore storage and database reference

Updated: 2026-11-13 (R7 Cloud & HealthKit Convergence + R8 RLS & Ownership Schema). Source: checked-in migrations (`001`–`20261113140000`) and Swift models/DTOs (`SwiftDataModels.swift`, `CloudDTOs.swift`, `SyncCoordinator.swift`, `AccountSession.swift`). Deployed Supabase schema/RLS replay and legacy backfill remain pending `supabase db push` (D1).

## Current local and cloud roles

HealthKit supplies passive telemetry and receives serialized dietary meal exports/deletes via `SyncOutbox` (`healthkitMeal`). SwiftData persists `MealEntity`, `WorkoutAnalysisEntity` (with `revision`), `AthleteTrainingPlanState`, `AthleteMemoryEntity`, and `SyncOperationEntity`. Profile calibration uses `UserDefaults`. Supabase receives typed REST uploads (`MealCloudDTO`, `WorkoutAnalysisCloudDTO`, daily telemetry) with expected-revision CAS (`PATCH` `?revision=eq.X`) and paginated incremental pulls (`SyncCoordinator.pullIncrementalAll`).

## Checked-in SQL contracts

### Meals and body measurements

Defined in [001_initial.sql](../supabase/migrations/001_initial.sql) and duplicated/extended in [20260904160000_lifecore_schema.sql](../supabase/migrations/20260904160000_lifecore_schema.sql).

`meals`: BIGINT identity primary key; required BIGINT `user_id`, TEXT `meal_name`, NUMERIC `kcal`, `protein`, `fat`, `carbs`, **`weight_g`**, DATE `dietary_date`; optional NUMERIC `confidence` (0–100 convention), TEXT `telegram_file_id`; timestamp `created_at`. Tags are TEXT[] default empty; `micronutrients` and `amino_acids` are JSONB default objects. These numeric fields do not have the precision/scale limits previously shown in this document. Current `kcal` is intended to be buffered; the live AI path does not enforce native normalization (F07).

`body_measurements`: BIGINT identity/user; required NUMERIC `weight_kg`, DATE `dietary_date`, timestamp `measured_at`; optional impedance, body-fat/water/muscle/bone/visceral-fat measures; source and creation timestamp. See migration for exact defaults.

Nutrition JSON keys match Swift Codable models:

```json
{
  "micronutrients": {
    "fiber_g": 3.5, "sodium_mg": 420, "potassium_mg": 400,
    "vitamin_c_mg": 8, "iron_mg": 2.2, "calcium_mg": 55
  },
  "amino_acids": {"bcaa_g": 4.8, "leucine_g": 2.2}
}
```

Values above illustrate shape, not measured or recommended nutrition. Nullable/absent fields remain unknown.

### Workout summaries and detailed analyses

[002_workouts.sql](../supabase/migrations/002_workouts.sql) defines `workouts`: BIGINT identity/user, required type/start/duration_min/dietary_date; optional distance_km, avg_heart_rate, max_heart_rate, active_kcal, avg_pace_min_km, elevation_m, notes and raw_data JSONB. `workout_analyses` does not delete or replace this table in the checked-in SQL.

[006_workout_analyses.sql](../supabase/migrations/006_workout_analyses.sql) defines:

- UUID primary key, BIGINT user, unique required TEXT `healthkit_workout_uuid`, required type/start timestamp.
- Required `duration_min NUMERIC(6,1)`; optional distance_km NUMERIC(6,2), avg_pace_min_km NUMERIC(5,2), avg_hr/max_hr NUMERIC(4,1), elevation_gain_m NUMERIC(6,1), efficiency_factor NUMERIC(6,3), aerobic_decoupling_pct NUMERIC(5,2).
- `splits_json`/`laps_json` JSONB default arrays; optional `ai_coach_report` TEXT; required created/updated timestamps.

Split/lap keys are defined by `WorkoutMathEngine.swift`, not guessed from display labels:

```json
{
  "splits_json": [{"km": 1, "duration_s": 360, "pace_min_km": 6,
    "avg_hr": 140, "max_hr": 150, "elevation_diff_m": 0, "avg_cadence": 170}],
  "laps_json": [{"lap_index": 1, "type": "work", "duration_s": 180,
    "distance_m": 500, "avg_pace_min_km": 6, "avg_hr": 145,
    "max_hr": 155, "hr_drop_bpm": 15}]
}
```

Current upload uses these SQL column names; restore expects incompatible names including `workout_uuid`/`duration_seconds`, causing skipped rows (F09). Local seconds/meters require explicit conversion to remote minutes/kilometers.

### Daily metrics and sleep

The timestamped schema defines `daily_metrics`: BIGINT identity/user, required DATE `metric_date`, optional body composition, sleep, resting_hr/hrv_ms, steps INTEGER, active_kcal and rolling weight fields; unique `(user_id, metric_date)`. [005](../supabase/migrations/005_daily_metrics_enhancements.sql) adds distance_km/source. [007](../supabase/migrations/007_lifecore_v3_vitals_and_correlations.sql) adds TRIMP, acute/chronic EWMA, ACWR and integer wake/min battery. **No checked-in migration creates `neat_kcal`; the client sends it.**

[003](../supabase/migrations/003_sleep_logs.sql) defines `sleep_logs`: BIGINT identity/user, required DATE `sleep_date`, nullable total/deep/rem/core/awake hours, hrv_avg_ms/rhr_bpm/vo2max, source/created_at; unique `(user_id, sleep_date)`. [004](../supabase/migrations/004_fix_sleep_logs_nullable.sql) explicitly drops total_hours NOT NULL. [007](../supabase/migrations/007_lifecore_v3_vitals_and_correlations.sql) adds hrv_rmssd_ms, wrist_temp_delta_c, spo2_pct, respiratory_rate, sleep_efficiency_pct and immune_state default `optimal`. That default is not evidence of measured normal physiology.

The timestamped schema also defines legacy `activities` (activity_date/type, duration_minutes, distance_km, avg_hr, kcal_burned, source). Do not infer that every schema table has a current native synchronization path.

## SwiftData models

- `MealEntity`: stable local UUID (`id`), `clientUUID`, `name`, `kcal` (preserves buffered calories), optional `kcalExact`, `bufferVersion` (default 1 for +12.5%), `proteinG`, `fatG`, `carbsG`, optional `weightG`, optional `confidence`, `tags`, `micronutrientsJson`, `aminoAcidsJson`, `dietaryDate`, `createdAt`, `updatedAt`, `statusRaw` / `lifecycleState` (`draft`, `analyzing`, `review`, `confirmed`, `failed`, `cancelled`), `revision`, `provenance` ("camera", "text", "manual", "legacy_seed", "fixture"), `isDeleted` (soft delete for sync tombstones), `isOptimisticPending`, `syncedToCloud`, `remoteId` / `legacyRemoteId`.
- `SyncOperationEntity`: durable queue operation (`operationID: UUID`, `entityID: UUID`, `entityType: String` ("meal", "workout"), `operationKind: String` ("upsert", "delete"), `revision: Int`, `payloadJson: String`, `attempts: Int`, `lastAttemptAt: Date?`, `status: String` ("pending", "processing", "completed", "failed"), `createdAt: Date`, `updatedAt: Date`). Atomic mutation commits survive app restarts.
- `WorkoutAnalysisEntity`: workout UUID, local seconds/meters, split/lap JSON, metrics/report and sync metadata.
- `AthleteTrainingPlanState`: queue index, frequency, duration cap, target ACWR, club override, date/timestamp.
- `AthleteMemoryEntity`: stored athlete context and retrieval metadata.

Models live in `Core/Storage/SwiftDataModels.swift`, `Core/Storage/SyncOutbox.swift`, and `TrainingPlanModels.swift`. Persistent container errors surface via `PersistenceRecovery` and `LifecoreDataStore.isRecoveredFallback` without silent unacknowledged data loss. Mutation APIs (`confirmMeal`, `deleteMeal`, `undoDeleteMeal`) are throwing operations with automatic context rollback on failure (resolving Audit F10/F11).

## Compatibility and migration gates

[20261113120000_r7_sync_convergence.sql](../supabase/migrations/20261113120000_r7_sync_convergence.sql) extends the checked-in SQL schema for R7 convergence (with contract assertions in [sync_contract.sql](../supabase/tests/sync_contract.sql)):

- **`public.daily_metrics`:** Reconciled in both [005](../supabase/migrations/005_daily_metrics_enhancements.sql) (`CREATE TABLE IF NOT EXISTS public.daily_metrics`) and `20261113120000` so fresh chronological replay succeeds; adds `neat_kcal NUMERIC(6,1)`.
- **`public.meals`:** `ALTER COLUMN weight_g DROP NOT NULL`; adds `client_uuid UUID`, `revision INTEGER NOT NULL DEFAULT 1`, `is_deleted BOOLEAN NOT NULL DEFAULT FALSE`, `kcal_exact NUMERIC`, `buffer_version INTEGER NOT NULL DEFAULT 1`, `provenance TEXT NOT NULL DEFAULT 'legacy'`, `updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())`, partial unique index `idx_meals_user_client_uuid` on `(user_id, client_uuid)`, and `idx_meals_user_updated_at`. Swift confidence `0...1` is normalized to `0...100` (`confidence * 100`) at `MealCloudDTO` boundary.
- **`public.workout_analyses`:** Adds `revision INTEGER NOT NULL DEFAULT 1` for CAS updates; `WorkoutAnalysisCloudDTO` matches `006_workout_analyses.sql` column names and converts `m <-> km` and `s <-> min` losslessly.

1. Local Swift `SyncContractTests` and `ConfigurationTests` verify DTO round-trips, outbox CAS, 409 conflict preservation, paginated pulls, HealthKit export serialization, session expiry, and cross-account outbox isolation.
2. Authored R8 RLS migration [20261113140000_r8_rls_and_ownership.sql](../supabase/migrations/20261113140000_r8_rls_and_ownership.sql) and contract test [rls_ownership_contract.sql](../supabase/tests/rls_ownership_contract.sql): adds `auth_user_id UUID DEFAULT auth.uid()` across all 7 user tables (`meals`, `workout_analyses`, `daily_metrics`, `sleep_logs`, `workouts`, `body_measurements`, `activities`), creates `public.user_account_mappings` (`SELECT`-only RLS for `authenticated`; writes restricted to `service_role`), and enables owner-only RLS policies (`auth.uid() = auth_user_id`).
3. Live remote application via `supabase db push`, PostgreSQL execution of `sync_contract.sql` / `rls_ownership_contract.sql`, and verified legacy ownership backfill remain pending remote DB deployment (`psql`/`docker` unavailable locally).
