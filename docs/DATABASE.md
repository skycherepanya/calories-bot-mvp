# Lifecore storage and database reference

Updated: 2026-11-12. Source: checked-in migrations and Swift models at audit baseline `3e6b998`. Deployed schema, policies and applied migration history were not inspected. No schema was changed or deployed by the documentation audit.

## Current local and cloud roles

HealthKit supplies passive telemetry; SwiftData stores meals, cached workout analyses, the training queue and athlete memory. Profile calibration uses UserDefaults. Supabase receives direct REST uploads and provides capped initial hydration for empty local collections. It is not currently an immutable warehouse or a complete convergent sync system.

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

1. Numbered migrations005/007 alter `daily_metrics`, whose only checked-in CREATE is in the later timestamped file. A fresh version-ordered replay therefore has an ordering prerequisite. This is source inspection, not a claim that a local replay ran. Inspect actual history and prepare a tested bootstrap/baseline strategy; do not blindly rename applied migrations.
2. Reconcile missing `neat_kcal`, nullable weight and complete typed round trips. SQL confidence is0–100; previous docs incorrectly stated0–1.
3. Current pulls only hydrate empty collections, cap60/30 rows and lose optional meal metadata. Local/remote identity, pagination, deletes and revisions need R7.
4. Checked-in migrations contain no RLS policies; deployed protection is unknown. Publishable keys are public configuration. R8 must verify authenticated ownership and cross-user denial before wider distribution.
5. Proposed fields (`client_uuid`, revision, outbox/tombstones, raw kcal/buffer version/provenance) are **not deployed schema**. R6/R7 own versioned local/cloud migrations and data-preservation tests. Preserve legacy IDs and already-buffered kcal.

Use local/staging migration, full restore and authorization tests before `supabase db push` against a verified production target. See [reliability packet](superpowers/plans/2026-11-12-native-redesign/01-reliability.md) and [audit](audits/2026-11-12-architecture-and-product-audit.md).
