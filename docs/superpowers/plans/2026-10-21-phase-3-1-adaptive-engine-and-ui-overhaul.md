# Phase 3.1 (Lifecore v3.1): Self-Learning Adaptive Physiology Engine & Complete Liquid Glass Bento UI Overhaul

> **For Agentic Workers (Optimized for Gemini Flash 3.8):**
> - Execute the 6 tasks below **sequentially in order** (Tasks 1 → 6).
> - **Token Economy Rule:** Exact file paths are provided (`ios/Lifecore/Lifecore/Lifecore/...`). Do NOT run broad searches or read unrelated files. Read only the target file(s) of the current task, apply the exact changes, and move to the next task.
> - **Verification Rule:** Run `xcodebuild` only once at the end of Task 2 (after math engine changes) and once at the end of Task 6 (after all UI changes).

**Goal:** Upgrade Lifecore v3.0 to **v3.1** by adding on-device mathematical self-learning (`AdaptivePhysiologyEngine`: Bayesian Shrinkage, MacroFactor-style Dynamic TDEE expenditure, Ridge OLS $\beta$-sensitivities, 60d EWMA baselines, and 1-Tap RPE weight calibration) and performing a complete top-to-bottom Liquid Glass Bento UI overhaul across all 4 tabs (`Today`, `Trends`, `Workouts`, `Nutrition`) with 100% Ukrainian localization and zero duplicate cards.

**Tech Stack:** Swift 6, SwiftUI, Swift Charts, HealthKit, SwiftData, Supabase PostgreSQL.

---

### Task 1: Create `AdaptivePhysiologyEngine.swift` & Update `AthleteProfileStore.swift` + `TrainingLoadAndBatteryEngine.swift`

**Files:**
- Create: `ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/AdaptivePhysiologyEngine.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/Core/Storage/AthleteProfileStore.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/TrainingLoadAndBatteryEngine.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/ReadinessCalculator.swift`

- [ ] **Step 1: Create `AdaptivePhysiologyEngine.swift`**
Create `ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/AdaptivePhysiologyEngine.swift` implementing the 4 self-learning loops:

