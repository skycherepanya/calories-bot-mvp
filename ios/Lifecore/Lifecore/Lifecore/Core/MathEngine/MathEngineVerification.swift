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

        return results
    }

    // MARK: - Individual Test Cases

    private static func verifyKilometerSplits() -> VerificationResult {
        let baseDate = Date(timeIntervalSince1970: 1729300000)
        var samples: [RawTelemetryPoint] = []

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
}

