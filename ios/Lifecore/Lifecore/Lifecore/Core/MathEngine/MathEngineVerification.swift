import Foundation

public struct VerificationResult: Sendable {
    public let testName: String
    public let passed: Bool
    public let details: String
}

public enum MathEngineVerification {

    public static func runAllVerifications() -> [VerificationResult] {
        var results: [VerificationResult] = []

        // Test 1: 1km Auto-Splits
        results.append(verifyKilometerSplits())

        // Test 2: Efficiency Factor (EF)
        results.append(verifyEfficiencyFactor())

        // Test 3: Aerobic Decoupling / Cardiac Drift
        results.append(verifyCardiacDrift())

        // Test 4: Pure NEAT Isolation
        results.append(verifyPureNEATIsolation())

        // Test 5: Rolling Body Weight Averages
        results.append(verifyRollingWeight())

        // Test 6: Recovery Score Calculation
        results.append(verifyRecoveryScore())

        // Test 7: SwiftData Models & Serialization
        results.append(verifySwiftDataModels())

        // Test 8: Overnight Vitals & Illness Prodrome
        results.append(verifyVitalsAndIllnessEngine())

        // Test 9: Garmin Firstbeat Workload (TRIMP, EWMA ACWR) & Body Battery
        results.append(verifyTrainingLoadAndBatteryEngine())

        // Test 10: Confounder-Controlled Time-Lagged Correlations
        results.append(verifyCorrelationEngine())

        // Test 11: Self-Learning Adaptive Physiology Engine (Phase 3.1)
        results.append(verifyAdaptivePhysiologyEngine())

        return results
    }

    // MARK: - Individual Test Cases

    private static func verifyKilometerSplits() -> VerificationResult {
        let baseDate = Date(timeIntervalSince1970: 1729300000)
        var samples: [RawTelemetryPoint] = [
            RawTelemetryPoint(timestamp: baseDate, distanceMeters: 0.0, heartRateBpm: 140.0, altitudeMeters: 50.0)
        ]

        // Generate 3000m running data (3 kilometers)
        // km 1: 360 seconds (pace 6:00/km)
        // km 2: 345 seconds (pace 5:45/km)
        // km 3: 330 seconds (pace 5:30/km)
        var currentTime = baseDate
        var currentDist = 0.0

        for m in stride(from: 100.0, through: 1000.0, by: 100.0) {
            currentTime = currentTime.addingTimeInterval(36.0)
            currentDist = m
            samples.append(RawTelemetryPoint(timestamp: currentTime, distanceMeters: currentDist, heartRateBpm: 142.0, altitudeMeters: 50.0))
        }

        for m in stride(from: 1100.0, through: 2000.0, by: 100.0) {
            currentTime = currentTime.addingTimeInterval(34.5)
            currentDist = m
            samples.append(RawTelemetryPoint(timestamp: currentTime, distanceMeters: currentDist, heartRateBpm: 148.0, altitudeMeters: 54.0))
        }

        for m in stride(from: 2100.0, through: 3000.0, by: 100.0) {
            currentTime = currentTime.addingTimeInterval(33.0)
            currentDist = m
            samples.append(RawTelemetryPoint(timestamp: currentTime, distanceMeters: currentDist, heartRateBpm: 155.0, altitudeMeters: 52.0))
        }

        let splits = WorkoutMathEngine.computeKilometerSplits(from: samples)

        guard splits.count == 3 else {
            return VerificationResult(testName: "1km Auto-Splits", passed: false, details: "Expected 3 splits, got \(splits.count)")
        }

        let km1 = splits[0]
        let km2 = splits[1]
        let km3 = splits[2]

        let paceMatches = abs(km1.paceMinPerKm - 6.00) < 0.1 &&
                           abs(km2.paceMinPerKm - 5.75) < 0.1 &&
                           abs(km3.paceMinPerKm - 5.50) < 0.1

        return VerificationResult(
            testName: "1km Auto-Splits",
            passed: paceMatches,
            details: "Splits paces: km1=\(km1.formattedPace), km2=\(km2.formattedPace), km3=\(km3.formattedPace)"
        )
    }