```swift
import Foundation

// MARK: - Self-Learning Models (Lifecore v3.1)

public struct ReadinessWeightVector: Codable, Sendable, Equatable {
    public var hrvWeight: Double
    public var rhrWeight: Double
    public var sleepDurationWeight: Double
    public var sleepArchitectureWeight: Double

    public init(
        hrvWeight: Double = 0.40,
        rhrWeight: Double = 0.30,
        sleepDurationWeight: Double = 0.15,
        sleepArchitectureWeight: Double = 0.15
    ) {
        self.hrvWeight = hrvWeight
        self.rhrWeight = rhrWeight
        self.sleepDurationWeight = sleepDurationWeight
        self.sleepArchitectureWeight = sleepArchitectureWeight
    }

    public mutating func normalize() {
        let clampedHrv = min(0.55, max(0.15, hrvWeight))
        let clampedRhr = min(0.45, max(0.10, rhrWeight))
        let clampedDur = min(0.35, max(0.10, sleepDurationWeight))
        let clampedArch = min(0.35, max(0.10, sleepArchitectureWeight))
        let sum = max(0.01, clampedHrv + clampedRhr + clampedDur + clampedArch)
        self.hrvWeight = round((clampedHrv / sum) * 1000.0) / 1000.0
        self.rhrWeight = round((clampedRhr / sum) * 1000.0) / 1000.0
        self.sleepDurationWeight = round((clampedDur / sum) * 1000.0) / 1000.0
        self.sleepArchitectureWeight = round((1.0 - self.hrvWeight - self.rhrWeight - self.sleepDurationWeight) * 1000.0) / 1000.0
    }
}

public struct DynamicTDEEResult: Codable, Sendable, Equatable {
    public let learnedBmrKcal: Double
    public let learnedDailyTdeeKcal: Double
    public let metabolicAdaptationKcal: Double   // learnedBmr - priorBmr
    public let adaptiveTargetIntakeKcal: Double
    public let trendWeightDelta14dKg: Double
    public let validDaysCount: Int

    public init(
        learnedBmrKcal: Double,
        learnedDailyTdeeKcal: Double,
        metabolicAdaptationKcal: Double,
        adaptiveTargetIntakeKcal: Double,
        trendWeightDelta14dKg: Double = 0.0,
        validDaysCount: Int = 0
    ) {
        self.learnedBmrKcal = learnedBmrKcal
        self.learnedDailyTdeeKcal = learnedDailyTdeeKcal
        self.metabolicAdaptationKcal = metabolicAdaptationKcal
        self.adaptiveTargetIntakeKcal = adaptiveTargetIntakeKcal
        self.trendWeightDelta14dKg = trendWeightDelta14dKg
        self.validDaysCount = validDaysCount
    }
}

public struct LearnedSensitivities: Codable, Sendable, Equatable {
    public let sodiumWaterKgPerGram: Double          // kg water per +1000mg Na (Prior: +0.32)
    public let trimpBatteryDrainFactor: Double       // Battery % drain per 1 TRIMP (Prior: 0.32)
    public let lateMealRhrPenaltyBpm: Double         // +bpm overnight RHR from late meal (Prior: +3.1)
    public let carbCardiacDriftSlopePctPer100g: Double // % drift delta per +100g carbs (Prior: -1.8)

    public init(
        sodiumWaterKgPerGram: Double = 0.32,
        trimpBatteryDrainFactor: Double = 0.32,
        lateMealRhrPenaltyBpm: Double = 3.1,
        carbCardiacDriftSlopePctPer100g: Double = -1.8
    ) {
        self.sodiumWaterKgPerGram = sodiumWaterKgPerGram
        self.trimpBatteryDrainFactor = trimpBatteryDrainFactor
        self.lateMealRhrPenaltyBpm = lateMealRhrPenaltyBpm
        self.carbCardiacDriftSlopePctPer100g = carbCardiacDriftSlopePctPer100g
    }
}

public struct AdaptivePhysiologySnapshot: Codable, Sendable, Equatable {
    public let confidencePct: Int
    public let sampleDaysCount: Int
    public let dynamicTDEE: DynamicTDEEResult
    public let sensitivities: LearnedSensitivities
    public let dynamicVitalsBaseline: NocturnalVitalsBaseline
    public let readinessWeights: ReadinessWeightVector
    public let statusTitleUk: String
    public let statusSummaryUk: String

    public init(
        confidencePct: Int,
        sampleDaysCount: Int,
        dynamicTDEE: DynamicTDEEResult,
        sensitivities: LearnedSensitivities,
        dynamicVitalsBaseline: NocturnalVitalsBaseline,
        readinessWeights: ReadinessWeightVector,
        statusTitleUk: String,
        statusSummaryUk: String
    ) {
        self.confidencePct = confidencePct
        self.sampleDaysCount = sampleDaysCount
        self.dynamicTDEE = dynamicTDEE
        self.sensitivities = sensitivities
        self.dynamicVitalsBaseline = dynamicVitalsBaseline
        self.readinessWeights = readinessWeights
        self.statusTitleUk = statusTitleUk
        self.statusSummaryUk = statusSummaryUk
    }
}

// MARK: - Engine

public enum AdaptivePhysiologyEngine {

    /// Bayesian shrinkage weight w_N = N / (N + kappa)
    public static func bayesianShrinkageWeight(sampleCount: Int, kappa: Double = 14.0) -> Double {
        guard sampleCount > 0 else { return 0.0 }
        let n = Double(sampleCount)
        return min(0.95, max(0.0, n / (n + kappa)))
    }

    /// Computes model confidence percentage (0 - 99%)
    public static func computeConfidencePct(sampleCount: Int, rpeCheckinsCount: Int = 0) -> Int {
        let effectiveN = Double(max(0, sampleCount)) + Double(min(20, rpeCheckinsCount)) * 0.5
        let raw = 100.0 * (effectiveN / (effectiveN + 10.0))
        return min(99, max(12, Int(round(raw))))
    }

    /// Loop 2: MacroFactor-style Dynamic TDEE & Adaptive BMR Calibration
    public static func computeDynamicTDEE(
        records: [DailyJoinedPhysiologyRecord],
        priorBmrKcal: Double = 1750.0,
        priorTargetKcal: Double = 2150.0,
        todayNeatKcal: Double = 450.0,
        todayWorkoutKcal: Double = 200.0
    ) -> DynamicTDEEResult {
        let sorted = records.sorted { $0.date < $1.date }
        let recent = Array(sorted.suffix(14))

        let validWeightDays = recent.compactMap { $0.rollingWeight7dKg ?? $0.weightKg }
        guard recent.count >= 4 && validWeightDays.count >= 2 else {
            let fallbackTdee = priorBmrKcal + todayNeatKcal + todayWorkoutKcal
            return DynamicTDEEResult(
                learnedBmrKcal: round(priorBmrKcal),
                learnedDailyTdeeKcal: round(fallbackTdee),
                metabolicAdaptationKcal: 0.0,
                adaptiveTargetIntakeKcal: round(priorTargetKcal),
                trendWeightDelta14dKg: 0.0,
                validDaysCount: recent.count
            )
        }

        let firstW = validWeightDays.first!
        let lastW = validWeightDays.last!
        let spanDays = Double(max(1, recent.count - 1))
        let deltaWeight14d = (lastW - firstW) * (14.0 / spanDays)

        // Average daily kcal intake from macros (with +12.5% buffer alignment)
        let dailyIntakes: [Double] = recent.map { rec in
            let rawKcal = (rec.proteinG * 4.0) + (rec.carbsG * 4.0) + (rec.fatG * 9.0)
            return rawKcal > 400.0 ? (rawKcal * 1.125) : priorTargetKcal
        }
        let avgIntake = dailyIntakes.reduce(0.0, +) / Double(dailyIntakes.count)

        // Tissue energy equivalent: 7700 kcal per 1 kg of trend mass change
        let dailyEnergyImbalance = (7700.0 * (lastW - firstW)) / spanDays
        let empiricalTdee = avgIntake - dailyEnergyImbalance

        // Estimate average active burn over the window (TRIMP proxy + baseline NEAT)
        let avgActiveBurn = recent.map { 420.0 + ($0.workoutTrimp * 3.2) }.reduce(0.0, +) / Double(recent.count)
        let empiricalBmr = empiricalTdee - avgActiveBurn

        let w = bayesianShrinkageWeight(sampleCount: recent.count, kappa: 14.0)
        let blendedBmr = ((1.0 - w) * priorBmrKcal) + (w * empiricalBmr)
        let clampedBmr = min(2450.0, max(1350.0, round(blendedBmr)))
        let adaptationDelta = round(clampedBmr - priorBmrKcal)

        let learnedTodayTdee = round(clampedBmr + todayNeatKcal + todayWorkoutKcal)
        let targetDeficit = max(250.0, (priorBmrKcal + 650.0) - priorTargetKcal)
        let adaptiveTarget = max(1550.0, min(3400.0, round(learnedTodayTdee - targetDeficit)))

        return DynamicTDEEResult(
            learnedBmrKcal: clampedBmr,
            learnedDailyTdeeKcal: learnedTodayTdee,
            metabolicAdaptationKcal: adaptationDelta,
            adaptiveTargetIntakeKcal: adaptiveTarget,
            trendWeightDelta14dKg: round(deltaWeight14d * 100.0) / 100.0,
            validDaysCount: recent.count
        )
    }

    /// Loop 3: Ridge OLS Regression for Individual Physiological Sensitivities (Beta Slopes)
    public static func computeLearnedSensitivities(
        records: [DailyJoinedPhysiologyRecord]
    ) -> LearnedSensitivities {
        let sorted = records.sorted { $0.date < $1.date }
        guard sorted.count >= 5 else { return LearnedSensitivities() }

        let w = bayesianShrinkageWeight(sampleCount: sorted.count, kappa: 14.0)

        // 1. Beta_Na -> H2O (kg water spike per +1000mg sodium above 2000mg)
        var naGrams: [Double] = []
        var waterSpikesKg: [Double] = []
        for i in 0..<(sorted.count - 1) {
            if let nextW = sorted[i + 1].weightKg, let next7d = sorted[i + 1].rollingWeight7dKg {
                naGrams.append((sorted[i].sodiumMg - 2000.0) / 1000.0)
                waterSpikesKg.append(nextW - next7d)
            }
        }
        let rawBetaNa = ridgeSlope(x: naGrams, y: waterSpikesKg, ridgeLambda: 1.5) ?? 0.32
        let learnedBetaNa = min(0.75, max(0.10, ((1.0 - w) * 0.32) + (w * abs(rawBetaNa))))

        // 2. Beta_TRIMP -> Battery Drain Factor (calibrated by next-morning HRV drop)
        var trimpValues: [Double] = []
        var hrvDropsPct: [Double] = []
        for i in 0..<(sorted.count - 1) {
            if sorted[i].workoutTrimp > 20.0,
               let hrvT = sorted[i].overnightHrvMs,
               let hrvT1 = sorted[i + 1].overnightHrvMs, hrvT > 0 {
                trimpValues.append(sorted[i].workoutTrimp)
                hrvDropsPct.append(max(5.0, ((hrvT - hrvT1) / hrvT) * 100.0 + 25.0))
            }
        }
        let rawBetaTrimp = ridgeSlope(x: trimpValues, y: hrvDropsPct, ridgeLambda: 2.0) ?? 0.32
        let learnedBetaTrimp = min(0.52, max(0.18, ((1.0 - w) * 0.32) + (w * max(0.20, rawBetaTrimp))))

        // 3. Beta_LateMeal -> Overnight RHR Penalty (bpm)
        var lateMealRhrDiffs: [Double] = []
        var cleanRhrValues: [Double] = []
        for i in 0..<(sorted.count - 1) {
            guard sorted[i].workoutTrimp <= 130.0, let nextRhr = sorted[i + 1].overnightRhrBpm else { continue }
            if sorted[i].hasLateMealAfter2130 {
                lateMealRhrDiffs.append(nextRhr)
            } else {
                cleanRhrValues.append(nextRhr)
            }
        }
        let empiricalLatePenalty: Double
        if !lateMealRhrDiffs.isEmpty && !cleanRhrValues.isEmpty {
            let meanLate = lateMealRhrDiffs.reduce(0.0, +) / Double(lateMealRhrDiffs.count)
            let meanClean = cleanRhrValues.reduce(0.0, +) / Double(cleanRhrValues.count)
            empiricalLatePenalty = max(1.0, meanLate - meanClean)
        } else {
            empiricalLatePenalty = 3.1
        }
        let learnedLatePenalty = min(6.5, max(1.2, ((1.0 - w) * 3.1) + (w * empiricalLatePenalty)))

        // 4. Beta_Carbs -> Cardiac Drift (% per +100g carbs)
        var carbsHundreds: [Double] = []
        var drifts: [Double] = []
        for i in 1..<sorted.count {
            if let drift = sorted[i].runningCardiacDriftPct {
                carbsHundreds.append(sorted[i - 1].carbsG / 100.0)
                drifts.append(drift)
            }
        }
        let rawBetaCarbs = ridgeSlope(x: carbsHundreds, y: drifts, ridgeLambda: 1.5) ?? -1.8
        let learnedBetaCarbs = max(-4.2, min(-0.5, ((1.0 - w) * -1.8) + (w * min(-0.5, rawBetaCarbs))))

        return LearnedSensitivities(
            sodiumWaterKgPerGram: round(learnedBetaNa * 100.0) / 100.0,
            trimpBatteryDrainFactor: round(learnedBetaTrimp * 100.0) / 100.0,
            lateMealRhrPenaltyBpm: round(learnedLatePenalty * 10.0) / 10.0,
            carbCardiacDriftSlopePctPer100g: round(learnedBetaCarbs * 10.0) / 10.0
        )
    }

    /// Loop 4A: 60-Day EWMA Dynamic Vitals Baseline Corridor
    public static func computeDynamicVitalsBaseline(
        records: [DailyJoinedPhysiologyRecord],
        priorBaseline: NocturnalVitalsBaseline
    ) -> NocturnalVitalsBaseline {
        let sorted = records.sorted { $0.date < $1.date }
        let hrvSeries = sorted.compactMap { $0.overnightHrvMs }.filter { $0 > 15.0 }
        let rhrSeries = sorted.compactMap { $0.overnightRhrBpm }.filter { $0 > 32.0 }

        guard hrvSeries.count >= 5 && rhrSeries.count >= 5 else {
            return priorBaseline
        }

        let lambda60 = 2.0 / 61.0
        var ewmaHrv = hrvSeries.first!
        for v in hrvSeries.dropFirst() {
            ewmaHrv = (v * lambda60) + (ewmaHrv * (1.0 - lambda60))
        }

        var ewmaRhr = rhrSeries.first!
        for v in rhrSeries.dropFirst() {
            ewmaRhr = (v * lambda60) + (ewmaRhr * (1.0 - lambda60))
        }

        let w = bayesianShrinkageWeight(sampleCount: hrvSeries.count, kappa: 14.0)
        let learnedHrvMean = round((((1.0 - w) * priorBaseline.hrvMeanMs) + (w * ewmaHrv)) * 10.0) / 10.0
        let learnedRhrMean = round((((1.0 - w) * priorBaseline.rhrMeanBpm) + (w * ewmaRhr)) * 10.0) / 10.0

        let hrvVariance = hrvSeries.reduce(0.0) { $0 + pow($1 - ewmaHrv, 2) } / Double(hrvSeries.count)
        let rhrVariance = rhrSeries.reduce(0.0) { $0 + pow($1 - ewmaRhr, 2) } / Double(rhrSeries.count)

        let learnedHrvStd = max(8.0, min(28.0, round(sqrt(hrvVariance) * 10.0) / 10.0))
        let learnedRhrStd = max(1.5, min(4.5, round(sqrt(rhrVariance) * 10.0) / 10.0))

        return NocturnalVitalsBaseline(
            hrvMeanMs: learnedHrvMean,
            hrvStdDevMs: learnedHrvStd,
            rhrMeanBpm: learnedRhrMean,
            rhrStdDevBpm: learnedRhrStd,
            wristTempMeanCelsius: priorBaseline.wristTempMeanCelsius,
            respiratoryRateMeanBpm: priorBaseline.respiratoryRateMeanBpm,
            spo2MeanPct: priorBaseline.spo2MeanPct
        )
    }

    /// Loop 4B: 1-Tap RPE Calibration Step (updates Readiness component weights)
    /// rpeFeedback: -1 (felt worse than predicted), 0 (accurate), +1 (felt better than predicted)
    public static func calibrateReadinessWeights(
        currentWeights: ReadinessWeightVector,
        rpeFeedback: Int,
        hrvWasLow: Bool,
        sleepWasLow: Bool
    ) -> ReadinessWeightVector {
        guard rpeFeedback != 0 else { return currentWeights }
        var updated = currentWeights
        let step = 0.015 * Double(rpeFeedback)

        // If athlete felt worse (-1) when sleep was low, increase sleep weight
        if rpeFeedback < 0 {
            if sleepWasLow {
                updated.sleepDurationWeight += abs(step)
                updated.sleepArchitectureWeight += abs(step) * 0.5
            } else if hrvWasLow {
                updated.hrvWeight += abs(step)
            }
        } else if rpeFeedback > 0 {
            // Athlete felt resilient despite autonomic dip -> slightly shift toward HRV/Sleep balance
            updated.hrvWeight += step * 0.5
        }

        updated.normalize()
        return updated
    }

    /// Master Snapshot Builder
    public static func evaluateAdaptiveSnapshot(
        records: [DailyJoinedPhysiologyRecord],
        priorBmrKcal: Double = 1750.0,
        priorTargetKcal: Double = 2150.0,
        priorBaseline: NocturnalVitalsBaseline = NocturnalVitalsBaseline(),
        currentWeights: ReadinessWeightVector = ReadinessWeightVector(),
        rpeCheckinsCount: Int = 0,
        todayNeatKcal: Double = 450.0,
        todayWorkoutKcal: Double = 200.0
    ) -> AdaptivePhysiologySnapshot {
        let confidence = computeConfidencePct(sampleCount: records.count, rpeCheckinsCount: rpeCheckinsCount)
        let tdee = computeDynamicTDEE(
            records: records,
            priorBmrKcal: priorBmrKcal,
            priorTargetKcal: priorTargetKcal,
            todayNeatKcal: todayNeatKcal,
            todayWorkoutKcal: todayWorkoutKcal
        )
        let sensitivities = computeLearnedSensitivities(records: records)
        let dynamicBaseline = computeDynamicVitalsBaseline(records: records, priorBaseline: priorBaseline)

        let titleUk: String
        if confidence >= 75 {
            titleUk = "Висока персональна калібрування (\(confidence)%)"
        } else if confidence >= 45 {
            titleUk = "Активне самонавчання ядра (\(confidence)%)"
        } else {
            titleUk = "Первинне калібрування бази (\(confidence)%)"
        }

        let summaryUk = String(
            format: "Адаптивний BMR: %.0f ккал (%+.0f) • Відгук води на 1г Na: +%.2f кг • Коридор HRV: %.0f±%.0f мс",
            tdee.learnedBmrKcal,
            tdee.metabolicAdaptationKcal,
            sensitivities.sodiumWaterKgPerGram,
            dynamicBaseline.hrvMeanMs,
            dynamicBaseline.hrvStdDevMs
        )

        return AdaptivePhysiologySnapshot(
            confidencePct: confidence,
            sampleDaysCount: records.count,
            dynamicTDEE: tdee,
            sensitivities: sensitivities,
            dynamicVitalsBaseline: dynamicBaseline,
            readinessWeights: currentWeights,
            statusTitleUk: titleUk,
            statusSummaryUk: summaryUk
        )
    }

    // MARK: - Internal Math Helper

    private static func ridgeSlope(x: [Double], y: [Double], ridgeLambda: Double) -> Double? {
        guard x.count == y.count && x.count >= 4 else { return nil }
        let n = Double(x.count)
        let meanX = x.reduce(0.0, +) / n
        let meanY = y.reduce(0.0, +) / n

        var num = 0.0
        var den = ridgeLambda
        for i in 0..<x.count {
            let dx = x[i] - meanX
            let dy = y[i] - meanY
            num += dx * dy
            den += dx * dx
        }
        guard den > 0.0001 else { return nil }
        return num / den
    }
}
```

