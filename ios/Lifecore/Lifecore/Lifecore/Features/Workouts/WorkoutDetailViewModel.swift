import Combine
import Foundation
import HealthKit

// MARK: - Sport Kind

public enum WorkoutSportKind: String, Sendable, CaseIterable {
    case running
    case cycling
    case strength
    case hiit
    case walking
    case other

    public static func from(activityType: HKWorkoutActivityType) -> WorkoutSportKind {
        switch activityType {
        case .running:
            return .running
        case .cycling:
            return .cycling
        case .traditionalStrengthTraining, .functionalStrengthTraining:
            return .strength
        case .highIntensityIntervalTraining:
            return .hiit
        case .walking:
            return .walking
        default:
            return .other
        }
    }

    public var titleUk: String {
        switch self {
        case .running: return "Біг"
        case .cycling: return "Велосипед"
        case .strength: return "Силове тренування"
        case .hiit: return "HIIT"
        case .walking: return "Прогулянка"
        case .other: return "Тренування"
        }
    }

    public var icon: String {
        switch self {
        case .running: return "figure.run"
        case .cycling: return "figure.outdoor.cycle"
        case .strength: return "figure.strengthtraining.traditional"
        case .hiit: return "figure.hiit"
        case .walking: return "figure.walk"
        case .other: return "figure.mixed.cardio"
        }
    }
}

// MARK: - Workout Session Summary

public struct WorkoutSessionSummary: Sendable, Identifiable {
    public var id: UUID { workoutUUID }
    public let workoutUUID: UUID
    public let sportKind: WorkoutSportKind
    public let activityType: HKWorkoutActivityType
    public let titleUk: String
    public let startDate: Date
    public let durationSeconds: Double
    public let durationMinutes: Double
    public let distanceMeters: Double?
    public let distanceKm: Double?
    public let caloriesKcal: Double?
    public let avgHeartRate: Double?
    public let maxHeartRate: Double?
    public let elevationGainMeters: Double?
    public let banisterTrimp: Double?

    public init(
        workoutUUID: UUID,
        sportKind: WorkoutSportKind,
        activityType: HKWorkoutActivityType,
        titleUk: String,
        startDate: Date,
        durationSeconds: Double,
        distanceMeters: Double? = nil,
        caloriesKcal: Double? = nil,
        avgHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        elevationGainMeters: Double? = nil,
        banisterTrimp: Double? = nil
    ) {
        self.workoutUUID = workoutUUID
        self.sportKind = sportKind
        self.activityType = activityType
        self.titleUk = titleUk
        self.startDate = startDate
        self.durationSeconds = durationSeconds
        self.durationMinutes = durationSeconds / 60.0
        self.distanceMeters = distanceMeters
        self.distanceKm = distanceMeters.map { $0 / 1000.0 }
        self.caloriesKcal = caloriesKcal
        self.avgHeartRate = avgHeartRate
        self.maxHeartRate = maxHeartRate
        self.elevationGainMeters = elevationGainMeters
        self.banisterTrimp = banisterTrimp
    }

    public static func from(
        workout: HKWorkout,
        elevationGainMeters: Double? = nil,
        athleteProfile: AthleteProfile? = nil
    ) -> WorkoutSessionSummary {
        let resolvedProfile = athleteProfile ?? AthleteProfileStore.shared.profile
        let sport = WorkoutSportKind.from(activityType: workout.workoutActivityType)
        let dist = workout.totalDistance?.doubleValue(for: .meter())
        let cals = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
        let avgHr = workout.statistics(for: HKQuantityType(.heartRate))?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        let maxHrStat = workout.statistics(for: HKQuantityType(.heartRate))?.maximumQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))

        let durationMin = workout.duration / 60.0
        let trimp: Double?
        if let hr = avgHr, hr > 0 {
            trimp = TrainingLoadAndBatteryEngine.computeBanisterTRIMP(
                durationMin: durationMin,
                avgHr: hr,
                restingHr: resolvedProfile.restingHeartRateBaselineBpm,
                maxHr: resolvedProfile.maxHeartRateBpm
            )
        } else {
            trimp = nil
        }

        return WorkoutSessionSummary(
            workoutUUID: workout.uuid,
            sportKind: sport,
            activityType: workout.workoutActivityType,
            titleUk: sport.titleUk,
            startDate: workout.startDate,
            durationSeconds: workout.duration,
            distanceMeters: dist,
            caloriesKcal: cals,
            avgHeartRate: avgHr,
            maxHeartRate: maxHrStat,
            elevationGainMeters: elevationGainMeters,
            banisterTrimp: trimp
        )
    }
}