    private static func verifyEfficiencyFactor() -> VerificationResult {
        // Distance = 10,000m, Duration = 3600s (60 min), Avg HR = 145 bpm
        // Speed = 10,000 / 60 = 166.667 m/min
        // EF = 166.667 / 145 = 1.149 m/min/bpm
        guard let ef = WorkoutMathEngine.computeEfficiencyFactor(distanceMeters: 10000.0, durationSeconds: 3600.0, avgHeartRate: 145.0) else {
            return VerificationResult(testName: "Efficiency Factor", passed: false, details: "Returned nil")
        }

        let passed = abs(ef - 1.149) < 0.005
        return VerificationResult(
            testName: "Efficiency Factor",
            passed: passed,
            details: "Computed EF = \(ef), expected ~1.149"
        )
    }

    private static func verifyCardiacDrift() -> VerificationResult {
        // First half: 2km at 140 bpm, 5:30/km -> EF = (1000 / 5.5) / 140 = 1.298
        // Second half: 2km at 155 bpm, 5:30/km -> EF = (1000 / 5.5) / 155 = 1.173
        // Drift = ((1.298 - 1.173) / 1.298) * 100 = ~9.63%
        let split1 = SplitMetric(km: 1, durationSeconds: 330.0, paceMinPerKm: 5.50, avgHeartRate: 139.0)
        let split2 = SplitMetric(km: 2, durationSeconds: 330.0, paceMinPerKm: 5.50, avgHeartRate: 141.0)
        let split3 = SplitMetric(km: 3, durationSeconds: 330.0, paceMinPerKm: 5.50, avgHeartRate: 154.0)
        let split4 = SplitMetric(km: 4, durationSeconds: 330.0, paceMinPerKm: 5.50, avgHeartRate: 156.0)

        guard let drift = WorkoutMathEngine.computeCardiacDrift(splits: [split1, split2, split3, split4]) else {
            return VerificationResult(testName: "Cardiac Drift %", passed: false, details: "Returned nil")
        }

        let passed = drift > 8.0 && drift < 12.0
        return VerificationResult(
            testName: "Cardiac Drift %",
            passed: passed,
            details: "Computed Cardiac Drift = \(drift)%, expected ~9.6%"
        )
    }

    private static func verifyPureNEATIsolation() -> VerificationResult {
        // Daily active = 1150 kcal, Workout = 695 kcal
        // Pure NEAT = max(0, 1150 - 695) = 455 kcal
        let neat1 = ReadinessCalculator.isolatePureNEAT(dailyActiveKcal: 1150.0, workoutActiveKcals: [695.0])
        let neat2 = ReadinessCalculator.isolatePureNEAT(dailyActiveKcal: 400.0, workoutActiveKcals: [600.0])

        let passed = (neat1 == 455.0) && (neat2 == 0.0)
        return VerificationResult(
            testName: "Pure NEAT Isolation",
            passed: passed,
            details: "neat1 = \(neat1) (expected 455.0), neat2 = \(neat2) (expected 0.0)"
        )
    }

    private static func verifyRollingWeight() -> VerificationResult {
        let weights = [76.5, 76.4, 76.3, 76.2, 76.1, 76.0, 75.9, 75.8, 75.7, 75.6, 75.5, 75.4, 75.3, 75.2]
        guard let trend = ReadinessCalculator.computeRollingWeight(weights: weights) else {
            return VerificationResult(testName: "Rolling Weight", passed: false, details: "Returned nil")
        }

        let passed7d = trend.rollingAvg7d != nil && abs(trend.rollingAvg7d! - 75.5) < 0.1
        let passed14d = trend.rollingAvg14d != nil && abs(trend.rollingAvg14d! - 75.85) < 0.1

        return VerificationResult(
            testName: "Rolling Weight",
            passed: passed7d && passed14d,
            details: "7d avg: \(trend.rollingAvg7d ?? 0.0), 14d avg: \(trend.rollingAvg14d ?? 0.0)"
        )
    }

    private static func verifyRecoveryScore() -> VerificationResult {
        // Sasha baseline: HRV 102ms, RHR 49bpm
        // High recovery day: HRV 106ms, RHR 48bpm, sleep 7.8h, deep 1.4h, rem 1.6h
        let primeEval = ReadinessCalculator.computeRecovery(
            morningHrv: 106.0,
            morningRhr: 48.0,
            totalSleepHours: 7.8,
            deepSleepHours: 1.4,
            remSleepHours: 1.6
        )

        // Strained day: HRV 65ms, RHR 56bpm, sleep 5.2h, deep 0.5h, rem 0.8h
        let strainedEval = ReadinessCalculator.computeRecovery(
            morningHrv: 65.0,
            morningRhr: 56.0,
            totalSleepHours: 5.2,
            deepSleepHours: 0.5,
            remSleepHours: 0.8
        )

        let passed = primeEval.score >= 80 &&
                     primeEval.state == .prime &&
                     strainedEval.score < 65 &&
                     strainedEval.state != .prime

        return VerificationResult(
            testName: "Recovery Score Calculation",
            passed: passed,
            details: "Prime score: \(primeEval.score) (\(primeEval.state.rawValue)), Strained score: \(strainedEval.score) (\(strainedEval.state.rawValue))"
        )
    }

