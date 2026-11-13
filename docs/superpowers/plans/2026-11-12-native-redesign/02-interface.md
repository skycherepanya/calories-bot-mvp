# Calm native interface implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` or `executing-plans` task-by-task.

**Goal:** Replace the engine-centric cockpit with readable, accessible daily decisions and complete user flows.
**Architecture:** Screens consume immutable snapshots and repository actions through injected view models; shared primitives format and route, never compute physiology.
**Tech Stack:** SwiftUI, Swift Charts, XCTest, Maestro, deterministic preview fixtures.
**Spec:** [Native redesign](../../specs/2026-11-12-native-redesign-design.md).

## Global constraints

Inherit all [master plan](../2026-11-12-native-redesign.md) constraints. `APP` = `ios/Lifecore/Lifecore/Lifecore`; `TEST` = `ios/Lifecore/Lifecore/LifecoreTests`. Use R2 `ScreenState` and R4 `DailyDashboardSnapshot`; do not invent another health model per screen. R1 owns target additions. Global docs are serialized through the orchestrator.

Each task includes all states: initial loading, empty, partial, fresh, stale, refresh with retained content, failed retry, unavailable source. Capture standard/large Ukrainian text in light/dark. Never substitute a preview fixture into production on failure. Test reducers/async transitions that can fail; do not write tests merely mirroring cosmetic constants.

## U1 — Semantic primitives, shell and settings route

Dependencies:R2; fixture composition R1. Own `APP/Core/UI/LifecoreDesignSystem.swift`, new `APP/Core/UI/Components/{MetricRow,SectionHeader,ScreenStateView,PrimaryAction,ChartSummary}.swift`, `APP/App/{MainTabView,LifecoreApp}.swift`, new `APP/Features/Settings/SettingsView.swift`, `TEST/NavigationTests.swift`.

Interfaces: `MetricRow(title: String, value: String, detail: String?)`; `SectionHeader(title: String)`; `PrimaryAction(title: String, action: () -> Void)`; `ChartSummary(title: String, value: String, coverage: String)`; `ScreenStateView` is generic over R2 `ScreenState` with injected retry/content builders. Avoid premature shared form/chart frameworks.

- [x] Build a fixture gallery (`ComponentGalleryFixtureView`) with ready/empty/failure/long-text examples; document16pt inset,4/8/12/16/24/32 spacing and44pt minimum targets. Use semantic fonts/colors and dynamic vertical reflow.
- [ ] Replace forced light appearance after every migrated screen can render semantic surfaces. During transition, keep old presentation isolated behind the migration route rather than changing colors globally without validation.
- [x] Keep four tabs and NavigationStack paths; add Settings route with athlete, Health access, AI setup, account/sync and memory entries. Child owners deliver their actual screens; incomplete features show explicit unavailable/setup state with a useful action, not a nonfunctional row.
- [x] Wire AppEnvironment (`snapshotCoordinator`, `modelContainer`) through the shell/Settings; feature screens adopt shared dependencies in U2–U5. Add navigation tests covering tab preservation and settings return path.
- [x] Keep VoiceOver labels, accessibility identifiers, and keyboard dismissal in Settings.
- [x] Run `NavigationTests`, Debug build, and update implementation docs.

## U2 — Today vertical slice

Dependencies:U1/R4. Own `APP/Features/Today/{TodayView,TacticalPrescriptionCard,OvernightVitalsCard,AthleteProfileSheet}.swift`, new `APP/Features/Today/TodayViewModel.swift`, `TEST/TodayViewModelTests.swift`. Shared profile persistence contract stays with storage owner.

Consumes R4 coordinator; `TodayViewModel` exposes its `ScreenState<DailyDashboardSnapshot>` and commands `refresh() async`, `openEvidence`, `openWorkout`. UI must not call `evaluateAdaptiveSnapshot`, assemble joined histories or manufacture a `TrainingPrescriptionPlan`.

