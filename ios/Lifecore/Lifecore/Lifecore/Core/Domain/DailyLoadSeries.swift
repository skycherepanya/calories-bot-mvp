import Foundation

// MARK: - Daily Load Series Model (Audit F02)

public struct DailyLoadSeries: Codable, Sendable, Equatable {
    public let date: Date
    public let trimpLoad: Double
    public let isKnownRestDay: Bool
    public let isObserved: Bool

    public init(
        date: Date,
        trimpLoad: Double,
        isKnownRestDay: Bool = false,
        isObserved: Bool = true
    ) {
        self.date = date
        self.trimpLoad = isKnownRestDay ? 0.0 : max(0.0, trimpLoad)
        self.isKnownRestDay = isKnownRestDay
        self.isObserved = isObserved
    }

    /// Factory for an explicitly recorded rest day (TRIMP = 0, observed = true).
    public static func restDay(date: Date) -> DailyLoadSeries {
        DailyLoadSeries(date: date, trimpLoad: 0.0, isKnownRestDay: true, isObserved: true)
    }

    /// Factory for an observed training day.
    public static func observed(date: Date, trimpLoad: Double) -> DailyLoadSeries {
        DailyLoadSeries(date: date, trimpLoad: trimpLoad, isKnownRestDay: false, isObserved: true)
    }

    /// Factory for an unobserved/missing day.
    public static func unobserved(date: Date) -> DailyLoadSeries {
        DailyLoadSeries(date: date, trimpLoad: 0.0, isKnownRestDay: false, isObserved: false)
    }
}

public typealias DailyLoadEntry = DailyLoadSeries

// MARK: - Workload Coverage & Confidence

public enum WorkloadConfidence: String, Codable, Sendable {
    case fullConfidence = "fullConfidence" // >= 28 observed consecutive days
    case provisional = "provisional"       // < 28 observed days
    case insufficient = "insufficient"     // 0 days or unobserved history
}

public struct WorkloadCoverage: Codable, Sendable, Equatable {
    public let observedDaysCount: Int
    public let consecutiveDaysCount: Int
    public let totalDaysCount: Int
    public let confidence: WorkloadConfidence
    public let isAggressiveProgressionAllowed: Bool

    public init(
        observedDaysCount: Int,
        consecutiveDaysCount: Int,
        totalDaysCount: Int,
        confidence: WorkloadConfidence,
        isAggressiveProgressionAllowed: Bool
    ) {
        self.observedDaysCount = observedDaysCount
        self.consecutiveDaysCount = consecutiveDaysCount
        self.totalDaysCount = totalDaysCount
        self.confidence = confidence
        self.isAggressiveProgressionAllowed = isAggressiveProgressionAllowed
    }

    public static var insufficient: WorkloadCoverage {
        WorkloadCoverage(
            observedDaysCount: 0,
            consecutiveDaysCount: 0,
            totalDaysCount: 0,
            confidence: .insufficient,
            isAggressiveProgressionAllowed: false
        )
    }
}