// MARK: - Sport Presentation Models

public struct RunningPresentationMetrics: Sendable {
    public let paceMinKm: Double
    public let formattedPace: String
    public let splits: [SplitMetric]
    public let laps: [LapIntervalMetric]
    public let efficiencyFactor: Double?
    public let aerobicDecouplingPct: Double?
    public let elevationGainMeters: Double?
    public let benchmarkDelta: BenchmarkDelta?

    public init(
        paceMinKm: Double,
        formattedPace: String,
        splits: [SplitMetric],
        laps: [LapIntervalMetric],
        efficiencyFactor: Double?,
        aerobicDecouplingPct: Double?,
        elevationGainMeters: Double?,
        benchmarkDelta: BenchmarkDelta?
    ) {
        self.paceMinKm = paceMinKm
        self.formattedPace = formattedPace
        self.splits = splits
        self.laps = laps
        self.efficiencyFactor = efficiencyFactor
        self.aerobicDecouplingPct = aerobicDecouplingPct
        self.elevationGainMeters = elevationGainMeters
        self.benchmarkDelta = benchmarkDelta
    }
}

public struct CyclingPresentationMetrics: Sendable {
    public let speedKmH: Double
    public let formattedSpeed: String
    public let distanceKm: Double
    public let formattedDistance: String
    public let durationMin: Double
    public let formattedDuration: String
    public let avgHeartRate: Double?
    public let maxHeartRate: Double?
    public let elevationGainMeters: Double?

    public init(
        speedKmH: Double,
        formattedSpeed: String,
        distanceKm: Double,
        formattedDistance: String,
        durationMin: Double,
        formattedDuration: String,
        avgHeartRate: Double?,
        maxHeartRate: Double?,
        elevationGainMeters: Double?
    ) {
        self.speedKmH = speedKmH
        self.formattedSpeed = formattedSpeed
        self.distanceKm = distanceKm
        self.formattedDistance = formattedDistance
        self.durationMin = durationMin
        self.formattedDuration = formattedDuration
        self.avgHeartRate = avgHeartRate
        self.maxHeartRate = maxHeartRate
        self.elevationGainMeters = elevationGainMeters
    }
}

public struct StrengthPresentationMetrics: Sendable {
    public let durationMin: Double
    public let formattedDuration: String
    public let avgHeartRate: Double?
    public let maxHeartRate: Double?
    public let banisterTrimp: Double?
    public let effortLevelUk: String
    public let caloriesKcal: Double?

    public init(
        durationMin: Double,
        formattedDuration: String,
        avgHeartRate: Double?,
        maxHeartRate: Double?,
        banisterTrimp: Double?,
        effortLevelUk: String,
        caloriesKcal: Double?
    ) {
        self.durationMin = durationMin
        self.formattedDuration = formattedDuration
        self.avgHeartRate = avgHeartRate
        self.maxHeartRate = maxHeartRate
        self.banisterTrimp = banisterTrimp
        self.effortLevelUk = effortLevelUk
        self.caloriesKcal = caloriesKcal
    }
}

// MARK: - Workout Detail View Model

@MainActor
public final class WorkoutDetailViewModel: ObservableObject {

    public let workout: HKWorkout

    @Published public private(set) var summary: WorkoutSessionSummary
    @Published public private(set) var series: WorkoutTelemetrySeries?
    @Published public private(set) var analysis: WorkoutAnalysisResult?
    @Published public private(set) var recoveryContext: RecentRecoveryContext?
    @Published public private(set) var localEntity: WorkoutAnalysisEntity?
    @Published public private(set) var isLoading: Bool = true
    @Published public private(set) var errorMessage: String?

    public typealias TelemetryLoader = @Sendable (HKWorkout) async throws -> WorkoutTelemetrySeries
    public typealias BenchmarkLoader = @Sendable (HKWorkout) async throws -> [(distanceKm: Double, paceMinKm: Double, avgHr: Double?, ef: Double?)]
    public typealias RecoveryLoader = @Sendable (Date) async -> RecentRecoveryContext?

    private let telemetryLoader: TelemetryLoader?
    private let benchmarkLoader: BenchmarkLoader?
    private let recoveryLoader: RecoveryLoader?