    private static func verifySwiftDataModels() -> VerificationResult {
        // 1. Verify MealEntity field roundtrip and +12.5% buffer preservation
        let meal = MealRecord(
            name: "Гречка з яловичиною",
            kcal: round(450 * 1.125),
            proteinG: 42,
            fatG: 12,
            carbsG: 50,
            weightG: 350,
            tags: ["whole_food", "solid"],
            micronutrients: .init(fiberG: 4.0, sodiumMg: 320, potassiumMg: 500, vitaminCMg: 0, ironMg: 3.0, calciumMg: 20),
            aminoAcids: .init(bcaaG: 8.0, leucineG: 3.5),
            dietaryDate: "2026-10-21",
            createdAt: Date(),
            isOptimisticPending: false
        )
        let entity = MealEntity(record: meal, syncedToCloud: false)
        let roundtrip = entity.toRecord()

        guard roundtrip.name == meal.name,
              roundtrip.kcal == meal.kcal,
              roundtrip.proteinG == 42.0,
              roundtrip.micronutrients?.sodiumMg == 320.0,
              roundtrip.aminoAcids?.leucineG == 3.5 else {
            return VerificationResult(testName: "SwiftData Models & Serialization", passed: false, details: "MealEntity field roundtrip failed")
        }

        // 2. Verify WorkoutAnalysisEntity serialization
        let splits: [SplitMetric] = [
            SplitMetric(km: 1, durationSeconds: 300, paceMinPerKm: 5.0, avgHeartRate: 145),
            SplitMetric(km: 2, durationSeconds: 290, paceMinPerKm: 4.83, avgHeartRate: 150)
        ]
        let laps: [LapIntervalMetric] = [
            LapIntervalMetric(lapIndex: 1, lapType: "work", durationSeconds: 120, avgHeartRate: 165)
        ]

        let splitsJson = WorkoutAnalysisEntity.serializeSplits(splits)
        let lapsJson = WorkoutAnalysisEntity.serializeLaps(laps)

        let workoutEntity = WorkoutAnalysisEntity(
            workoutUUID: UUID(),
            workoutType: "Running",
            startedAt: Date(),
            distanceMeters: 2000,
            durationSeconds: 590,
            splitsJson: splitsJson,
            lapsJson: lapsJson,
            aiCoachReport: "Чудова пробіжка!"
        )

        guard workoutEntity.splits.count == 2,
              workoutEntity.splits.first?.km == 1,
              workoutEntity.laps.count == 1,
              workoutEntity.aiCoachReport == "Чудова пробіжка!" else {
            return VerificationResult(testName: "SwiftData Models & Serialization", passed: false, details: "WorkoutAnalysisEntity serialization failed")
        }

        return VerificationResult(testName: "SwiftData Models & Serialization", passed: true, details: "MealEntity & WorkoutAnalysisEntity 100% verified")
    }

