# Reliability and data contracts implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` or `executing-plans` task-by-task.

**Goal:** Make every displayed/persisted result attributable, reproducible and recoverable before visual migration.
**Architecture:** Typed observations → repositories → deterministic engines → shared snapshot; confirmed meals → durable outbox → typed sync.
**Tech Stack:** Swift, XCTest/Swift Testing, HealthKit, SwiftData, URLSession, PostgreSQL.
**Spec:** [Native redesign](../../specs/2026-11-12-native-redesign-design.md).

## Global constraints

Inherit every constraint from the [master plan](../2026-11-12-native-redesign.md). `APP` = `ios/Lifecore/Lifecore/Lifecore`; `TEST` = `ios/Lifecore/Lifecore/LifecoreTests`. These aliases name exact directories, not additional modules. Proposed files do not exist until their owning task creates them. R1 owns project integration; R6 owns entity schema; orchestrator owns global documentation. Each task below ends with targeted tests, corresponding documentation notes and a conventional commit. Run the master's test command with the stated class filter.

## R1 — Enforced baseline tests and isolated composition

Dependencies: none. Findings:F20. Own `ios/Lifecore/Lifecore/Lifecore.xcodeproj/project.pbxproj`, shared scheme, `TEST/LegacyVerificationTests.swift`, `TEST/TestFixtures.swift`, `APP/App/AppEnvironment.swift`, `APP/App/LifecoreApp.swift`, `.github/workflows/e2e.yml`, `scripts/run_e2e.sh`.

- [ ] Add application-hosted `LifecoreTests` target and shared scheme test action; migrate the startup verification loop into assertions. Preserve existing functions until their coverage is replaced.

```swift
import XCTest
@testable import Lifecore
final class LegacyVerificationTests: XCTestCase {
    @MainActor func testLegacyVerifications() {
        for result in MathEngineVerification.runAllVerifications() {
            XCTAssertTrue(result.passed, "\(result.testName): \(result.details)")
        }
    }
}
```

- [ ] Verify an intentionally failing temporary assertion makes `xcodebuild test` exit nonzero; remove it and run the real harness. Investigate any existing failures rather than weakening expected behavior.
- [ ] Introduce `AppEnvironment.live` and `.fixture`; choose fixture mode only through explicit DEBUG test launch arguments. The test host must select fixture composition before startup verification or any singleton initialization. A fixture environment uses a separate temporary SwiftData container, fixed clock, fake AI, no-op external exporters and deterministic health data. Assert no `.shared` live dependency is constructed in fixture mode. Add `EnvironmentIsolationTests` counting external calls (expected0).
- [ ] Fix actor-isolation warnings at their owning boundaries, then test a Swift 6 language-mode build. Only change `SWIFT_VERSION` to6 after compilation/tests pass; otherwise record a separate unresolved migration gate and retain truthful Swift 5 docs. Do not add blanket `@unchecked Sendable` to silence errors.
- [ ] Update CI to assert an installed SDK supports the actual iOS 27 floor; fail when Maestro/Java/test target is missing. Runner must use its explicit fixture simulator, not an arbitrary booted user's simulator. Keep launch/build logs and artifacts.
- [ ] Run unit tests, Debug build and `bash -n scripts/run_e2e.sh`. Update README/ios README toolchain and test commands; commit `test: enforce isolated native verification`.

## R2 — Observation and dietary-day contracts

Dependencies:R1. Findings:F01/F05/F26. Own new `APP/Core/Domain/{Observation,DietaryDay,ScreenState}.swift`, `TEST/{ObservationTests,DietaryDayTests}.swift`.

Freeze this shared vocabulary before workers consume it:

```swift
import Foundation
public enum ObservationSource: String, Codable, Sendable {
    case healthKit, user, derived, aiEstimate, fixture, legacy
}
public enum DataQuality: String, Codable, Sendable {
    case measured, estimated, stale, unavailable
}
public struct Observation<Value: Sendable>: Sendable {
    public let value: Value?
    public let unit: String
    public let observedAt: Date?
    public let source: ObservationSource
    public let quality: DataQuality
    public let observedCount: Int
    public let expectedCount: Int?
}
public struct DietaryDay: Hashable, Sendable {
    public let key: String
    public let interval: DateInterval
    public let timeZoneID: String
    public static func containing(_ date: Date, calendar: Calendar) -> DietaryDay
}
public enum ScreenState<Value> {
    case loading
    case empty
    case content(Value, isRefreshing: Bool, isStale: Bool)
    case failed(message: String, retained: Value?)
    case unavailable(message: String)
}
```

`containing` above is the implementation signature, not a complete method body. Implement boundaries using calendar start-of-day + local04:00; if before boundary choose previous local day. Construct end from the following local day at04:00; format `key` with fixed Gregorian yyyy-MM-dd and the same timezone. Do not subtract fixed seconds across DST.

- [ ] Write tests for Budapest dates:2026-11-12 03:59→key2026-11-11;04:00→2026-11-12. Across2026-03-29 and2026-10-25 verify adjacent boundaries remain04:00 and intervals may be23/25h.
- [ ] Test `Observation(value:nil,... quality:.unavailable)` stays missing through reducers; a user-confirmed0 remains a distinct measured observation.
- [ ] Implement helpers; persist dietary key/timezone at meal creation so travel does not rewrite historical identity. Define half-open membership `start <= timestamp && timestamp < end` for all interval aggregation.
- [ ] Document which records use dietary day vs sleep episode; test no overlap/gap at boundaries. Run `DietaryDayTests` and `ObservationTests`; commit `feat: define truthful observation and day contracts`.

## R3a — Real HealthKit observations and sleep episodes

Dependencies:R2. Findings:F01/F04/F05. Own `APP/Core/HealthKit/HealthKitManager.swift`, new `APP/Core/HealthKit/{HealthRepository,SleepEpisodeReader}.swift`, `TEST/HealthRepositoryTests.swift`. Do not edit extractor until this task ends.

Produces `HealthRepository` protocol with async throwing `weightHistory(in: DateInterval) -> [Observation<Double>]` and `sleepEpisode(endingBefore: Date) -> SleepEpisode?`; define `SleepEpisode` with interval and optional method-tagged HRV/RHR/temp/respiration/SpO2 observations. A concrete query adapter supplies these values; fixture implementation lives in test composition.

- [ ] Write fixtures with0/1/4/5 actual samples; assert exact returned sample count and timestamps, no fallback generator invocation. Include query error and unavailable HealthKit paths.
- [ ] Bound nocturnal samples to the selected episode. Dedupe overlapping samples using documented source precedence and interval union; include `.asleepUnspecified` in total sleep without inventing stage distribution.
- [ ] Preserve RMSSD/SDNN identity and same-method baseline selection. Missing/stale pillars stay optional; never replace with a normal baseline.
- [ ] Remove automatic synthetic history branches; move deterministic sample generators to fixture-only providers. Preserve sparse measured samples rather than replacing entire collections.
- [ ] Test two overlapping sources, unspecified-only sleep, old temperature with fresh HRV, partial permission-like data and both HRV methods. Run `HealthRepositoryTests`; update HealthKit architecture notes; commit `fix: preserve real health coverage and episode timing`.

## R3b — Workout normalization and metadata

Dependencies:R3a. Findings:F13/F14. Own `APP/Core/HealthKit/WorkoutTelemetryExtractor.swift`, `APP/Core/MathEngine/WorkoutMathEngine.swift`, `TEST/WorkoutTelemetryTests.swift`.

- [ ] Add a fixture with workout start `t0`, distance increments100m at36s intervals through1000m; expected first split duration360s. The current end-point-only stream demonstrates324s.

