import Foundation
import HealthKit

// MARK: - Telemetry Models

public struct RawTelemetryPoint: Sendable, Codable {
    public let timestamp: Date
    public let distanceMeters: Double
    public let heartRateBpm: Double?
    public let altitudeMeters: Double?
    public let cadenceRpm: Double?

    public init(
        timestamp: Date,
        distanceMeters: Double,
        heartRateBpm: Double? = nil,
        altitudeMeters: Double? = nil,
        cadenceRpm: Double? = nil
    ) {
        self.timestamp = timestamp
        self.distanceMeters = distanceMeters
        self.heartRateBpm = heartRateBpm
        self.altitudeMeters = altitudeMeters
        self.cadenceRpm = cadenceRpm
    }
}

public struct RawIntervalLap: Sendable, Codable, Identifiable {
    public var id: String { "\(startDate.timeIntervalSince1970)-\(endDate?.timeIntervalSince1970 ?? 0)" }
    public let lapIndex: Int
    public let startDate: Date
    public let endDate: Date?
    public let durationSeconds: Double
    public let distanceMeters: Double?
    public let activeCalories: Double?

    public init(
        lapIndex: Int,
        startDate: Date,
        endDate: Date? = nil,
        durationSeconds: Double,
        distanceMeters: Double? = nil,
        activeCalories: Double? = nil
    ) {
        self.lapIndex = lapIndex
        self.startDate = startDate
        self.endDate = endDate
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.activeCalories = activeCalories
    }
}

public struct WorkoutTelemetrySeries: Sendable, Codable {
    public let workoutUUID: UUID
    public let workoutType: String
    public let startDate: Date
    public let endDate: Date
    public let totalDurationSeconds: Double
    public let totalDistanceMeters: Double?
    public let totalActiveCalories: Double?
    public let samples: [RawTelemetryPoint]
    public let intervalActivities: [RawIntervalLap]
    public let isIndoor: Bool

    public init(
        workoutUUID: UUID,
        workoutType: String,
        startDate: Date,
        endDate: Date,
        totalDurationSeconds: Double,
        totalDistanceMeters: Double?,
        totalActiveCalories: Double?,
        samples: [RawTelemetryPoint],
        intervalActivities: [RawIntervalLap],
        isIndoor: Bool
    ) {
        self.workoutUUID = workoutUUID
        self.workoutType = workoutType
        self.startDate = startDate
        self.endDate = endDate
        self.totalDurationSeconds = totalDurationSeconds
        self.totalDistanceMeters = totalDistanceMeters
        self.totalActiveCalories = totalActiveCalories
        self.samples = samples
        self.intervalActivities = intervalActivities
        self.isIndoor = isIndoor
    }
}

// MARK: - Workout Telemetry Extractor

public final class WorkoutTelemetryExtractor: @unchecked Sendable {
    public static let shared = WorkoutTelemetryExtractor()
    private let healthStore = HKHealthStore()

    private init() {}

    /// Extracts granular telemetry series for a specific HealthKit workout.
    public func extractTelemetry(for workout: HKWorkout) async throws -> WorkoutTelemetrySeries {
        let isIndoor = workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool ?? false
        let timePredicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: .strictStartDate)

        // 1. Concurrently fetch Heart Rate and Distance series samples
        async let hrSamples = fetchQuantitySamples(for: HKQuantityType(.heartRate), predicate: timePredicate)
        async let distSamples = fetchQuantitySamples(for: HKQuantityType(.distanceWalkingRunning), predicate: timePredicate)

        let heartRates = try await hrSamples
        let distances = try await distSamples

        // 2. Align samples by timestamp into a unified stream
        var telemetryPoints: [RawTelemetryPoint] = []
        var runningCumulativeDistance: Double = 0.0

        let hrUnit = HKUnit.count().unitDivided(by: .minute())
        let distanceUnit = HKUnit.meter()

        // Index HR samples for fast nearest-neighbor matching
        let sortedHR = heartRates.sorted { $0.startDate < $1.startDate }
        let sortedDist = distances.sorted { $0.startDate < $1.startDate }

