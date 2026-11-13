import Foundation
import Combine
import HealthKit

// MARK: - Invalidation & Snapshot Models

public extension Notification.Name {
    static let lifecoreMealDidMutate = Notification.Name("lifecore.mealDidMutate")
    static let lifecoreProfileDidMutate = Notification.Name("lifecore.profileDidMutate")
    static let lifecoreWorkoutDidMutate = Notification.Name("lifecore.workoutDidMutate")
    static let lifecoreTrainingPlanDidMutate = Notification.Name("lifecore.trainingPlanDidMutate")
}

public enum SnapshotInvalidationReason: String, Sendable, Equatable {
    case manual
    case profileUpdated
    case mealMutated
    case workoutMutated
    case dietaryDayRollover
}

public struct DailyDashboardSnapshot: Sendable, Equatable {
    public let revision: UUID
    public let day: DietaryDay
    public let generatedAt: Date
    public let requestGeneration: UInt64
    public let sleepEpisode: SleepEpisode?
    public let vitalsEvaluation: OvernightVitalsEvaluation?
    public let readinessScore: Int?
    public let morningBodyBattery: Int?
    public let currentBodyBattery: Int?
    public let workloadEvaluation: ACWREvaluation?
    public let adaptiveSnapshot: AdaptivePhysiologySnapshot?
    public let prescriptionPlan: TrainingPrescriptionPlan?
    public let unavailabilityReasons: [PrescriptionUnavailabilityReason]
    public let isProvisionalWorkload: Bool
    public let confirmedMealsCount: Int
    public let confirmedIntakeKcal: Double?
    public let latestWorkout: PhysiologyWorkoutSample?

    public init(
        revision: UUID = UUID(),
        day: DietaryDay,
        generatedAt: Date,
        requestGeneration: UInt64,
        sleepEpisode: SleepEpisode? = nil,
        vitalsEvaluation: OvernightVitalsEvaluation? = nil,
        readinessScore: Int? = nil,
        morningBodyBattery: Int? = nil,
        currentBodyBattery: Int? = nil,
        workloadEvaluation: ACWREvaluation? = nil,
        adaptiveSnapshot: AdaptivePhysiologySnapshot? = nil,
        prescriptionPlan: TrainingPrescriptionPlan? = nil,
        unavailabilityReasons: [PrescriptionUnavailabilityReason] = [],
        isProvisionalWorkload: Bool = false,
        confirmedMealsCount: Int = 0,
        confirmedIntakeKcal: Double? = nil,
        latestWorkout: PhysiologyWorkoutSample? = nil
    ) {
        self.revision = revision
        self.day = day
        self.generatedAt = generatedAt
        self.requestGeneration = requestGeneration
        self.sleepEpisode = sleepEpisode
        self.vitalsEvaluation = vitalsEvaluation
        self.readinessScore = readinessScore
        self.morningBodyBattery = morningBodyBattery
        self.currentBodyBattery = currentBodyBattery
        self.workloadEvaluation = workloadEvaluation
        self.adaptiveSnapshot = adaptiveSnapshot
        self.prescriptionPlan = prescriptionPlan
        self.unavailabilityReasons = unavailabilityReasons
        self.isProvisionalWorkload = isProvisionalWorkload
        self.confirmedMealsCount = confirmedMealsCount
        self.confirmedIntakeKcal = confirmedIntakeKcal
        self.latestWorkout = latestWorkout
    }
}

public struct DailySnapshotRawInputs: Sendable {
    public let day: DietaryDay
    public let queueState: RollingQueueState
    public let goalConfig: TrainingGoalConfig
    public let sleepEpisode: SleepEpisode?
    public let vitalsEvaluation: OvernightVitalsEvaluation?
    public let readinessScore: Int?
    public let morningBodyBattery: Int?
    public let currentBodyBattery: Int?
    public let workloadEvaluation: ACWREvaluation?
    public let adaptiveSnapshot: AdaptivePhysiologySnapshot?
    public let rolling3dEnergyBalanceKcal: Double?
    public let efSamples: [Double]
    public let recentLongRunDriftsPct: [Double]
    public let efDelta30dPct: Double?
    public let restingHr: Double?
    public let maxHr: Double?
    public let carbDriftSlope: Double?
    public let confirmedMealsCount: Int
    public let confirmedIntakeKcal: Double?
    public let latestWorkout: PhysiologyWorkoutSample?
    public let hasAnyObservation: Bool