```swift
let t0 = Date(timeIntervalSince1970: 1_700_000_000)
let samples = (0...10).map { i in
    RawTelemetryPoint(timestamp: t0.addingTimeInterval(Double(i * 36)),
                      distanceMeters: Double(i * 100),
                      heartRateBpm: 140, altitudeMeters: nil)
}
let split = WorkoutMathEngine.computeKilometerSplits(from: samples)[0]
XCTAssertEqual(split.paceMinPerKm, 6.0, accuracy: 0.001)
```

- [ ] Test the query-to-normalized-series boundary, not just hand-built zero-anchored samples. Add the zero-distance start anchor only when cumulative stream semantics support it; document elapsed vs moving-time treatment and pause handling.
- [ ] Use explicit indoor metadata. Keep absent elevation absent in result contract and consumers; remove the zero-elevation treadmill heuristic. Do not invent constant-speed granular samples from summary distance.
- [ ] Test flat outdoor, explicit treadmill, missing route/distance, sparse first point, partial final kilometer and pause events. Verify EF/drift only when required telemetry exists.
- [ ] Run `WorkoutTelemetryTests` and legacy math tests; update telemetry documentation; commit `fix: anchor splits and preserve workout metadata`.

## R3c — Workload, battery and one vitals evaluation

Dependencies:R3a. Findings:F02/F04. Own `APP/Core/MathEngine/{TrainingLoadAndBatteryEngine,VitalsAndIllnessEngine}.swift`, `APP/Core/HealthKit/HealthKitManager.swift`, new `APP/Core/Domain/DailyLoadSeries.swift`, `TEST/PhysiologyTests.swift`.

- [ ] Write regression using28 known days at50TRIMP, then a final spike250; assert ratio differs from stable-history ratio. Empty history must yield insufficient coverage, not1.0. Known rest is0; unknown days are excluded or cause declared coverage failure.
- [ ] Assemble ordered daily history through R2 calendar rules; return coverage with ACWR. Use one evaluator for Today, sync and downstream advice. Require a documented minimum history (28 observed consecutive days for full-confidence workload; shorter history labeled provisional and excluded from progression advice).
- [ ] Replace hour17 with timestamped workout events. Handle06:00/09:00/18:00 and multiple events before/after current time. Remove unsupported fixed circadian score or expose unavailable.
- [ ] Select one HRV method with a matching baseline; never compare RMSSD to SDNN baseline. Test project confluence boundaries, including missing temperature and fewer than required observed pillars.
- [ ] Run `PhysiologyTests`; document coverage and battery assumptions; commit `fix: calculate physiology from dated measured inputs`.

## R3d — Shared longitudinal joins and honest associations

Dependencies:R3a/R3c/R6. Findings:F05/F15/F26. Own `APP/Core/MathEngine/{CorrelationEngine,AdaptivePhysiologyEngine}.swift`, new `APP/Core/Repositories/PhysiologyHistoryBuilder.swift`, `TEST/LongitudinalTests.swift`. UI join removal belongs to U2/U5.

Produces `PhysiologyHistoryBuilder.build(in: DateInterval) async throws -> [DailyJoinedPhysiologyRecord]`, extending that record to carry optional nutrition/sleep/load plus completeness. Meals come only from confirmed records in the interval. Use optional evidence rather than fabricated quality ratios/sleep/TRIMP.

- [ ] Test no logged food vs confirmed zero and real sleep stages. Sparse input dates must join T+1/T+2 by calendar key, never row adjacency.
- [ ] Feed rising whole-food ratio with falling next-day sleep; assert negative association wording and no canned15–25min effect. Positive/negative/zero/group-missing cases must preserve sign and sample count.
- [ ] Derive effect magnitudes from matched comparison groups only if a defined estimator and coverage permit them; otherwise omit. Label correlation as observational; replace statistical-significance claims unsupported by a specified method.
- [ ] Compute adaptive weight slopes from actual valid endpoint dates; test7 records spanning14days, absent endpoint weights and partial meal logs. Incomplete intake must not train TDEE as if complete.
- [ ] Run `LongitudinalTests`; document formulas/windows/eligibility; commit `fix: build longitudinal evidence without invented covariates`.

