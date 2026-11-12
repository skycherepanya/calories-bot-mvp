# Lifecore native iOS client

## Verified configuration — 2026-11-12

- Project: `ios/Lifecore/Lifecore/Lifecore.xcodeproj`; application source: `ios/Lifecore/Lifecore/Lifecore/`.
- Deployment target:iOS 27.0. Language mode:Swift 5.0. Audited toolchain:Xcode 27.1 (27A9275). Swift 6 mode is a planned migration gate, not current configuration.
- Frameworks:SwiftUI, Swift Charts, HealthKit, SwiftData, AppIntents. No separate XCTest target exists at baseline.
- UI:four tabs, current forced-light Daylight theme. Calm native redesign is proposed in the [master plan](../docs/superpowers/plans/2026-11-12-native-redesign.md).

## Setup

1. Open the project in Xcode with an SDK supporting iOS 27.0; Xcode 27.1 is the verified toolchain.
2. For physical-device runs, select the developer team and signing identity, preserve the configured bundle ID, and enable the HealthKit capabilities required by the checked-in entitlements.
3. Use a compatible physical iPhone/Watch for actual nocturnal measurements; availability varies by device, data source and granted access. Simulator builds do not verify real HealthKit ingestion.
4. Inspect account/provider configuration before invoking live sync/AI. Current bundled credential/shared-identity limitations are documented in the audit; do not publish their values.

From repository root:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project ios/Lifecore/Lifecore/Lifecore.xcodeproj -scheme Lifecore -destination 'generic/platform=iOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

The command-local environment override avoids changing global `xcode-select`. Build passed with warnings during the audit. `xcodebuild test` returned66: scheme not configured for the test action. Debug startup calls13 verification groups but only prints failures. R1 adds an actual test target and isolated fixtures; D1 adds outcome assertions and device evidence.

## Modules

`Core/HealthKit` reads telemetry; `Core/MathEngine` computes metrics; `Core/Storage` persists meals/workout analyses/training queue/memory; `Core/AI` handles prompts/provider/RAG; `Core/UI` defines current styling. `Features` currently also orchestrate queries/history joins, a boundary addressed by the redesign. `Intents` exposes food and sync operations.

Read the [audit](../docs/audits/2026-11-12-architecture-and-product-audit.md) before relying on displayed readiness, load, trends, fallback AI output or restore. Source review is not clinical validation. Prior <5ms query and <5s capture claims lack measured evidence in this audit.
