import Foundation
import Combine
import HealthKit

public typealias TrendsDataLoader = @Sendable (Int) async throws -> TrendsSnapshot

public struct DailyTrimpLoadPoint: Sendable, Equatable, Identifiable {
    public var id: Date { date }
    public let date: Date
    public let trimp: Double

    public init(date: Date, trimp: Double) {
        self.date = date
        self.trimp = trimp
    }
}

public struct TrendsSnapshot: Sendable {
    public let rangeDays: Int
    public let records: [DailyJoinedPhysiologyRecord]
    public let weightPoints: [TrendWeightPoint]
    public let autonomicSamples: [DateAutonomicSample]
    public let efSamples: [AerobicEfficiencyTrendSample]
    public let correlationInsights: [CorrelationInsight]
    public let acwrEvaluation: ACWREvaluation?
    public let dailyTrimpLoads: [DailyTrimpLoadPoint]
    public let adaptiveSnapshot: AdaptivePhysiologySnapshot?

    public let weightCoverage: String
    public let autonomicCoverage: String
    public let efCoverage: String
    public let dynamicTdeeCoverage: String
    public let acwrCoverage: String
    public let correlationCoverage: String

    public init(
        rangeDays: Int,
        records: [DailyJoinedPhysiologyRecord],
        weightPoints: [TrendWeightPoint],
        autonomicSamples: [DateAutonomicSample],
        efSamples: [AerobicEfficiencyTrendSample],
        correlationInsights: [CorrelationInsight],
        acwrEvaluation: ACWREvaluation?,
        dailyTrimpLoads: [DailyTrimpLoadPoint],
        adaptiveSnapshot: AdaptivePhysiologySnapshot?,
        weightCoverage: String,
        autonomicCoverage: String,
        efCoverage: String,
        dynamicTdeeCoverage: String,
        acwrCoverage: String,
        correlationCoverage: String
    ) {
        self.rangeDays = rangeDays
        self.records = records
        self.weightPoints = weightPoints
        self.autonomicSamples = autonomicSamples
        self.efSamples = efSamples
        self.correlationInsights = correlationInsights
        self.acwrEvaluation = acwrEvaluation
        self.dailyTrimpLoads = dailyTrimpLoads
        self.adaptiveSnapshot = adaptiveSnapshot
        self.weightCoverage = weightCoverage
        self.autonomicCoverage = autonomicCoverage
        self.efCoverage = efCoverage
        self.dynamicTdeeCoverage = dynamicTdeeCoverage
        self.acwrCoverage = acwrCoverage
        self.correlationCoverage = correlationCoverage
    }
}

extension TrendsSnapshot: Equatable {
    public static func == (lhs: TrendsSnapshot, rhs: TrendsSnapshot) -> Bool {
        lhs.rangeDays == rhs.rangeDays &&
        lhs.records.count == rhs.records.count &&
        zip(lhs.records, rhs.records).allSatisfy { $0.dateString == $1.dateString && $0.weightKg == $1.weightKg && $0.overnightHrvMs == $1.overnightHrvMs && $0.workoutTrimp == $1.workoutTrimp } &&
        lhs.weightPoints.count == rhs.weightPoints.count &&
        zip(lhs.weightPoints, rhs.weightPoints).allSatisfy { $0.date == $1.date && $0.rawWeightKg == $1.rawWeightKg && $0.isWaterSpike == $1.isWaterSpike } &&
        lhs.autonomicSamples.count == rhs.autonomicSamples.count &&
        zip(lhs.autonomicSamples, rhs.autonomicSamples).allSatisfy { $0.date == $1.date && $0.hrvMs == $1.hrvMs && $0.rhrBpm == $1.rhrBpm } &&
        lhs.efSamples.count == rhs.efSamples.count &&
        zip(lhs.efSamples, rhs.efSamples).allSatisfy { $0.id == $1.id && $0.efficiencyFactor == $1.efficiencyFactor } &&
        lhs.correlationInsights == rhs.correlationInsights &&
        lhs.acwrEvaluation == rhs.acwrEvaluation &&
        lhs.dailyTrimpLoads == rhs.dailyTrimpLoads &&
        lhs.adaptiveSnapshot == rhs.adaptiveSnapshot &&
        lhs.weightCoverage == rhs.weightCoverage &&
        lhs.autonomicCoverage == rhs.autonomicCoverage &&
        lhs.efCoverage == rhs.efCoverage &&
        lhs.dynamicTdeeCoverage == rhs.dynamicTdeeCoverage &&
        lhs.acwrCoverage == rhs.acwrCoverage &&
        lhs.correlationCoverage == rhs.correlationCoverage
    }
}

