# Redesign resume review — 2026-11-18

Reviewed source: `b0bf0bd`. Previous independent review: `6f8cd6c` on November 13. Scope: reconcile that review with the November 14 hotfix, inspect affected live paths, and restore an actionable backlog. No application fixes or remote database changes in this review.

## Delivered work

- Selected Core icon is installed in `Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`.
- Four native tabs and feature ViewModels are wired. Today and Workouts share the daily snapshot/prescription coordinator.
- Observation/day contracts, isolated fixtures, native nutrition normalization, review-before-confirm, evidence-scoped AI, outbox/revisions/tombstones, and test suites exist.
- `b0bf0bd` separates absolute wrist temperature from its personal delta. It adds model property defaults, a persistent-store retry, and three tests. The original approximately +36°C delta defect is addressed in code.
- The new persistence test opens, writes and reopens the **current** schema. It does not establish old-schema migration safety.

## Evidence and limits

Fresh November 18 verification at `b0bf0bd`: **143 passed, 0 failed, 0 skipped**, `xcodebuild` exit 0 and `xcresulttool` result `Passed`, iPhone 17 / iOS 27.0 simulator. The November 13 independent run passed 140 tests at `6f8cd6c`. Earlier Release and 5/5 Maestro results remain historical evidence, not a fresh November 18 rerun.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project ios/Lifecore/Lifecore/Lifecore.xcodeproj -scheme Lifecore \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' \
  -derivedDataPath /tmp/lifecore-review-20261113 \
  -resultBundlePath /tmp/lifecore-review-20261118-tests.xcresult \
  test CODE_SIGNING_ALLOWED=NO > /tmp/lifecore-review-20261118-tests.log 2>&1