    public init(
        workout: HKWorkout,
        series: WorkoutTelemetrySeries? = nil,
        analysis: WorkoutAnalysisResult? = nil,
        recoveryContext: RecentRecoveryContext? = nil,
        telemetryLoader: TelemetryLoader? = nil,
        benchmarkLoader: BenchmarkLoader? = nil,
        recoveryLoader: RecoveryLoader? = nil
    ) {
        self.workout = workout
        self.series = series
        self.analysis = analysis
        self.recoveryContext = recoveryContext
        self.telemetryLoader = telemetryLoader
        self.benchmarkLoader = benchmarkLoader
        self.recoveryLoader = recoveryLoader

        self.summary = WorkoutSessionSummary.from(
            workout: workout,
            elevationGainMeters: analysis?.elevationGainMeters
        )

        if series != nil || analysis != nil {
            self.isLoading = false
        }
    }

    // MARK: - Sport Kind & Presentation Sections

    public var sportKind: WorkoutSportKind { summary.sportKind }
    public var isRunning: Bool { sportKind == .running }
    public var isCycling: Bool { sportKind == .cycling }
    public var isStrengthOrOther: Bool { !isRunning && !isCycling }

    public var runningPresentation: RunningPresentationMetrics? {
        guard isRunning else { return nil }
        let pace = analysis?.avgPaceMinKm ?? (summary.distanceKm.flatMap { $0 > 0 ? (summary.durationMinutes / $0) : nil } ?? 0.0)
        let formattedPace = analysis?.formattedAvgPace ?? Self.formatPaceString(paceMinKm: pace)
        return RunningPresentationMetrics(
            paceMinKm: pace,
            formattedPace: formattedPace,
            splits: analysis?.splits ?? [],
            laps: analysis?.laps ?? [],
            efficiencyFactor: analysis?.efficiencyFactor,
            aerobicDecouplingPct: analysis?.aerobicDecouplingPct,
            elevationGainMeters: analysis?.elevationGainMeters ?? summary.elevationGainMeters,
            benchmarkDelta: analysis?.benchmarkDelta
        )
    }

    public var cyclingPresentation: CyclingPresentationMetrics? {
        guard isCycling else { return nil }
        let distKm = summary.distanceKm ?? (analysis?.distanceKm ?? 0.0)
        let durHours = summary.durationSeconds / 3600.0
        let speedKmH = durHours > 0 ? (distKm / durHours) : 0.0
        return CyclingPresentationMetrics(
            speedKmH: speedKmH,
            formattedSpeed: String(format: "%.1f км/год", speedKmH),
            distanceKm: distKm,
            formattedDistance: String(format: "%.2f км", distKm),
            durationMin: summary.durationMinutes,
            formattedDuration: String(format: "%.0f хв", summary.durationMinutes),
            avgHeartRate: summary.avgHeartRate ?? analysis?.avgHeartRate,
            maxHeartRate: summary.maxHeartRate ?? analysis?.maxHeartRate,
            elevationGainMeters: analysis?.elevationGainMeters ?? summary.elevationGainMeters
        )
    }

    public var strengthPresentation: StrengthPresentationMetrics? {
        guard isStrengthOrOther else { return nil }
        let trimp = summary.banisterTrimp ?? 0.0
        let effortLevelUk: String = {
            if trimp >= 80 { return "Високе" }
            if trimp >= 45 { return "Помірне" }
            return "Легке"
        }()
        return StrengthPresentationMetrics(
            durationMin: summary.durationMinutes,
            formattedDuration: String(format: "%.0f хв", summary.durationMinutes),
            avgHeartRate: summary.avgHeartRate ?? analysis?.avgHeartRate,
            maxHeartRate: summary.maxHeartRate ?? analysis?.maxHeartRate,
            banisterTrimp: trimp > 0 ? trimp : nil,
            effortLevelUk: effortLevelUk,
            caloriesKcal: summary.caloriesKcal
        )
    }

