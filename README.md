# Lifecore

Native iOS athletic-performance application combining Apple Health telemetry, deterministic workout/recovery calculations, meal logging and Ukrainian AI explanations. The active client uses SwiftUI, Swift Charts, HealthKit and SwiftData; Supabase provides cloud upload and limited initial hydration. Legacy Telegram code is archived in tag `v1.0-telegram-archive`.

## Current status — 2026-11-13

The application builds (Debug and Release) and passes its `LifecoreTests` suite (**140 tests**, 0 failures on `iPhone 17` / **iOS 27.0**, Xcode `27.1`, language mode **Swift 5.0**) alongside all **5/5** isolated Maestro E2E flows (`./scripts/run_e2e.sh .maestro/suite.yaml`). Reliability/data tasks **R1–R9**, calm native UI tasks **U1–U6**, and simulator/E2E verification **D1** are documented in [2026-11-12-redesign-acceptance.md](docs/verification/2026-11-12-redesign-acceptance.md); remote `supabase db push` / RLS contract replay, physical-device HealthKit/VoiceOver validation, and owner-side API key rotation remain open external gates before production rollout.

- [Design specification](docs/superpowers/specs/2026-11-12-native-redesign-design.md).
- [Master execution plan and copyable subagent launch prompt](docs/superpowers/plans/2026-11-12-native-redesign.md).
- [Reliability packet](docs/superpowers/plans/2026-11-12-native-redesign/01-reliability.md), [interface packet](docs/superpowers/plans/2026-11-12-native-redesign/02-interface.md), [delivery packet](docs/superpowers/plans/2026-11-12-native-redesign/03-delivery.md).

## Existing capabilities

- Four tabs: Today, Workouts, Nutrition, Trends; current visual theme is forced-light Hallmark Daylight.
- HealthKit ingestion, kilometer splits, EF/drift, readiness, vitals, workload/battery, correlations and training prescription engines. See audit for input/coverage defects.
- Text/photo nutrition recognition, local meals, HealthKit dietary exports and delete/undo interactions. Failure, normalization and sync semantics require planned repairs.
- Structured coach reports, conversational analysis and stored athlete memory. AI errors can currently produce unmarked heuristic fallback results.
- SwiftData meal/workout/plan/memory storage; profile calibration in UserDefaults. Cloud synchronization is not yet a complete convergent multi-device protocol.

## Structure

```text
ios/Lifecore/Lifecore/Lifecore.xcodeproj
ios/Lifecore/Lifecore/Lifecore/
  App/           Application lifecycle and four-tab shell
  Core/          HealthKit, MathEngine, AI, Storage, UI
  Features/      Today, Workouts, Nutrition, Trends
  Intents/       Food capture and health sync
supabase/migrations/  Checked-in SQL; deployment state not audited
.maestro/             Five existing UI smoke flows
scripts/run_e2e.sh    Build/install/Maestro runner
.github/workflows/    Existing UI-test CI
docs/               Architecture, schema, audit, specifications and plans
```

## Build and verification

Open `ios/Lifecore/Lifecore/Lifecore.xcodeproj` in Xcode 27.1 (verified baseline) with an SDK supporting iOS 27.0. Physical-device signing and HealthKit access must be configured for the developer's device/account. See [iOS setup](ios/README.md).

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project ios/Lifecore/Lifecore/Lifecore.xcodeproj -scheme Lifecore -destination 'generic/platform=iOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

Baseline result: application builds cleanly with Xcode 27.1. Task R1 established an application-hosted `LifecoreTests` target and shared scheme `Lifecore.xcscheme`. The 13 legacy `MathEngineVerification` groups now execute within `LegacyVerificationTests.swift`. `AppEnvironment` provides `.live` and `.fixture` isolation with in-memory SwiftData containers and deterministic mock providers, verified by `EnvironmentIsolationTests.swift`.

Run the test suite:
```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project ios/Lifecore/Lifecore/Lifecore.xcodeproj -scheme Lifecore -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' test CODE_SIGNING_ALLOWED=NO
```

`./scripts/run_e2e.sh` is hardened to fail closed with a nonzero exit code if Maestro CLI or required dependencies are missing. CI workflow `.github/workflows/e2e.yml` asserts SDK compatibility for the iOS 27.0 floor and runs `LifecoreTests` prior to E2E execution.

## Data and configuration

Do not copy credentials from source into logs or documentation. Bundled Gemini provider secrets have been removed (`GeminiService.defaultApiKey = ""`); Gemini BYOK credentials are stored in Keychain (`KeychainCredentialStore` via `AppConfiguration.resolveGeminiAPIKey()`, with transparent one-time UserDefaults migration), and no-key mode degrades gracefully without fabricating nutrition or debrief outputs. `AccountSessionManager` isolates user auth tokens from the public Supabase anon key and purges pending outbox mutations on sign-out/account switch. Checked-in RLS migration `20261113140000_r8_rls_and_ownership.sql` and `supabase/tests/rls_ownership_contract.sql` await remote `supabase db push` verification before production distribution. See [database reference](docs/DATABASE.md).

## Project references

[Current implementation](PROJECT_KNOWLEDGE.md), [architecture](docs/ARCHITECTURE.md), [roadmap](docs/ROADMAP.md), [changelog](CHANGELOG.md), [agent rules](AGENTS.md).
