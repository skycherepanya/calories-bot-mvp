# Phase 2.1: HealthKit Telemetry Reader & Deterministic Math Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the native Swift 6 on-device telemetry extraction (`WorkoutTelemetryExtractor`) and deterministic physiological math engine (`WorkoutMathEngine`, `ReadinessCalculator`) in `ios/Lifecore/`, reorganizing into the target modular directory structure.

**Architecture:** 
- `Core/HealthKit/`: Extracts raw biometric series from Apple HealthStore (`HKQuantitySeriesSample`, `HKWorkoutActivity`, `HKWorkoutRoute`).
- `Core/MathEngine/`: Pure, testable, deterministic Swift engine for 1km auto-splits, interval laps, Efficiency Factor ($EF$), Cardiac Drift %, Pure NEAT isolation, Recovery Score (0-100%), and 7d/14d rolling weight averages.
- Zero arithmetic in LLM prompts; all telemetry is pre-calculated on-device.

**Tech Stack:** Swift 6, HealthKit, Foundation, SwiftUI, Xcode 27 / iOS 27 deployment target.

**Spec:** `ARCHITECTURAL_PIVOT_IOS_FIRST.md` (Sections 2 & 3), `PROJECT_KNOWLEDGE.md` (Sections 2 & 3), `docs/ROADMAP.md` (Section 2.1).

## Global Constraints
- Swift 6 strict concurrency (`Sendable`, actor isolation where appropriate).
- Zero floating-point arithmetic or statistical calculation in AI prompts.
- All code comments and documentation in concise English (Token Economy).
- Day shift convention at 04:00 AM (`shiftHours = 4`).
- Caloric deficit buffer +12.5% (`round(raw_kcal * 1.125)`).
- Normal RHR variations ($\pm 2-4$ bpm) are standard training adaptations; no panic thresholds.

---

### Task 1: Reorganize `ios/Lifecore/` into Modular Architecture

**Files:**
- Move: `ios/Lifecore/Lifecore/Lifecore/HealthKitManager.swift` -> `ios/Lifecore/Lifecore/Lifecore/Core/HealthKit/HealthKitManager.swift`
- Move: `ios/Lifecore/Lifecore/Lifecore/HealthPayload.swift` -> `ios/Lifecore/Lifecore/Lifecore/Core/Storage/HealthPayload.swift`
- Move: `ios/Lifecore/Lifecore/Lifecore/LifecoreAPIService.swift` -> `ios/Lifecore/Lifecore/Lifecore/Core/Storage/LifecoreAPIService.swift`
- Move: `ios/Lifecore/Lifecore/Lifecore/LifecoreSyncIntent.swift` -> `ios/Lifecore/Lifecore/Lifecore/Intents/LifecoreSyncIntent.swift`
- Move: `ios/Lifecore/Lifecore/Lifecore/LifecoreApp.swift` -> `ios/Lifecore/Lifecore/Lifecore/App/LifecoreApp.swift`
- Move: `ios/Lifecore/Lifecore/Lifecore/ContentView.swift` -> `ios/Lifecore/Lifecore/Lifecore/Features/Today/ContentView.swift`

- [ ] **Step 1: Create directories & move files**
Move files into `App/`, `Core/HealthKit/`, `Core/Storage/`, `Features/Today/`, `Intents/`.
- [ ] **Step 2: Verify project builds with `xcodebuild`**
Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ios/Lifecore/Lifecore/Lifecore.xcodeproj -scheme Lifecore -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`
Expected: `** BUILD SUCCEEDED **`
- [ ] **Step 3: Commit reorganization**

---

### Task 2: Implement `WorkoutTelemetryExtractor.swift`

**Files:**
- Create: `ios/Lifecore/Lifecore/Lifecore/Core/HealthKit/WorkoutTelemetryExtractor.swift`

**Interfaces:**
- Consumes: `HKHealthStore`, `HKWorkout`
- Produces: `WorkoutTelemetrySeries` (time-series samples of distance, heart rate, elevation, cadence, speed) and interval activities.

- [ ] **Step 1: Define `RawTelemetrySample` and `WorkoutTelemetrySeries` data structures**
Timestamped distance meters, heart rate bpm, elevation meters, cadence rpm.
- [ ] **Step 2: Implement async quantity series queries**
Query `HKQuantityType(.heartRate)`, `HKQuantityType(.distanceWalkingRunning)`, and workout activities.
- [ ] **Step 3: Build & verify compilation with `xcodebuild`**
- [ ] **Step 4: Commit**

---

### Task 3: Implement `WorkoutMathEngine.swift`

**Files:**
- Create: `ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/WorkoutMathEngine.swift`

**Interfaces:**
- Consumes: `WorkoutTelemetrySeries`, distance, duration, elevation samples.
- Produces: `WorkoutAnalysisResult`:
  - `splits: [SplitMetric]` (1km auto-splits with pace, avg HR, max HR, $\Delta h$, avg cadence).
  - `laps: [LapIntervalMetric]` (work vs recovery laps, HR recovery drop).
  - `efficiencyFactor: Double` ($\text{Speed (m/min)} / \text{Avg HR (bpm)}$).
  - `aerobicDecouplingPct: Double` ($((EF_1 - EF_2) / EF_1) \times 100\%$).
  - `isIndoorTreadmill: Bool`.
  - `benchmarkComparison(against: [WorkoutAnalysisResult]) -> BenchmarkDelta`.

- [ ] **Step 1: Write deterministic mathematical algorithms**
Implement 1km split slicing algorithm, interval lap parser, EF formula, and cardiac drift % calculation.
- [ ] **Step 2: Implement benchmark delta comparison against prior sessions**
- [ ] **Step 3: Build & verify compilation with `xcodebuild`**
- [ ] **Step 4: Commit**

---

### Task 4: Implement `ReadinessCalculator.swift`

**Files:**
- Create: `ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/ReadinessCalculator.swift`

**Interfaces:**
- Consumes: `SleepLog`, morning HRV, morning RHR, 30-day baseline statistics, daily active calories, workout calories, historical weights.
- Produces:
  - `recoveryScore: Int` (0–100%)
  - `strainScore: Double` (0–100%)
  - `neatKcal: Double` ($\max(0, \text{active\_kcal} - \sum \text{workout\_kcal})$)
  - `rollingWeight7d: Double?`
  - `rollingWeight14d: Double?`

- [ ] **Step 1: Implement Pure NEAT Isolation**
- [ ] **Step 2: Implement 7d and 14d Rolling Weight Averages**
- [ ] **Step 3: Implement Recovery Score (0–100%) & Strain Score**
- [ ] **Step 4: Build & verify compilation with `xcodebuild`**
- [ ] **Step 5: Commit**

---

### Task 5: Unit Verification Suite for Math Engine

**Files:**
- Create: `ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/MathEngineVerification.swift`

- [ ] **Step 1: Write standalone verification tests**
Test 1km auto-split accuracy on sample 10km run data.
Test EF calculation: $Speed (m/min) / HR$.
Test Aerobic Decoupling: $<5\%$ vs $>5\%$.
Test Pure NEAT: $\max(0, 1100 - 695) = 405$ kcal.
Test Rolling Weight: 7-day and 14-day window smoothing.
Test Recovery Score: Sasha's baseline inputs (HRV 102ms, RHR 49bpm, 7.8h sleep -> High Recovery).
- [ ] **Step 2: Execute verification via `xcodebuild` / CLI test runner**
- [ ] **Step 3: Commit and update documentation**
Update `CHANGELOG.md`, `docs/ROADMAP.md` (mark completed items in 2.1).
