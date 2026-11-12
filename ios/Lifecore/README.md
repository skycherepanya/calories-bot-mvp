# Lifecore Native iOS Client

## Architecture & Test Suite Configuration

- **Xcode Project:** `ios/Lifecore/Lifecore/Lifecore.xcodeproj`
- **Application Target:** `Lifecore` (iOS 27.0 deployment target)
- **Unit Test Target:** `LifecoreTests` (hosted by `Lifecore.app`, `@testable import Lifecore`)
- **Shared Scheme:** `ios/Lifecore/Lifecore/Lifecore.xcodeproj/xcshareddata/xcschemes/Lifecore.xcscheme` (TestAction enables `LifecoreTests`)
- **Language Mode & Concurrency:** `SWIFT_VERSION = 5.0` with `SWIFT_APPROACHABLE_CONCURRENCY = YES`.
  - *Swift 6 Migration Gate:* Existing global actor boundaries across `LifecoreSyncIntent`, `LogMealIntent` (AppIntents), `SwiftDataModels.swift`, and `HealthKitManager.swift` will be isolated in tasks R2–R7 before transitioning project build settings to `SWIFT_VERSION = 6.0`.

## Verified Test & Build Commands

Run unit tests on iOS 27.0 Simulator:
```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project ios/Lifecore/Lifecore/Lifecore.xcodeproj \
           -scheme Lifecore \
           -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' \
           test CODE_SIGNING_ALLOWED=NO
```

Run Debug application build:
```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project ios/Lifecore/Lifecore/Lifecore.xcodeproj \
           -scheme Lifecore \
           -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' \
           -configuration Debug \
           build CODE_SIGNING_ALLOWED=NO
```

## Isolated Composition (`AppEnvironment`)

`AppEnvironment` manages runtime dependencies and storage isolation:
- `AppEnvironment.live`: Live HealthKit, Gemini AI, and Supabase sync providers using `LifecoreDataStore.shared.container`.
- `AppEnvironment.fixture`: Deterministic mock providers (`MockHealthDataProvider`, `MockAIProvider`, `MockSyncProvider`) and an isolated, in-memory `ModelContainer`.
  - Zero network calls to Supabase or Gemini.
  - Zero queries or writes to Apple HealthKit.
  - Automatically activated during unit test execution or via `--fixture` / `-LifecoreFixtureMode 1` / `LIFECORE_FIXTURE_MODE=1`.