- [ ] **Step 2: Update `AthleteProfileStore.swift` to persist learned Readiness weights and RPE check-in count**
In `ios/Lifecore/Lifecore/Lifecore/Core/Storage/AthleteProfileStore.swift`:
1. Add two properties to `AthleteProfile` (with default values in `init` and `sashaDefault` so backward decoding never breaks):
   - `public var readinessWeights: ReadinessWeightVector = ReadinessWeightVector()`
   - `public var rpeCalibrationCount: Int = 0`
   - `public var lastRpeCalibrationDate: String? = nil`
2. Add method `public func recordRPEFeedback(_ feedback: Int, hrvWasLow: Bool, sleepWasLow: Bool, dietaryDate: String)` on `AthleteProfileStore` that calls `AdaptivePhysiologyEngine.calibrateReadinessWeights`, increments `profile.rpeCalibrationCount`, sets `profile.lastRpeCalibrationDate = dietaryDate`, and saves.

- [ ] **Step 3: Wire `trimpDrainFactor` into `TrainingLoadAndBatteryEngine.swift` and `ReadinessWeightVector` into `ReadinessCalculator.swift`**
1. In `TrainingLoadAndBatteryEngine.computeEnergyBankTimeline`, add default parameter `trimpDrainFactor: Double = 0.32` and replace `w.trimp * 0.32` on line 262 with `w.trimp * trimpDrainFactor`.
2. In `ReadinessCalculator.evaluateRecovery` (in `ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/ReadinessCalculator.swift`), add optional parameter `weights: ReadinessWeightVector = ReadinessWeightVector()` and use `weights.hrvWeight`, `weights.rhrWeight`, `weights.sleepDurationWeight`, `weights.sleepArchitectureWeight` when computing the weighted recovery score.