    public init(
        day: DietaryDay,
        queueState: RollingQueueState = RollingQueueState(),
        goalConfig: TrainingGoalConfig = TrainingGoalConfig(),
        sleepEpisode: SleepEpisode? = nil,
        vitalsEvaluation: OvernightVitalsEvaluation? = nil,
        readinessScore: Int? = nil,
        morningBodyBattery: Int? = nil,
        currentBodyBattery: Int? = nil,
        workloadEvaluation: ACWREvaluation? = nil,
        adaptiveSnapshot: AdaptivePhysiologySnapshot? = nil,
        rolling3dEnergyBalanceKcal: Double? = nil,
        efSamples: [Double] = [],
        recentLongRunDriftsPct: [Double] = [],
        efDelta30dPct: Double? = nil,
        restingHr: Double? = nil,
        maxHr: Double? = nil,
        carbDriftSlope: Double? = nil,
        confirmedMealsCount: Int = 0,
        confirmedIntakeKcal: Double? = nil,
        latestWorkout: PhysiologyWorkoutSample? = nil,
        hasAnyObservation: Bool? = nil
    ) {
        self.day = day
        self.queueState = queueState
        self.goalConfig = goalConfig
        self.sleepEpisode = sleepEpisode
        self.vitalsEvaluation = vitalsEvaluation
        self.readinessScore = readinessScore
        self.morningBodyBattery = morningBodyBattery
        self.currentBodyBattery = currentBodyBattery
        self.workloadEvaluation = workloadEvaluation
        self.adaptiveSnapshot = adaptiveSnapshot
        self.rolling3dEnergyBalanceKcal = rolling3dEnergyBalanceKcal
        self.efSamples = efSamples
        self.recentLongRunDriftsPct = recentLongRunDriftsPct
        self.efDelta30dPct = efDelta30dPct
        self.restingHr = restingHr
        self.maxHr = maxHr
        self.carbDriftSlope = carbDriftSlope
        self.confirmedMealsCount = confirmedMealsCount
        self.confirmedIntakeKcal = confirmedIntakeKcal
        self.latestWorkout = latestWorkout

        if let explicit = hasAnyObservation {
            self.hasAnyObservation = explicit
        } else {
            let hasVitals = vitalsEvaluation.map { !$0.allPillars.isEmpty } ?? false
            let hasWorkload = workloadEvaluation != nil && workloadEvaluation?.coverage.confidence != .insufficient
            self.hasAnyObservation = sleepEpisode != nil
                || hasVitals
                || readinessScore != nil
                || morningBodyBattery != nil
                || currentBodyBattery != nil
                || hasWorkload
                || confirmedMealsCount > 0
                || confirmedIntakeKcal != nil
                || latestWorkout != nil
                || !efSamples.isEmpty
                || !recentLongRunDriftsPct.isEmpty
        }
    }
}

// MARK: - Data Source Protocol & Live Implementation

public protocol DailySnapshotDataSource: Sendable {
    func fetchSnapshotInputs(for day: DietaryDay) async throws -> DailySnapshotRawInputs
}

public struct FixtureDailySnapshotDataSource: DailySnapshotDataSource {
    public init() {}