```

Local artifacts: `/tmp/lifecore-review-20261118-tests.xcresult` and `/tmp/lifecore-review-20261118-tests.log` (temporary, not committed).

Static findings below identify concrete production paths. Failure injection, account switching, process termination and real-device HealthKit have not been reproduced end-to-end in this review. Do not label these regressions fixed from fixture-only tests.

All source paths below are relative to `ios/Lifecore/Lifecore/Lifecore/`; test paths are relative to `ios/Lifecore/Lifecore/LifecoreTests/`. Line references refer to `b0bf0bd`.

## Open findings

### C01 — P1: store recovery can hide existing history

`Core/Storage/SwiftDataModels.swift:290–325` moves the database, WAL and SHM files after **any** container initialization error, then retries with a fresh store. Directory creation/file moves use `try?`; partial backup failures are ignored. A second open failure still selects an in-memory store. Recovery flags have no UI consumer. This can replace visible history with an empty database or allow volatile writes without explaining the state.

Required: retain the original store on failure; verified backup/restore and explicit recovery state; prevent ordinary successful-save UX without durable storage. Test a populated pre-redesign SQLite store upgraded to HEAD, injected open failure, partial backup failure and relaunch. Current `PersistenceTests.testPersistentStoreSchemaAllowsFileBackedReopenAfterMealInsert` is not an upgrade test. Inline defaults alone do not prove migration preservation.

### C02 — P1: meal confirmation still hides save failure

`Features/Nutrition/NutritionViewModel.swift:371–384` calls nonthrowing `addMeal`, exports to HealthKit and dismisses review. `Core/Storage/MealStorageService.swift:398–412` suppresses outbox/save errors and updates the visible list regardless. A failed disk write can look successful and produce external data without a durable local record.

Required: route confirmation through one throwing atomic entity/outbox transaction, retain review on failure, and use the serialized export queue after commit. Inject failure at the actual storage dependency; assert no dismissal, no published confirmed record, no external export, and recoverable draft. The ViewModel's `simulatedSaveError` shortcut does not exercise this path.

### C03 — P1: historical HRV methods are relabeled

`Core/Services/DailySnapshotCoordinator.swift:297,515` labels baseline values with the current observation's method. `Core/Repositories/PhysiologyHistoryBuilder.swift:211` loses historical method identity. A mixed SDNN/RMSSD history can bypass the engine's method-mismatch guard.

Required: retain method/source with historical samples; calculate method-specific baselines; do not relabel an existing baseline. Extend `PhysiologyTests` and `DailySnapshotTests` through the live adapter: SDNN baseline plus RMSSD observation must remain incomparable until enough matching history exists.

### C04 — P1: missing workout coverage becomes confirmed rest

`Core/Services/DailySnapshotCoordinator.swift:327–342` treats sleep/weight/HRV presence as observed load and `workoutTrimp == 0` as known rest. Unavailable workouts or missing workout HR can therefore enter EWMA as zero load.

Required: carry workout-query coverage separately from other health observations. Test sleep/weight-only history with unavailable workouts and workouts without usable HR; neither may become confirmed rest or full-confidence load history.

### C05 — P2: temperature calibration remains incomplete

The hotfix reader preserves missing delta with fewer than two prior samples. However, `Core/HealthKit/HealthKitManager.swift:261` and `Core/MathEngine/VitalsAndIllnessEngine.swift:403` reconstruct a delta using profile baseline, whose default is 36.40°C (`Core/Storage/AthleteProfileStore.swift:106`). Missing personal calibration can still appear measured. Also, the reader counts samples, not distinct nights.

Required: preserve unavailable personal delta through every adapter when calibration is absent; distinguish explicit user calibration from defaults; group prior temperature measurements by eligible night. Extend the existing temperature tests through the coordinator/engine, including first-night data and duplicate same-night samples.

### C06 — P2: one meal is treated as a complete nutrition day

`Core/Repositories/PhysiologyHistoryBuilder.swift:183` treats any logged meal as confirmed nutrition; `Core/MathEngine/CorrelationEngine.swift:31` exposes that as complete nutrition. Partial journals and the current unfinished day can influence deficit/TDEE/prescription calculations.

Required: distinguish confirmed meal from complete day. Exclude incomplete days from full-day adaptation. Extend `LongitudinalTests` with breakfast-only days and the current dietary day, retaining explicit confirmed-zero behavior.

### C07 — P1: interrupted outbox operations remain processing

`Core/Storage/SyncCoordinator.swift:624,650` selects pending operations and durably marks processing before network completion. No relaunch recovery resets abandoned processing operations; enqueue deduplication at `:540` blocks replacing them. HealthKit flush uses the same lifecycle.

Required: recover abandoned operations safely without racing an active flush. Extend `SyncContractTests` with a file-backed reopen after processing starts, before acknowledgement; confirm eventual single logical application and truthful pending/failure status.

### C08 — P1: account isolation/auth integration is unfinished

`Core/Configuration/AccountSession.swift:119–123` purges outbox on account switch but retains ownerless unsynced local entities. `Core/Storage/SyncCoordinator.swift:530–555` can enqueue those records under the new session. Production sign-in/refresh callers of `setSession`/`switchAccount` were not found; Settings exposes diagnostics, not a complete login flow.

Required: owner-scoped local records/stores and a defined guest-data transition before enabling sign-in. Test offline meal under A → switch B → enqueue/flush: A's data must never upload as B. Then integrate sign-in, refresh, sign-out and expiry UX. Verify migrations/RLS in staging before deployment; their presence in Git is not deployment evidence.

### C09 — P1: Settings retains a plaintext API key

`Features/Settings/SettingsView.swift:528` writes the key to UserDefaults as well as Keychain. `Core/Configuration/AppConfiguration.swift:56–59` returns a Keychain hit before legacy cleanup. Legacy migration also ignores Keychain write failure before removing the old value (`:69–70`).

Required: one throwing credential-store boundary, no new plaintext copies, cleanup after verified Keychain write, visible failure state. Test Settings save/relaunch with both stores populated and injected Keychain write failure. Never print credentials in test logs.

### C10 — P2: lost PATCH response becomes a false conflict

`Core/Storage/SyncCoordinator.swift:186–188,252–253` treats an empty revision-guarded retry as conflict even when the server already applied the same operation. POST has recovery; PATCH needs equivalent identity-aware acknowledgement.

Required: transport test where the server commits a revision, its response is lost, and retry reads the identical remote operation/payload. Acknowledge that operation; retain a real competing revision as conflict.

### C11 — P2: Sync Intent can report false success

`Intents/LifecoreSyncIntent.swift:108–127` returns clean success after checking only authorization/network/pending, ignoring other failed operations. Telemetry upload failure is suppressed at `:74`.

Required: derive the dialog from the complete result. Extend `IntentOutcomeTests` with conflict, bad request and telemetry failure with an empty outbox; none may report clean synchronization.

### C12 — P2: cancelled food analysis can overwrite a new draft

`Features/Nutrition/NutritionViewModel.swift:239–248` publishes after await without a generation check; cancellation at `:285–287` only resets state.

Required: retained cancellation plus generation guard. Test delayed request A → cancel → request B → completion of A; only B may update the current draft.

### C13 — P2: UI/release acceptance remains partial

`App/LifecoreApp.swift:16` forces light appearance; semantic and fixed colors/fonts coexist. Previous accessibility-size screenshots show truncation. Coach stale-report state has no production assignment. Maestro 03–05 mostly check visibility/navigation, not filter results, range data or Today/Workouts recommendation equality. CI skips all test stages when iOS 27 SDK is unavailable.

Required: complete dark/Dynamic Type handling and Coach freshness; assert actual output in E2E, including Coach error/retry. Run the outstanding visual/accessibility matrix and record performance measurements. A skipped CI job is not test evidence. Physical HealthKit, staging RLS/migration/backfill and credential rotation remain separate release gates.

## Next execution order

Continue the existing redesign plan; do not restart the redesign or regenerate the selected icon.

- [ ] **A — Local data safety:** C01/C02, then C12. One owner for SwiftData, MealStorageService and Nutrition. Gate: old-store upgrade, real save-failure injection and cancelled-analysis regressions.
- [ ] **B — Truthful physiology:** C03/C04/C05/C06. One owner for history/coordinator/math adapters. Gate: live-input integration tests, not only hand-built engine fixtures.
- [ ] **C — Credentials:** C09. May run beside A/B if Settings/configuration files are exclusively owned.
- [ ] **D — Cloud and Intents:** C07/C08/C10/C11 after A establishes storage/ownership contracts. Serialize model edits with A; prove crash recovery/account isolation before deploying migrations.
- [ ] **E — Acceptance:** C13 after A–D. Run the full suite, meaningful E2E and device/backend gates; attach exact commit, command, exit code and artifacts. Reopen any failed contract.

Use at most three workers with disjoint file ownership, one orchestrator for shared docs/integration, and red/green regression evidence per task. The existing master plan/spec remain the implementation contract. This list prioritizes corrections; it does not mark them implemented.
