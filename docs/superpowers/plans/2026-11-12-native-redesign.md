# Lifecore native redesign implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` (recommended) or `executing-plans` to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Deliver a calm native iOS interface backed by truthful, consistent health/nutrition data and recoverable persistence/sync.

**Architecture:** Keep existing native engines. Introduce provenance-aware repositories, one versioned daily snapshot/prescription, validated AI boundaries and a durable outbox. Migrate feature screens after contracts stabilize.

**Tech Stack:** SwiftUI, Swift Charts, HealthKit, SwiftData, URLSession, Supabase/PostgreSQL, XCTest/Swift Testing and Maestro.

**Spec:** [2026-11-12-native-redesign-design.md](../specs/2026-11-12-native-redesign-design.md)

## Global constraints

- Native SwiftUI, Swift Charts, HealthKit, SwiftData; preserve four tabs and current application identity.
- Keep deployment floor iOS 27.0 during this redesign; use Xcode 27.1 for the recorded baseline.
- Current language mode is Swift 5.0. Move to Swift 6 only through R1's explicit migration gate.
- English code/documentation/prompts; Ukrainian product strings.
- Deterministic computations remain Swift; calorie buffer exactly once: `round(kcal_exact * 1.125)`, macros unchanged.
- Dietary boundary 04:00 via Calendar; missing observations are never zeros/normal baselines.
- Preserve project illness confluence, quality tags and 70/15/15 coach emphasis. Read the full spec before any task.
- No production fixtures, destructive resets, bundled provider secrets or assumed cloud authorization.
- This document is an executable proposal. All implementation checkboxes start open; documentation completion is not application implementation.

## Required reading and executable packets

1. [Audit:28 findings and baseline verification](../../audits/2026-11-12-architecture-and-product-audit.md).
2. [Target product/architecture specification](../specs/2026-11-12-native-redesign-design.md).
3. [Reliability and data contracts: R1–R9](2026-11-12-native-redesign/01-reliability.md), including R3a–d and R5a–b.
4. [Native screen redesign: U1–U6](2026-11-12-native-redesign/02-interface.md).
5. [Integration/release gate: D1](2026-11-12-native-redesign/03-delivery.md).

## Scheduling and ownership

Use one orchestrator plus at most three simultaneous workers. A task may start only when dependencies have merged and its owned files are unclaimed. Parallel read-only reviews are safe. Parallel implementation is limited to disjoint file sets.

- **Wave0:** R1 test/build composition, then R2 domain contracts. R1 owns project/scheme/test-target edits for all waves.
- **Wave1:** R3a HealthKit ingestion; R5a nutrition AI; R6 durable storage. These own different source files. R6 owns all SwiftData schema edits.
- **Wave2:** R3b workout math after R3a; R3c physiology after R3a; R5b evidence after R5a/R6. R3b owns extractor while R3a is finished; R3c owns manager while R3a is finished. R5b owns RAG/prompts while R5a is finished.
- **Wave3:** R3d longitudinal analytics after R3a/R3c/R6; R7 sync after R6/R5a/R3c; U1 visual primitives after R2. R7 sends required entity additions to R6 owner before editing DTOs. U1 alone owns shell/design-system files.
- **Wave4:** R4 coordinator after R3b/c/d; R8 configuration/auth after R5a/R7; U5 Trends after R3d/U1. R8 changes AI/sync adapters only while their prior owners are idle.
- **Wave5:** U2 Today, U3 Workouts, U4 Nutrition after R4/R5a/R6/R7/U1. At most three workers. They consume frozen protocols and do not edit shared files.
- **Wave6:** U6 Coach after R5b/U3/R8; R9 Intents after R5a/R6/R7/R8; D1 integration review starts after both and all screen tasks complete.

U5 can run in a later wave if capacity or integration dependencies require it. Wave order is a safe default, not permission to bypass task dependencies. Never parallel-edit `HealthKitManager.swift`, `SwiftDataModels.swift`, `GeminiService.swift`, project.pbxproj, shell/theme or global docs.

## Execution checklist