    public func fetchSnapshotInputs(for day: DietaryDay) async throws -> DailySnapshotRawInputs {
        let isUnitTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let scenario = UserDefaults.standard.string(forKey: "LifecoreFixtureScenario")
        if isUnitTest || scenario == "empty" {
            return DailySnapshotRawInputs(day: day, hasAnyObservation: false)
        }

        // Seeded deterministic E2E scenario computed via real Swift Math Engine primitives.
        let calendar = Calendar.current
        let dailyLoads: [(date: Date, trimp: Double)] = (0..<28).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: day.interval.start) else { return nil }
            let trimp = (offset % 3 == 0) ? 72.0 : 48.0
            return (date: date, trimp: trimp)
        }
        let workload = TrainingLoadAndBatteryEngine.computeEWMAWorkload(dailyLoads: dailyLoads, calendar: calendar)
        let vitals = OvernightVitalsEvaluation(
            state: .optimal,
            hrvPillar: VitalsPillarMetric(name: "HRV (RMSSD)", currentValue: 64.0, baselineValue: 60.0, delta: 4.0, unit: "ms", status: .inside, zScore: 0.4),
            rhrPillar: VitalsPillarMetric(name: "Спокійний пульс", currentValue: 52.0, baselineValue: 53.0, delta: -1.0, unit: "bpm", status: .inside, zScore: -0.3),
            tempPillar: VitalsPillarMetric(name: "Температура зап'ястя", currentValue: 0.05, baselineValue: 0.0, delta: 0.05, unit: "°C", status: .inside),
            respPillar: VitalsPillarMetric(name: "Частота дихання", currentValue: 14.2, baselineValue: 14.4, delta: -0.2, unit: "rpm", status: .inside),
            spo2Pillar: VitalsPillarMetric(name: "SpO₂", currentValue: 98.0, baselineValue: 98.0, delta: 0.0, unit: "%", status: .inside),
            outliersCount: 0,
            warningsCount: 0,
            headline: "Нічні вітальні у коридорі норми",
            actionDirective: "Оптимальне відновлення для планової роботи."
        )

        let (queueState, goalConfig) = await MainActor.run {
            (TrainingPlanStore.shared.queueState, TrainingPlanStore.shared.goalConfig)
        }

        return DailySnapshotRawInputs(
            day: day,
            queueState: queueState,
            goalConfig: goalConfig,
            vitalsEvaluation: vitals,
            readinessScore: 84,
            morningBodyBattery: 82,
            currentBodyBattery: 74,
            workloadEvaluation: workload,
            efSamples: [1.52, 1.54, 1.55],
            restingHr: 52.0,
            maxHr: 190.0,
            hasAnyObservation: true
        )
    }
}

public struct LiveDailySnapshotDataSource: DailySnapshotDataSource {
    private let calendar: Calendar
    private let now: @Sendable () -> Date

    public init(
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.calendar = calendar
        self.now = now
    }

    public func fetchSnapshotInputs(for day: DietaryDay) async throws -> DailySnapshotRawInputs {
        // Strict fixture isolation: never query HealthKit in fixture mode
        if AppEnvironment.current.isFixtureMode {
            return DailySnapshotRawInputs(day: day, hasAnyObservation: false)
        }

        let storeSnapshot = await readMainActorStores(for: day)
        let profile = storeSnapshot.profile
        let restingHr = profile.restingHeartRateBaselineBpm > 0 ? profile.restingHeartRateBaselineBpm : nil
        let maxHr = profile.maxHeartRateBpm > 0 ? profile.maxHeartRateBpm : nil

        let manager = HealthKitManager.shared
        guard manager.isAvailable else {
            return DailySnapshotRawInputs(
                day: day,
                queueState: storeSnapshot.queueState,
                goalConfig: storeSnapshot.goalConfig,
                restingHr: restingHr,
                maxHr: maxHr,
                confirmedMealsCount: storeSnapshot.confirmedMealsCount,
                confirmedIntakeKcal: storeSnapshot.confirmedIntakeKcal
            )
        }

        let rawSleep = try? await manager.sleepEpisode(endingBefore: day.interval.end)
        let sleepEpisode = rawSleep.flatMap { day.contains($0.interval.end) ? $0 : nil }

        let hkWorkouts = (try? await manager.fetchRecentWorkouts(days: 30, limit: 60)) ?? []
        let workoutSamples = makeWorkoutSamples(
            from: hkWorkouts,
            restingHr: profile.restingHeartRateBaselineBpm,
            maxHr: profile.maxHeartRateBpm
        )
        let dayWorkouts = workoutSamples
            .filter { day.contains($0.startedAt) }
            .sorted { $0.startedAt > $1.startedAt }
        let latestWorkout = dayWorkouts.first

        let lookbackStart = calendar.date(byAdding: .day, value: -27, to: day.interval.start) ?? day.interval.start
        let historyInterval = DateInterval(start: lookbackStart, end: day.interval.end)
        let joinedRecords = (try? await PhysiologyHistoryBuilder.build(
            in: historyInterval,
            healthRepository: manager,
            meals: storeSnapshot.allMeals,
            workouts: workoutSamples,
            calendar: calendar
        )) ?? []

        let dailyActivity = try? await manager.fetchDailyActivity(for: day.interval.start)
        let workoutKcalToday = hkWorkouts
            .filter { day.contains($0.startDate) }
            .compactMap { $0.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()) }
            .reduce(0.0, +)
        let pureNeatKcal = dailyActivity.map {
            max(0.0, $0.activeKcal - workoutKcalToday)
        }

