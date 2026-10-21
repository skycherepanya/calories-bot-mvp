import Foundation

// MARK: - Self-Learning Models (Lifecore v3.1)

public struct ReadinessWeightVector: Codable, Sendable, Equatable {
    public var hrvWeight: Double
    public var rhrWeight: Double
    public var sleepDurationWeight: Double
    public var sleepArchitectureWeight: Double

    public static let `default` = ReadinessWeightVector()

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

    public static func == (lhs: AdaptivePhysiologySnapshot, rhs: AdaptivePhysiologySnapshot) -> Bool {
        lhs.confidencePct == rhs.confidencePct &&
        lhs.sampleDaysCount == rhs.sampleDaysCount &&
        lhs.dynamicTDEE == rhs.dynamicTDEE &&
        lhs.sensitivities == rhs.sensitivities &&
        lhs.readinessWeights == rhs.readinessWeights &&
        lhs.statusTitleUk == rhs.statusTitleUk &&
        lhs.statusSummaryUk == rhs.statusSummaryUk &&
        lhs.dynamicVitalsBaseline.hrvMeanMs == rhs.dynamicVitalsBaseline.hrvMeanMs &&
        lhs.dynamicVitalsBaseline.rhrMeanBpm == rhs.dynamicVitalsBaseline.rhrMeanBpm
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