        // Aggregate distance points and pair with closest heart rate
        for sample in sortedDist {
            let sampleDistance = sample.quantity.doubleValue(for: distanceUnit)
            runningCumulativeDistance += sampleDistance
            let sampleTime = sample.endDate

            // Find closest heart rate within 10 seconds window
            let hrBpm = findClosestHeartRate(at: sampleTime, in: sortedHR, unit: hrUnit, windowSeconds: 10.0)

            telemetryPoints.append(
                RawTelemetryPoint(
                    timestamp: sampleTime,
                    distanceMeters: runningCumulativeDistance,
                    heartRateBpm: hrBpm,
                    altitudeMeters: nil,
                    cadenceRpm: nil
                )
            )
        }

        // If no distance samples (e.g. Strength / Indoor non-treadmill), capture HR stream directly
        if telemetryPoints.isEmpty && !sortedHR.isEmpty {
            for sample in sortedHR {
                let bpm = sample.quantity.doubleValue(for: hrUnit)
                telemetryPoints.append(
                    RawTelemetryPoint(
                        timestamp: sample.startDate,
                        distanceMeters: 0.0,
                        heartRateBpm: bpm
                    )
                )
            }
        }

        // 3. Extract structured interval laps (HKWorkoutActivity on iOS 16+)
        var intervalLaps: [RawIntervalLap] = []
        for (index, activity) in workout.workoutActivities.enumerated() {
            let dist = activity.allStatistics[HKQuantityType(.distanceWalkingRunning)]?.sumQuantity()?.doubleValue(for: .meter())
            let energy = activity.allStatistics[HKQuantityType(.activeEnergyBurned)]?.sumQuantity()?.doubleValue(for: .kilocalorie())

            intervalLaps.append(
                RawIntervalLap(
                    lapIndex: index + 1,
                    startDate: activity.startDate,
                    endDate: activity.endDate,
                    durationSeconds: activity.duration,
                    distanceMeters: dist,
                    activeCalories: energy
                )
            )
        }

        let totalDist = workout.totalDistance?.doubleValue(for: .meter())
        let totalEnergy = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())

        var typeString = "other"
        switch workout.workoutActivityType {
        case .running: typeString = "running"
        case .cycling: typeString = "cycling"
        case .walking: typeString = "walking"
        case .traditionalStrengthTraining, .functionalStrengthTraining: typeString = "strength"
        case .highIntensityIntervalTraining: typeString = "hiit"
        case .swimming: typeString = "swimming"
        default: typeString = "other"
        }

        return WorkoutTelemetrySeries(
            workoutUUID: workout.uuid,
            workoutType: typeString,
            startDate: workout.startDate,
            endDate: workout.endDate,
            totalDurationSeconds: workout.duration,
            totalDistanceMeters: totalDist,
            totalActiveCalories: totalEnergy,
            samples: telemetryPoints,
            intervalActivities: intervalLaps,
            isIndoor: isIndoor
        )
    }

    // MARK: - Private Query Helpers

    private func fetchQuantitySamples(for type: HKQuantityType, predicate: NSPredicate) async throws -> [HKQuantitySample] {
        try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (results as? [HKQuantitySample]) ?? [])
            }
            healthStore.execute(query)
        }
    }

    private func findClosestHeartRate(
        at targetTime: Date,
        in samples: [HKQuantitySample],
        unit: HKUnit,
        windowSeconds: TimeInterval
    ) -> Double? {
        guard !samples.isEmpty else { return nil }

        var closestSample: HKQuantitySample?
        var minDifference: TimeInterval = .infinity

        for sample in samples {
            let diff = abs(sample.startDate.timeIntervalSince(targetTime))
            if diff < minDifference {
                minDifference = diff
                closestSample = sample
            }
            if sample.startDate > targetTime && diff > minDifference {
                break
            }
        }

        if minDifference <= windowSeconds, let match = closestSample {
            return match.quantity.doubleValue(for: unit)
        }
        return nil
    }
}