    private static func verifyVitalsAndIllnessEngine() -> VerificationResult {
        // 1. Beat-to-beat RMSSD with 20% filter
        // Realistic normal intervals ~800ms with ~30-50ms physiological variations + 1 ectopic spike (+450ms)
        let intervals = [0.80, 0.84, 0.79, 0.83, 0.78, 0.82, 0.81, 0.85, 0.80, 0.79, 1.35, 0.80, 0.83, 0.78, 0.82, 0.80, 0.84, 0.81, 0.79, 0.83]
        var beatTimestamps: [(timeSinceStart: TimeInterval, precededByGap: Bool)] = []
        var t = 0.0
        for interval in intervals {
            t += interval
            beatTimestamps.append((timeSinceStart: t, precededByGap: false))
        }
        guard let cleanRmssd = VitalsAndIllnessEngine.computeCleanRMSSD(beats: beatTimestamps) else {
            return VerificationResult(testName: "Overnight Vitals & Illness Prodrome", passed: false, details: "computeCleanRMSSD returned nil")
        }
        guard cleanRmssd > 20.0 && cleanRmssd < 60.0 else {
            return VerificationResult(testName: "Overnight Vitals & Illness Prodrome", passed: false, details: "computeCleanRMSSD value out of expected range: \(cleanRmssd)")
        }

        // 2. Log-HRV Z-score test
        let zZero = VitalsAndIllnessEngine.computeLogHRVZScore(currentHrvMs: 102.0, fallbackMeanMs: 102.0)
        let zDepressed = VitalsAndIllnessEngine.computeLogHRVZScore(currentHrvMs: 60.0, fallbackMeanMs: 102.0)
        guard abs(zZero) < 0.01 && zDepressed < -1.5 else {
            return VerificationResult(testName: "Overnight Vitals & Illness Prodrome", passed: false, details: "computeLogHRVZScore failed: zZero=\(zZero), zDepressed=\(zDepressed)")
        }

        // 3. Confluence state machine: Optimal vs Training Fatigue vs Illness Prodrome
        let baseline = NocturnalVitalsBaseline(hrvMeanMs: 102.0, rhrMeanBpm: 49.0, wristTempMeanCelsius: 36.40, respiratoryRateMeanBpm: 14.2, spo2MeanPct: 97.8)

        // Optimal: all normal
        let optimalInput = NocturnalVitalsInput(hrvMs: 104.0, rhrBpm: 48.5, wristTempCelsius: 36.45, wristTempDeltaCelsius: 0.05, respiratoryRateBpm: 14.1, spo2Pct: 98.0)
        let evalOptimal = VitalsAndIllnessEngine.evaluateOvernightVitals(input: optimalInput, baseline: baseline)

        // Fatigue: 1 outlier (low HRV), temp normal -> trainingFatigue, NOT illness
        let fatigueInput = NocturnalVitalsInput(hrvMs: 70.0, rhrBpm: 49.5, wristTempCelsius: 36.48, wristTempDeltaCelsius: 0.08, respiratoryRateBpm: 14.3, spo2Pct: 97.6)
        let evalFatigue = VitalsAndIllnessEngine.evaluateOvernightVitals(input: fatigueInput, baseline: baseline)

        // Illness: elevated temp (+0.46) + elevated RHR (56) + depressed HRV (58) -> illnessProdrome
        let illnessInput = NocturnalVitalsInput(hrvMs: 58.0, rhrBpm: 56.0, wristTempCelsius: 36.86, wristTempDeltaCelsius: 0.46, respiratoryRateBpm: 16.5, spo2Pct: 95.0)
        let evalIllness = VitalsAndIllnessEngine.evaluateOvernightVitals(input: illnessInput, baseline: baseline)

        let passed = (evalOptimal.state == .optimal) &&
                     (evalFatigue.state == .trainingFatigue) &&
                     (evalIllness.state == .illnessProdrome)

        return VerificationResult(
            testName: "Overnight Vitals & Illness Prodrome",
            passed: passed,
            details: "Optimal=\(evalOptimal.state.rawValue), Fatigue=\(evalFatigue.state.rawValue), Illness=\(evalIllness.state.rawValue), RMSSD=\(String(format: "%.1f", cleanRmssd))ms"
        )
    }