---

### Task 2: Add Self-Learning Verification Tests & Update `CoachPrompt.swift`

**Files:**
- Modify: `ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/MathEngineVerification.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/Core/AI/CoachPrompt.swift`

- [ ] **Step 1: Extend `MathEngineVerification.swift` with Phase 3.1 Adaptive Engine assertions**
Add `verifyAdaptivePhysiologyEngine()` inside `MathEngineVerification.swift` and call it from `runAllAssertions()`:
- Verify `bayesianShrinkageWeight(sampleCount: 14, kappa: 14.0) == 0.5`.
- Verify `computeDynamicTDEE` shifts `learnedBmrKcal` upward when weight decreases faster than expected for a given caloric intake.
- Verify `calibrateReadinessWeights` keeps `hrvWeight + rhrWeight + sleepDurationWeight + sleepArchitectureWeight == 1.0`.

- [ ] **Step 2: Inject Learned Adaptive Metrics into `CoachPrompt.swift`**
In `ios/Lifecore/Lifecore/Lifecore/Core/AI/CoachPrompt.swift`, add optional `adaptiveSummaryUk: String? = nil` to the prompt builder and include it under `[SELF-LEARNING PHYSIOLOGY CALIBRATION]` so Gemini AI Coach references the athlete's learned TDEE and $\beta$-sensitivities.

