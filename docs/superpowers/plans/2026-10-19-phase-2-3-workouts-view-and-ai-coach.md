# Phase 2.3: Workouts View & 70/15/15 AI Coach Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native iOS athletic workout dashboard featuring workout filtering, 1km auto-splits, structured interval laps, synchronized Swift Charts telemetry (pace, HR zones, elevation profile), Efficiency Factor ($EF$), cardiac drift %, and on-demand 70/15/15 Athletic Performance Analyst AI coaching via Gemini.

**Architecture:** Native iOS (Swift 6, SwiftUI, Swift Charts, HealthKit) with local-first deterministic telemetry processing via `WorkoutMathEngine.swift` and `WorkoutTelemetryExtractor.swift`, passing structured metrics into `GeminiService.swift` configured with `CoachPrompt.swift` for qualitative narrative reasoning.

**Tech Stack:** Swift 6, SwiftUI, Swift Charts, HealthKit, Google AI Studio Gemini API (`gemini-2.5-flash`), Supabase PostgreSQL.

**Spec:** [docs/ROADMAP.md](file:///Users/skycherepanya/Developer/GitHub/calories-bot-mvp/docs/ROADMAP.md) (Phase 2, Step 2.3), [PROJECT_KNOWLEDGE.md](file:///Users/skycherepanya/Developer/GitHub/calories-bot-mvp/PROJECT_KNOWLEDGE.md) (Section 3.1 & Section 5.2).

## Global Constraints
- **Token Economy:** All documentation, code, variable names, and comments strictly in concise English.
- **Ukrainian Output:** AI Coach generated reports and end-user labels strictly in Ukrainian.
- **Deterministic Math:** Zero arithmetic calculations performed by Gemini. All splits, EF, drift %, and recovery deltas computed natively in Swift.
- **Anti-Alarmism:** Zero "anxious therapist" tone; normal day-to-day RHR variations ($\pm 2\text{--}4\text{ bpm}$) are standard adaptations, NOT medical emergencies; no generic unsolicited wellness platitudes.
- **70 / 15 / 15 Formula:** 70% workout telemetry analysis, 15% historical benchmark comparison, 15% physiological root causes + 1 actionable 24h athletic directive.

---

### Task 1: AI Prompt & Gemini Service Foundation (`Core/AI/`)

**Files:**
- Create: `ios/Lifecore/Lifecore/Lifecore/Core/AI/CoachPrompt.swift`
- Create: `ios/Lifecore/Lifecore/Lifecore/Core/AI/GeminiService.swift`

**Interfaces:**
- Produces: `CoachPrompt.buildSystemPrompt() -> String`
- Produces: `CoachPrompt.buildUserPrompt(analysis: WorkoutAnalysisResult, recoveryContext: RecentRecoveryContext?) -> String`
- Produces: `GeminiService.shared.generateCoachReport(analysis: WorkoutAnalysisResult, recoveryContext: RecentRecoveryContext?) async throws -> String`

- [ ] **Step 1: Implement `CoachPrompt.swift`** with the 70/15/15 rules, zero-alarmism constraints, and Ukrainian output formatting.
- [ ] **Step 2: Implement `GeminiService.swift`** supporting Google AI Studio endpoint, API key configuration, and async network requests.

---

### Task 2: HealthKit Workout Fetching & Context Extensions (`Core/HealthKit/`)

**Files:**
- Modify: `ios/Lifecore/Lifecore/Lifecore/Core/HealthKit/HealthKitManager.swift`

**Interfaces:**
- Consumes: HealthKit `HKWorkout`, `HKQuantityType`, `HKSampleQuery`
- Produces: `HealthKitManager.shared.fetchRecentWorkouts(days:limit:) async throws -> [HKWorkout]`
- Produces: `HealthKitManager.shared.fetchHistoricalSimilarWorkouts(to:limit:) async throws -> [(distanceKm: Double, paceMinKm: Double, avgHr: Double?, ef: Double?)]`
- Produces: `HealthKitManager.shared.fetchRecentRecoveryContext(for:) async -> RecentRecoveryContext`

- [ ] **Step 1: Add `fetchRecentWorkouts`** querying `HKWorkout` with date predicate and reverse chronological sort.
- [ ] **Step 2: Add `fetchHistoricalSimilarWorkouts`** querying prior sessions with similar activity type and $\pm 20\%$ distance.
- [ ] **Step 3: Add `fetchRecentRecoveryContext`** fetching preceding 48h sleep stages, morning HRV, and resting HR.

---

### Task 3: Swift Charts Synchronized Telemetry Component (`Features/Workouts/`)

**Files:**
- Create: `ios/Lifecore/Lifecore/Lifecore/Features/Workouts/WorkoutChartsView.swift`

**Interfaces:**
- Consumes: `WorkoutTelemetrySeries`, `RawTelemetryPoint`
- Produces: `WorkoutChartsView(series:isIndoor:)` with Swift Charts plotting Pace, Heart Rate Zones, and Elevation Profile.

- [ ] **Step 1: Implement `WorkoutChartsView.swift`** using `Charts` framework with tabs for Heart Rate, Pace, and Elevation.
- [ ] **Step 2: Add interactive selection scrub** displaying distance, instantaneous HR, and pace.

---

### Task 4: Interactive Split Table, Interval Laps & Metric Cards (`Features/Workouts/`)

**Files:**
- Create: `ios/Lifecore/Lifecore/Lifecore/Features/Workouts/WorkoutDetailComponents.swift`

**Interfaces:**
- Consumes: `WorkoutAnalysisResult`, `SplitMetric`, `LapIntervalMetric`, `BenchmarkDelta`
- Produces: `EfficiencyFactorCard`, `CardiacDriftCard`, `BenchmarkComparisonCard`, `SplitsTableView`, `IntervalLapsTableView`

- [ ] **Step 1: Implement `EfficiencyFactorCard` and `CardiacDriftCard`** with color-coded aerobic decoupling thresholds.
- [ ] **Step 2: Implement `SplitsTableView`** rendering 1km splits (km, pace, avg HR, max HR, $\Delta h$, cadence).
- [ ] **Step 3: Implement `IntervalLapsTableView`** rendering structured interval laps with heart rate recovery drop ($\text{HR}_{\text{drop}}$).

---

### Task 5: AI Coach Report Component & Detail Screen (`Features/Workouts/`)

**Files:**
- Create: `ios/Lifecore/Lifecore/Lifecore/Features/Workouts/CoachReportView.swift`
- Create: `ios/Lifecore/Lifecore/Lifecore/Features/Workouts/WorkoutDetailView.swift`

**Interfaces:**
- Consumes: `HKWorkout`, `WorkoutTelemetryExtractor`, `WorkoutMathEngine`, `GeminiService`
- Produces: `CoachReportView` (expandable 70/15/15 sections with generation trigger)
- Produces: `WorkoutDetailView(workout: HKWorkout)`

- [ ] **Step 1: Implement `CoachReportView.swift`** with Markdown parsing and 70/15/15 structured layout.
- [ ] **Step 2: Implement `WorkoutDetailView.swift`** combining Header, Charts, Split Table, Interval Laps, and AI Coach Report.

---

### Task 6: Athletic Workout Filtering & Workouts List Screen (`Features/Workouts/`)

**Files:**
- Modify: `ios/Lifecore/Lifecore/Lifecore/Features/Workouts/WorkoutsView.swift`

**Interfaces:**
- Consumes: `HealthKitManager.fetchRecentWorkouts`
- Produces: `WorkoutsView` with athletic category filtering (All, Running, Cycling, Strength, HIIT, Walks) and navigation to `WorkoutDetailView`.

- [ ] **Step 1: Implement filter selector and state in `WorkoutsView.swift`**.
- [ ] **Step 2: Build workout row cards** showing duration, distance, pace, calories, and heart rate.
- [ ] **Step 3: Connect `NavigationLink` to `WorkoutDetailView`**.

---

### Task 7: Build Verification, Documentation & Git Commit

- [ ] **Step 1: Run `xcodebuild`** verifying zero compilation errors.
- [ ] **Step 2: Update `docs/ROADMAP.md`** marking Step 2.3 complete.
- [ ] **Step 3: Update `CHANGELOG.md`** with high-density English release notes.
- [ ] **Step 4: Commit and push** to `origin/main`.
