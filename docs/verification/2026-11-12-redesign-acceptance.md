# Lifecore Native Redesign — Acceptance & Verification Report (D1)

**Date:** 2026-11-13
**Target Plan:** [2026-11-12-native-redesign.md](../superpowers/plans/2026-11-12-native-redesign.md) / [03-delivery.md](../superpowers/plans/2026-11-12-native-redesign/03-delivery.md)
**Baseline Commits Covered:** `17b86ff` (R2) → `dbf49c5` (R1) → `430e43c` (R3a) → `89806e2` (R3b/R5a) → `ff2bfef` (R3c/R6) → `661034d` (R3d/R5b) → `318f025` (R4/R7/U1) → `5c0a768` (R8/R9/U2–U6) + D1 integration/E2E fixes
**Toolchain:** Xcode `27.1` (`Build version 27A9275`), Swift `5.0` language mode, deployment target `iOS 27.0`
**Simulator Destination:** `iPhone 17` (`iOS 27.0`, UDID `70393F75-9EBB-42D3-804D-358354739CFC`)
**E2E / Backend Tooling:** Maestro CLI `2.11.0` (`JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`), Supabase CLI (linked project `khmviccwbuktnvdxhnwg`)

---

## 1. Gate Summary

| Gate | Scope | Fixture / Environment | Expected Result | Observed Result | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **G1** | `LifecoreTests` Debug XCTest Suite | `AppEnvironment.fixture` (in-memory SwiftData, zero network/HK writes) on `iPhone 17` (`iOS 27.0`) | All tests pass cleanly with 0 failures | **140 tests, 0 failures** (`2.109s`, `** TEST SUCCEEDED **`) | **PASS** |
| **G2** | Release Configuration Build | `generic/platform=iOS Simulator`, `Release`, `CODE_SIGNING_ALLOWED=NO` | Release compilation + dSYM succeeds with exit 0 | `** BUILD SUCCEEDED **`, exit code `0` | **PASS** |
| **G3** | Outcome-Based Maestro E2E Suite | `LifecoreFixtureMode=true`, `LifecoreFixtureScenario=seeded`, persistent `LifecoreFixtureE2E.store` (cleanly reset per script run) | Shell check (`bash -n`) and all 5 flows (`01`–`05`) pass via `./scripts/run_e2e.sh .maestro/suite.yaml` | Exit code `0`, `5/5` flows green (`All Maestro E2E Tests Succeeded!`) | **PASS** |
| **G4** | Visual & Accessibility Inspection | Simulator screenshots (`today_light_medium.png`, `today_dark_ax_xl.png`) on `iPhone 17` (`iOS 27.0`) | No occluded actions, readable ax-XL layout; verify light/dark and edge strings | Toolbar Settings & inline Undo overlap fixed; Ax-XL scales cleanly inside `ScrollView` with minor card text truncation; `.preferredColorScheme(.light)` lock prevents dark theme; multi-device sizes & VoiceOver/Reduce Motion walkthrough not run | **PARTIAL** |
| **G5** | Audit Findings F01–F28 Resolution | Audit baseline (`2026-11-12-architecture-and-product-audit.md`) | Each P1/P2 finding has verified regression coverage or explicit blocker disposition | 26 client/engine/UI findings covered by `LifecoreTests` + Maestro; F12 remote RLS & key rotation + F19 physical/assistive checks remain gated | **PARTIAL** |
| **G6** | Remote Supabase Migration & RLS Replay | Linked Supabase (`khmviccwbuktnvdxhnwg`), `20261113120000_r7_sync_convergence.sql`, `20261113140000_r8_rls_and_ownership.sql`, `sync_contract.sql`, `rls_ownership_contract.sql` | `supabase db push` + remote contract replay verify pagination, CAS `409`, ownerA/ownerB/anon RLS & backfill | Blocked: `psql`/`docker` unavailable locally; `supabase migration list` fails with `unexpected login role status 544` timeout | **NOT RUN / BLOCKED BY ENVIRONMENT** |
| **G7** | Physical iPhone / Apple Watch HealthKit | Physical hardware + real HealthKit sensors + developer signing identity | Scoped overnight vitals + HealthKit meal save/delete/undo verified on device | Blocked: simulator-only environment without paired Watch/HealthKit hardware or signing certificate | **NOT RUN / BLOCKED BY ENVIRONMENT** |
| **G8** | Key Rotation & Cloud CI Runner SDK | Google AI Studio / Supabase credentials + GitHub Actions `macos-15` | Upstream leaked/legacy key rotated by owner; cloud CI runs iOS 27.0 E2E | Client bundled secret removed (`GeminiService.defaultApiKey = ""`), but upstream rotation requires owner dashboard; GitHub `macos-15` runners lacking iOS 27 SDK skip E2E per `09c21b9` | **NOT RUN / BLOCKED BY ENVIRONMENT** |

