import Foundation
import HealthKit
import CoreLocation

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

    /// Filters GPS route locations according to realistic horizontal and vertical accuracy thresholds.
    /// Rejects negative accuracy values (invalid signal) and excessive drift.
    public static func filterLocations(
        _ locations: [CLLocation],
        maxHorizontalAccuracy: CLLocationAccuracy = 50.0,
        maxVerticalAccuracy: CLLocationAccuracy = 35.0
    ) -> [CLLocation] {
        return locations.filter { loc in
            loc.horizontalAccuracy >= 0 &&
            loc.horizontalAccuracy <= maxHorizontalAccuracy &&
            loc.verticalAccuracy >= 0 &&
            loc.verticalAccuracy <= maxVerticalAccuracy
        }
    }

    /// Finds the closest GPS altitude within a time tolerance window.
    public static func findClosestAltitude(
        at targetTime: Date,
        in locations: [CLLocation],
        windowSeconds: TimeInterval = 15.0
    ) -> Double? {
        guard !locations.isEmpty else { return nil }

        var closestLoc: CLLocation?
        var minDifference: TimeInterval = .infinity

        for loc in locations {
            let diff = abs(loc.timestamp.timeIntervalSince(targetTime))
            if diff < minDifference {
                minDifference = diff
                closestLoc = loc
            }
            if loc.timestamp > targetTime && diff > minDifference {
                break
            }
        }

        if minDifference <= windowSeconds, let match = closestLoc {
            return match.altitude
        }
        return nil
    }

    /// Extracts granular telemetry series for a specific HealthKit workout.
    public func extractTelemetry(for workout: HKWorkout) async throws -> WorkoutTelemetrySeries {
        let isIndoor = workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool ?? false
        let timePredicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: .strictStartDate)

        // 1. Concurrently fetch Heart Rate, Distance series samples, and Route locations
        async let hrSamplesTask = fetchWorkoutQuantitySamples(for: HKQuantityType(.heartRate), workout: workout, timePredicate: timePredicate)
        async let distSamplesTask = fetchWorkoutQuantitySamples(for: HKQuantityType(.distanceWalkingRunning), workout: workout, timePredicate: timePredicate)
        async let routeLocationsTask = (try? await fetchWorkoutRouteLocations(for: workout)) ?? []

        let heartRates = try await hrSamplesTask
        let distances = try await distSamplesTask
        let rawLocations = await routeLocationsTask
        let validLocations = WorkoutTelemetryExtractor.filterLocations(rawLocations)

        let hrUnit = HKUnit.count().unitDivided(by: .minute())
        let distanceUnit = HKUnit.meter()

        // 2. Filter out aggregate summary samples (e.g. multi-minute summary batches or non-granular chunks)
        // Granular running telemetry samples are small increments (typically < 300m and duration <= 60s)
        var granularDistances: [HKQuantitySample] = []
        for sample in distances {
            let dur = sample.endDate.timeIntervalSince(sample.startDate)
            let dist = sample.quantity.doubleValue(for: distanceUnit)
            if dur > 60.0 || dist > 300.0 {
                continue // Ignore macro summary samples that cause instant distance jumps
            }
            granularDistances.append(sample)
        }
        let activeDistances = granularDistances.isEmpty ? distances : granularDistances

        // 3. Sort strictly by endDate to ensure chronological progression
        let sortedHR = heartRates.sorted { $0.startDate < $1.startDate }
        let sortedDist = activeDistances.sorted { $0.endDate < $1.endDate }

        // 4. Ground-truth calibration against authoritative workout.totalDistance
        let authoritativeTotalMeters = workout.totalDistance?.doubleValue(for: distanceUnit)
        let rawSumMeters = sortedDist.reduce(0.0) { $0 + $1.quantity.doubleValue(for: distanceUnit) }
        let distanceScale: Double = (authoritativeTotalMeters != nil && authoritativeTotalMeters! > 0 && rawSumMeters > 0)
            ? (authoritativeTotalMeters! / rawSumMeters)
            : 1.0

        var telemetryPoints: [RawTelemetryPoint] = []
        var runningCumulativeDistance: Double = 0.0

        // Explicitly anchor at workout start (t0) with distance 0.0m so the first interval duration
        // is never omitted from split calculations.
        if let firstSample = sortedDist.first {
            let startAnchorTime = min(workout.startDate, firstSample.startDate)
            let initialHR = findClosestHeartRate(at: startAnchorTime, in: sortedHR, unit: hrUnit, windowSeconds: 10.0)
            let initialAlt = WorkoutTelemetryExtractor.findClosestAltitude(at: startAnchorTime, in: validLocations, windowSeconds: 15.0)

            telemetryPoints.append(
                RawTelemetryPoint(
                    timestamp: startAnchorTime,
                    distanceMeters: 0.0,
                    heartRateBpm: initialHR,
                    altitudeMeters: initialAlt,
                    cadenceRpm: nil
                )
            )
        }

        for sample in sortedDist {
            let sampleDistance = sample.quantity.doubleValue(for: distanceUnit) * distanceScale
            runningCumulativeDistance += sampleDistance
            let sampleTime = sample.endDate

            // Find closest heart rate within 10 seconds window
            let hrBpm = findClosestHeartRate(at: sampleTime, in: sortedHR, unit: hrUnit, windowSeconds: 10.0)
            let alt = WorkoutTelemetryExtractor.findClosestAltitude(at: sampleTime, in: validLocations, windowSeconds: 15.0)

            telemetryPoints.append(
                RawTelemetryPoint(
                    timestamp: sampleTime,
                    distanceMeters: runningCumulativeDistance,
                    heartRateBpm: hrBpm,
                    altitudeMeters: alt,
                    cadenceRpm: nil
                )
            )
        }

        // If no distance samples (e.g. Strength / Indoor non-treadmill), capture HR stream directly
        if telemetryPoints.isEmpty && !sortedHR.isEmpty {
            let duration = max(1.0, workout.duration)
            for sample in sortedHR {
                let bpm = sample.quantity.doubleValue(for: hrUnit)
                let elapsed = sample.startDate.timeIntervalSince(workout.startDate)
                let simulatedDist = (authoritativeTotalMeters ?? 0.0) * min(1.0, max(0.0, elapsed / duration))
                telemetryPoints.append(
                    RawTelemetryPoint(
                        timestamp: sample.startDate,
                        distanceMeters: simulatedDist,
                        heartRateBpm: bpm
                    )
                )
            }
        }

        // 5. Extract structured interval laps (HKWorkoutActivity on iOS 16+)
        var intervalLaps: [RawIntervalLap] = []
        for (index, activity) in workout.workoutActivities.enumerated() {
            let dist = activity.allStatistics[HKQuantityType(.distanceWalkingRunning)]?.sumQuantity()?.doubleValue(for: .meter())
                ?? activity.allStatistics[HKQuantityType(.distanceCycling)]?.sumQuantity()?.doubleValue(for: .meter())
                ?? activity.allStatistics[HKQuantityType(.distanceSwimming)]?.sumQuantity()?.doubleValue(for: .meter())
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

        // Fallback: If workoutActivities is empty, extract from HKWorkoutEvent lap events without dropping laps
        if intervalLaps.isEmpty, let events = workout.workoutEvents {
            let lapEvents = events.filter { $0.type == .lap }
            for (index, event) in lapEvents.enumerated() {
                let duration = event.dateInterval.duration
                intervalLaps.append(
                    RawIntervalLap(
                        lapIndex: index + 1,
                        startDate: event.dateInterval.start,
                        endDate: event.dateInterval.end,
                        durationSeconds: duration > 0 ? duration : (workout.duration / Double(max(1, lapEvents.count))),
                        distanceMeters: nil,
                        activeCalories: nil
                    )
                )
            }
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

    // MARK: - Route Query Helpers

    /// Fetches all GPS route locations associated with an HKWorkout.
    public func fetchWorkoutRouteLocations(for workout: HKWorkout) async throws -> [CLLocation] {
        let routePredicate = HKQuery.predicateForObjects(from: workout)
        let routes = (try? await fetchWorkoutRoutes(predicate: routePredicate)) ?? []
        guard let firstRoute = routes.first else { return [] }

        return (try? await fetchRouteLocations(for: firstRoute)) ?? []
    }

    private func fetchWorkoutRoutes(predicate: NSPredicate) async throws -> [HKWorkoutRoute] {
        try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: HKSeriesType.workoutRoute(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (results as? [HKWorkoutRoute]) ?? [])
            }
            healthStore.execute(query)
        }
    }

    private func fetchRouteLocations(for route: HKWorkoutRoute) async throws -> [CLLocation] {
        try await withCheckedThrowingContinuation { continuation in
            var accumulatedLocations: [CLLocation] = []
            let query = HKWorkoutRouteQuery(route: route) { _, locationsOrNil, done, errorOrNil in
                if let error = errorOrNil {
                    continuation.resume(throwing: error)
                    return
                }
                if let locs = locationsOrNil {
                    accumulatedLocations.append(contentsOf: locs)
                }
                if done {
                    continuation.resume(returning: accumulatedLocations)
                }
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Private Query Helpers

    private func fetchWorkoutQuantitySamples(
        for type: HKQuantityType,
        workout: HKWorkout,
        timePredicate: NSPredicate
    ) async throws -> [HKQuantitySample] {
        // 1. Priority 1: Samples explicitly attached to this HKWorkout
        let workoutPredicate = HKQuery.predicateForObjects(from: workout)
        let workoutSamples = (try? await fetchQuantitySamples(for: type, predicate: workoutPredicate)) ?? []
        if !workoutSamples.isEmpty {
            return workoutSamples
        }

        // 2. Priority 2: Filter strictly by the workout's creator device (Apple Watch)
        let sourcePredicate = HKQuery.predicateForObjects(from: [workout.sourceRevision.source])
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [timePredicate, sourcePredicate])
        let sourceSamples = (try? await fetchQuantitySamples(for: type, predicate: compoundPredicate)) ?? []
        if !sourceSamples.isEmpty {
            return sourceSamples
        }

        // 3. Fallback: time predicate alone
        return (try? await fetchQuantitySamples(for: type, predicate: timePredicate)) ?? []
    }

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