@MainActor
public final class TrendsViewModel: ObservableObject {
    @Published public private(set) var state: ScreenState<TrendsSnapshot> = .loading
    @Published public private(set) var selectedRangeDays: Int

    private var requestGeneration: UInt64 = 0
    private let dataLoader: TrendsDataLoader

    public init(
        selectedRangeDays: Int = 30,
        dataLoader: TrendsDataLoader? = nil,
        healthRepository: (any HealthRepository)? = nil,
        athleteProfile: AthleteProfile? = nil
    ) {
        self.selectedRangeDays = selectedRangeDays
        if let dataLoader {
            self.dataLoader = dataLoader
        } else {
            self.dataLoader = Self.makeDefaultDataLoader(
                healthRepository: healthRepository,
                athleteProfile: athleteProfile
            )
        }
    }

    public func load(rangeDays: Int) async {
        requestGeneration &+= 1
        let activeGeneration = requestGeneration
        selectedRangeDays = rangeDays

        // Retain cached content while refreshing
        if let current = state.value {
            state = .content(current, isRefreshing: true, isStale: false)
        } else if !state.isLoading {
            state = .loading
        }

        do {
            let snapshot = try await dataLoader(rangeDays)

            guard !Task.isCancelled && activeGeneration == requestGeneration else {
                if Task.isCancelled && activeGeneration == requestGeneration {
                    if let current = state.value {
                        state = .content(current, isRefreshing: false, isStale: false)
                    } else {
                        state = .empty
                    }
                }
                return
            }

            state = .content(snapshot, isRefreshing: false, isStale: false)
        } catch is CancellationError {
            if activeGeneration == requestGeneration {
                if let current = state.value {
                    state = .content(current, isRefreshing: false, isStale: false)
                } else {
                    state = .empty
                }
            }
        } catch {
            guard !Task.isCancelled && activeGeneration == requestGeneration else {
                if Task.isCancelled && activeGeneration == requestGeneration {
                    if let current = state.value {
                        state = .content(current, isRefreshing: false, isStale: false)
                    } else {
                        state = .empty
                    }
                }
                return
            }

            state = .failed(message: error.localizedDescription, retained: state.value)
        }
    }

    // MARK: - Coverage Formatters

    public static func formatDynamicTdeeCoverage(records: [DailyJoinedPhysiologyRecord]) -> String {
        let recent14 = Array(records.suffix(14))
        let observedWeights = recent14.compactMap(\.weightKg).count
        let observedMeals = recent14.filter { $0.hasCompleteNutrition }.count
        return "Вікно 14 днів (TDEE) • \(observedWeights) замірів ваги • \(observedMeals) днів харчування"
    }

    public static func formatAcwrCoverage(records: [DailyJoinedPhysiologyRecord]) -> String {
        let recent28 = Array(records.suffix(28))
        let trainingDays = recent28.filter { $0.workoutTrimp > 0 }.count
        return "Вікно 28 днів (EWMA) • \(trainingDays) тренувальних днів"
    }

    public static func formatWeightCoverage(records: [DailyJoinedPhysiologyRecord], totalDays: Int) -> String {
        let observed = records.compactMap(\.weightKg).count
        let missing = max(0, totalDays - observed)
        if missing > 0 {
            return "\(totalDays) днів • \(observed) замірів (\(missing) без замірів)"
        } else {
            return "\(totalDays) днів • \(observed) замірів"
        }
    }

    public static func formatAutonomicCoverage(records: [DailyJoinedPhysiologyRecord], totalDays: Int) -> String {
        let observed = records.compactMap(\.overnightHrvMs).count
        let missing = max(0, totalDays - observed)
        if missing > 0 {
            return "\(totalDays) днів • \(observed) нічних замірів (\(missing) без замірів)"
        } else {
            return "\(totalDays) днів • \(observed) нічних замірів"
        }
    }

    public static func formatCorrelationCoverage(records: [DailyJoinedPhysiologyRecord]) -> String {
        let completeDays = records.filter { $0.hasCompleteNutrition }.count
        return "Загальна вибірка: \(records.count) днів • \(completeDays) днів з повним раціоном"
    }

    // MARK: - Factory Constructors