---

## 2. Executed Commands & Observed Evidence

### G1 — Hosted Unit, Contract & ViewModel Tests (`PASS`)
- **Command:**
  ```bash
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  export PATH="$DEVELOPER_DIR/bin:$PATH"
  xcodebuild -project ios/Lifecore/Lifecore/Lifecore.xcodeproj -scheme Lifecore -destination 'id=70393F75-9EBB-42D3-804D-358354739CFC' test CODE_SIGNING_ALLOWED=NO
  ```
- **Observed Output:** `Executed 140 tests, with 0 failures (0 unexpected) in 2.109 (2.146) seconds` (`** TEST SUCCEEDED **`).
- **Artifact:** `/Users/skycherepanya/Library/Developer/Xcode/DerivedData/Lifecore-dkqkzcpdnmswsgcxxjyreuhnqqar/Logs/Test/Test-Lifecore-2026.11.13_12-36-23-+0100.xcresult`
- **Covered Suites (22 test/helper files in `LifecoreTests/`):** `EnvironmentIsolationTests`, `DietaryDayTests`, `ObservationTests`, `HealthRepositoryTests`, `WorkoutTelemetryTests`, `PhysiologyTests`, `LongitudinalTests`, `DailySnapshotTests`, `NutritionContractTests`, `CoachEvidenceTests`, `PersistenceTests`, `SyncContractTests`, `ConfigurationTests`, `IntentOutcomeTests`, `NavigationTests`, `TodayViewModelTests`, `WorkoutsViewModelTests`, `NutritionFlowTests`, `TrendsViewModelTests`, `CoachFlowTests`, and `LegacyVerificationTests`.

### G2 — Release Simulator Build (`PASS`)
- **Command:**
  ```bash
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  export PATH="$DEVELOPER_DIR/bin:$PATH"
  xcodebuild -project ios/Lifecore/Lifecore/Lifecore.xcodeproj -scheme Lifecore -destination 'generic/platform=iOS Simulator' -configuration Release build CODE_SIGNING_ALLOWED=NO
  ```
- **Observed Output:** Exit code `0`, `GenerateDSYMFile ... Lifecore.app.dSYM`, `** BUILD SUCCEEDED **`.

### G3 — Outcome-Based Maestro E2E Suite (`PASS`)
- **Commands:**
  ```bash
  bash -n scripts/run_e2e.sh
  ./scripts/run_e2e.sh .maestro/suite.yaml
  ```
- **D1 Integration Fixes Verified in Run:**
  1. `AppEnvironment.swift`: Added `UserDefaults.standard` fixture detection (`LifecoreFixtureMode`) and persistent isolated E2E store (`LifecoreFixtureE2E.store` in Application Support outside XCTest) so Maestro app relaunches retain logged/restored meals without polluting live storage or XCTest in-memory runs.
  2. `DailySnapshotCoordinator.swift`: Differentiated `FixtureDailySnapshotDataSource` between `"empty"`/XCTest and E2E `"seeded"` mode (`readinessScore: 84`, `morningBodyBattery: 82`, `currentBodyBattery: 74`, real `TrainingLoadAndBatteryEngine` & `OvernightVitalsEvaluation` math).
  3. `MainTabView.swift`, `TodayView.swift`, `WorkoutsView.swift`, `NutritionView.swift`, `TrendsView.swift`: Replaced floating `.bottomTrailing` `btn_open_settings` overlay (which occluded `MealItemCard` controls) with `SettingsToolbarButton` (`OpenLifecoreSettingsKey`) in `.topBarTrailing` across all 4 tabs; resolved duplicate `"screen_trends"` / `"trends_scroll_view"` accessibility identifier in `TrendsView.swift`.
  4. `NutritionComponents.swift`, `NutritionView.swift`, `NutritionViewModel.swift`: Added explicit `btn_meal_details` callback & synchronous delete before sheet dismiss; moved `undoBanner` inline inside `mealsListSection` with `.padding(.bottom, 88)` so iOS 27's floating Liquid Glass Tab Bar no longer blocks `meal_undo`; extended `scheduleUndoDismiss` window to `30s`.
  5. `scripts/run_e2e.sh` & `.maestro/01`–`05`: Reset `LifecoreFixtureE2E.store` & UserDefaults cleanly on suite start, enforced `LifecoreFixtureMode=true` + `LifecoreFixtureScenario=seeded`, preserved debug/screenshot artifacts in `/tmp/lifecore-e2e-artifacts` with an `EXIT` failure-screenshot trap, and aligned flows with redesigned controls.