- [x] Create fixtures: no data; partial night; measured ready day; measured confluence day; stale cache+network error. Test no-data produces no85% score, no `.optimal` fallback and no exportable synthetic telemetry.
- [x] Render date/freshness → primary readiness+explanation → single next-session action → compact sleep/vitals/activity rows → last workout. Put source detail behind an evidence disclosure; put cloud operations in settings.
- [x] Remove `loadFallbackSnapshot`, default healthy TacticalPrescriptionCard initialization and duplicated longitudinal builder. Bind to coordinator; source error and real empty are distinct.
- [x] Profile save triggers coordinator invalidation and retains the chosen form input on save failure. Numeric input accepts locale decimal separators with validation; no unsupported anthropometric clamp.
- [x] Test refresh retains content, stale result cannot replace current revision,03:59→04:00 rollover changes day, and profile edit changes inputs once. Fixture Today/Workouts consumers must read the same plan revision.
- [ ] Capture compact/large text, empty/stale/confluence screenshots; inspect VoiceOver evidence/action order. Update `.maestro/01_profile_and_readiness.yaml` through D1 owner to reopen/check persisted value. (Unit & integration assertions verified via `TodayViewModelTests`; screenshot/Maestro evidence pending D1.)

## U3 — Workouts vertical slice

Dependencies:U1/R4/R3b. Own `APP/Features/Workouts/{WorkoutsView,RollingHorizonDeckView,WorkoutDetailView,WorkoutDetailComponents,WorkoutChartsView}.swift`, new `APP/Features/Workouts/{WorkoutsViewModel,WorkoutDetailViewModel}.swift`, `TEST/WorkoutsViewModelTests.swift`. Explicitly exclude CoachReportView and LifecoreIntelligenceChatView (U6).

Interfaces: `WorkoutsViewModel` consumes the shared coordinator and workout repository; owns selected DietaryDay, sport filter and `ScreenState` of history. Workout detail consumes analyzed result + evidence availability, not synthetic fallback telemetry.

- [x] Test illness/load fixture yields the same displayed prescription as Today; delete fixed64/60/.optimal inputs. Future entries are projections with generated-at timestamp.
- [x] Separate Today's plan from History; selected day supports multiple sessions. Use R2 dietary boundaries for01:00 workouts and date navigation. Show accessible reset when filters remove all results.
- [x] Fix hide-walks scope: when selected category is Walks, its actual records remain visible. Test All→hide walks→Walks→All transitions and load failure vs true empty.
- [x] Implement sport-aware detail: running gets compatible pace/splits/EF/drift, cycling uses valid speed/distance/HR, strength emphasizes duration/HR/effort. Omit unsupported metrics with a concise source-coverage explanation where useful.
- [x] Charts expose units, inspected timestamp/value and a readable alternative. Missing route/elevation/HR remains absent; respect pauses and partial splits from R3b.
- [x] Test retry, stale refresh and cached history. (`WorkoutsViewModelTests` pass; large-text screenshot capture and D1 flow03/05 run pending D1.)

## U4 — Nutrition vertical slice

Dependencies:U1/R5a/R6/R7. Own `APP/Features/Nutrition/{NutritionView,NutritionComponents,FoodInputSheet}.swift`, new `APP/Features/Nutrition/{NutritionViewModel,MealReviewSheet}.swift`, `TEST/NutritionFlowTests.swift`.

Consumes R6 durable lifecycle/repository and R5a raw-to-normalized service. UI shows final tracked kcal plus explainable exact estimate; it never multiplies kcal again. Analysis does not automatically confirm or export a meal.