- [x] R1 — Enforced tests, isolated fixtures, honest toolchain, explicit Swift 6 gate. (commit `9bf75de`; fixture isolation repaired and verified in Task B)
- [x] R2 — Observation, dietary-day, interval and screen-state contracts. (commit `18bc227`)
- [x] R3a — Real HealthKit histories, episode normalization and missingness.
- [x] R3b — Workout timing and metadata correctness.
- [x] R3c — Longitudinal load, timed battery and HRV-method consistency.
- [x] R3d — Calendar-based joins, signed correlations and adaptive date math.
- [x] R4 — One daily snapshot and prescription with revisioned invalidation.
- [x] R5a — Validated nutrition and honest AI failures.
- [x] R5b — Scoped evidence, factual offline explanation and controlled memory.
- [x] R6 — Durable mutations, migration preservation and meal lifecycle.
- [x] R7 — Typed, idempotent, revisioned, paginated sync. (Swift/DTO/Coordinator verified via `SyncContractTests`; `supabase db push` deployment pending remote DB check)
- [x] R8 — Configuration, credential migration and cloud authorization. (`ConfigurationTests` pass; `20261113140000_r8_rls_and_ownership.sql` & `rls_ownership_contract.sql` authored; live `supabase db push`, remote RLS replay, legacy ownership backfill & key rotation pending D1/staging verification)
- [x] R9 — Durable and truthful AppIntents. (`IntentOutcomeTests` pass)
- [x] U1 — Semantic design system, native shell and settings.
- [x] U2 — Today hierarchy and all data states. (`TodayViewModelTests` pass; D1 Maestro/screenshot verification pending)
- [x] U3 — Workout planning/history/detail by sport. (`WorkoutsViewModelTests` pass; D1 Maestro/screenshot verification pending)
- [x] U4 — Food capture/review/confirm/delete/undo. (`NutritionFlowTests` pass; D1 Maestro/screenshot verification pending)
- [x] U5 — Trends range, safe domains and coverage. (`TrendsViewModelTests` pass; D1 Maestro/screenshot verification pending)
- [x] U6 — Coach report/chat/evidence/memory. (`CoachFlowTests` pass; D1 Maestro/screenshot verification pending)
- [ ] D1 — Integrated verification, visual/accessibility acceptance and release evidence.

## Shared commands

Run from repository root. The project path is intentionally nested; do not substitute an older documentation path.

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -version
xcrun simctl list devices available
xcodebuild -project ios/Lifecore/Lifecore/Lifecore.xcodeproj -scheme Lifecore -destination 'generic/platform=iOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

After R1 creates `LifecoreTests` and enables the scheme test action:

```bash
xcodebuild -project ios/Lifecore/Lifecore/Lifecore.xcodeproj -scheme Lifecore -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' test CODE_SIGNING_ALLOWED=NO
```

Use an actually installed destination if names/runtimes differ; record it. Packet test filters append `-only-testing:LifecoreTests/TEST_CLASS`. Before R1 the test command is expected to fail (baseline exit 66); do not report test pass from a build alone. Network integrations use URLProtocol/fake repositories and local/staging Supabase, never the user's production records.

## Per-task review protocol

1. Orchestrator reads spec, task and referenced findings; confirms prerequisite commits and worktree state.
2. Worker receives exact owned paths, immutable contract signatures, fixture inputs and required output. Use the repository worktree skill when isolation is needed; reuse a suitable current checkout otherwise.
3. Worker demonstrates the failing regression, implements the smallest coherent fix/slice, reruns targeted tests and supplies docs notes. Capture commands, exit codes and limitations.
4. Fresh reviewer checks spec compliance; another pass checks correctness, data-loss risks and tests. Fix findings before starting dependent work.
5. Orchestrator integrates serialized shared-file edits, updates global docs immediately, runs the affected integration tests and commits a conventional change. Push the verified integration to `origin/main` per AGENTS.md; workers do not independently push.
6. Update this task checkbox and audit resolution with the actual commit/test evidence. If blocked, record the exact external dependency; do not fabricate passing evidence or mark completed.

## Economical execution mode

For a limited-context worker, execute one task per session after reading the audit summary, relevant finding IDs, global constraints and that task's packet section. Do not paste the whole repository/history into every worker. The orchestrator retains the dependency/ownership ledger and supplies prerequisite commit IDs and frozen interfaces. Start sequentially with R1, then R2; expand parallelism only for the disjoint waves above. External account/device gates may pause the affected release step without blocking unrelated local work.

All code snippets in packets are contract examples or test fragments, not drop-in complete implementations. The owning task must finish the types and tests, compile them, and publish exact signatures before dependent workers start. No worker may silently revise another task's interface.

## Copyable launch prompt

```text
Execute docs/superpowers/plans/2026-11-12-native-redesign.md task-by-task with subagent-driven-development. Read AGENTS.md, the linked audit, design spec and all three packets first. Preserve the user's calm native iOS direction. Implement the full plan, starting with R1/R2 and respecting the dependency waves and exclusive file ownership. Use one orchestrator plus at most three workers. For each task run failing-before/passing-after regressions and independent spec/correctness reviews. Keep demo data isolated; never reset user storage or treat missing metrics as measured. Update documentation after each landed slice. Commit conventional changes and push verified integration to origin/main. Apply any new schema migrations only after local/staging migration, restore and ownership tests pass; never infer ownership of legacy numeric IDs. Finish with the D1 evidence matrix and disclose unverified device/backend gates. Do not stop after a cosmetic theme change.
```

The prompt authorizes future implementation when the user invokes it; this audit/documentation turn does not execute the proposed app changes.