- **Observed Flow Outcomes (`All Maestro E2E Tests Succeeded!`, exit `0`):**
  - `01_profile_and_readiness.yaml`: Readiness cockpit visible, opens/closes Settings (`screen_settings`), saves profile weight `82` and verifies `"82.*"` after reopening.
  - `02_nutrition_logging_and_undo.yaml`: Logs oatmeal preset (`"Вівсянка з ягодами"`, `"320 ккал"`), opens `btn_meal_details`, deletes & confirms (`meal_delete`), restores via inline `meal_undo`, relaunches app verifying SwiftData persistence.
  - `03_workout_filtering_and_refresh.yaml`: Scrolls below `RollingHorizonDeckView` to `filter_workout_all`, exercises workout category filters and refresh.
  - `04_trends_adaptive_analytics.yaml`: Exercises `"90 днів"` range pill and all category tabs in `screen_trends`.
  - `05_training_prescription_flow.yaml`: Verifies shared `card_tactical_prescription` parity across `tab_today` and `deck_rolling_horizon` / `btn_recalculate_club_queue` on `tab_workouts`.
- **Artifacts:** `/tmp/lifecore-e2e-artifacts/`

### G4 — Visual & Accessibility Observations (`PARTIAL`)
- **Captures Inspected:**
  - `/tmp/lifecore-e2e-artifacts/visual/today_light_medium.png`: Light mode / Medium Dynamic Type renders cleanly with 84% readiness ring, tactical prescription (`Легкий біг з прискореннями`), overnight vitals, sleep cards, and unoccluded top-right Settings button. Note: `.topBarLeading` `btn_open_profile` coexists with `dateAndFreshnessRow` `btn_athlete_profile` (minor duplicate entry point, non-blocking).
  - `/tmp/lifecore-e2e-artifacts/visual/today_dark_ax_xl.png`: Accessibility-XL typography scales inside `ScrollView` without clipping cards or primary actions; `"Нічні вітальні у к..."` truncates in `readinessCockpitCard`. Because `LifecoreApp.swift` line 16 locks `.preferredColorScheme(.light)` (`Hallmark Daylight`), system Dark Mode stayed light-paper; an adaptive dark theme was not activated.
- **Remaining Visual/A11y Items:** Smallest/largest physical iPhone form factors, full multi-state screenshot matrix beyond Today/Nutrition/Workouts/Trends E2E checks, manual VoiceOver screen-reader traversal, Reduce Motion / Increased Contrast visual audit, and manual multi-timezone DST device checks (TZ math is tested in unit suites).

---

## 3. Audit Findings F01–F28 Disposition