        let priorBaseline = NocturnalVitalsBaseline(
            hrvMeanMs: profile.hrvBaselineMs,
            hrvStdDevMs: 15.0,
            hrvMethod: sleepEpisode?.hrvMethod,
            rhrMeanBpm: profile.restingHeartRateBaselineBpm,
            rhrStdDevBpm: 2.5,
            wristTempMeanCelsius: profile.wristTempBaselineCelsius,
            respiratoryRateMeanBpm: profile.respiratoryRateBaselineBpm,
            spo2MeanPct: profile.spo2BaselinePct
        )

        let adaptiveSnapshot: AdaptivePhysiologySnapshot? = joinedRecords.isEmpty
            ? nil
            : AdaptivePhysiologyEngine.evaluateAdaptiveSnapshot(
                records: joinedRecords,
                priorBmrKcal: profile.bmrKcalPerDay,
                priorTargetKcal: profile.targetCaloriesKcal,
                priorBaseline: priorBaseline,
                currentWeights: profile.readinessWeights,
                rpeCheckinsCount: profile.rpeCalibrationCount,
                todayNeatKcal: pureNeatKcal ?? 0.0,
                todayWorkoutKcal: workoutKcalToday
            )

        let effectiveBaseline = adaptiveSnapshot?.dynamicVitalsBaseline ?? priorBaseline
        let vitalsEvaluation = evaluateVitals(from: sleepEpisode, baseline: effectiveBaseline)
        let readinessScore = evaluateReadinessScore(
            from: sleepEpisode,
            vitalsEvaluation: vitalsEvaluation,
            baseline: effectiveBaseline,
            profile: profile
        )

        let loadSeries: [DailyLoadSeries] = joinedRecords.map { record in
            let hasHealthKitDaySignal = record.workoutTrimp > 0
                || record.isKnownRestDay
                || record.overnightHrvMs != nil
                || record.overnightRhrBpm != nil
                || record.deepSleepHours != nil
                || record.weightKg != nil
            if hasHealthKitDaySignal {
                return DailyLoadSeries(
                    date: record.date,
                    trimpLoad: record.workoutTrimp,
                    isKnownRestDay: record.workoutTrimp == 0,
                    isObserved: true
                )
            }
            return .unobserved(date: record.date)
        }
        let workloadEvaluation = TrainingLoadAndBatteryEngine.computeEWMAWorkload(
            series: loadSeries,
            calendar: calendar
        )

        let batteryResult = evaluateBodyBattery(
            day: day,
            sleepEpisode: sleepEpisode,
            readinessScore: readinessScore,
            vitalsEvaluation: vitalsEvaluation,
            dayWorkouts: dayWorkouts,
            pureNeatKcal: pureNeatKcal,
            profile: profile,
            trimpDrainFactor: adaptiveSnapshot?.sensitivities.trimpBatteryDrainFactor ?? 0.32
        )

        let efSamples = joinedRecords.compactMap(\.runningEf)
        let recentDrifts = workoutSamples
            .filter { $0.isRunning && $0.durationSeconds >= 2700 }
            .compactMap(\.cardiacDriftPct)
        let efDelta30dPct = computeEFDeltaPct(efSamples: efSamples)
        let rolling3dEnergyBalance = computeRolling3dEnergyBalance(
            records: joinedRecords,
            estimatedDailyTdee: adaptiveSnapshot?.dynamicTDEE.learnedDailyTdeeKcal
        )