    public static func makeSnapshot(
        rangeDays: Int,
        records: [DailyJoinedPhysiologyRecord],
        workouts: [PhysiologyWorkoutSample] = [],
        profile: AthleteProfile? = nil
    ) -> TrendsSnapshot {
        let resolvedProfile = profile ?? AthleteProfileStore.shared.profile
        // 1. Weight points
        var rawWeightSamples: [DateWeightSample] = []
        for r in records {
            if let w = r.weightKg {
                rawWeightSamples.append(DateWeightSample(date: r.date, weightKg: w))
            }
        }
        let weightPoints = ReadinessCalculator.computeLongitudinalWeightTrend(samples: rawWeightSamples)

        // 2. Autonomic samples
        var autonomicSamples: [DateAutonomicSample] = []
        for (i, r) in records.enumerated() {
            let lookback = records[max(0, i - 29)...i].compactMap(\.overnightHrvMs)
            let baselineMean: Double?
            let baselineLower: Double?
            let baselineUpper: Double?
            if lookback.count >= 5 {
                let mean = lookback.reduce(0.0, +) / Double(lookback.count)
                let variance = lookback.map { pow($0 - mean, 2.0) }.reduce(0.0, +) / Double(lookback.count)
                let stdDev = max(4.0, sqrt(variance))
                baselineMean = round(mean * 10) / 10
                baselineLower = round((mean - 0.5 * stdDev) * 10) / 10
                baselineUpper = round((mean + 0.5 * stdDev) * 10) / 10
            } else {
                baselineMean = resolvedProfile.hrvBaselineMs
                baselineLower = resolvedProfile.hrvBaselineMs - 7.0
                baselineUpper = resolvedProfile.hrvBaselineMs + 7.0
            }
            autonomicSamples.append(
                DateAutonomicSample(
                    date: r.date,
                    hrvMs: r.overnightHrvMs,
                    rhrBpm: r.overnightRhrBpm,
                    hrvBaselineMean: baselineMean,
                    hrvBaselineLower: baselineLower,
                    hrvBaselineUpper: baselineUpper
                )
            )
        }

        // 3. EF samples from workouts / records
        var efSamples: [AerobicEfficiencyTrendSample] = []
        for w in workouts where w.isRunning {
            if let ef = w.efficiencyFactor {
                let durationMin = w.durationSeconds / 60.0
                let avgHr = w.avgHeartRate ?? 145.0
                let speedMPerMin = ef * avgHr
                let distanceKm = max(0.0, (speedMPerMin * durationMin) / 1000.0)
                let avgPaceMinKm = distanceKm > 0 ? durationMin / distanceKm : 5.5
                efSamples.append(
                    AerobicEfficiencyTrendSample(
                        date: w.startedAt,
                        workoutName: "Пробіжка",
                        distanceKm: distanceKm,
                        durationMin: durationMin,
                        avgPaceMinKm: avgPaceMinKm,
                        avgHrBpm: avgHr,
                        efficiencyFactor: ef,
                        aerobicDecouplingPct: w.cardiacDriftPct
                    )
                )
            }
        }
        if efSamples.isEmpty {
            for r in records {
                if let ef = r.runningEf {
                    efSamples.append(
                        AerobicEfficiencyTrendSample(
                            date: r.date,
                            workoutName: "Пробіжка",
                            distanceKm: 8.0,
                            durationMin: 45.0,
                            avgPaceMinKm: 5.5,
                            avgHrBpm: 145.0,
                            efficiencyFactor: ef,
                            aerobicDecouplingPct: r.runningCardiacDriftPct
                        )
                    )
                }
            }
        }

        // 4. Daily TRIMP loads for ACWR
        var dailyLoads: [DailyTrimpLoadPoint] = []
        for r in records {
            dailyLoads.append(DailyTrimpLoadPoint(date: r.date, trimp: r.workoutTrimp))
        }
        let tupleLoads = dailyLoads.map { ($0.date, $0.trimp) }
        let acwr = TrainingLoadAndBatteryEngine.computeEWMAWorkload(dailyLoads: tupleLoads)

        // 5. Correlation Insights
        let insights = CorrelationEngine.computeInsights(records: records)

        // 6. Adaptive Physiology Snapshot
        let adaptive = AdaptivePhysiologyEngine.evaluateAdaptiveSnapshot(
            records: records,
            priorBmrKcal: resolvedProfile.bmrKcalPerDay,
            priorTargetKcal: resolvedProfile.targetCaloriesKcal,
            priorBaseline: NocturnalVitalsBaseline(
                hrvMeanMs: resolvedProfile.hrvBaselineMs,
                rhrMeanBpm: resolvedProfile.restingHeartRateBaselineBpm,
                wristTempMeanCelsius: resolvedProfile.wristTempBaselineCelsius,
                respiratoryRateMeanBpm: resolvedProfile.respiratoryRateBaselineBpm,
                spo2MeanPct: resolvedProfile.spo2BaselinePct
            ),
            currentWeights: resolvedProfile.readinessWeights,
            rpeCheckinsCount: resolvedProfile.rpeCalibrationCount,
            todayNeatKcal: 450.0,
            todayWorkoutKcal: 200.0
        )

        // 7. Explicit coverages for fixed-window engine summaries vs requested range
        let weightCov = formatWeightCoverage(records: records, totalDays: rangeDays)
        let autonomicCov = formatAutonomicCoverage(records: records, totalDays: rangeDays)
        let efCov = "\(efSamples.count) бігових тренувань у вибірці"
        let dynamicTdeeCov = formatDynamicTdeeCoverage(records: records)
        let acwrCov = formatAcwrCoverage(records: records)
        let correlationCov = formatCorrelationCoverage(records: records)

        return TrendsSnapshot(
            rangeDays: rangeDays,
            records: records,
            weightPoints: weightPoints,
            autonomicSamples: autonomicSamples,
            efSamples: efSamples,
            correlationInsights: insights,
            acwrEvaluation: acwr,
            dailyTrimpLoads: dailyLoads,
            adaptiveSnapshot: adaptive,
            weightCoverage: weightCov,
            autonomicCoverage: autonomicCov,
            efCoverage: efCov,
            dynamicTdeeCoverage: dynamicTdeeCov,
            acwrCoverage: acwrCov,
            correlationCoverage: correlationCov
        )
    }