| Findings | Redesign Task(s) | Verification Basis | Disposition |
| :--- | :--- | :--- | :--- |
| `F20` | `R1`, `D1` | `LifecoreTests` hosted target (`140/140`), `EnvironmentIsolationTests`, `run_e2e.sh`, Release build (`dbf49c5`, D1) | **Resolved** (cloud CI `macos-15` runner SDK `<27` limitation documented in `09c21b9`) |
| `F01`, `F05`, `F26` | `R2`, `R3d` | `ObservationTests`, `DietaryDayTests`, `LongitudinalTests` (`17b86ff`, `661034d`) | **Resolved** |
| `F02`, `F04`, `F13`, `F14`, `F15` | `R3a`, `R3b`, `R3c`, `R3d` | `HealthRepositoryTests`, `WorkoutTelemetryTests`, `PhysiologyTests`, `LongitudinalTests` (`430e43c`, `89806e2`, `ff2bfef`, `661034d`) | **Resolved** |
| `F03` | `R4`, `U2`, `U3` | `DailySnapshotTests`, `TodayViewModelTests`, `WorkoutsViewModelTests`, Maestro `01` & `05` (`318f025`, `5c0a768`) | **Resolved** |
| `F06`, `F07`, `F08`, `F21` | `R5a`, `R5b`, `U4`, `U6` | `NutritionContractTests`, `CoachEvidenceTests`, `NutritionFlowTests`, `CoachFlowTests`, Maestro `02` (`89806e2`, `661034d`, `5c0a768`) | **Resolved** |
| `F09`, `F10`, `F11`, `F22`, `F23`, `F24`, `F25`, `F28` | `R6`, `R7`, `R9` | `PersistenceTests`, `SyncContractTests`, `IntentOutcomeTests` (`ff2bfef`, `318f025`, `5c0a768`) | **Client Resolved / Remote SQL Replay Blocked** (`G6`) |
| `F16`, `F17` | `U5` | `TrendsViewModelTests`, Maestro `04` (`5c0a768`) | **Resolved** |
| `F18` | `U3` | `WorkoutsViewModelTests`, Maestro `03` (`5c0a768`) | **Resolved** |
| `F27` | `U6` | `CoachFlowTests` (`5c0a768`) | **Resolved** |
| `F12` | `R8` | `ConfigurationTests`, `20261113140000_r8_rls_and_ownership.sql`, `rls_ownership_contract.sql` (`5c0a768`) | **Client Key Isolation Resolved / Remote RLS & Key Rotation Blocked** (`G6`, `G8`) |
| `F19` | `U1`–`U6`, `D1` | `NavigationTests`, `Today/Workouts/Nutrition/Trends/Coach` tests, `01`–`05` Maestro E2E, `today_light_medium` & `today_dark_ax_xl` (`318f025`, `5c0a768`, D1) | **Partially Resolved** (UI overlap & Ax-XL scroll verified; Dark lock, VoiceOver & physical sizes pending `G4`/`G7`) |

---

## 4. Open External Gates (Required Before Production Distribution)

1. **Remote Supabase Deployment & Contract Verification (`G6`):** Install/run with Postgres `psql` and working Supabase DB role connectivity (`544` login-role timeout cleared), execute `supabase db push` to apply `20261113120000_r7_sync_convergence.sql` and `20261113140000_r8_rls_and_ownership.sql`, verify `supabase/tests/sync_contract.sql` and `supabase/tests/rls_ownership_contract.sql`, and complete legacy `auth_user_id` ownership backfill on user data.
2. **Physical iPhone / Apple Watch & Assistive Audit (`G4`, `G7`):** Run signed Release build on physical hardware with live HealthKit samples (sleep stages, wrist temperature, workout GPX splits, meal HealthKit export/delete/undo), VoiceOver focus-order walkthrough, Reduce Motion/Increased Contrast checks, and multi-device viewport sizing.
3. **Owner-Side Credential Rotation (`G8`):** Rotate any previously committed Gemini / backend credentials in the provider consoles (`GeminiService.defaultApiKey = ""` is now empty and BYOK uses `KeychainCredentialStore`).

---

## 5. Rollback & Recovery Policy

- **Presentation Rollback:** UI slices (`Features/Today`, `Workouts`, `Nutrition`, `Trends`, `Coach`, `Settings`, `App/MainTabView`) can be reverted per-feature without altering `DailySnapshotCoordinator`, `PhysiologyHistoryBuilder`, or `SyncOutbox` contracts.
- **Schema & Outbox Preservation:** Do **not** run destructive SQL down-migrations dropping `meals` (`client_uuid`, `revision`, `is_deleted`, `kcal_exact`, `buffer_version`, `provenance`, `updated_at`), `workout_analyses.revision`, `daily_metrics.neat_kcal`, or `auth_user_id`. Additive columns remain backwards-compatible with paused clients.
- **Local Store & Sync Safety:** `PersistenceRecovery` retains backups across SwiftData migration; on incompatible schema or expired auth (`AccountSessionManager`), pause `SyncCoordinator` uploads instead of clearing local `SyncOutbox` entries unless switching/signing out of accounts.
