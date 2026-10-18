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
            HKCategoryType(.sleepAnalysis),
            HKWorkoutType.workoutType()
        ]

        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
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

    // MARK: - 3. Workouts (Today's Most Recent)
    public func fetchLatestWorkoutToday() async throws -> WorkoutLog? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let workout = (results as? [HKWorkout])?.first else {
                    continuation.resume(returning: nil)
                    return
                }

                let durationMin = round((workout.duration / 60.0) * 10) / 10
                let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
                let distance = workout.totalDistance?.doubleValue(for: .meter())
                let distanceKm = distance != nil ? round((distance! / 1000.0) * 100) / 100 : nil

                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

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

                let log = WorkoutLog(
                    type: workoutTypeName,
                    durationMin: durationMin,
                    avgHeartRate: nil, // Can be augmented via HKStatisticsCollection
                    maxHeartRate: nil,
                    activeCalories: calories != nil ? round(calories!) : nil,
                    distanceKm: distanceKm,
                    startedAt: isoFormatter.string(from: workout.startDate)
                )

                continuation.resume(returning: log)
            }
            self.healthStore.execute(query)
        }
    }

    // MARK: - Private Helpers
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
