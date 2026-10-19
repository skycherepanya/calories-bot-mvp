import Foundation
import HealthKit

public final class HealthKitManager: @unchecked Sendable {
    public static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()

    private init() {}

    // MARK: - HealthKit Availability & Permissions
    public var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    public func requestAuthorization() async throws {
        guard isAvailable else {
            throw HealthKitError.notAvailableOnDevice
        }

        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.dietaryEnergyConsumed),
            HKQuantityType(.dietaryProtein),
            HKQuantityType(.dietaryFatTotal),
            HKQuantityType(.dietaryCarbohydrates),
            HKQuantityType(.dietarySodium),
            HKCategoryType(.sleepAnalysis),
            HKWorkoutType.workoutType()
        ]

        let shareTypes: Set<HKSampleType> = [
            HKQuantityType(.dietaryEnergyConsumed),
            HKQuantityType(.dietaryProtein),
            HKQuantityType(.dietaryFatTotal),
            HKQuantityType(.dietaryCarbohydrates),
            HKQuantityType(.dietarySodium)
        ]

        try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    // MARK: - Dietary Write-Back
    public func saveMealToHealthKit(
        name: String,
        kcal: Double,
        proteinG: Double,
        fatG: Double,
        carbsG: Double,
        sodiumMg: Double? = nil,
        fiberG: Double? = nil,
        date: Date = Date()
    ) async throws {
        guard isAvailable else { throw HealthKitError.notAvailableOnDevice }

        var samples: [HKQuantitySample] = []
        let metadata: [String: Any] = [
            HKMetadataKeyFoodType: name,
            HKMetadataKeySyncVersion: 1
        ]

        let kcalType = HKQuantityType(.dietaryEnergyConsumed)
        let kcalQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: kcal)
        samples.append(HKQuantitySample(type: kcalType, quantity: kcalQuantity, start: date, end: date, metadata: metadata))

        if proteinG > 0 {
            let pType = HKQuantityType(.dietaryProtein)
            let pQuantity = HKQuantity(unit: .gram(), doubleValue: proteinG)
            samples.append(HKQuantitySample(type: pType, quantity: pQuantity, start: date, end: date, metadata: metadata))
        }

        if fatG > 0 {
            let fType = HKQuantityType(.dietaryFatTotal)
            let fQuantity = HKQuantity(unit: .gram(), doubleValue: fatG)
            samples.append(HKQuantitySample(type: fType, quantity: fQuantity, start: date, end: date, metadata: metadata))
        }

        if carbsG > 0 {
            let cType = HKQuantityType(.dietaryCarbohydrates)
            let cQuantity = HKQuantity(unit: .gram(), doubleValue: carbsG)
            samples.append(HKQuantitySample(type: cType, quantity: cQuantity, start: date, end: date, metadata: metadata))
        }

        if let sodium = sodiumMg, sodium > 0 {
            let sType = HKQuantityType(.dietarySodium)
            let sQuantity = HKQuantity(unit: HKUnit.gramUnit(with: .milli), doubleValue: sodium)
            samples.append(HKQuantitySample(type: sType, quantity: sQuantity, start: date, end: date, metadata: metadata))
        }

        if let fiber = fiberG, fiber > 0 {
            let fibType = HKQuantityType(.dietaryFiber)
            let fibQuantity = HKQuantity(unit: .gram(), doubleValue: fiber)
            samples.append(HKQuantitySample(type: fibType, quantity: fibQuantity, start: date, end: date, metadata: metadata))
        }

        try await healthStore.save(samples)
    }

    // MARK: - 1. Daily NEAT Activity
    public func fetchDailyActivity(for date: Date = Date()) async throws -> DailyActivity {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            throw HealthKitError.invalidDateRange
        }

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        async let steps = fetchSum(for: HKQuantityType(.stepCount), unit: .count(), predicate: predicate)
        async let activeKcal = fetchSum(for: HKQuantityType(.activeEnergyBurned), unit: .kilocalorie(), predicate: predicate)
        async let distance = fetchSum(for: HKQuantityType(.distanceWalkingRunning), unit: .meter(), predicate: predicate)

        let stepsCount = try await Int(steps)
        let kcal = try await round(activeKcal * 10) / 10
        let distanceKm = try await round((distance / 1000.0) * 100) / 100

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        return DailyActivity(
            date: formatter.string(from: startOfDay),
            steps: stepsCount,
            activeKcal: kcal,
            distanceKm: distanceKm
        )
    }

    // MARK: - 2. Sleep Stages & Recovery Biomarkers
    public func fetchLastNightSleep() async throws -> SleepLog {
        let calendar = Calendar.current
        let now = Date()
        // Pull samples from last 24 hours to capture overnight sleep
        guard let yesterday = calendar.date(byAdding: .hour, value: -24, to: now) else {
            throw HealthKitError.invalidDateRange
        }

        let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: now, options: .strictEndDate)
        let sleepType = HKCategoryType(.sleepAnalysis)

        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (results as? [HKCategorySample]) ?? [])
            }
            healthStore.execute(query)
        }

        var deepSeconds: TimeInterval = 0
        var remSeconds: TimeInterval = 0
        var coreSeconds: TimeInterval = 0
        var awakeSeconds: TimeInterval = 0

        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            switch sample.value {
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                deepSeconds += duration
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                remSeconds += duration
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                coreSeconds += duration
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                awakeSeconds += duration
            default:
                break
            }
        }

        let deepHours = round((deepSeconds / 3600.0) * 100) / 100
        let remHours = round((remSeconds / 3600.0) * 100) / 100
        let coreHours = round((coreSeconds / 3600.0) * 100) / 100
        let awakeHours = round((awakeSeconds / 3600.0) * 100) / 100
        let totalHours = round((deepHours + remHours + coreHours) * 100) / 100

        // Fetch latest morning autonomic biomarkers
        async let hrv = fetchLatestQuantity(for: HKQuantityType(.heartRateVariabilitySDNN), unit: .secondUnit(with: .milli))
        async let rhr = fetchLatestQuantity(for: HKQuantityType(.restingHeartRate), unit: HKUnit.count().unitDivided(by: .minute()))

        let hrvValue = try? await hrv
        let rhrValue = try? await rhr

        // Determine sleep date (typically yesterday if waking up today)
        let sleepDate: Date
        if let firstSample = samples.last {
            sleepDate = firstSample.startDate
        } else {
            sleepDate = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        return SleepLog(
            sleepDate: dateFormatter.string(from: sleepDate),
            totalHours: totalHours,
            deepHours: deepHours,
            remHours: remHours,
            coreHours: coreHours,
            awakeHours: awakeHours,
            hrvAvgMs: hrvValue != nil ? round(hrvValue! * 10) / 10 : nil,
            rhrBpm: rhrValue != nil ? round(rhrValue! * 10) / 10 : nil
        )
    }

    // MARK: - 3. Workouts (Today)
    public func fetchLatestWorkoutToday() async throws -> WorkoutLog? {
        let all = try await fetchAllWorkoutsToday()
        return all.first
    }

    public func fetchAllWorkoutsToday() async throws -> [WorkoutLog] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let workouts = results as? [HKWorkout] else {
                    continuation.resume(returning: [])
                    return
                }

                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                let logs: [WorkoutLog] = workouts.map { workout in
                    let durationMin = round((workout.duration / 60.0) * 10) / 10
                    let calories = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
                        ?? workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
                    let distance = workout.totalDistance?.doubleValue(for: .meter())
                    let distanceKm = distance != nil ? round((distance! / 1000.0) * 100) / 100 : nil

                    let avgHr = workout.statistics(for: HKQuantityType(.heartRate))?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    let maxHr = workout.statistics(for: HKQuantityType(.heartRate))?.maximumQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))

                    var workoutTypeName = "other"
                    switch workout.workoutActivityType {
                    case .running: workoutTypeName = "running"
                    case .cycling: workoutTypeName = "cycling"
                    case .walking: workoutTypeName = "walking"
                    case .traditionalStrengthTraining, .functionalStrengthTraining: workoutTypeName = "strength"
                    case .highIntensityIntervalTraining: workoutTypeName = "hiit"
                    case .swimming: workoutTypeName = "swimming"
                    default: workoutTypeName = "other"
                    }

                    return WorkoutLog(
                        type: workoutTypeName,
                        durationMin: durationMin,
                        avgHeartRate: avgHr != nil ? round(avgHr! * 10) / 10 : nil,
                        maxHeartRate: maxHr != nil ? round(maxHr! * 10) / 10 : nil,
                        activeCalories: calories != nil ? round(calories!) : nil,
                        distanceKm: distanceKm,
                        startedAt: isoFormatter.string(from: workout.startDate)
                    )
                }

                continuation.resume(returning: logs)
            }
            self.healthStore.execute(query)
        }
    }

    /// Fetches recent HealthKit workouts within the given days.
    public func fetchRecentWorkouts(days: Int = 30, limit: Int = 60) async throws -> [HKWorkout] {
        let calendar = Calendar.current
        let now = Date()
        let pastDate = calendar.date(byAdding: .day, value: -days, to: now) ?? now.addingTimeInterval(-TimeInterval(days * 86400))
        let predicate = HKQuery.predicateForSamples(withStart: pastDate, end: now, options: [])

        return try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (results as? [HKWorkout]) ?? [])
            }
            self.healthStore.execute(query)
        }
    }

    /// Queries previous workouts of matching activity type within ±25% distance for benchmark comparison.
    public func fetchHistoricalSimilarWorkouts(to workout: HKWorkout, limit: Int = 3) async throws -> [(distanceKm: Double, paceMinKm: Double, avgHr: Double?, ef: Double?)] {
        let targetType = workout.workoutActivityType
        let targetDistance = workout.totalDistance?.doubleValue(for: .meter()) ?? 0.0
        let targetDate = workout.startDate

        let calendar = Calendar.current
        let pastDate = calendar.date(byAdding: .day, value: -60, to: targetDate) ?? targetDate.addingTimeInterval(-60 * 86400)
        let predicate = HKQuery.predicateForSamples(withStart: pastDate, end: targetDate.addingTimeInterval(-60), options: [])

        let candidates: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: 30,
                sortDescriptors: [sortDescriptor]
            ) { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (results as? [HKWorkout]) ?? [])
            }
            self.healthStore.execute(query)
        }

        var results: [(distanceKm: Double, paceMinKm: Double, avgHr: Double?, ef: Double?)] = []
        for c in candidates where c.workoutActivityType == targetType && c.uuid != workout.uuid {
            let distM = c.totalDistance?.doubleValue(for: .meter()) ?? 0.0
            if targetDistance > 0 {
                let ratio = distM / targetDistance
                guard ratio >= 0.75 && ratio <= 1.25 else { continue }
            }
            guard c.duration > 300 else { continue } // min 5 minutes

            let distKm = distM / 1000.0
            let durationMin = c.duration / 60.0
            let paceMinKm = distKm > 0 ? (durationMin / distKm) : 0.0
            let avgHr = c.statistics(for: HKQuantityType(.heartRate))?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))

            let speedMpm = c.duration > 0 ? (distM / (c.duration / 60.0)) : 0.0
            let ef = (avgHr != nil && avgHr! > 0 && speedMpm > 0) ? (speedMpm / avgHr!) : nil

            results.append((distanceKm: distKm, paceMinKm: paceMinKm, avgHr: avgHr, ef: ef))
            if results.count >= limit { break }
        }

        return results
    }

    /// Fetches 48h pre-workout physiological recovery context (sleep architecture, morning HRV, RHR baseline delta).
    public func fetchRecentRecoveryContext(for workoutDate: Date) async -> RecentRecoveryContext {
        let calendar = Calendar.current
        let startWindow = calendar.date(byAdding: .day, value: -2, to: workoutDate) ?? workoutDate.addingTimeInterval(-172800)
        let baseline = await fetchHistoricalBaseline(days: 30)

        let sleepPredicate = HKQuery.predicateForSamples(withStart: startWindow, end: workoutDate, options: [])
        let sleepSamples: [HKCategorySample] = (try? await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: HKCategoryType(.sleepAnalysis),
                predicate: sleepPredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, res, _ in
                continuation.resume(returning: (res as? [HKCategorySample]) ?? [])
            }
            self.healthStore.execute(query)
        }) ?? []

        var deepSec: TimeInterval = 0
        var remSec: TimeInterval = 0
        var coreSec: TimeInterval = 0
        for s in sleepSamples {
            let dur = s.endDate.timeIntervalSince(s.startDate)
            switch s.value {
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue: deepSec += dur
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue: remSec += dur
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue: coreSec += dur
            default: break
            }
        }
        let totalSleep = round(((deepSec + remSec + coreSec) / 3600.0) * 10) / 10
        let deepHours = round((deepSec / 3600.0) * 10) / 10
        let remHours = round((remSec / 3600.0) * 10) / 10

        let biomarkerPredicate = HKQuery.predicateForSamples(withStart: startWindow, end: workoutDate, options: [])
        let hrvVals = (try? await fetchQuantityValues(for: HKQuantityType(.heartRateVariabilitySDNN), unit: .secondUnit(with: .milli), predicate: biomarkerPredicate)) ?? []
        let rhrVals = (try? await fetchQuantityValues(for: HKQuantityType(.restingHeartRate), unit: HKUnit.count().unitDivided(by: .minute()), predicate: biomarkerPredicate)) ?? []

        let morningHrv = hrvVals.first != nil ? round(hrvVals.first! * 10) / 10 : nil
        let morningRhr = rhrVals.first != nil ? round(rhrVals.first! * 10) / 10 : nil

        let recovery = ReadinessCalculator.computeRecovery(
            morningHrv: morningHrv,
            morningRhr: morningRhr,
            totalSleepHours: totalSleep > 0 ? totalSleep : 7.2,
            deepSleepHours: deepHours > 0 ? deepHours : 1.2,
            remSleepHours: remHours > 0 ? remHours : 1.4,
            baseline: baseline
        )

        return RecentRecoveryContext(
            lastNightSleepHours: totalSleep > 0 ? totalSleep : nil,
            lastNightDeepHours: deepHours > 0 ? deepHours : nil,
            lastNightRemHours: remHours > 0 ? remHours : nil,
            morningHrvMs: morningHrv,
            baselineHrvMs: baseline.avgHrvSDNN,
            morningRhrBpm: morningRhr,
            baselineRhrBpm: baseline.avgRHR,
            yesterdayActiveKcal: nil,
            recoveryScore: recovery.score
        )
    }

    // MARK: - 4. 30-Day Historical Baselines
    public func fetchHistoricalBaseline(days: Int = 30) async -> ReadinessCalculator.Baseline {
        let calendar = Calendar.current
        let now = Date()
        guard let pastDate = calendar.date(byAdding: .day, value: -days, to: now) else {
            return .sasha
        }

        let predicate = HKQuery.predicateForSamples(withStart: pastDate, end: now, options: [])

        async let hrvTask = fetchQuantityValues(for: HKQuantityType(.heartRateVariabilitySDNN), unit: .secondUnit(with: .milli), predicate: predicate)
        async let rhrTask = fetchQuantityValues(for: HKQuantityType(.restingHeartRate), unit: HKUnit.count().unitDivided(by: .minute()), predicate: predicate)

        let hrvValues = (try? await hrvTask) ?? []
        let rhrValues = (try? await rhrTask) ?? []

        // Compute mean and standard deviation for HRV
        let avgHrv: Double
        let stdDevHrv: Double
        if hrvValues.count >= 3 {
            let mean = hrvValues.reduce(0.0, +) / Double(hrvValues.count)
            let variance = hrvValues.map { pow($0 - mean, 2.0) }.reduce(0.0, +) / Double(hrvValues.count)
            avgHrv = round(mean * 10) / 10
            stdDevHrv = max(5.0, round(sqrt(variance) * 10) / 10)
        } else {
            avgHrv = ReadinessCalculator.Baseline.sasha.avgHrvSDNN
            stdDevHrv = ReadinessCalculator.Baseline.sasha.stdDevHrv
        }

        // Compute mean for Resting HR
        let avgRhr: Double
        if rhrValues.count >= 3 {
            let mean = rhrValues.reduce(0.0, +) / Double(rhrValues.count)
            avgRhr = round(mean * 10) / 10
        } else {
            avgRhr = ReadinessCalculator.Baseline.sasha.avgRHR
        }

        return ReadinessCalculator.Baseline(
            avgHrvSDNN: avgHrv,
            stdDevHrv: stdDevHrv,
            avgRHR: avgRhr,
            targetSleepHours: 7.5,
            targetDeepHours: 1.2,
            targetRemHours: 1.5
        )
    }

    // MARK: - 5. Complete Today Snapshot
    public func fetchTodaySnapshot() async throws -> TodaySnapshot {
        async let actTask = fetchDailyActivity()
        async let sleepTask = fetchLastNightSleep()
        async let workoutsTask = fetchAllWorkoutsToday()
        async let baselineTask = fetchHistoricalBaseline(days: 30)

        let act = try await actTask
        let sleep = try await sleepTask
        let workouts = (try? await workoutsTask) ?? []
        let baseline = await baselineTask

        // Compute Recovery Score
        let recovery = ReadinessCalculator.computeRecovery(
            morningHrv: sleep.hrvAvgMs,
            morningRhr: sleep.rhrBpm,
            totalSleepHours: sleep.totalHours,
            deepSleepHours: sleep.deepHours,
            remSleepHours: sleep.remHours,
            baseline: baseline
        )

        // Compute Strain & Pure NEAT
        let workoutTuples = workouts.map {
            (durationMin: $0.durationMin, avgHr: $0.avgHeartRate, activeKcal: $0.activeCalories ?? 0.0)
        }
        let strain = ReadinessCalculator.computeStrain(
            dailyActiveKcal: act.activeKcal,
            workouts: workoutTuples
        )

        let neatKcal = ReadinessCalculator.isolatePureNEAT(
            dailyActiveKcal: act.activeKcal,
            workoutActiveKcals: workouts.compactMap { $0.activeCalories }
        )

        return TodaySnapshot(
            dailyActivity: act,
            sleepLog: sleep,
            workouts: workouts,
            baseline: baseline,
            recovery: recovery,
            strain: strain,
            pureNEATKcal: neatKcal
        )
    }

    // MARK: - Private Helpers
    private func fetchQuantityValues(for quantityType: HKQuantityType, unit: HKUnit, predicate: NSPredicate) async throws -> [Double] {
        try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let samples = results as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }
                let values = samples.map { $0.quantity.doubleValue(for: unit) }
                continuation.resume(returning: values)
            }
            healthStore.execute(query)
        }
    }

    private func fetchSum(for quantityType: HKQuantityType, unit: HKUnit, predicate: NSPredicate) async throws -> Double {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let sum = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0.0
                continuation.resume(returning: sum)
            }
            healthStore.execute(query)
        }
    }

    private func fetchLatestQuantity(for quantityType: HKQuantityType, unit: HKUnit) async throws -> Double? {
        try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let sample = (results as? [HKQuantitySample])?.first else {
                    continuation.resume(returning: nil)
                    return
                }
                let value = sample.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }
}