        return DailySnapshotRawInputs(
            day: day,
            queueState: storeSnapshot.queueState,
            goalConfig: storeSnapshot.goalConfig,
            sleepEpisode: sleepEpisode,
            vitalsEvaluation: vitalsEvaluation,
            readinessScore: readinessScore,
            morningBodyBattery: batteryResult?.wakeBattery,
            currentBodyBattery: batteryResult?.currentBattery,
            workloadEvaluation: workloadEvaluation,
            adaptiveSnapshot: adaptiveSnapshot,
            rolling3dEnergyBalanceKcal: rolling3dEnergyBalance,
            efSamples: efSamples,
            recentLongRunDriftsPct: recentDrifts,
            efDelta30dPct: efDelta30dPct,
            restingHr: restingHr,
            maxHr: maxHr,
            carbDriftSlope: adaptiveSnapshot?.sensitivities.carbCardiacDriftSlopePctPer100g,
            confirmedMealsCount: storeSnapshot.confirmedMealsCount,
            confirmedIntakeKcal: storeSnapshot.confirmedIntakeKcal,
            latestWorkout: latestWorkout
        )
    }

    // MARK: - Helpers

    private struct MainActorStoreSnapshot: Sendable {
        let profile: AthleteProfile
        let queueState: RollingQueueState
        let goalConfig: TrainingGoalConfig
        let allMeals: [MealRecord]
        let confirmedMealsCount: Int
        let confirmedIntakeKcal: Double?
    }

    @MainActor
    private func readMainActorStores(for day: DietaryDay) -> MainActorStoreSnapshot {
        let profile = AthleteProfileStore.shared.profile
        let planStore = TrainingPlanStore.shared
        let allMeals = MealStorageService.shared.allMeals
        let confirmedDayMeals = allMeals.filter { !$0.isOptimisticPending && $0.dietaryDate == day.key }
        let confirmedIntakeKcal: Double? = confirmedDayMeals.isEmpty
            ? nil
            : round(confirmedDayMeals.reduce(0.0) { $0 + $1.kcal })
        return MainActorStoreSnapshot(
            profile: profile,
            queueState: planStore.queueState,
            goalConfig: planStore.goalConfig,
            allMeals: allMeals,
            confirmedMealsCount: confirmedDayMeals.count,
            confirmedIntakeKcal: confirmedIntakeKcal
        )
    }

    private func makeWorkoutSamples(
        from workouts: [HKWorkout],
        restingHr: Double,
        maxHr: Double
    ) -> [PhysiologyWorkoutSample] {
        let hrType = HKQuantityType(.heartRate)
        let hrUnit = HKUnit.count().unitDivided(by: .minute())
        let distType = HKQuantityType(.distanceWalkingRunning)

        return workouts.map { workout in
            let durationMin = workout.duration / 60.0
            let avgHr = workout.statistics(for: hrType)?.averageQuantity()?.doubleValue(for: hrUnit)
            let distanceM = workout.totalDistance?.doubleValue(for: .meter())
                ?? (workout.statistics(for: distType)?.sumQuantity()?.doubleValue(for: .meter()) ?? 0.0)
            let trimp = avgHr.map {
                TrainingLoadAndBatteryEngine.computeBanisterTRIMP(
                    durationMin: durationMin,
                    avgHr: $0,
                    restingHr: restingHr,
                    maxHr: maxHr
                )
            }
            let ef: Double?
            if let hr = avgHr, hr > 0, durationMin > 0, distanceM > 0 {
                ef = round(((distanceM / durationMin) / hr) * 1000.0) / 1000.0
            } else {
                ef = nil
            }
            return PhysiologyWorkoutSample(
                startedAt: workout.startDate,
                durationSeconds: workout.duration,
                trimp: trimp,
                avgHeartRate: avgHr,
                cardiacDriftPct: nil,
                efficiencyFactor: ef,
                isRunning: workout.workoutActivityType == .running
            )
        }
    }

    private func evaluateVitals(
        from sleepEpisode: SleepEpisode?,
        baseline: NocturnalVitalsBaseline
    ) -> OvernightVitalsEvaluation? {
        guard let episode = sleepEpisode else { return nil }
        let hrv = (episode.hrv?.quality != .unavailable) ? episode.hrv?.value : nil
        let hrvMethod = hrv != nil ? episode.hrvMethod : nil
        let rhr = (episode.restingHeartRate?.quality != .unavailable) ? episode.restingHeartRate?.value : nil
        let tempDelta = (episode.wristTemperatureDeltaCelsius?.quality != .unavailable)
            ? episode.wristTemperatureDeltaCelsius?.value
            : nil
        let respRate = (episode.respiratoryRate?.quality != .unavailable) ? episode.respiratoryRate?.value : nil
        let spo2 = (episode.oxygenSaturation?.quality != .unavailable) ? episode.oxygenSaturation?.value : nil

        guard hrv != nil || rhr != nil || tempDelta != nil || respRate != nil || spo2 != nil else {
            return nil
        }

        let input = NocturnalVitalsInput(
            hrvMs: hrv,
            hrvMethod: hrvMethod,
            rhrBpm: rhr,
            wristTempCelsius: tempDelta.map { baseline.wristTempMeanCelsius + $0 },
            wristTempDeltaCelsius: tempDelta,
            respiratoryRateBpm: respRate,
            spo2Pct: spo2
        )
        let alignedBaseline = NocturnalVitalsBaseline(
            hrvMeanMs: baseline.hrvMeanMs,
            hrvStdDevMs: baseline.hrvStdDevMs,
            hrvMethod: hrvMethod,
            rhrMeanBpm: baseline.rhrMeanBpm,
            rhrStdDevBpm: baseline.rhrStdDevBpm,
            wristTempMeanCelsius: baseline.wristTempMeanCelsius,
            respiratoryRateMeanBpm: baseline.respiratoryRateMeanBpm,
            spo2MeanPct: baseline.spo2MeanPct
        )
        return VitalsAndIllnessEngine.evaluateOvernightVitals(input: input, baseline: alignedBaseline)
    }

    private func evaluateReadinessScore(
        from sleepEpisode: SleepEpisode?,
        vitalsEvaluation: OvernightVitalsEvaluation?,
        baseline: NocturnalVitalsBaseline,
        profile: AthleteProfile
    ) -> Int? {
        guard let episode = sleepEpisode else { return nil }
        guard episode.totalSleepDurationSeconds > 0 || vitalsEvaluation != nil else { return nil }

        let hrv = (episode.hrv?.quality != .unavailable) ? episode.hrv?.value : nil
        let rhr = (episode.restingHeartRate?.quality != .unavailable) ? episode.restingHeartRate?.value : nil
        let calcBaseline = ReadinessCalculator.Baseline(
            avgHrvSDNN: baseline.hrvMeanMs,
            stdDevHrv: baseline.hrvStdDevMs,
            avgRHR: baseline.rhrMeanBpm,
            targetSleepHours: profile.targetSleepHours,
            targetDeepHours: 1.2,
            targetRemHours: 1.5
        )
        return ReadinessCalculator.computeRecovery(
            morningHrv: hrv,
            morningRhr: rhr,
            totalSleepHours: episode.totalSleepHours,
            deepSleepHours: episode.deepDurationSeconds / 3600.0,
            remSleepHours: episode.remDurationSeconds / 3600.0,
            baseline: calcBaseline,
            weights: profile.readinessWeights
        ).score
    }

    private func evaluateBodyBattery(
        day: DietaryDay,
        sleepEpisode: SleepEpisode?,
        readinessScore: Int?,
        vitalsEvaluation: OvernightVitalsEvaluation?,
        dayWorkouts: [PhysiologyWorkoutSample],
        pureNeatKcal: Double?,
        profile: AthleteProfile,
        trimpDrainFactor: Double
    ) -> EnergyBankEvaluation? {
        guard let episode = sleepEpisode,
              let score = readinessScore,
              let vitals = vitalsEvaluation else {
            return nil
        }

        let events = dayWorkouts.compactMap { workout -> WorkoutBatteryEvent? in
            guard let trimp = workout.trimp, trimp > 0 else { return nil }
            let end = workout.startedAt.addingTimeInterval(max(60.0, workout.durationSeconds))
            return WorkoutBatteryEvent(startTime: workout.startedAt, endTime: end, trimp: trimp)
        }

        let currentHour = calendar.component(.hour, from: now())
        return TrainingLoadAndBatteryEngine.computeEnergyBankTimeline(
            wakeRecoveryScore: score,
            sleepHours: episode.totalSleepHours,
            targetSleepHours: profile.targetSleepHours,
            pureNeatKcal: pureNeatKcal ?? 0.0,
            events: events,
            immuneState: vitals.state,
            currentHour: currentHour,
            trimpDrainFactor: trimpDrainFactor,
            calendar: calendar,
            referenceDate: day.interval.start
        )
    }

    private func computeEFDeltaPct(efSamples: [Double]) -> Double? {
        let valid = efSamples.filter { $0.isFinite && $0 > 0 }
        guard valid.count >= 4 else { return nil }
        let midpoint = valid.count / 2
        let earlier = valid.prefix(midpoint)
        let recent = valid.suffix(valid.count - midpoint)
        guard !earlier.isEmpty, !recent.isEmpty else { return nil }
        let earlyMean = earlier.reduce(0.0, +) / Double(earlier.count)
        let recentMean = recent.reduce(0.0, +) / Double(recent.count)
        guard earlyMean > 0 else { return nil }
        return ((recentMean - earlyMean) / earlyMean) * 100.0
    }

    private func computeRolling3dEnergyBalance(
        records: [DailyJoinedPhysiologyRecord],
        estimatedDailyTdee: Double?
    ) -> Double? {
        guard let tdee = estimatedDailyTdee, tdee > 0 else { return nil }
        let recent = records.suffix(3).filter(\.hasCompleteNutrition)
        guard recent.count == 3 else { return nil }
        let avgIntake = recent.compactMap(\.confirmedKcal).reduce(0.0, +) / 3.0
        return avgIntake - tdee
    }
}

