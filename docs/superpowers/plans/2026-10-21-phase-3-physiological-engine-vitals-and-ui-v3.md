# Lifecore 3.0 (Phase 3) — Physiological Intelligence, Overnight Vitals, Illness Prodrome, Time-Lagged Correlations & UI 3.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade Lifecore into a clinical-grade, on-device physiological intelligence platform incorporating 5-metric Overnight Vitals (`appleSleepingWristTemperature`, `oxygenSaturation`, `respiratoryRate`, `restingHeartRate`, beat-to-beat `RMSSD` / $\ln\text{SDNN}$), pre-symptomatic illness detection (Stanford NightSignal + Apple Vitals confluence), Garmin Firstbeat workload math (Banister TRIMP, EWMA ACWR, Continuous Energy Bank), a confounder-controlled Time-Lagged Correlation Engine ($T+0, T+1, T+2$), and the **Lifecore UI 3.0 (Bevel 2.0 + Apple Vitals Liquid Glass Dark)** redesign.

**Architecture:** All mathematical modeling, R-R ectopic artifact filtering, logarithmic Z-score baseline normalization, EWMA workload ratios, illness state-machine evaluation, and statistical correlation matrices execute deterministically in pure Swift 6 on-device (`Lifecore/Core/MathEngine/`). `HealthKitManager` is expanded to ingest `HKHeartbeatSeriesSample`, `appleSleepingWristTemperature`, `oxygenSaturation`, `respiratoryRate`, and `vo2Max`. Gemini AI receives pre-computed correlation coefficients ($r, r_{pb}$) and vitals confluence states strictly for qualitative synthesis in Ukrainian.

**Tech Stack:** Swift 6, SwiftUI, Swift Charts, HealthKit (`HKHeartbeatSeriesQuery`, `HKStatisticsQuery`), SwiftData, Supabase PostgreSQL (`007_lifecore_v3_vitals_and_correlations.sql`).

**Spec:** `docs/superpowers/specs/2026-10-21-lifecore-v3-physiological-engine-and-ui-design.md`

## Global Constraints

1. **English-Only Code & Docs:** All Swift code, comments, database migrations, and markdown documentation must be written in concise, high-density English (`AGENTS.md` Rule 1.1).
2. **Ukrainian User Output:** All user-facing UI strings, Insights cards, Illness Radar alerts, and AI Coach outputs must be in natural athletic Ukrainian (`AGENTS.md` Rule 1.2).
3. **Strict Math vs AI Separation:** Zero arithmetic or statistical correlation calculation is delegated to Gemini (`AGENTS.md` Rule 2.2).
4. **Zero Medical Alarmism Guardrail:** Single-metric fluctuations (e.g., $\pm 2\text{--}3\text{ bpm}$ RHR from a hard workout) must never trigger sickness alarms. The **Immune Strain / Illness Prodrome Radar** activates strictly upon multi-metric nocturnal confluence ($\ge 3$ simultaneous outliers, or wrist temperature elevation $\Delta T \ge +0.40^\circ\text{C}$ paired with an autonomic shift).
5. **Dietary Date Shift:** Maintain the `04:00 AM` dietary day cutoff across all nutrition-to-recovery time-lag correlations.

---

## Proposed File Structure & Decomposition

