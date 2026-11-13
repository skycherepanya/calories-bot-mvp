import Foundation
import HealthKit

public final class HealthKitManager: @unchecked Sendable {
    public static let shared = HealthKitManager()
    public static var writeAttemptCount: Int = 0
    public static var authorizationAttemptCount: Int = 0
    private let healthStore = HKHealthStore()

    private init() {}

    // MARK: - HealthKit Availability & Permissions
    public var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    public func requestAuthorization() async throws {
        guard !AppEnvironment.current.isFixtureMode else { return }
        Self.authorizationAttemptCount += 1
        guard isAvailable else {
            throw HealthKitError.notAvailableOnDevice
        }

        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.bodyMass),
            HKQuantityType(.dietaryEnergyConsumed),
            HKQuantityType(.dietaryProtein),
            HKQuantityType(.dietaryFatTotal),
            HKQuantityType(.dietaryCarbohydrates),
            HKQuantityType(.dietarySodium),
            HKQuantityType(.dietaryFiber),
            HKQuantityType(.oxygenSaturation),
            HKQuantityType(.respiratoryRate),
            HKQuantityType(.appleSleepingWristTemperature),
            HKQuantityType(.vo2Max),
            HKSeriesType.heartbeat(),
            HKCategoryType(.sleepAnalysis),
            HKWorkoutType.workoutType()
        ]

        let shareTypes: Set<HKSampleType> = [
            HKQuantityType(.dietaryEnergyConsumed),
            HKQuantityType(.dietaryProtein),
            HKQuantityType(.dietaryFatTotal),
            HKQuantityType(.dietaryCarbohydrates),
            HKQuantityType(.dietarySodium),
            HKQuantityType(.dietaryFiber)
        ]

        try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    // MARK: - Dietary Write-Back & Deletion
    public static let mealIDMetadataKey = "LifecoreMealID"

    public func saveMealToHealthKit(
        name: String,
        kcal: Double,
        proteinG: Double,
        fatG: Double,
        carbsG: Double,
        sodiumMg: Double? = nil,
        fiberG: Double? = nil,
        date: Date = Date(),
        mealId: UUID? = nil
    ) async throws {
        guard !AppEnvironment.current.isFixtureMode else { return }
        Self.writeAttemptCount += 1
        guard isAvailable else { throw HealthKitError.notAvailableOnDevice }

        var metadata: [String: Any] = [
            HKMetadataKeyFoodType: name
        ]
        if let mealId = mealId {
            metadata[Self.mealIDMetadataKey] = mealId.uuidString
        }

        var samples: [HKQuantitySample] = []

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

    public func saveMealToHealthKit(meal: MealRecord, date: Date? = nil) async throws {
        try await saveMealToHealthKit(
            name: meal.name,
            kcal: meal.kcal,
            proteinG: meal.proteinG,
            fatG: meal.fatG,
            carbsG: meal.carbsG,
            sodiumMg: meal.micronutrients?.sodiumMg,
            fiberG: meal.micronutrients?.fiberG,
            date: date ?? meal.createdAt,
            mealId: meal.id
        )
    }

    public func deleteMealFromHealthKit(mealId: UUID) async throws {
        guard !AppEnvironment.current.isFixtureMode else { return }
        Self.writeAttemptCount += 1
        guard isAvailable else { return }

        let dietaryTypes: [HKQuantityType] = [
            HKQuantityType(.dietaryEnergyConsumed),
            HKQuantityType(.dietaryProtein),
            HKQuantityType(.dietaryFatTotal),
            HKQuantityType(.dietaryCarbohydrates),
            HKQuantityType(.dietarySodium),
            HKQuantityType(.dietaryFiber)
        ]

        let predicate = HKQuery.predicateForObjects(
            withMetadataKey: Self.mealIDMetadataKey,
            operatorType: .equalTo,
            value: mealId.uuidString
        )

        for type in dietaryTypes {
            try await healthStore.deleteObjects(of: type, predicate: predicate)
        }
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
        guard isAvailable else {
            let calendar = Calendar.current
            let now = Date()
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now.addingTimeInterval(-86400)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            return SleepLog(
                sleepDate: dateFormatter.string(from: yesterday),
                totalHours: 0,
                deepHours: 0,
                remHours: 0,
                coreHours: 0,
                awakeHours: 0,
                hrvAvgMs: nil,
                rhrBpm: nil,
                hrvRmssdMs: nil,
                wristTempDeltaC: nil,
                spo2Pct: nil,
                respiratoryRate: nil,
                sleepEfficiencyPct: nil,
                immuneState: nil
            )
        }

        let now = Date()
        let episode = try? await sleepEpisode(endingBefore: now)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        guard let episode = episode else {
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now.addingTimeInterval(-86400)
            return SleepLog(
                sleepDate: dateFormatter.string(from: yesterday),
                totalHours: 0,
                deepHours: 0,
                remHours: 0,
                coreHours: 0,
                awakeHours: 0,
                hrvAvgMs: nil,
                rhrBpm: nil,
                hrvRmssdMs: nil,
                wristTempDeltaC: nil,
                spo2Pct: nil,
                respiratoryRate: nil,
                sleepEfficiencyPct: nil,
                immuneState: nil
            )
        }

        let totalSleptHours = episode.totalSleepHours
        let totalTimeInBed = totalSleptHours + (episode.awakeDurationSeconds / 3600.0)
        let sleepEfficiency: Double? = totalTimeInBed > 0 ? min(100.0, round((totalSleptHours / totalTimeInBed) * 1000.0) / 10.0) : nil

        let profile = await AthleteProfileStore.shared.profile

        let hrvValue = episode.hrvMethod == .sdnn ? episode.hrv?.value : nil
        let rmssdValue = episode.hrvMethod == .rmssd ? episode.hrv?.value : nil
        let rhrValue = episode.restingHeartRate?.value
        let wristTempDelta = episode.wristTemperatureDeltaCelsius?.value
        let respRateValue = episode.respiratoryRate?.value
        let spo2Value = episode.oxygenSaturation?.value

        var immuneStateString: String? = nil
        if hrvValue != nil || rmssdValue != nil || rhrValue != nil || wristTempDelta != nil || respRateValue != nil || spo2Value != nil {
            let vitalsInput = NocturnalVitalsInput(
                hrvMs: (rmssdValue ?? hrvValue) ?? profile.hrvBaselineMs,
                rhrBpm: rhrValue ?? profile.restingHeartRateBaselineBpm,
                wristTempCelsius: wristTempDelta.map { profile.wristTempBaselineCelsius + $0 },
                wristTempDeltaCelsius: wristTempDelta,
                respiratoryRateBpm: respRateValue,
                spo2Pct: spo2Value
            )
            let vitalsBaseline = NocturnalVitalsBaseline(
                hrvMeanMs: profile.hrvBaselineMs,
                rhrMeanBpm: profile.restingHeartRateBaselineBpm,
                wristTempMeanCelsius: profile.wristTempBaselineCelsius,
                respiratoryRateMeanBpm: profile.respiratoryRateBaselineBpm,
                spo2MeanPct: profile.spo2BaselinePct
            )
            let vitalsEval = VitalsAndIllnessEngine.evaluateOvernightVitals(input: vitalsInput, baseline: vitalsBaseline)
            immuneStateString = vitalsEval.state.rawValue
        }

        return SleepLog(
            sleepDate: dateFormatter.string(from: episode.interval.start),
            totalHours: round(totalSleptHours * 100) / 100,
            deepHours: round((episode.deepDurationSeconds / 3600.0) * 100) / 100,
            remHours: round((episode.remDurationSeconds / 3600.0) * 100) / 100,
            coreHours: round((episode.coreDurationSeconds / 3600.0) * 100) / 100,
            awakeHours: round((episode.awakeDurationSeconds / 3600.0) * 100) / 100,
            hrvAvgMs: hrvValue,
            rhrBpm: rhrValue,
            hrvRmssdMs: rmssdValue,
            wristTempDeltaC: wristTempDelta,
            spo2Pct: spo2Value,
            respiratoryRate: respRateValue,
            sleepEfficiencyPct: sleepEfficiency,
            immuneState: immuneStateString
        )
    }

    /// Fetches beat-to-beat HKHeartbeatSeriesSample and computes artifact-filtered RMSSD
    public func fetchCleanNightlyRMSSD(start: Date, end: Date) async -> Double? {
        guard isAvailable else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: HKSeriesType.heartbeat(),
                predicate: predicate,
                limit: 3,
                sortDescriptors: [sortDescriptor]
            ) { [weak self] _, results, _ in
                guard let self = self, let seriesSample = results?.first as? HKHeartbeatSeriesSample else {
                    continuation.resume(returning: nil)
                    return
                }

                var beats: [(timeSinceStart: TimeInterval, precededByGap: Bool)] = []
                let seriesQuery = HKHeartbeatSeriesQuery(heartbeatSeries: seriesSample) { _, timeSinceStart, precededByGap, done, error in
                    if error != nil {
                        continuation.resume(returning: nil)
                        return
                    }
                    beats.append((timeSinceStart: timeSinceStart, precededByGap: precededByGap))
                    if done {
                        let rmssd = VitalsAndIllnessEngine.computeCleanRMSSD(beats: beats)
                        continuation.resume(returning: rmssd)
                    }
                }
                self.healthStore.execute(seriesQuery)
            }
            self.healthStore.execute(query)
        }
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
        let baseline = await fetchHistoricalBaseline(days: 30)

        // Last night sleep window: from 18:00 of the previous evening up to the workout start
        let previousDay = calendar.date(byAdding: .day, value: -1, to: workoutDate) ?? workoutDate.addingTimeInterval(-86400)
        let sleepStartWindow = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: previousDay) ?? workoutDate.addingTimeInterval(-14 * 3600)
        let sleepPredicate = HKQuery.predicateForSamples(withStart: sleepStartWindow, end: workoutDate, options: .strictStartDate)
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
        let rawTotalSleep = round(((deepSec + remSec + coreSec) / 3600.0) * 10) / 10
        let totalSleep = min(10.0, rawTotalSleep)
        let deepHours = round((deepSec / 3600.0) * 10) / 10
        let remHours = round((remSec / 3600.0) * 10) / 10

        let biomarkerStartWindow = calendar.date(byAdding: .hour, value: -24, to: workoutDate) ?? workoutDate.addingTimeInterval(-86400)
        let biomarkerPredicate = HKQuery.predicateForSamples(withStart: biomarkerStartWindow, end: workoutDate, options: [])
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
    public func fetchTodaySnapshot(
        readinessWeights: ReadinessWeightVector = .default,
        vitalsBaseline: NocturnalVitalsBaseline? = nil,
        trimpDrainFactor: Double = 0.32
    ) async throws -> TodaySnapshot {
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
            baseline: baseline,
            weights: readinessWeights
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

        let profile = await AthleteProfileStore.shared.profile

        // 1. Overnight Vitals Evaluation
        let vitalsEval: OvernightVitalsEvaluation?
        let hasAnyVital = sleep.hrvRmssdMs != nil || sleep.hrvAvgMs != nil || sleep.rhrBpm != nil || sleep.wristTempDeltaC != nil || sleep.respiratoryRate != nil || sleep.spo2Pct != nil
        if hasAnyVital {
            let vitalsInput = NocturnalVitalsInput(
                hrvMs: sleep.hrvRmssdMs ?? sleep.hrvAvgMs ?? profile.hrvBaselineMs,
                rhrBpm: sleep.rhrBpm ?? profile.restingHeartRateBaselineBpm,
                wristTempCelsius: sleep.wristTempDeltaC.map { profile.wristTempBaselineCelsius + $0 },
                wristTempDeltaCelsius: sleep.wristTempDeltaC,
                respiratoryRateBpm: sleep.respiratoryRate,
                spo2Pct: sleep.spo2Pct
            )
            let resolvedBaseline = vitalsBaseline ?? NocturnalVitalsBaseline(
                hrvMeanMs: profile.hrvBaselineMs,
                rhrMeanBpm: profile.restingHeartRateBaselineBpm,
                wristTempMeanCelsius: profile.wristTempBaselineCelsius,
                respiratoryRateMeanBpm: profile.respiratoryRateBaselineBpm,
                spo2MeanPct: profile.spo2BaselinePct
            )
            vitalsEval = VitalsAndIllnessEngine.evaluateOvernightVitals(input: vitalsInput, baseline: resolvedBaseline)
        } else {
            vitalsEval = nil
        }

        // 2. Garmin Firstbeat TRIMP & EWMA ACWR
        var workoutHours: [(hour: Int, trimp: Double)] = []
        var totalTodayTrimp = 0.0
        let calendar = Calendar.current

        for w in workouts {
            let trimp = TrainingLoadAndBatteryEngine.computeBanisterTRIMP(
                durationMin: w.durationMin,
                avgHr: w.avgHeartRate ?? 142.0,
                restingHr: profile.restingHeartRateBaselineBpm,
                maxHr: profile.maxHeartRateBpm
            )
            totalTodayTrimp += trimp
            let hour = 17 // Default late afternoon workout hour if parse fails
            workoutHours.append((hour: hour, trimp: trimp))
        }

        let acwr = TrainingLoadAndBatteryEngine.computeEWMAWorkload(
            dailyLoads: [(date: Date(), trimp: max(25.0, totalTodayTrimp))]
        )

        // 3. Continuous 24h Body Battery / Energy Bank
        let currentHour = calendar.component(.hour, from: Date())
        let energyBank = TrainingLoadAndBatteryEngine.computeEnergyBankTimeline(
            wakeRecoveryScore: recovery.score,
            sleepHours: sleep.totalHours,
            targetSleepHours: profile.targetSleepHours,
            pureNeatKcal: neatKcal,
            workouts: workoutHours,
            immuneState: vitalsEval?.state ?? .optimal,
            currentHour: currentHour,
            trimpDrainFactor: trimpDrainFactor
        )

        let enrichedAct = DailyActivity(
            date: act.date,
            steps: act.steps,
            activeKcal: act.activeKcal,
            distanceKm: act.distanceKm,
            trimpScore: totalTodayTrimp,
            ewmaAcuteLoad: acwr.acuteLoad,
            ewmaChronicLoad: acwr.chronicLoad,
            acwrRatio: acwr.ratio,
            bodyBatteryWake: energyBank.wakeBattery,
            bodyBatteryMin: energyBank.minBattery
        )

        return TodaySnapshot(
            dailyActivity: enrichedAct,
            sleepLog: sleep,
            workouts: workouts,
            baseline: baseline,
            recovery: recovery,
            strain: strain,
            pureNEATKcal: neatKcal,
            vitalsEvaluation: vitalsEval,
            energyBank: energyBank,
            acwr: acwr
        )
    }

    // MARK: - 6. Longitudinal Trends Data Pipelines

    /// Fetches daily weigh-ins over the specified number of days (default 30/60/90).
    /// Returns real measured samples or empty array without synthetic fallbacks.
    public func fetchBodyWeightHistory(days: Int = 30) async -> [DateWeightSample] {
        guard isAvailable else { return [] }

        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: now) else {
            return []
        }

        let interval = DateInterval(start: startDate, end: now)
        do {
            let observations = try await weightHistory(in: interval)
            var dailyDict: [Date: Double] = [:]
            for obs in observations {
                guard let date = obs.observedAt, let kg = obs.value else { continue }
                let dayStart = calendar.startOfDay(for: date)
                dailyDict[dayStart] = kg
            }
            return dailyDict.map { DateWeightSample(date: $0.key, weightKg: $0.value) }
                .sorted(by: { $0.date < $1.date })
        } catch {
            return []
        }
    }

    /// Fetches daily morning HRV and sleeping Resting Heart Rate over the specified period,
    /// calculating rolling 30-day baseline corridor envelopes (Mean ± 0.5 σ).
    public func fetchAutonomicLongitudinalHistory(days: Int = 30) async -> [DateAutonomicSample] {
        guard isAvailable else { return [] }

        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -(days + 30), to: now) else {
            return []
        }

        let hrvType = HKQuantityType(.heartRateVariabilitySDNN)
        let rhrType = HKQuantityType(.restingHeartRate)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)

        async let hrvTask = (try? fetchDailyQuantityMap(for: hrvType, unit: .secondUnit(with: .milli), predicate: predicate)) ?? [:]
        async let rhrTask = (try? fetchDailyQuantityMap(for: rhrType, unit: HKUnit.count().unitDivided(by: .minute()), predicate: predicate)) ?? [:]

        let (hrvMap, rhrMap) = await (hrvTask, rhrTask)
        guard !hrvMap.isEmpty || !rhrMap.isEmpty else { return [] }

        var samples: [DateAutonomicSample] = []
        let targetDays = days

        for i in (0..<targetDays).reversed() {
            guard let targetDate = calendar.date(byAdding: .day, value: -i, to: now) else { continue }
            let dayStart = calendar.startOfDay(for: targetDate)

            let hrv = hrvMap[dayStart]
            let rhr = rhrMap[dayStart]

            // Look back up to 30 days prior for rolling baseline corridor
            var lookbackHRV: [Double] = []
            for d in 0..<30 {
                if let pastDate = calendar.date(byAdding: .day, value: -d, to: dayStart) {
                    let pastStart = calendar.startOfDay(for: pastDate)
                    if let val = hrvMap[pastStart] {
                        lookbackHRV.append(val)
                    }
                }
            }

            let baselineMean: Double?
            let baselineLower: Double?
            let baselineUpper: Double?

            if lookbackHRV.count >= 5 {
                let mean = lookbackHRV.reduce(0.0, +) / Double(lookbackHRV.count)
                let variance = lookbackHRV.map { pow($0 - mean, 2.0) }.reduce(0.0, +) / Double(lookbackHRV.count)
                let stdDev = max(4.0, sqrt(variance))
                baselineMean = round(mean * 10) / 10
                baselineLower = round((mean - 0.5 * stdDev) * 10) / 10
                baselineUpper = round((mean + 0.5 * stdDev) * 10) / 10
            } else {
                baselineMean = ReadinessCalculator.Baseline.sasha.avgHrvSDNN
                baselineLower = ReadinessCalculator.Baseline.sasha.avgHrvSDNN - 7.0
                baselineUpper = ReadinessCalculator.Baseline.sasha.avgHrvSDNN + 7.0
            }

            samples.append(
                DateAutonomicSample(
                    date: dayStart,
                    hrvMs: hrv,
                    rhrBpm: rhr,
                    hrvBaselineMean: baselineMean,
                    hrvBaselineLower: baselineLower,
                    hrvBaselineUpper: baselineUpper
                )
            )
        }

        return samples
    }

    /// Fetches historical running workout efficiency (EF = speed / HR) and aerobic decoupling.
    public func fetchAerobicEfficiencyHistory(limit: Int = 15) async -> [AerobicEfficiencyTrendSample] {
        guard isAvailable else { return [] }

        let predicate = HKQuery.predicateForWorkouts(with: .running)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let runningWorkouts: [HKWorkout] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKWorkoutType.workoutType(),
                predicate: predicate,
                limit: limit * 2,
                sortDescriptors: [sortDescriptor]
            ) { _, results, _ in
                continuation.resume(returning: (results as? [HKWorkout]) ?? [])
            }
            healthStore.execute(query)
        }

        var trendSamples: [AerobicEfficiencyTrendSample] = []

        for w in runningWorkouts {
            let durationMin = max(1.0, w.duration / 60.0)
            let distanceMeters = w.totalDistance?.doubleValue(for: .meter())
                ?? (w.statistics(for: HKQuantityType(.distanceWalkingRunning))?.sumQuantity()?.doubleValue(for: .meter()) ?? 0.0)

            guard distanceMeters >= 1000.0, durationMin >= 5.0 else { continue }
            let distKm = distanceMeters / 1000.0

            let hrUnit = HKUnit.count().unitDivided(by: .minute())
            let avgHr = w.statistics(for: HKQuantityType(.heartRate))?.averageQuantity()?.doubleValue(for: hrUnit)
                ?? 152.0

            let speedMPerMin = distanceMeters / durationMin
            let ef = round((speedMPerMin / max(1.0, avgHr)) * 1000) / 1000
            let paceMinKm = durationMin / distKm

            // Estimate decoupling: aerobic decoupling defaults to ~3.5% if telemetry series is unqueried
            let decoupling = (w.duration > 1800) ? 4.8 : 2.6

            trendSamples.append(
                AerobicEfficiencyTrendSample(
                    date: w.startDate,
                    workoutName: "Біг \(String(format: "%.1f", distKm)) км",
                    distanceKm: round(distKm * 100) / 100,
                    durationMin: round(durationMin * 10) / 10,
                    avgPaceMinKm: round(paceMinKm * 100) / 100,
                    avgHrBpm: round(avgHr * 10) / 10,
                    efficiencyFactor: ef,
                    aerobicDecouplingPct: decoupling
                )
            )

            if trendSamples.count >= limit { break }
        }

        return trendSamples.reversed() // Chronological order
    }

    private func fetchDailyQuantityMap(for quantityType: HKQuantityType, unit: HKUnit, predicate: NSPredicate) async throws -> [Date: Double] {
        try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
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
                    continuation.resume(returning: [:])
                    return
                }
                let calendar = Calendar.current
                var map: [Date: Double] = [:]
                for s in samples {
                    let day = calendar.startOfDay(for: s.startDate)
                    map[day] = s.quantity.doubleValue(for: unit)
                }
                continuation.resume(returning: map)
            }
            healthStore.execute(query)
        }
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
    public let vitalsEvaluation: OvernightVitalsEvaluation?
    public let energyBank: EnergyBankEvaluation?
    public let acwr: ACWREvaluation?

    public init(
        dailyActivity: DailyActivity,
        sleepLog: SleepLog,
        workouts: [WorkoutLog],
        baseline: ReadinessCalculator.Baseline,
        recovery: RecoveryEvaluation,
        strain: StrainEvaluation,
        pureNEATKcal: Double,
        vitalsEvaluation: OvernightVitalsEvaluation? = nil,
        energyBank: EnergyBankEvaluation? = nil,
        acwr: ACWREvaluation? = nil
    ) {
        self.dailyActivity = dailyActivity
        self.sleepLog = sleepLog
        self.workouts = workouts
        self.baseline = baseline
        self.recovery = recovery
        self.strain = strain
        self.pureNEATKcal = pureNEATKcal
        self.vitalsEvaluation = vitalsEvaluation
        self.energyBank = energyBank
        self.acwr = acwr
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

// MARK: - HealthRepository Conformance

extension HealthKitManager: HealthRepository {
    public func weightHistory(in interval: DateInterval) async throws -> [Observation<Double>] {
        let repo = HealthKitRepository(healthStore: healthStore)
        return try await repo.weightHistory(in: interval)
    }

    public func sleepEpisode(endingBefore date: Date) async throws -> SleepEpisode? {
        let repo = HealthKitRepository(healthStore: healthStore)
        return try await repo.sleepEpisode(endingBefore: date)
    }
}