## R4 — Shared daily snapshot and prescription

Dependencies:R3b/R3c/R3d. Findings:F03. Own new `APP/Core/Services/{DailySnapshotCoordinator,TrainingPrescriptionService}.swift`, `TEST/DailySnapshotTests.swift`; environment wiring through U1 owner. Feature migrations stay with U2/U3.

Produces `@MainActor DailySnapshotCoordinator` with `state: ScreenState<DailyDashboardSnapshot>`, `refresh(day: DietaryDay) async`, and `invalidate()`. Define `DailyDashboardSnapshot` containing `revision: UUID`, `day: DietaryDay`, `generatedAt: Date`, observations, optional `TrainingPrescriptionPlan` and explicit unavailability reasons. `TrainingPrescriptionService` consumes validated observations; no default healthy inputs.

- [ ] Test two subscribers observe the same revision and plan during a low-battery/confluence fixture. No required inputs means no generated plan.
- [ ] Use an increasing request generation or UUID: capture on refresh, publish only if still current and task not cancelled. Cached stale content remains visible while refreshing.
- [ ] Invalidate on profile, meal confirmation/deletion, workouts and dietary-day rollover; use injected clock. Avoid repeat HealthKit queries per view redraw.
- [ ] Test delayed old request arriving after newer one; new snapshot remains. Run `DailySnapshotTests`; update architecture data-flow diagram; commit `feat: share one revisioned daily recommendation`.

## R5a — AI nutrition trust boundary

Dependencies:R2. Findings:F06/F07/F08. Own `APP/Core/AI/{FoodPrompt,GeminiService}.swift`, new `APP/Core/AI/NutritionNormalizer.swift`, `TEST/NutritionContractTests.swift`. R8 later owns credential changes; no simultaneous edits.

Produces `RawNutritionEstimate` with required name, `kcalExact`, protein/fat/carbs and relevant tags; optional weight/confidence/micronutrients. `NutritionNormalizer.normalize(_:) throws -> MealNutrition` is the only raw→buffered conversion. Stored legacy meals bypass it. Provider returns errors on timeout/auth/rate-limit/invalid payload; no synthetic successful meals.

```swift
let raw = RawNutritionEstimate(mealName: "Яйця", kcalExact: 200,
                              protein: 12.25, fat: 10.5, carbs: 0,
                              tags: ["whole_food", "solid"])
let meal = try NutritionNormalizer.normalize(raw)
XCTAssertEqual(meal.kcal, 225)
XCTAssertEqual(meal.protein, 12.25)
XCTAssertEqual(meal.carbs, 0)
```

Provide defaults only for optional constructor fields, never required nutritional values.

- [ ] Reject `{}`, missing required fields, negative/non-finite numbers and invalid confidence before Int conversion. Add 401/429/500/malformed JSON/timeout URLProtocol fixtures; assert typed failure and no external writes.
- [ ] Change prompt schema to exact unbuffered kcal; preserve cooked-state and Ukrainian food-label rules. Validate tags semantically; plain meat must not have imposed carbs, mixed dishes remain distinct.
- [ ] Normalize once in Swift; add raw/buffer version metadata via R6 owner. Existing `kcal` stays final when migrating; never recalculate unknown exact values as if measured.
- [ ] Remove production offline fabrication branches, including caller-level fallbacks during U4/R9 integration. Run `NutritionContractTests`; update nutrition contract documentation; commit `fix: validate AI nutrition and normalize calories natively`.

## R5b — Scoped coach evidence and memory

Dependencies:R5a/R6. Findings:F06/F21. Own `APP/Core/AI/{LifecoreContextRAG,CoachPrompt}.swift`, new `APP/Core/AI/CoachEvidence.swift`, `TEST/CoachEvidenceTests.swift`; Gemini adapter changes are serialized after R5a.