| File Path | Action | Responsibility |
|---|---|---|
| `supabase/migrations/007_lifecore_v3_vitals_and_correlations.sql` | **Create** | Adds `hrv_rmssd_ms`, `wrist_temp_delta_c`, `spo2_pct`, `respiratory_rate`, `sleep_efficiency_pct`, `immune_state` to `sleep_logs`; adds `trimp_score`, `ewma_acute_load`, `ewma_chronic_load`, `acwr_ratio`, `body_battery_wake`, `body_battery_min` to `daily_metrics`. |
| `ios/Lifecore/Lifecore/Lifecore/Core/Storage/AthleteProfileStore.swift` | **Create** | Stores editable athlete profile (Weight, Height, Age, Max HR, RHR baseline, BMR, Active Move Goal, Macro Targets, HRV method toggle `hybridRMSSD` vs `appleSDNN`). |
| `ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/VitalsAndIllnessEngine.swift` | **Create** | Beat-to-beat R-R 20% artifact filter, $\ln(\text{RMSSD})$ calculator, 5-metric Overnight Vitals corridor evaluator, and NightSignal + Apple Vitals Illness Prodrome state machine. |
| `ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/TrainingLoadAndBatteryEngine.swift` | **Create** | Banister TRIMP calculator, EWMA Acute (7d) & Chronic (28d) Workload Ratio (ACWR), Continuous 24h Body Battery / Energy Bank curve, and Sleep Debt / Consistency score. |
| `ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/CorrelationEngine.swift` | **Create** | Multi-day time-lagged ($T+0, T+1, T+2$) Point-Biserial ($r_{pb}$) and Pearson ($r$) correlation engine with high-strain confounder filtering. |
| `ios/Lifecore/Lifecore/Lifecore/Core/HealthKit/HealthKitManager.swift` | **Modify** | Queries `appleSleepingWristTemperature`, `oxygenSaturation`, `respiratoryRate`, `vo2Max`, and `HKHeartbeatSeriesSample` via `HKHeartbeatSeriesQuery`. |
| `ios/Lifecore/Lifecore/Lifecore/Core/Storage/HealthPayload.swift` | **Modify** | Extends `SleepLog` and `DailyActivity` with Vitals, RMSSD, TRIMP, EWMA ACWR, and Body Battery fields. |
| `ios/Lifecore/Lifecore/Lifecore/Core/Storage/SupabaseSyncService.swift` | **Modify** | Syncs new Vitals/ACWR columns and adds `pullHistoricalDataIfNeeded()` for two-way cloud hydration. |
| `ios/Lifecore/Lifecore/Lifecore/Core/UI/LifecoreDesignSystem.swift` | **Create** | Liquid Glass Dark surface modifiers, specular borders, animated ring gradients, and Vitals corridor pill components. |
| `ios/Lifecore/Lifecore/Lifecore/Features/Today/OvernightVitalsCard.swift` | **Create** | 5-metric Overnight Vitals corridor bar, Illness Prodrome Radar banner, and 24h Energy Bank chart card. |
| `ios/Lifecore/Lifecore/Lifecore/Features/Today/AthleteProfileSheet.swift` | **Create** | User-editable physiological & nutritional calibration sheet. |
| `ios/Lifecore/Lifecore/Lifecore/Features/Today/TodayView.swift` | **Modify** | Integrates `LifecoreDesignSystem`, `OvernightVitalsCard`, `EnergyBankCard`, `AthleteProfileStore`, and `AthleteProfileSheet`. |
| `ios/Lifecore/Lifecore/Lifecore/Features/Trends/CorrelationInsightsCard.swift` | **Create** | Interactive Insights & Correlations Hub + EWMA ACWR Sweet-Spot chart for `TrendsView`. |
| `ios/Lifecore/Lifecore/Lifecore/Features/Trends/TrendsView.swift` | **Modify** | Adds segmented/sectioned navigation for Physiological Trends, ACWR Workload, Overnight Vitals History, and Time-Lagged Correlations. |
| `ios/Lifecore/Lifecore/Lifecore/Core/AI/CoachPrompt.swift` | **Modify** | Injects Overnight Vitals status, ACWR ratio, and top personal time-lagged correlations into Gemini's context. |
| `ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/MathEngineVerification.swift` | **Modify** | Adds deterministic unit tests for `VitalsAndIllnessEngine`, `TrainingLoadAndBatteryEngine`, and `CorrelationEngine`. |

---

## Bite-Sized Implementation Tasks

### Task 1: Database Schema Upgrade (`007_lifecore_v3_vitals_and_correlations.sql`) & Athlete Profile Store

**Files:**
- Create: `supabase/migrations/007_lifecore_v3_vitals_and_correlations.sql`
- Create: `ios/Lifecore/Lifecore/Lifecore/Core/Storage/AthleteProfileStore.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/Core/Storage/HealthPayload.swift`

**Interfaces:**
- Produces: `AthleteProfile`, `AthleteProfileStore`, extended `SleepLog` and `DailyActivity`.

- [ ] **Step 1: Create SQL migration `supabase/migrations/007_lifecore_v3_vitals_and_correlations.sql`**

```sql
-- Migration 007: Lifecore 3.0 Overnight Vitals, Immune Radar, EWMA ACWR & Body Battery
ALTER TABLE sleep_logs
    ADD COLUMN IF NOT EXISTS hrv_rmssd_ms NUMERIC(5, 1),
    ADD COLUMN IF NOT EXISTS wrist_temp_delta_c NUMERIC(4, 2),
    ADD COLUMN IF NOT EXISTS spo2_pct NUMERIC(4, 1),
    ADD COLUMN IF NOT EXISTS respiratory_rate NUMERIC(4, 1),
    ADD COLUMN IF NOT EXISTS sleep_efficiency_pct NUMERIC(4, 1),
    ADD COLUMN IF NOT EXISTS immune_state TEXT DEFAULT 'optimal';

ALTER TABLE daily_metrics
    ADD COLUMN IF NOT EXISTS trimp_score NUMERIC(6, 1),
    ADD COLUMN IF NOT EXISTS ewma_acute_load NUMERIC(6, 1),
    ADD COLUMN IF NOT EXISTS ewma_chronic_load NUMERIC(6, 1),
    ADD COLUMN IF NOT EXISTS acwr_ratio NUMERIC(4, 2),
    ADD COLUMN IF NOT EXISTS body_battery_wake INTEGER,
    ADD COLUMN IF NOT EXISTS body_battery_min INTEGER;
```