// MARK: - Today Snapshot Model

public struct TodaySnapshot: Sendable {
    public let dailyActivity: DailyActivity
    public let sleepLog: SleepLog
    public let workouts: [WorkoutLog]
    public let baseline: ReadinessCalculator.Baseline
    public let recovery: RecoveryEvaluation
    public let strain: StrainEvaluation
    public let pureNEATKcal: Double

    public init(
        dailyActivity: DailyActivity,
        sleepLog: SleepLog,
        workouts: [WorkoutLog],
        baseline: ReadinessCalculator.Baseline,
        recovery: RecoveryEvaluation,
        strain: StrainEvaluation,
        pureNEATKcal: Double
    ) {
        self.dailyActivity = dailyActivity
        self.sleepLog = sleepLog
        self.workouts = workouts
        self.baseline = baseline
        self.recovery = recovery
        self.strain = strain
        self.pureNEATKcal = pureNEATKcal
    }
}

public enum HealthKitError: Error, LocalizedError {
    case notAvailableOnDevice
    case invalidDateRange
    case queryFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notAvailableOnDevice:
            return "HealthKit is not available on this device."
        case .invalidDateRange:
            return "Invalid date range for HealthKit query."
        case .queryFailed(let message):
            return "HealthKit query failed: \(message)"
        }
    }
}