Produces `CoachEvidence` with `anchor: Date`, `nutritionInterval: DateInterval`, observed metrics with source IDs and coverage, plus confirmed memories. `CoachEvidenceBuilder.build(anchor: Date, nutritionInterval: DateInterval, meals: [MealRecord])` excludes nonconfirmed/out-of-window/future entries. Current context uses trailing24h; workout context explicitly uses pre-workout36h and labels that interval. Future meals are not evidence for a past workout.

- [ ] Test anchors with meals−37h/−25h/−23h/+30m and pending entries; verify exact totals/count/window labels. Replace misleading `fetchTodayMeals` use with scoped query contracts.
- [ ] Offline explanation formats only supplied facts and marks itself offline; an empty dossier cannot report sleep/HR/ACWR. Validate returned evidence IDs against the dossier, rejecting unsupported references.
- [ ] Separate AI-extracted memory candidates from confirmed memories. User review is required before promotion; retained legacy memory has explicit origin. Removal invalidates retrieval and is durable through R6 repository.
- [ ] Run `CoachEvidenceTests`; document what is sent to the provider and what stays local; commit `fix: scope coach context to attributable evidence`.

## R6 — Durable local state and recoverable migrations

Dependencies:R2. Findings:F10/F11/F25. Own `APP/Core/Storage/{SwiftDataModels,MealStorageService}.swift`, new `APP/Core/Storage/{PersistenceRecovery,SyncOutbox}.swift`, `TEST/PersistenceTests.swift`. Own all shared entity changes requested by R5/R7.

Produces persisted meal lifecycle `draft/analyzing/review/confirmed/failed/cancelled`, stable client UUID, legacy remote ID, revision, provenance, optional exact kcal/buffer version and retry metadata. Use throwing mutation APIs. `MealRepository.confirm(id: UUID) throws` durably saves and enqueues export intent atomically; `delete(id:)`/`undoDelete(id:)` preserve identity/revision. `SyncOutbox` stores operationID, entityID, revision, operation kind, attempt/retry metadata and payload.

- [ ] Inject failing container/save; assert recoverable storage state, no silent in-memory production fallback and no successful UI acknowledgment.
- [ ] Keep UserDefaults migration bytes until a successful transaction and reread verification; retry must dedupe by stable legacy identity. Test failure before/after save, relaunch and duplicate names.
- [ ] Replace name-based seed deletion with proven fixture identifiers/provenance; preserve ambiguous real legacy records. Do not silently purge their HealthKit samples.
- [ ] Introduce versioned SwiftData migration; export/restore fixtures containing meals, workouts, training queue and memories. Old buffered calories remain unchanged; unknown provenance remains legacy.
- [ ] Test confirm/delete/undo/save failure/relaunch; outbox operation identity survives retry. Run `PersistenceTests`; update DATABASE and migration notes; commit `fix: make local mutations durable and recoverable`.

## R7 — Cloud and HealthKit export convergence

Dependencies:R6 (and R5a contract before nutrition export). Findings:F09/F10/F22/F23/F24/F28. Own `APP/Core/Storage/SupabaseSyncService.swift`, new `APP/Core/Storage/{CloudDTOs,SyncCoordinator}.swift`, new timestamped Supabase migration, `supabase/tests/sync_contract.sql`, `TEST/SyncContractTests.swift`. Entity changes go through R6 owner. Depends additionally on R3c before editing HealthKit export adapters; its owner must be idle.