// MARK: - Daily Snapshot Coordinator

@MainActor
public final class DailySnapshotCoordinator: ObservableObject {
    public static let shared = DailySnapshotCoordinator()

    @Published public private(set) var state: ScreenState<DailyDashboardSnapshot> = .loading
    @Published public private(set) var currentDay: DietaryDay
    public private(set) var requestGeneration: UInt64 = 0
    public private(set) var lastInvalidationReason: SnapshotInvalidationReason?

    private let dataSource: any DailySnapshotDataSource
    private let calendar: Calendar
    private let now: @Sendable () -> Date
    private let freshnessWindowSeconds: TimeInterval
    private var inFlightRefresh: (day: DietaryDay, generation: UInt64, task: Task<Void, Never>)?
    private var mutationTokens: [NSObjectProtocol] = []

    public init(
        dataSource: any DailySnapshotDataSource = LiveDailySnapshotDataSource(),
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = { Date() },
        freshnessWindowSeconds: TimeInterval = 60.0,
        observeStoreMutations: Bool = true
    ) {
        self.dataSource = dataSource
        self.calendar = calendar
        self.now = now
        self.freshnessWindowSeconds = freshnessWindowSeconds
        self.currentDay = DietaryDay.containing(now(), calendar: calendar)
        if observeStoreMutations {
            registerMutationObservers()
        }
    }