- [ ] **Step 3: Verify Compilation of Math Engine**
Run: `xcodebuild -project ios/Lifecore/Lifecore/Lifecore.xcodeproj -scheme Lifecore -destination 'generic/platform=iOS Simulator' build`

---

### Task 3: Expand `LifecoreDesignSystem.swift` & Localize `MainTabView.swift`

**Files:**
- Modify: `ios/Lifecore/Lifecore/Lifecore/Core/UI/LifecoreDesignSystem.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/App/MainTabView.swift`

- [ ] **Step 1: Add Reusable v3.1 Bento & Adaptive UI Components to `LifecoreDesignSystem.swift`**
Append the following reusable Liquid Glass components to `LifecoreDesignSystem.swift`:
1. **`AdaptiveEngineBadgeBar`:** Sleek pill showing `sparkles` icon, `"Адаптивне ядро • \(snapshot.confidencePct)% точності"`, `"BMR \(Int(snapshot.dynamicTDEE.learnedBmrKcal)) ккал (\(String(format: "%+.0f", snapshot.dynamicTDEE.metabolicAdaptationKcal)))"`, and `"Na→H₂O +\(String(format: "%.2f", snapshot.sensitivities.sodiumWaterKgPerGram)) кг"`.
2. **`RPEQuickCalibrationRow`:** 1-Tap subjective check-in row (`"Як ти реально почуваєшся сьогодні?"` with 3 capsule buttons: `"Нижче прогнозу"`, `"Точно"`, `"Краще прогнозу"`) that triggers `onSelect(Int)` and shows `"Враховано у вагах ядра ✓"` when already calibrated today.
3. **`AdaptiveEngineStatusCard`:** Detailed card for `TrendsView` displaying the 4 self-learning loops:
   - Loop 1: Model Confidence progress bar (`confidencePct%`) + sample days $N$.
   - Loop 2: MacroFactor Adaptive TDEE (`learnedDailyTdeeKcal` kcal, `learnedBmrKcal` kcal, adaptation delta).
   - Loop 3: Personal $\beta$-Sensitivities grid (`sodiumWaterKgPerGram`, `trimpBatteryDrainFactor`, `lateMealRhrPenaltyBpm`, `carbCardiacDriftSlopePctPer100g`).
   - Loop 4: Personalized Readiness Weight percentages (`HRV \(Int(w.hrvWeight*100))% • RHR \(Int(w.rhrWeight*100))% • Сон \(Int((w.sleepDurationWeight+w.sleepArchitectureWeight)*100))%`).