- [ ] **Step 2: Create `AthleteProfileStore.swift` to replace hardcoded BMR, Move, Macro, and HR constants**

```swift
import Foundation
import Combine

public enum HRVCalculationMethod: String, Codable, CaseIterable, Sendable {
    case hybridRMSSD = "rmssd_hybrid" // Bevel-style beat-to-beat RMSSD with ln(SDNN) fallback
    case appleSDNN = "sdnn_only"      // Native Apple Health SDNN with ln(SDNN) normalization
}

public struct AthleteProfile: Codable, Sendable, Equatable {
    public var weightKg: Double
    public var heightCm: Double
    public var ageYears: Int
    public var maxHeartRateBpm: Double
    public var restingHeartRateBaselineBpm: Double
    public var hrvBaselineMs: Double
    public var wristTempBaselineCelsius: Double
    public var respiratoryRateBaselineBpm: Double
    public var spo2BaselinePct: Double
    public var bmrKcalPerDay: Double
    public var activeMoveGoalKcal: Double
    public var targetCaloriesKcal: Double
    public var targetProteinG: Double
    public var targetFatG: Double
    public var targetCarbsG: Double
    public var targetSleepHours: Double
    public var hrvMethod: HRVCalculationMethod

    public static let sashaDefault = AthleteProfile(
        weightKg: 78.6,
        heightCm: 181.0,
        ageYears: 28,
        maxHeartRateBpm: 192.0,
        restingHeartRateBaselineBpm: 49.0,
        hrvBaselineMs: 102.0,
        wristTempBaselineCelsius: 36.40,
        respiratoryRateBaselineBpm: 14.2,
        spo2BaselinePct: 97.8,
        bmrKcalPerDay: 1750.0,
        activeMoveGoalKcal: 650.0,
        targetCaloriesKcal: 2150.0,
        targetProteinG: 165.0,
        targetFatG: 70.0,
        targetCarbsG: 215.0,
        targetSleepHours: 7.5,
        hrvMethod: .hybridRMSSD
    )
}

@MainActor
public final class AthleteProfileStore: ObservableObject {
    public static let shared = AthleteProfileStore()
    private let storageKey = "lifecore.athlete_profile.v3"

    @Published public var profile: AthleteProfile {
        didSet { save() }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(AthleteProfile.self, from: data) {
            self.profile = decoded
        } else {
            self.profile = .sashaDefault
        }
    }

    public func save() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
```

- [ ] **Step 3: Update `HealthPayload.swift` to include the new Vitals & Workload fields with backward-compatible optional properties**

---

### Task 2: Overnight Vitals & Illness Prodrome Engine (`VitalsAndIllnessEngine.swift`)

**Files:**
- Create: `ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/VitalsAndIllnessEngine.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/MathEngineVerification.swift`

**Interfaces:**
- Produces:
  - `VitalsAndIllnessEngine.computeCleanRMSSD(beats: [(timeSinceStart: TimeInterval, precededByGap: Bool)]) -> Double?`
  - `VitalsAndIllnessEngine.computeLogHRVZScore(currentHrvMs: Double, historicalHrvMs: [Double], fallbackMeanMs: Double) -> Double`
  - `VitalsAndIllnessEngine.evaluateOvernightVitals(input: NocturnalVitalsInput, baseline: NocturnalVitalsBaseline) -> OvernightVitalsEvaluation`

- [ ] **Step 1: Implement `VitalsAndIllnessEngine.swift` with 20% ectopic R-R filter, $\ln(\text{RMSSD})$, and 5-metric confluence Illness Prodrome Classifier**
- [ ] **Step 2: Add deterministic tests for `computeCleanRMSSD`, `computeLogHRVZScore`, and `evaluateOvernightVitals` in `MathEngineVerification.swift`**

---

### Task 3: Garmin Firstbeat Workload (Banister TRIMP, EWMA ACWR) & Continuous Energy Bank (`TrainingLoadAndBatteryEngine.swift`)

**Files:**
- Create: `ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/TrainingLoadAndBatteryEngine.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/ReadinessCalculator.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/MathEngineVerification.swift`

**Interfaces:**
- Produces:
  - `TrainingLoadAndBatteryEngine.computeBanisterTRIMP(durationMin: Double, avgHr: Double, restingHr: Double, maxHr: Double) -> Double`
  - `TrainingLoadAndBatteryEngine.computeEWMAWorkload(dailyLoads: [(date: Date, trimp: Double)]) -> ACWREvaluation`
  - `TrainingLoadAndBatteryEngine.computeEnergyBankTimeline(wakeRecoveryScore: Int, sleepHours: Double, targetSleepHours: Double, pureNeatKcal: Double, workouts: [(hour: Int, trimp: Double)], immuneState: ImmuneSystemState, currentHour: Int) -> EnergyBankEvaluation`