    private static func verifyTrainingLoadAndBatteryEngine() -> VerificationResult {
        // 1. Banister TRIMP test: 60 min, avg HR 150, rest 49, max 192 -> expected ~105 TRIMP
        let trimp = TrainingLoadAndBatteryEngine.computeBanisterTRIMP(
            durationMin: 60.0,
            avgHr: 150.0,
            restingHr: 49.0,
            maxHr: 192.0
        )
        let trimpMatches = trimp >= 100.0 && trimp <= 110.0

        // 2. EWMA ACWR:
        // Case A: Steady 14 days of 100 TRIMP -> ratio ~ 1.0 (sweetSpot)
        let baseDate = Date(timeIntervalSince1970: 1729300000)
        var steadyLoads: [(date: Date, trimp: Double)] = []
        for d in 0..<14 {
            steadyLoads.append((date: baseDate.addingTimeInterval(Double(d) * 86400.0), trimp: 100.0))
        }
        let steadyEval = TrainingLoadAndBatteryEngine.computeEWMAWorkload(dailyLoads: steadyLoads)
        let steadyMatches = steadyEval.zone == .sweetSpot && abs(steadyEval.ratio - 1.0) < 0.15

        // Case B: Spike: 21 days of 40 TRIMP, then 4 days of 180 TRIMP -> ratio should ramp into caution/dangerSpike (> 1.30)
        var spikeLoads: [(date: Date, trimp: Double)] = []
        for d in 0..<21 {
            spikeLoads.append((date: baseDate.addingTimeInterval(Double(d) * 86400.0), trimp: 40.0))
        }
        for d in 21..<25 {
            spikeLoads.append((date: baseDate.addingTimeInterval(Double(d) * 86400.0), trimp: 180.0))
        }
        let spikeEval = TrainingLoadAndBatteryEngine.computeEWMAWorkload(dailyLoads: spikeLoads)
        let spikeMatches = spikeEval.ratio >= 1.30 && (spikeEval.zone == .caution || spikeEval.zone == .dangerSpike)

        // 3. Body Battery 24h timeline
        let batteryEval = TrainingLoadAndBatteryEngine.computeEnergyBankTimeline(
            wakeRecoveryScore: 90,
            sleepHours: 7.5,
            targetSleepHours: 7.5,
            pureNeatKcal: 450.0,
            workouts: [(hour: 17, trimp: 100.0)],
            immuneState: .optimal,
            currentHour: 18
        )
        let batteryMatches = batteryEval.wakeBattery >= 88 &&
                             batteryEval.timeline.count == 24 &&
                             batteryEval.currentBattery < batteryEval.wakeBattery &&
                             batteryEval.currentBattery >= 15

        let passed = trimpMatches && steadyMatches && spikeMatches && batteryMatches

        return VerificationResult(
            testName: "Garmin Firstbeat Workload & Body Battery",
            passed: passed,
            details: "TRIMP=\(trimp), SteadyACWR=\(steadyEval.ratio) (\(steadyEval.zone.rawValue)), SpikeACWR=\(spikeEval.ratio) (\(spikeEval.zone.rawValue)), WakeBattery=\(batteryEval.wakeBattery)%"
        )
    }

    private static func verifyCorrelationEngine() -> VerificationResult {
        // 1. Basic Pearson r sanity check
        let x = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
        let yPos = [2.0, 4.0, 6.0, 8.0, 10.0, 12.0]
        let yNeg = [12.0, 10.0, 8.0, 6.0, 4.0, 2.0]

        guard let rPos = CorrelationEngine.pearsonR(x, yPos),
              let rNeg = CorrelationEngine.pearsonR(x, yNeg),
              abs(rPos - 1.0) < 0.01,
              abs(rNeg - (-1.0)) < 0.01 else {
            return VerificationResult(testName: "Confounder-Controlled Time-Lagged Correlations", passed: false, details: "Basic Pearson r calculation failed")
        }

        // 2. Multi-day synthetic history with sodium-water spike & high TRIMP confounder
        let baseDate = Date(timeIntervalSince1970: 1729300000)
        var records: [DailyJoinedPhysiologyRecord] = []

        for i in 0..<10 {
            let dayDate = baseDate.addingTimeInterval(Double(i) * 86400.0)
            let isSodiumSpikeDay = (i % 2 == 1) // Days 1, 3, 5, 7, 9
            let sodium = isSodiumSpikeDay ? 4200.0 : 1800.0

            // Day T+1 water retention: +1.2kg on high sodium, -0.2kg on normal
            let prevDayWasSodium = (i > 0) && ((i - 1) % 2 == 1)
            let waterRetention = prevDayWasSodium ? 1.2 : -0.2
            let weight = 78.0 + waterRetention

            // Confounder test: Day 4 has late meal BUT high TRIMP (160) -> must be excluded from late-meal RHR analysis
            let isDay4 = (i == 4)
            let hasLateMeal = isDay4 || (i == 2) || (i == 6)
            let trimp = isDay4 ? 160.0 : 40.0
            let rhr = hasLateMeal ? 53.0 : 48.0

            records.append(DailyJoinedPhysiologyRecord(
                dateString: "2026-10-\(10 + i)",
                date: dayDate,
                weightKg: weight,
                rollingWeight7dKg: 78.0,
                sodiumMg: sodium,
                carbsG: 220.0,
                proteinG: 160.0,
                fatG: 65.0,
                wholeFoodRatio: 0.85,
                ultraProcessedRatio: 0.15,
                hasLateMealAfter2130: hasLateMeal,
                hasHighSodiumMeal: isSodiumSpikeDay,
                overnightHrvMs: 95.0,
                overnightRhrBpm: rhr,
                deepSleepHours: 1.4,
                remSleepHours: 1.6,
                workoutTrimp: trimp,
                runningCardiacDriftPct: 4.5,
                runningEf: 1.15
            ))
        }

        let insights = CorrelationEngine.computeInsights(records: records)
        guard !insights.isEmpty else {
            return VerificationResult(testName: "Confounder-Controlled Time-Lagged Correlations", passed: false, details: "computeInsights returned empty array")
        }

        let sodiumInsight = insights.first { $0.category == .hydrationWater }
        guard let sInsight = sodiumInsight, sInsight.pearsonR > 0.50 else {
            return VerificationResult(testName: "Confounder-Controlled Time-Lagged Correlations", passed: false, details: "Sodium water retention correlation missing or weak: r=\(sodiumInsight?.pearsonR ?? 0.0)")
        }

        return VerificationResult(
            testName: "Confounder-Controlled Time-Lagged Correlations",
            passed: true,
            details: "Generated \(insights.count) insights, SodiumWater r=\(sInsight.pearsonR) (N=\(sInsight.sampleCount))"
        )
    }