- [ ] **Step 2: Localize `MainTabView.swift` to Ukrainian**
In `ios/Lifecore/Lifecore/Lifecore/App/MainTabView.swift`, update the 4 tab labels:
- `"Today"` → `"Сьогодні"`
- `"Workouts"` → `"Тренування"`
- `"Nutrition"` → `"Харчування"`
- `"Trends"` → `"Тренди"`

---

### Task 4: Complete Overhaul of `TodayView.swift` (Bento Cockpit, Zero Duplication, Adaptive TDEE)

**Files:**
- Modify: `ios/Lifecore/Lifecore/Lifecore/Features/Today/TodayView.swift`

- [ ] **Step 1: Add `@State private var adaptiveSnapshot: AdaptivePhysiologySnapshot?` to `TodayView`**
In `refreshAllMetrics()` inside `TodayView.swift`:
1. Build `[DailyJoinedPhysiologyRecord]` for the last 28 days (or use available HealthKit weight/HRV/RHR + `MealStorageService.shared` daily totals) and compute `let snapshot = AdaptivePhysiologyEngine.evaluateAdaptiveSnapshot(...)`.
2. Replace hardcoded `let bmr = 1750.0` with `let bmr = snapshot.dynamicTDEE.learnedBmrKcal`.
3. Pass `weights: athleteStore.profile.readinessWeights` into `ReadinessCalculator.evaluateRecovery(...)`.
4. Pass `baseline: snapshot.dynamicVitalsBaseline` into `VitalsAndIllnessEngine.evaluateOvernightVitals(...)`.
5. Pass `trimpDrainFactor: snapshot.sensitivities.trimpBatteryDrainFactor` into `TrainingLoadAndBatteryEngine.computeEnergyBankTimeline(...)`.