    deinit {
        for token in mutationTokens {
            NotificationCenter.default.removeObserver(token)
        }
    }

    private func registerMutationObservers() {
        let mappings: [(Notification.Name, SnapshotInvalidationReason)] = [
            (.lifecoreMealDidMutate, .mealMutated),
            (.lifecoreProfileDidMutate, .profileUpdated),
            (.lifecoreWorkoutDidMutate, .workoutMutated),
            (.lifecoreTrainingPlanDidMutate, .profileUpdated)
        ]
        mutationTokens = mappings.map { name, reason in
            NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.invalidate(reason: reason)
                }
            }
        }
    }

    public func refresh(day: DietaryDay? = nil, force: Bool = false) async {
        let targetDay = day ?? DietaryDay.containing(now(), calendar: calendar)

        if !force {
            if let existingInFlight = inFlightRefresh, existingInFlight.day == targetDay {
                await existingInFlight.task.value
                return
            }
            if case .content(let existing, let isRefreshing, let isStale) = state,
               !isRefreshing,
               !isStale,
               existing.day == targetDay,
               freshnessWindowSeconds > 0,
               now().timeIntervalSince(existing.generatedAt) < freshnessWindowSeconds {
                return
            }
        }

        currentDay = targetDay

        requestGeneration &+= 1
        let activeGeneration = requestGeneration
        let retainedValue = state.value

        if let existing = retainedValue {
            state = .content(existing, isRefreshing: true, isStale: state.isStale)
        } else {
            state = .loading
        }

        let task = Task<Void, Never> { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if self.inFlightRefresh?.generation == activeGeneration {
                    self.inFlightRefresh = nil
                }
            }

            do {
                let rawInputs = try await self.dataSource.fetchSnapshotInputs(for: targetDay)
                if Task.isCancelled {
                    if self.requestGeneration == activeGeneration {
                        self.restoreNonRefreshingState(retainedValue: retainedValue)
                    }
                    return
                }
                guard self.requestGeneration == activeGeneration else {
                    return
                }

                let evaluation: PrescriptionEvaluationOutcome
                if !rawInputs.hasAnyObservation {
                    evaluation = PrescriptionEvaluationOutcome(
                        plan: nil,
                        unavailabilityReasons: [
                            .noObservationsAvailable,
                            .missingOvernightVitals,
                            .missingWorkloadHistory
                        ],
                        isProvisionalWorkload: false
                    )
                } else {
                    evaluation = TrainingPrescriptionService.evaluate(
                        queueState: rawInputs.queueState,
                        config: rawInputs.goalConfig,
                        vitalsEvaluation: rawInputs.vitalsEvaluation,
                        morningBodyBattery: rawInputs.morningBodyBattery,
                        workloadEvaluation: rawInputs.workloadEvaluation,
                        rolling3dEnergyBalanceKcal: rawInputs.rolling3dEnergyBalanceKcal,
                        efSamples: rawInputs.efSamples,
                        recentLongRunDriftsPct: rawInputs.recentLongRunDriftsPct,
                        efDelta30dPct: rawInputs.efDelta30dPct,
                        restingHr: rawInputs.restingHr,
                        maxHr: rawInputs.maxHr,
                        carbDriftSlope: rawInputs.carbDriftSlope
                    )
                }

                let snapshot = DailyDashboardSnapshot(
                    revision: UUID(),
                    day: rawInputs.day,
                    generatedAt: self.now(),
                    requestGeneration: activeGeneration,
                    sleepEpisode: rawInputs.sleepEpisode,
                    vitalsEvaluation: rawInputs.vitalsEvaluation,
                    readinessScore: rawInputs.hasAnyObservation ? rawInputs.readinessScore : nil,
                    morningBodyBattery: rawInputs.hasAnyObservation ? rawInputs.morningBodyBattery : nil,
                    currentBodyBattery: rawInputs.hasAnyObservation ? rawInputs.currentBodyBattery : nil,
                    workloadEvaluation: rawInputs.workloadEvaluation,
                    adaptiveSnapshot: rawInputs.adaptiveSnapshot,
                    prescriptionPlan: evaluation.plan,
                    unavailabilityReasons: evaluation.unavailabilityReasons,
                    isProvisionalWorkload: evaluation.isProvisionalWorkload,
                    confirmedMealsCount: rawInputs.confirmedMealsCount,
                    confirmedIntakeKcal: rawInputs.confirmedIntakeKcal,
                    latestWorkout: rawInputs.latestWorkout
                )

                self.state = .content(snapshot, isRefreshing: false, isStale: false)
            } catch is CancellationError {
                if self.requestGeneration == activeGeneration {
                    self.restoreNonRefreshingState(retainedValue: retainedValue)
                }
            } catch {
                guard !Task.isCancelled, self.requestGeneration == activeGeneration else {
                    if Task.isCancelled, self.requestGeneration == activeGeneration {
                        self.restoreNonRefreshingState(retainedValue: retainedValue)
                    }
                    return
                }
                self.state = .failed(message: error.localizedDescription, retained: retainedValue)
            }
        }

        inFlightRefresh = (targetDay, activeGeneration, task)
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private func restoreNonRefreshingState(retainedValue: DailyDashboardSnapshot?) {
        if let retainedValue {
            state = .content(retainedValue, isRefreshing: false, isStale: state.isStale)
        } else {
            state = .empty
        }
    }

    public func invalidate(reason: SnapshotInvalidationReason = .manual) async {
        lastInvalidationReason = reason
        if case .content(let value, let isRefreshing, _) = state {
            state = .content(value, isRefreshing: isRefreshing, isStale: true)
        }
        await refresh(day: currentDay, force: true)
    }

    @discardableResult
    public func checkDietaryDayRolloverIfNeeded() async -> Bool {
        let latestDay = DietaryDay.containing(now(), calendar: calendar)
        guard latestDay != currentDay else {
            return false
        }
        currentDay = latestDay
        await invalidate(reason: .dietaryDayRollover)
        return true
    }
}