    public var streamSignalNoteUk: String {
        switch sportKind {
        case .running:
            if summary.elevationGainMeters == nil && analysis?.elevationGainMeters == nil {
                return "Дані висоти відсутні (тренування в приміщенні або без GPS)."
            }
            return "Усі ключові сигнали бігу (темп, пульс, спліти) зафіксовано."
        case .cycling:
            if summary.elevationGainMeters == nil && analysis?.elevationGainMeters == nil {
                return "Швидкість та ЧСС зафіксовано. Перепад висоти не вимірювався. Бігові спліти не застосовуються."
            }
            return "Швидкість, дистанція та набір висоти зафіксовані. Бігові спліти не застосовуються."
        case .strength:
            if summary.avgHeartRate != nil {
                return "ЧСС та Banister TRIMP зафіксовано. Біговий темп, спліти та висота не застосовуються для силових вправ."
            } else {
                return "Дані ЧСС відсутні для силових вправ. Датчик серцевого ритму не передавав показників."
            }
        case .hiit:
            if summary.avgHeartRate != nil {
                return "Пульсові піки зафіксовано. Кардіоваскулярний дрейф не розраховується для анаеробних інтервалів."
            } else {
                return "Дані ЧСС відсутні для цієї інтервальної сесії."
            }
        case .walking:
            return "Дистанція та кроки зафіксовані. Спліти та аеробне роз'єднання відключені для ходьби."
        case .other:
            if summary.avgHeartRate != nil {
                return "Тривалість та ЧСС зафіксовано. Специфічні бігові метрики не застосовуються."
            } else {
                return "Зафіксовано лише тривалість сесії. Біометричні потоки відсутні."
            }
        }
    }

    // MARK: - Telemetry Extraction & Analysis

    public func loadWorkoutTelemetry() async {
        isLoading = true
        errorMessage = nil

        do {
            if telemetryLoader == nil && !AppEnvironment.current.isFixtureMode {
                try await HealthKitManager.shared.requestAuthorization()
            }

            let extractedSeries: WorkoutTelemetrySeries
            if let customLoader = telemetryLoader {
                extractedSeries = try await customLoader(workout)
            } else if AppEnvironment.current.isFixtureMode {
                extractedSeries = WorkoutTelemetrySeries(
                    workoutUUID: workout.uuid,
                    workoutType: summary.sportKind.rawValue,
                    startDate: workout.startDate,
                    endDate: workout.endDate,
                    totalDurationSeconds: workout.duration,
                    totalDistanceMeters: summary.distanceKm.map { $0 * 1000.0 },
                    totalActiveCalories: summary.caloriesKcal,
                    samples: [],
                    intervalActivities: [],
                    isIndoor: false
                )
            } else {
                extractedSeries = try await WorkoutTelemetryExtractor.shared.extractTelemetry(for: workout)
            }
            self.series = extractedSeries

            let benchmarks: [(distanceKm: Double, paceMinKm: Double, avgHr: Double?, ef: Double?)]
            if let customBench = benchmarkLoader {
                benchmarks = try await customBench(workout)
            } else if AppEnvironment.current.isFixtureMode {
                benchmarks = []
            } else {
                benchmarks = (try? await HealthKitManager.shared.fetchHistoricalSimilarWorkouts(to: workout)) ?? []
            }

            let recovery: RecentRecoveryContext?
            if let customRec = recoveryLoader {
                recovery = await customRec(workout.startDate)
            } else if AppEnvironment.current.isFixtureMode {
                recovery = nil
            } else {
                recovery = await HealthKitManager.shared.fetchRecentRecoveryContext(for: workout.startDate)
            }
            self.recoveryContext = recovery

            let analysisResult = WorkoutMathEngine.analyze(
                series: extractedSeries,
                historicalWorkouts: benchmarks
            )
            self.analysis = analysisResult

            self.summary = WorkoutSessionSummary.from(
                workout: workout,
                elevationGainMeters: analysisResult.elevationGainMeters
            )

            let distanceM = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
            let cached = WorkoutStorageService.fetchAnalysis(for: workout.uuid)
            self.localEntity = cached

            let entity = WorkoutStorageService.saveOrUpdate(
                workoutUUID: workout.uuid,
                workoutType: summary.titleUk,
                startedAt: workout.startDate,
                distanceMeters: distanceM,
                durationSeconds: workout.duration,
                avgPaceSecPerKm: analysisResult.avgPaceMinKm * 60.0,
                avgHeartRate: analysisResult.avgHeartRate,
                maxHeartRate: analysisResult.maxHeartRate,
                elevationGainMeters: analysisResult.elevationGainMeters,
                efficiencyFactor: analysisResult.efficiencyFactor,
                cardiacDriftPercentage: analysisResult.aerobicDecouplingPct,
                splits: analysisResult.splits,
                laps: analysisResult.laps,
                aiCoachReport: cached?.aiCoachReport
            )
            self.localEntity = entity

        } catch {
            self.errorMessage = "Помилка читання телеметрії: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private static func formatPaceString(paceMinKm: Double) -> String {
        guard paceMinKm.isFinite && paceMinKm > 0 else { return "--:--/km" }
        let totalSeconds = max(0, Int(round(paceMinKm * 60.0)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d/km", minutes, seconds)
    }
}