    private static func makeDefaultDataLoader(
        healthRepository: (any HealthRepository)?,
        athleteProfile: AthleteProfile?
    ) -> TrendsDataLoader {
        return { rangeDays in
            let calendar = Calendar.current
            let now = Date()
            guard let startDate = calendar.date(byAdding: .day, value: -rangeDays, to: now) else {
                throw HealthKitError.invalidDateRange
            }
            let interval = DateInterval(start: startDate, end: now)

            if AppEnvironment.current.isFixtureMode {
                let repo = healthRepository ?? FixtureHealthRepository(
                    weightObservations: [],
                    sleepEpisodes: [],
                    isHealthKitAvailable: true
                )
                let records = (try? await PhysiologyHistoryBuilder.build(
                    in: interval,
                    healthRepository: repo,
                    meals: [],
                    workouts: [],
                    calendar: calendar
                )) ?? []

                return await MainActor.run {
                    let profile = athleteProfile ?? AthleteProfileStore.shared.profile
                    return makeSnapshot(
                        rangeDays: rangeDays,
                        records: records,
                        workouts: [],
                        profile: profile
                    )
                }
            } else {
                let repo = healthRepository ?? HealthKitManager.shared
                let (allMeals, profile) = await MainActor.run {
                    (MealStorageService.shared.allMeals, athleteProfile ?? AthleteProfileStore.shared.profile)
                }

                let hkWorkouts = (try? await HealthKitManager.shared.fetchRecentWorkouts(
                    days: rangeDays,
                    limit: max(60, rangeDays * 2)
                )) ?? []

                let workouts = hkWorkouts.map { hk in
                    let durationMin = hk.duration / 60.0
                    let hrType = HKQuantityType(.heartRate)
                    let hrUnit = HKUnit.count().unitDivided(by: .minute())
                    let avgHr = hk.statistics(for: hrType)?.averageQuantity()?.doubleValue(for: hrUnit)
                    let distType = HKQuantityType(.distanceWalkingRunning)
                    let distanceM = hk.totalDistance?.doubleValue(for: .meter())
                        ?? (hk.statistics(for: distType)?.sumQuantity()?.doubleValue(for: .meter()) ?? 0.0)

                    let trimp = avgHr.map {
                        TrainingLoadAndBatteryEngine.computeBanisterTRIMP(
                            durationMin: durationMin,
                            avgHr: $0,
                            restingHr: profile.restingHeartRateBaselineBpm,
                            maxHr: profile.maxHeartRateBpm
                        )
                    }
                    let ef: Double?
                    if let hr = avgHr, hr > 0, durationMin > 0, distanceM > 0 {
                        ef = round(((distanceM / durationMin) / hr) * 1000.0) / 1000.0
                    } else {
                        ef = nil
                    }
                    return PhysiologyWorkoutSample(
                        startedAt: hk.startDate,
                        durationSeconds: hk.duration,
                        trimp: trimp,
                        avgHeartRate: avgHr,
                        cardiacDriftPct: nil,
                        efficiencyFactor: ef,
                        isRunning: hk.workoutActivityType == .running
                    )
                }

                let records = try await PhysiologyHistoryBuilder.build(
                    in: interval,
                    healthRepository: repo,
                    meals: allMeals,
                    workouts: workouts,
                    calendar: calendar
                )

                return await MainActor.run {
                    makeSnapshot(
                        rangeDays: rangeDays,
                        records: records,
                        workouts: workouts,
                        profile: profile
                    )
                }
            }
        }
    }
}
