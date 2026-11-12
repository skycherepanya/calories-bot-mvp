# Lifecore

Native iOS athletic-performance application combining Apple Health telemetry, deterministic workout/recovery calculations, meal logging and Ukrainian AI explanations. The active client uses SwiftUI, Swift Charts, HealthKit and SwiftData; Supabase provides cloud upload and limited initial hydration. Legacy Telegram code is archived in tag `v1.0-telegram-archive`.

## Current status — 2026-11-12

The application builds with Xcode 27.1 for iOS Simulator. Checked-in deployment target is **iOS 27.0**, language mode **Swift 5.0**. The toolchain supports newer Swift; this does not mean the target uses Swift 6 language mode. Build warnings and substantial correctness gaps remain.

The [architecture/product audit](docs/audits/2026-11-12-architecture-and-product-audit.md) records28 findings, including synthetic production health fallbacks, inconsistent training inputs, fabricated AI fallback results, cloud restore mismatches and unenforced tests. Existing model outputs are heuristics; clinical validity and performance claims have not been established by this audit.

A complete redesign is **planned, not implemented**. The selected direction is calm native iOS with clear hierarchy and minimal noise:

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

Baseline result: build passes with warnings. `xcodebuild test` currently fails because the scheme has no test action/target. Thirteen verification groups print results on Debug app startup; they do not enforce build failure. Existing Maestro flows mostly check navigation/control visibility. They are not proof of physiology, persistence, undo or cloud correctness. R1/D1 in the plan introduce enforced isolated tests.

The current `./scripts/run_e2e.sh` mutates simulator profile/meal state and can use live service dependencies. It was syntax-checked but not executed during the audit. Do not present its missing-Maestro exit0 as a test pass.

## Data and configuration

Do not copy credentials from source into logs or documentation. Current configuration includes a bundled reversible AI credential and shared cloud identity; R8 replaces these with explicit credential setup/authenticated ownership. A Supabase publishable key is public application configuration, not a secret. Deployed RLS policies and actual credential validity were not checked.

No database migration was created/applied in the documentation audit. Before future `supabase db push`, verify the target project, existing migration history, isolated replay/restore and ownership tests. See [database reference](docs/DATABASE.md).

## Project references

[Current implementation](PROJECT_KNOWLEDGE.md), [architecture](docs/ARCHITECTURE.md), [roadmap](docs/ROADMAP.md), [changelog](CHANGELOG.md), [agent rules](AGENTS.md).