- [ ] **Step 2: Restructure `TodayView` Body into the 5-Block Liquid Glass Bento Cockpit**
1. **Remove** `autonomicCard(recovery)` completely from `TodayView` (eliminating HRV/RHR duplication with `OvernightVitalsCard`).
2. **Hero Cockpit (`ringsHeaderView`):**
   - Translate ring titles to Ukrainian: `"Відновлення"`, `"Навантаження"`, `"Калорії"`.
   - Embed `AdaptiveEngineBadgeBar(snapshot: snapshot)` and `RPEQuickCalibrationRow(...)` directly inside the bottom of the Hero Cockpit card, and style the entire container with `.lifecoreGlassCard(cornerRadius: 24, borderColor: LifecoreTheme.recoveryGreen.opacity(0.25))`.
3. **2-Column Bento Grid (`sleepAndMetabolismBentoSection`):**
   - Replace the old wide flat `sleepArchitectureCard` and `activityAndNeatCard` with a sleek Ukrainian Liquid Glass Bento layout:
     - **Card A (`sleepArchitectureCard`):** Title `"Архітектура сну"`, Ukrainian labels (`"Тривалість"`, `"Глибокий"`, `"REM"`, `"Борг сну"`), styled with `.lifecoreGlassCard()`.
     - **Card B (`activityAndNeatCard`):** Title `"Чистий NEAT та Адаптивний TDEE"`, Ukrainian labels (`"Чистий NEAT"`, `"Тренування"`, `"Адаптивний BMR"`, `"Реальний TDEE"`, `"Баланс калорій"`), styled with `.lifecoreGlassCard()`.
4. **Sessions Card (`todayWorkoutsCard`) & Navigation Title:**
   - Change `.navigationTitle("Lifecore")` subtitle/labels to Ukrainian (`"Сьогоднішні сесії"`, `"Синхронізація..."`) and apply `.lifecoreGlassCard()` to `todayWorkoutsCard` and `coachErrorBanner`.

---

### Task 5: Complete Overhaul of `TrendsView.swift` & `TrendsComponents.swift` (Segmented Glass Hub)

**Files:**
- Modify: `ios/Lifecore/Lifecore/Lifecore/Features/Trends/TrendsView.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/Features/Trends/TrendsComponents.swift`

- [ ] **Step 1: Add Segmented Category Switcher (`TrendsCategory`) to `TrendsView.swift`**
In `ios/Lifecore/Lifecore/Lifecore/Features/Trends/TrendsView.swift`:
1. Define enum `TrendsCategory: String, CaseIterable, Identifiable`:
   - `.adaptation = "Адаптація"` (icon `"brain.head.profile"`)
   - `.workload = "Навантаження"` (icon `"flame.fill"`)
   - `.body = "Тіло & Вага"` (icon `"scalemass.fill"`)
   - `.cardio = "Кардіо & ВНС"` (icon `"waveform.path.ecg"`)
2. Add `@State private var selectedCategory: TrendsCategory = .adaptation` and `@State private var adaptiveSnapshot: AdaptivePhysiologySnapshot?`.
3. Compute `adaptiveSnapshot = AdaptivePhysiologyEngine.evaluateAdaptiveSnapshot(records: joinedRecords, ...)` inside `loadTrendsData()`.
4. Render a horizontal Liquid Glass Segmented Switcher right below `TrendsRangePickerView`:
   - When `.adaptation` is selected: show `AdaptiveEngineStatusCard(snapshot: snapshot)` + `CorrelationInsightsCard(insights: correlationInsights)`.
   - When `.workload` is selected: show `ACWRWorkloadTrendCard(evaluation: acwrEval, dailyLoads: dailyTrimpLoads)`.
   - When `.body` is selected: show `WeightTrendCard(points: weightPoints)`.
   - When `.cardio` is selected: show `AutonomicTrendCard(samples: autonomicSamples)` + `AerobicEfficiencyTrendCard(samples: efSamples)`.