- [x] Test state transitions with fake provider and save failure: draft→analyzing→review→confirmed; analyzing→failed→retry; review→cancel. Assert zero HealthKit/cloud calls before confirmation.
- [x] Show dietary date, consumed/target with logging-completeness language, meal list and one Add action. Distinguish no logs from zero confirmed intake. Move quality/micronutrient details below primary content/disclosure.
- [x] Preserve photo/text on error, support editable manual entry and retry, explain AI estimate confidence without false guarantees. Validate nonnegative finite amounts and valid tags; always keep protein/fat/carbs precision in storage.
- [x] Remove both service-level/caller-level offline fabricated results. Confirm performs durable save before success; optional export failures show saved-local/pending state.
- [x] Native swipe/context/accessibility delete uses repository tombstone; Undo preserves UUID and revision. Test delete→undo during export, relaunch after deletion and save-failed rollback of visible success state.
- [x] Keep unique identifiers: `btn_add_meal`, `meal_review_confirm`, `meal_analysis_retry`, `meal_delete`, `meal_undo`; per-row values include stable fixture identity when multiple records exist.
- [x] Run `NutritionFlowTests`; updated `.maestro/02_nutrition_logging_and_undo.yaml` for `meal_review_confirm` (live Maestro flow run & screenshots pending D1).

## U5 — Trends vertical slice

Dependencies:U1/R3d. Own `APP/Features/Trends/{TrendsView,TrendsComponents,CorrelationInsightsCard}.swift`, new `APP/Features/Trends/{TrendsViewModel,ChartDomain}.swift`, `TEST/TrendsViewModelTests.swift`.

`TrendsViewModel.load(rangeDays: Int) async` captures range and request generation; only the latest completion publishes. `ChartDomain.weight(_ values: [Double]) -> ClosedRange<Double>?` filters non-finite values and returns nil if empty; otherwise padding = max(1.5, (max-min)*0.1), lower=min-padding, upper=max+padding. Do not clip valid weights to40/150.

```swift
XCTAssertEqual(ChartDomain.weight([38]), 36.5...39.5)
XCTAssertEqual(ChartDomain.weight([152]), 150.5...153.5)
XCTAssertNil(ChartDomain.weight([.nan, .infinity]))
```

- [x] Write domain tests above plus empty/constant/mixed-invalid series before implementing the helper; no invalid ClosedRange can reach Chart.
- [x] Test delayed30d response after fast90d response; final displayed range and data remain90d. Cancellation must clear only its own request state. Remove `isLoading` early-return behavior that drops new selections.
- [x] Replace feature-level fake joins with R3d builder. A90d display receives90d data; any fixed-window engine summary is separately labeled with its actual observation interval/coverage.
- [x] Render one primary chart+summary per selected metric/category; accessible point list, gaps and sample counts. Put adaptation diagnostics behind disclosure. Signed correlations match calculated evidence and avoid causal medical language.
- [x] Run `TrendsViewModelTests` (sparse screenshot captures and live flow04 run pending D1).

## U6 — Coach, evidence and memory presentation

Dependencies:U1/R5b/U3/R8. Own `APP/Features/Workouts/{CoachReportView,LifecoreIntelligenceChatView}.swift`, new `APP/Features/Coach/{CoachViewModel,CoachEvidenceView,MemoryReviewView}.swift`, `TEST/CoachFlowTests.swift`. Settings destination wiring is serialized with U1 owner.

Produces `@MainActor CoachViewModel.submit(_ text: String) async`; this method guards in-flight state for both keyboard and button. Snapshot evidence and chat turn IDs are immutable per request; failure preserves draft and successful earlier history.

- [x] Test immediate duplicate submission from button/keyboard; fake provider receives one request. Resolve requests in reversed timing; history remains ordered or later request was explicitly queued.
- [x] Replace technical RAG/engine badges with concise Ukrainian Coach/Explain language; expose source/time/coverage via evidence disclosure. Preserve 70/15/15 report emphasis and one24h directive without making absent sections look computed.
- [x] Distinguish generating, unavailable provider, rate-limit/retry, stale report and confirmed completed report. Old stored reports remain readable with legacy provenance; never overwrite with a fabricated fallback.
- [x] Confirm/remove memory candidates via durable repository; do not auto-promote inferred medical/dietary assertions. Add first-use external-data explanation and credential setup route through R8.
- [x] Test empty evidence, unsupported evidence IDs, failed request/retry, memory reject/accept/delete/relaunch and missing key. (`CoachFlowTests` pass; keyboard/VoiceOver screenshot checks pending D1.)
- [x] Run `CoachFlowTests`; update documentation.