- [ ] **Step 1: Implement `TrainingLoadAndBatteryEngine.swift` with Banister TRIMP, 7d/28d EWMA ACWR, and 24h Body Battery differential trajectory**
- [ ] **Step 2: Add unit tests for Banister TRIMP and EWMA ACWR sweet-spot classification in `MathEngineVerification.swift`**

---

### Task 4: Multi-Day Time-Lagged Correlation Engine (`CorrelationEngine.swift`)

**Files:**
- Create: `ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/CorrelationEngine.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/MathEngineVerification.swift`

**Interfaces:**
- Produces:
  - `CorrelationEngine.pearsonR(_ x: [Double], _ y: [Double]) -> Double?`
  - `CorrelationEngine.computeInsights(records: [DailyJoinedPhysiologyRecord]) -> [CorrelationInsight]`

- [ ] **Step 1: Implement `CorrelationEngine.swift` evaluating $T+0, T+1, T+2$ lags with high-TRIMP confounder filtering**
- [ ] **Step 2: Add unit tests in `MathEngineVerification.swift` verifying sodium-to-water retention correlation and confounder exclusion**

---

### Task 5: HealthKit Extended Telemetry & Two-Way Supabase Sync (`HealthKitManager.swift`, `SupabaseSyncService.swift`)

**Files:**
- Modify: `ios/Lifecore/Lifecore/Lifecore/Core/HealthKit/HealthKitManager.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/Core/Storage/SupabaseSyncService.swift`

- [ ] **Step 1: Extend `HealthKitManager.requestAuthorization()` with `.oxygenSaturation`, `.respiratoryRate`, `.appleSleepingWristTemperature`, `.vo2Max`, and `HKSeriesType.heartbeat()`**
- [ ] **Step 2: Add `fetchOvernightVitals()` and `fetchCleanNightlyRMSSD()` in `HealthKitManager.swift` and wire into `fetchTodaySnapshot()`**
- [ ] **Step 3: Upgrade `SupabaseSyncService.swift` to sync Vitals/ACWR columns and implement `pullHistoricalDataIfNeeded()` for two-way cloud hydration**

---

### Task 6: Lifecore UI 3.0 Redesign (`LifecoreDesignSystem.swift`, `OvernightVitalsCard.swift`, `CorrelationInsightsCard.swift`, `AthleteProfileSheet.swift`)

**Files:**
- Create: `ios/Lifecore/Lifecore/Lifecore/Core/UI/LifecoreDesignSystem.swift`
- Create: `ios/Lifecore/Lifecore/Lifecore/Features/Today/OvernightVitalsCard.swift`
- Create: `ios/Lifecore/Lifecore/Lifecore/Features/Today/AthleteProfileSheet.swift`
- Create: `ios/Lifecore/Lifecore/Lifecore/Features/Trends/CorrelationInsightsCard.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/Features/Today/TodayView.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/Features/Trends/TrendsView.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/Core/AI/CoachPrompt.swift`

- [ ] **Step 1: Create `LifecoreDesignSystem.swift` with Liquid Glass Dark cards (`.lifecoreGlassCard()`), specular gradient borders, and status glow pills**
- [ ] **Step 2: Create `OvernightVitalsCard.swift` (5-metric Apple Vitals corridor + Illness Prodrome Radar banner + 24h Energy Bank chart) and `AthleteProfileSheet.swift`**
- [ ] **Step 3: Upgrade `TodayView.swift` to UI 3.0 using dynamic `AthleteProfileStore` targets, `OvernightVitalsCard`, and `EnergyBankCard`**
- [ ] **Step 4: Create `CorrelationInsightsCard.swift` (Time-Lagged Correlation Hub + EWMA ACWR Sweet-Spot chart) and integrate into `TrendsView.swift`**
- [ ] **Step 5: Inject Vitals Confluence, ACWR, and Time-Lagged Correlations into `CoachPrompt.swift`**

---

### Task 7: Verification, Documentation Sync & Supabase Migration Deployment

- [ ] **Step 1: Run `MathEngineVerification` and full Xcode build (`xcodebuild -project ios/Lifecore/Lifecore/Lifecore.xcodeproj -scheme Lifecore -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`)**
- [ ] **Step 2: Apply Supabase migration `007_lifecore_v3_vitals_and_correlations.sql` via `supabase db push --include-all`**
- [ ] **Step 3: Update `CHANGELOG.md`, `PROJECT_KNOWLEDGE.md`, `docs/ROADMAP.md`, `docs/DATABASE.md`, `docs/ARCHITECTURE.md`, and `README.md`**
