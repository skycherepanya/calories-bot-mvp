# Redesign integration and release implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` or `executing-plans` task-by-task.

**Goal:** Demonstrate the redesigned application works across data, storage, UI and accessibility boundaries before declaring release readiness.
**Architecture:** One integration owner assembles reviewed slices; isolated fixtures drive deterministic checks; staging verifies external contracts.
**Tech Stack:** xcodebuild/XCTest, Maestro, Simulator/device, Supabase CLI and SQL tests.
**Spec:** [Native redesign](../../specs/2026-11-12-native-redesign-design.md).

## Global constraints

Inherit all [master plan](../2026-11-12-native-redesign.md) constraints. An unmet release criterion is reported as unmet, not waived by a successful build. No production reset, destructive migration or real-user test fixture. Required schema deployment uses Supabase CLI only after migration/restore/ownership checks.

## D1 — Integration, evidence and release

Dependencies: all R/U tasks. Own `.maestro/*.yaml`, `scripts/run_e2e.sh`, `.github/workflows/e2e.yml` after R1; new `docs/verification/2026-11-12-redesign-acceptance.md` and evidence assets; global documentation. R1 owns project test-target changes during integration.

### Automated outcome matrix

- [ ] Run all tests from master command, store xcresult and exact toolchain/destination/commit. Every F01–F28 finding has a named regression test, a resolving commit or explicit unresolved disposition.
- [ ] Today/Profile flow reopens saved profile, verifies value and changed snapshot revision; empty HealthKit shows no fabricated status; Today/Workouts recommendation values match.
- [ ] Nutrition flow captures text, waits for review, verifies known fixture exact/final kcal and macros, confirms, deletes, undoes, relaunches and verifies one record. Failure/invalid JSON keeps recoverable input and never exports fabricated nutrition.
- [ ] Workouts flow checks hidden-filter regression, previous dietary-day attribution, multiple sessions, sport-specific fields and a fixed360s kilometer fixture.
- [ ] Trends flow verifies90d selection during in-flight30d load, correct selected data interval,38/152kg domains, missing-data gaps and negative association wording.
- [ ] Coach flow tests duplicate keyboard/button submission, failure/retry and evidence/memory lifecycle. Ensure one queued request and no unsupported metric fallback.
- [ ] Fixture environment counts all outgoing requests and HealthKit writes; expected0 to real services. E2E must fail, not exit0, when Maestro/runtime/fixture mode is missing. Preserve screenshot/video/log artifacts on failure.

### Storage and external contracts

- [ ] Migrate a copy of legacy local data with meals, optional fields, analyses, queue and memories; verify counts/IDs/content/buffered kcal before and after. A simulated save failure preserves the source backup.
- [ ] On isolated Supabase, apply migration history and new migration, then >60-meal/>30-workout pagination, nullable weight, revision conflict, lost-response retry, delete/undo and incremental restore tests.
- [ ] Verify authenticated ownerA own access and ownerB/anon denial for select/insert/update/delete. Record policies inspected; do not infer deployed protection from a public client key.
- [ ] Validate physical-device HealthKit save/delete/undo and scoped overnight reading with a test account/dataset. Record whether real device validation was possible; simulator-only success does not verify this gate.
- [ ] Confirm bundled provider credential removal and owner-side rotation if active. Check logs/artifacts for accidental sensitive content before publication.

### Visual and accessibility acceptance

- [ ] Use smallest supported available iPhone layout, standard iPhone and largest iPhone; standard text and largest accessibility size; light/dark; long Ukrainian copy. Identify exact devices and OS in evidence.
- [ ] Capture Today ready/empty/partial/stale/error; Workout multiple-session/running/strength; Nutrition empty/review/error/undo; Trends sparse90d/extreme-weight; Coach answer/error/keyboard.
- [ ] Inspect every capture: no clipped primary action, overlapping keyboard/toolbars, unreadable units, contradictory status or empty chart frame. Largest text may scroll; do not reduce font size to fit.
- [ ] Run VoiceOver through tab roots, evidence disclosure, charts/list alternatives, add/edit/delete/undo and chat retry; verify labels/order/focus and accessible alternatives to swipes.
- [ ] Enable Reduce Motion and Increased Contrast. Confirm status is understandable without color and animations do not block tasks.
- [ ] Check03:59→04:00, Budapest spring/fall DST and timezone travel without rewriting existing dietary attribution.

### Performance and final gate

- [ ] Measure cold launch, warm tab switch, refresh and trend query on named fixture/device; collect median/p95 and main-thread stall observations. Compare before/after using the same dataset; investigate regressions rather than asserting inherited <5ms claims.
- [ ] Run Debug tests and Release simulator build. Physical signing/archive is separate evidence if a signing identity is available.

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project ios/Lifecore/Lifecore/Lifecore.xcodeproj -scheme Lifecore -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' test CODE_SIGNING_ALLOWED=NO
xcodebuild -project ios/Lifecore/Lifecore/Lifecore.xcodeproj -scheme Lifecore -destination 'generic/platform=iOS Simulator' -configuration Release build CODE_SIGNING_ALLOWED=NO
bash -n scripts/run_e2e.sh
./scripts/run_e2e.sh .maestro/suite.yaml
git diff --check
```

- [ ] Update CHANGELOG with affected files and date; PROJECT_KNOWLEDGE current implementation; ARCHITECTURE actual flow; DATABASE actual schema/migration state; ROADMAP only verified completion; README/ios README setup and limitations. Remove outdated duplicate claims rather than append another conflicting version.
- [ ] Independent review checks complete spec coverage and verifies no P1 is hidden by fallback data or disabled tests. Keep unresolved physical-device/backend gates visible if access is unavailable.
- [ ] Commit `feat: complete verified native redesign` only when the statement is accurate; otherwise use a narrower conventional message. Push verified changes to `origin/main` without force. Apply production migration via `supabase db push` only after verified target/backup and completed local/staging acceptance; record version and result.

## Acceptance report format

The evidence document records, for each gate: requirement, fixture/device/backend, command/action, expected result, observed result, commit, artifact path and status (pass/fail/not run). Include limitations and rollback/recovery instructions. Never substitute a checked roadmap box for the underlying evidence.

Rollback preserves user data: revert presentation independently; retain additive schema columns and durable outbox compatibility; recover local store from validated backup; pause sync on incompatible schema/auth rather than deleting records. No destructive down-migration as an automatic rollback.
