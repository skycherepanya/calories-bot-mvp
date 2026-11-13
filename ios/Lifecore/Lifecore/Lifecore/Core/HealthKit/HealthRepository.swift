import Foundation
import HealthKit

// MARK: - Health Repository Protocol

public protocol HealthRepository: Sendable {
    func weightHistory(in interval: DateInterval) async throws -> [Observation<Double>]
    func sleepEpisode(endingBefore date: Date) async throws -> SleepEpisode?
}

// MARK: - Sleep Domain Models

public enum SleepStage: String, Codable, Sendable, CaseIterable {
    case awake
    case rem
    case core
    case deep
    case unspecified
}

public struct SleepStageSegment: Sendable, Equatable, Codable {
    public let interval: DateInterval
    public let stage: SleepStage
    public let source: ObservationSource

    public init(interval: DateInterval, stage: SleepStage, source: ObservationSource = .healthKit) {
        self.interval = interval
        self.stage = stage
        self.source = source
    }
}

public enum HRVMethod: String, Codable, Sendable, CaseIterable {
    case sdnn = "sdnn"
    case rmssd = "rmssd"
}

public struct SleepEpisode: Sendable, Equatable {
    public let interval: DateInterval
    public let stages: [SleepStageSegment]
    public let totalSleepDurationSeconds: TimeInterval
    public let hrv: Observation<Double>?
    public let hrvMethod: HRVMethod?
    public let restingHeartRate: Observation<Double>?
    public let wristTemperatureDeltaCelsius: Observation<Double>?
    public let respiratoryRate: Observation<Double>?
    public let oxygenSaturation: Observation<Double>?

    public init(
        interval: DateInterval,
        stages: [SleepStageSegment],
        totalSleepDurationSeconds: TimeInterval,
        hrv: Observation<Double>? = nil,
        hrvMethod: HRVMethod? = nil,
        restingHeartRate: Observation<Double>? = nil,
        wristTemperatureDeltaCelsius: Observation<Double>? = nil,
        respiratoryRate: Observation<Double>? = nil,
        oxygenSaturation: Observation<Double>? = nil
    ) {
        self.interval = interval
        self.stages = stages
        self.totalSleepDurationSeconds = totalSleepDurationSeconds
        self.hrv = hrv
        self.hrvMethod = hrvMethod
        self.restingHeartRate = restingHeartRate
        self.wristTemperatureDeltaCelsius = wristTemperatureDeltaCelsius
        self.respiratoryRate = respiratoryRate
        self.oxygenSaturation = oxygenSaturation
    }

    // MARK: - Stage Durations
    public var deepDurationSeconds: TimeInterval {
        stages.filter { $0.stage == .deep }.reduce(0) { $0 + $1.interval.duration }
    }

    public var remDurationSeconds: TimeInterval {
        stages.filter { $0.stage == .rem }.reduce(0) { $0 + $1.interval.duration }
    }

    public var coreDurationSeconds: TimeInterval {
        stages.filter { $0.stage == .core }.reduce(0) { $0 + $1.interval.duration }
    }

    public var awakeDurationSeconds: TimeInterval {
        stages.filter { $0.stage == .awake }.reduce(0) { $0 + $1.interval.duration }
    }

    public var unspecifiedDurationSeconds: TimeInterval {
        stages.filter { $0.stage == .unspecified }.reduce(0) { $0 + $1.interval.duration }
    }

    public var totalSleepHours: Double {
        totalSleepDurationSeconds / 3600.0
    }

    public var sleepEfficiencyPct: Double? {
        let totalInBed = totalSleepDurationSeconds + awakeDurationSeconds
        guard totalInBed > 0 else { return nil }
        return min(100.0, round((totalSleepDurationSeconds / totalInBed) * 1000.0) / 10.0)
    }
}

// MARK: - Fixture Health Repository

public final class FixtureHealthRepository: HealthRepository, @unchecked Sendable {
    public var weightObservations: [Observation<Double>]
    public var sleepEpisodes: [SleepEpisode]
    public var isHealthKitAvailable: Bool
    public var errorToThrow: Error?

    public init(
        weightObservations: [Observation<Double>] = [],
        sleepEpisodes: [SleepEpisode] = [],
        isHealthKitAvailable: Bool = true,
        errorToThrow: Error? = nil
    ) {
        self.weightObservations = weightObservations
        self.sleepEpisodes = sleepEpisodes
        self.isHealthKitAvailable = isHealthKitAvailable
        self.errorToThrow = errorToThrow
    }

    public func weightHistory(in interval: DateInterval) async throws -> [Observation<Double>] {
        if let error = errorToThrow {
            throw error
        }
        guard isHealthKitAvailable else {
            throw HealthKitError.notAvailableOnDevice
        }

        return weightObservations.filter { obs in
            guard let date = obs.observedAt else { return false }
            return (interval.start <= date && date <= interval.end)
        }.sorted { ($0.observedAt ?? Date.distantPast) < ($1.observedAt ?? Date.distantPast) }
    }

    public func sleepEpisode(endingBefore date: Date) async throws -> SleepEpisode? {
        if let error = errorToThrow {
            throw error
        }
        guard isHealthKitAvailable else {
            throw HealthKitError.notAvailableOnDevice
        }

        return sleepEpisodes
            .filter { $0.interval.end <= date }
            .sorted { $0.interval.end > $1.interval.end }
            .first
    }
}

// MARK: - Live HealthKit Repository

public final class HealthKitRepository: HealthRepository, Sendable {
    private let healthStore: HKHealthStore
    private let sleepReader: SleepEpisodeReader

    public init(
        healthStore: HKHealthStore = HKHealthStore(),
        sleepReader: SleepEpisodeReader? = nil
    ) {
        self.healthStore = healthStore
        self.sleepReader = sleepReader ?? SleepEpisodeReader(healthStore: healthStore)
    }

    public var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    public func weightHistory(in interval: DateInterval) async throws -> [Observation<Double>] {
        guard isAvailable else {
            throw HealthKitError.notAvailableOnDevice
        }

        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: .strictStartDate)
        let weightType = HKQuantityType(.bodyMass)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: weightType,
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

                let kgUnit = HKUnit.gramUnit(with: .kilo)
                let observations = samples.map { sample in
                    let kg = round(sample.quantity.doubleValue(for: kgUnit) * 100) / 100
                    return Observation<Double>(
                        value: kg,
                        unit: "kg",
                        observedAt: sample.startDate,
                        source: .healthKit,
                        quality: .measured,
                        observedCount: 1,
                        expectedCount: 1
                    )
                }
                continuation.resume(returning: observations)
            }
            healthStore.execute(query)
        }
    }

    public func sleepEpisode(endingBefore date: Date) async throws -> SleepEpisode? {
        guard isAvailable else {
            throw HealthKitError.notAvailableOnDevice
        }
        return try await sleepReader.readSleepEpisode(endingBefore: date)
    }
}