- [ ] Reconcile fresh migration order:005/007 depend on `daily_metrics` created only in the later timestamped migration. Inspect deployed history read-only; create a tested bootstrap/baseline strategy without renaming already-applied migrations. Add the missing `neat_kcal` column or remove unsupported upload through an explicitly documented contract; test it against a fresh database.
- [ ] Add typed WorkoutDTO CodingKeys matching migration006: UUID, minutes/km units, avg/maxHR, drift, splits_json/laps_json, reports. Decode/encode schema fixture, verifying lossless intended fields and explicit unit conversions.
- [ ] Add meal `client_uuid`, `revision`, tombstone/update metadata with unique owner+client identity; allow unknown weight NULL. Preserve BIGINT legacy IDs. Canonical confidence is optional0–100 at existing storage boundary; document conversion if a provider uses0–1.
- [ ] Serialize outbox processing, retry using stable identity, acknowledge only the transmitted revision. Test server commit/lost response/retry, concurrent flush, edit-during-upload, delete/restart/restore and undo.
- [ ] Add cursor pagination/incremental pulls even when local collections are nonempty. Round-trip >60 meals/>30 workouts including optional micronutrients/confidence and stable UUIDs. Define conflict policy: revisions advance per operation; stale server acknowledgment cannot clear newer local work; writes carry an expected server revision and atomically compare-and-set it. A mismatch returns409, retains both versions and surfaces a conflict; it never silently overwrites either version. Test this with two clients.
- [ ] Return `SyncResult` with succeeded/failed/pending operation IDs and classified error; HTTP non2xx is never a clean success. Retain retryable queue on network failure.
- [ ] HealthKit exports use stable `LifecoreMealID` and serialized ordered operations; test delete→undo while a previous export is in flight. Persist retry state rather than untracked Tasks.
- [ ] Apply migration to isolated local/staging database; inspect schema history conflicts before `supabase db push`. Run `SyncContractTests` and SQL contract checks; update DATABASE with new schema/JSON examples. Commit `fix: converge revisioned cloud and health exports`.

## R8 — Account and credential configuration

Dependencies:R5a/R7. Findings:F12. Own new `APP/Core/Configuration/{AppConfiguration,CredentialStore,AccountSession}.swift`, `TEST/ConfigurationTests.swift`, settings adapter, Gemini/Supabase configuration sections, RLS migration/tests. UI settings belongs to U1/U6; coordinate serialized integration.

- [ ] Remove automatically decoded bundled provider credential. Supply BYOK through Keychain and explicit provider setup; preserve no-key as usable app state with AI disabled. Do not print keys or include them in logs/screenshots.
- [ ] Add user-auth session token distinct from publishable app key. Introduce verified owner mapping from legacy numeric ID to authenticated user; never trust the client to assign ownership. Existing local data remains accessible if cloud sign-in/migration fails.
- [ ] Inspect deployed policies read-only and record findings; test anon denial, userA own access, userB denial for read/write/delete in staging with RLS enabled. Backfill legacy ownership only from an explicitly verified mapping; unmatched rows remain protected/unassigned.
- [ ] Rotate the embedded provider credential through its owner if active; record completion without the value. If external ownership/access is unavailable, leave the release gate open with a precise blocker rather than claiming safe deployment.
- [ ] Test token expiry, signout, account switching (no cross-account queue replay), missing configuration and Keychain failure. Run `ConfigurationTests` plus RLS tests; update setup/privacy documentation; commit `fix: isolate credentials and authenticated cloud ownership`.

## R9 — Truthful AppIntents

Dependencies:R5a/R6/R7/R8. Findings:F22. Own `APP/Intents/{LogMealIntent,LifecoreSyncIntent}.swift`, `TEST/IntentOutcomeTests.swift`.

- [ ] Call durable repositories/coordinator; every task required after Intent termination must be persisted as work before returning.
- [ ] Map analyzing/review/failed/saved-locally/synchronized to distinct Ukrainian dialogs. Do not say saved after provider failure; unreviewed estimates do not become confirmed nutrition.
- [ ] Test provider failure, expired account, partial sync, app termination after draft save and later retry. Assert no indefinite anonymous pending entry and no detached success claim.
- [ ] Run `IntentOutcomeTests`; update Siri/setup documentation; commit `fix: report durable intent outcomes accurately`.