    private static func verifyAdaptivePhysiologyEngine() -> VerificationResult {
        // 1. Bayesian Shrinkage: N=14, kappa=14.0 -> 14 / (14 + 14) = 0.5
        let w = AdaptivePhysiologyEngine.bayesianShrinkageWeight(sampleCount: 14, kappa: 14.0)
        let wPassed = abs(w - 0.5) < 0.001

        // 2. Dynamic TDEE: rapid weight drop with steady intake shifts learned BMR upward
        let baseDate = Date(timeIntervalSince1970: 1729300000)
        var dropRecords: [DailyJoinedPhysiologyRecord] = []
        for i in 0..<14 {
            let dayDate = baseDate.addingTimeInterval(Double(i) * 86400.0)
            let weight = 80.0 - (Double(i) * 0.15) // Dropping 2.1kg in 14 days
            dropRecords.append(DailyJoinedPhysiologyRecord(
                dateString: "2026-10-\(10 + i)",
                date: dayDate,
                weightKg: weight,
                rollingWeight7dKg: weight,
                sodiumMg: 2000.0,
                carbsG: 250.0,
                proteinG: 170.0,
                fatG: 70.0,
                wholeFoodRatio: 0.9,
                ultraProcessedRatio: 0.1,
                hasLateMealAfter2130: false,
                hasHighSodiumMeal: false,
                overnightHrvMs: 100.0,
                overnightRhrBpm: 48.0,
                deepSleepHours: 1.5,
                remSleepHours: 1.5,
                workoutTrimp: 40.0,
                runningCardiacDriftPct: 4.0,
                runningEf: 1.2
            ))
        }

        let tdee = AdaptivePhysiologyEngine.computeDynamicTDEE(
            records: dropRecords,
            priorBmrKcal: 1750.0,
            priorTargetKcal: 2150.0
        )
        let bmrIncreased = tdee.learnedBmrKcal > 1750.0 && tdee.metabolicAdaptationKcal > 0

        // 3. Calibrate Readiness Weights sum == 1.0
        let initialWeights = ReadinessWeightVector()
        let calibrated = AdaptivePhysiologyEngine.calibrateReadinessWeights(
            currentWeights: initialWeights,
            rpeFeedback: -1,
            hrvWasLow: false,
            sleepWasLow: true
        )
        let weightSum = calibrated.hrvWeight + calibrated.rhrWeight + calibrated.sleepDurationWeight + calibrated.sleepArchitectureWeight
        let weightsNormalized = abs(weightSum - 1.0) < 0.005

        let passed = wPassed && bmrIncreased && weightsNormalized

        return VerificationResult(
            testName: "Self-Learning Adaptive Physiology Engine",
            passed: passed,
            details: "BayesianWeight=\(w) (expected 0.5), LearnedBMR=\(tdee.learnedBmrKcal) (adaptation: \(tdee.metabolicAdaptationKcal)), WeightsSum=\(weightSum)"
        )
    }
}

