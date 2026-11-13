# Lifecore architecture

Updated: 2026-11-13 (Waves 1-4: R1-R7 + U1). Target architecture specification: [redesign specification](superpowers/specs/2026-11-12-native-redesign-design.md).

## Product and platform

Lifecore combines workout telemetry, recovery context and nutrition into athletic decisions. Native iOS remains the primary client and math engine. SwiftUI/Charts present four tabs plus a modal Settings flow; HealthKit reads and exports device data; SwiftData persists local records and durable sync operations; Supabase REST synchronizes meals, workout analyses, and telemetry; Gemini supplies qualitative recognition and narrative.

Actual project settings: iOS 27.0 deployment floor, Swift 5.0 language mode, verified Xcode 27.1 toolchain (`LifecoreTests` hosted suite: 98 passing tests on `iPhone 17` iOS 27.0). Swift 6 language-mode migration remains a separate tracked gate.

## Current component/data flow (R4 + R7 + U1)

```mermaid
flowchart TD
    HK[HealthKitManager / WorkoutTelemetryExtractor] --> HB[PhysiologyHistoryBuilder R3d]
    HB --> DSC[DailySnapshotCoordinator R4]
    STORES[AthleteProfileStore + TrainingPlanStore + MealStorageService + WorkoutAnalysisStorage] -->|NotificationCenter invalidation| DSC
    DSC --> TPS[TrainingPrescriptionService R4]
    DSC --> ENV[AppEnvironment live/fixture]
    ENV --> SHELL[MainTabView + SettingsView + UI Primitives U1]
    SHELL --> TABS[Today / Workouts / Nutrition / Trends]
    M[MealStorageService] <--> SD[SwiftData + SyncOutbox R6/R7]
    SD <--> SC[SyncCoordinator + CloudDTOs R7]
    SC <--> SB[Supabase REST]
    SC --> HKW[Serialized HealthKit Meal Queue]
    TABS --> G[GeminiService + CoachPrompt + LifecoreContextRAG R5]
    G --> SD
```

R4 establishes `DailySnapshotCoordinator` and `TrainingPrescriptionService` as the single evaluated snapshot and prescription source; feature screen migrations onto the coordinator (`U2-U5`) follow in Wave 5. R7 introduces `SyncCoordinator` and typed `CloudDTOs` for revisioned CAS uploads, paginated incremental pulls, and serialized HealthKit meal exports. U1 establishes semantic adaptive tokens (`LifecoreDesignSystem`), reusable state/metric components (`Core/UI/Components/`), and `SettingsView` backed by `AppEnvironment`.

## Verified boundaries and open waves

- **Ingestion & deterministic math (R2-R4):** `DietaryDay`, `MetricSample`, `PhysiologyHistoryBuilder`, `VitalsAndIllnessEngine`, `TrainingLoadAndBatteryEngine`, `TrainingPrescriptionService`, and `DailySnapshotCoordinator` compute from observed HealthKit/SwiftData inputs without synthetic defaults or fake priors.
- **Storage & sync convergence (R6-R7):** `SyncOutbox` tracks durable `.meal`, `.workout`, and `.healthkitMeal` mutations with monotonic local revisions; `SyncCoordinator` performs serialized FIFO uploads, expected-revision CAS (`409` conflict retention), idempotent initial-`POST` retry recovery, and paginated pulls. Migration `20261113120000_r7_sync_convergence.sql` and `005_daily_metrics_enhancements.sql` reconcile `daily_metrics`, `meals`, and `workout_analyses`; live `supabase db push` verification remains pending against remote DB.
- **AI & presentation (R5, U1-U6):** Meal buffer arithmetic stays deterministic in Swift (`1.125` once); coach dossiers carry scoped evidence IDs and manual candidate memory confirmation. `U2-U6`, `R8` (auth/credential hardening), `R9` (truthful AppIntents), and `D1` E2E validation remain in upcoming waves.

Deterministic Swift arithmetic precedes AI explanation. Ukrainian end-user copy; English prompts/code/docs. Native calorie buffer is exactly12.5% once, macros unchanged. Dietary attribution uses04:00; sleep has a separate bounded episode. Missing is not zero/normal. Preserve project multi-metric confluence rather than alarm on one ordinary RHR variation. Data must retain source/time/coverage and cannot silently become measured from a fixture or prior.

## Planned boundaries and rollout

R1/R2 establish executable tests and shared contracts. HealthRepository and PhysiologyHistoryBuilder supply measured optional inputs to engines; DailySnapshotCoordinator publishes a revisioned result; TrainingPrescriptionService creates one plan; view models consume these results. Durable MealRepository/outbox and typed cloud DTOs preserve identity, revisions and recoverability. AI adapters validate payloads and evidence. Explicit fixture composition disables real exports.

The [master plan](superpowers/plans/2026-11-12-native-redesign.md) assigns exclusive file owners, dependencies, regression cases and integration gates. Screens migrate after shared contracts; no new backend/platform rewrite is proposed. Future migrations are additive and tested before production deployment. Audit findings stay open until evidence resolves them.

## References

[Audit with source anchors](audits/2026-11-12-architecture-and-product-audit.md), [database contract](DATABASE.md), [roadmap](ROADMAP.md), [design specification](superpowers/specs/2026-11-12-native-redesign-design.md). Historical October specs remain design history and are not proof of current correctness.