5. Change `.navigationTitle("Trends")` to `.navigationTitle("Тренди та Аналітика")` and background to `LifecoreTheme.deepVoidBackground.ignoresSafeArea()`.

- [ ] **Step 2: Upgrade `TrendsComponents.swift` to Liquid Glass & 100% Ukrainian**
In `ios/Lifecore/Lifecore/Lifecore/Features/Trends/TrendsComponents.swift`:
- Replace all `Color(red: 0.09, green: 0.10, blue: 0.14)` card backgrounds on `WeightTrendCard`, `AutonomicTrendCard`, and `AerobicEfficiencyTrendCard` with `.lifecoreGlassCard()`.
- Ensure all remaining English headers/subtitles in `TrendsComponents.swift` are in Ukrainian.

---

### Task 6: Complete Overhaul of `WorkoutsView.swift`, `NutritionView.swift`, and `NutritionComponents.swift`

**Files:**
- Modify: `ios/Lifecore/Lifecore/Lifecore/Features/Workouts/WorkoutsView.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/Features/Nutrition/NutritionView.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/Features/Nutrition/NutritionComponents.swift`

- [ ] **Step 1: Upgrade `WorkoutsView.swift` to Liquid Glass + Live Banister TRIMP Badge**
In `ios/Lifecore/Lifecore/Lifecore/Features/Workouts/WorkoutsView.swift`:
1. Change `.navigationTitle("Workouts")` to `.navigationTitle("Тренування")` and background to `LifecoreTheme.deepVoidBackground.ignoresSafeArea()`.
2. In `workoutRowCard(for workout: HKWorkout)`:
   - Compute live Banister TRIMP using `TrainingLoadAndBatteryEngine.computeBanisterTRIMP(durationMin: durationMin, avgHr: avgHr ?? 130.0, restingHr: AthleteProfileStore.shared.profile.restingHeartRateBaselineBpm, maxHr: AthleteProfileStore.shared.profile.maxHeartRateBpm)` and display a glowing capsule badge `"TRIMP \(Int(trimp))"` in the card header.
   - Replace the flat `Color(red: 0.09, green: 0.10, blue: 0.14)` background with `.lifecoreGlassCard(cornerRadius: 18, borderColor: typeColor.opacity(0.25))`.

- [ ] **Step 2: Upgrade `NutritionView.swift` & `NutritionComponents.swift` to Liquid Glass + Adaptive TDEE & Sodium Water Forecast**
1. In `ios/Lifecore/Lifecore/Lifecore/Features/Nutrition/NutritionView.swift`:
   - Observe `@ObservedObject private var athleteStore = AthleteProfileStore.shared`.
   - Change `.navigationTitle("Nutrition")` to `.navigationTitle("Харчування")`, `"04:00 AM cutoff"` to `"Зміна доби о 04:00"`, and background to `LifecoreTheme.deepVoidBackground.ignoresSafeArea()`.
   - Pass `targetKcal: athleteStore.profile.targetCaloriesKcal`, `targetProteinG: athleteStore.profile.targetProteinG`, `targetFatG: athleteStore.profile.targetFatG`, `targetCarbsG: athleteStore.profile.targetCarbsG` into `MacroSummaryCard`.
   - Apply `.lifecoreGlassCard(cornerRadius: 14)` to `fastActionBar` buttons.
2. In `ios/Lifecore/Lifecore/Lifecore/Features/Nutrition/NutritionComponents.swift`:
   - In `MacroSummaryCard`: translate `"Daily Energy & Macros"` → `"Енергетичний баланс та Макроси"`, `"+12.5% Deficit Buffer"` → `"+12.5% Буфер дефіциту"`, and replace the flat card background with `.lifecoreGlassCard(cornerRadius: 20, borderColor: LifecoreTheme.strainOrange.opacity(0.25))`.
   - In `DietaryQualityCard`: translate any remaining English strings to Ukrainian, add a **Sodium Water Retention Forecast Row** (`"Прогноз затримки води на завтра: +\(String(format: "%.2f", max(0, (totalSodiumMg - 2000.0) / 1000.0 * 0.32))) кг"` when `totalSodiumMg > 2300`), and apply `.lifecoreGlassCard()`.
   - Apply `.lifecoreGlassCard(cornerRadius: 16)` to `MealRowCard`.

- [ ] **Step 3: Final Build Verification & Documentation Update**
1. Run `xcodebuild -project ios/Lifecore/Lifecore/Lifecore.xcodeproj -scheme Lifecore -destination 'generic/platform=iOS Simulator' build` and verify `BUILD SUCCEEDED`.
2. Update `CHANGELOG.md` and `docs/ROADMAP.md` marking Phase 3.1 (`[x]`) complete, then commit with `feat(v3.1): implement self-learning adaptive physiology engine and full liquid glass UI overhaul`.
