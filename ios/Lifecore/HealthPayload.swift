import Foundation

// MARK: - Root Ingestion Payload
public struct HealthPayload: Codable {
    public let secret: String
    public let userId: Int
    public let dailyActivity: DailyActivity?
    public let sleep: SleepLog?
    public let workout: WorkoutLog?

    public init(
        secret: String,
        userId: Int,
        dailyActivity: DailyActivity? = nil,
        sleep: SleepLog? = nil,
        workout: WorkoutLog? = nil
    ) {
        self.secret = secret
        self.userId = userId
        self.dailyActivity = dailyActivity
        self.sleep = sleep
        self.workout = workout
    }

    enum CodingKeys: String, CodingKey {
        case secret
        case userId = "user_id"
        case dailyActivity = "daily_activity"
        case sleep
        case workout
    }
}

// MARK: - Daily NEAT Activity
public struct DailyActivity: Codable {
    public let date: String
    public let steps: Int
    public let activeKcal: Double
    public let distanceKm: Double

    public init(date: String, steps: Int, activeKcal: Double, distanceKm: Double) {
        self.date = date
        self.steps = steps
        self.activeKcal = activeKcal
        self.distanceKm = distanceKm
    }

    enum CodingKeys: String, CodingKey {
        case date
        case steps
        case activeKcal = "active_kcal"
        case distanceKm = "distance_km"
    }
}

// MARK: - Sleep & Recovery Biomarkers
public struct SleepLog: Codable {
    public let sleepDate: String
    public let totalHours: Double
    public let deepHours: Double
    public let remHours: Double
    public let coreHours: Double
    public let awakeHours: Double
    public let hrvAvgMs: Double?
    public let rhrBpm: Double?

    public init(
        sleepDate: String,
        totalHours: Double,
        deepHours: Double,
        remHours: Double,
        coreHours: Double,
        awakeHours: Double,
        hrvAvgMs: Double?,
        rhrBpm: Double?
    ) {
        self.sleepDate = sleepDate
        self.totalHours = totalHours
        self.deepHours = deepHours
        self.remHours = remHours
        self.coreHours = coreHours
        self.awakeHours = awakeHours
        self.hrvAvgMs = hrvAvgMs
        self.rhrBpm = rhrBpm
    }

    enum CodingKeys: String, CodingKey {
        case sleepDate = "sleep_date"
        case totalHours = "total_hours"
        case deepHours = "deep_hours"
        case remHours = "rem_hours"
        case coreHours = "core_hours"
        case awakeHours = "awake_hours"
        case hrvAvgMs = "hrv_avg_ms"
        case rhrBpm = "rhr_bpm"
    }
}

// MARK: - Workout Session
public struct WorkoutLog: Codable {
    public let type: String
    public let durationMin: Double
    public let avgHeartRate: Double?
    public let maxHeartRate: Double?
    public let activeCalories: Double?
    public let distanceKm: Double?
    public let startedAt: String

    public init(
        type: String,
        durationMin: Double,
        avgHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        activeCalories: Double? = nil,
        distanceKm: Double? = nil,
        startedAt: String
    ) {
        self.type = type
        self.durationMin = durationMin
        self.avgHeartRate = avgHeartRate
        self.maxHeartRate = maxHeartRate
        self.activeCalories = activeCalories
        self.distanceKm = distanceKm
        self.startedAt = startedAt
    }

    enum CodingKeys: String, CodingKey {
        case type
        case durationMin = "duration_min"
        case avgHeartRate = "avg_heart_rate"
        case maxHeartRate = "max_heart_rate"
        case activeCalories = "active_calories"
        case distanceKm = "distance_km"
        case startedAt = "started_at"
    }
}

// MARK: - Server Response
public struct IngestResponse: Codable {
    public let ok: Bool
    public let inserted: InsertedStatus?
    public let errors: [String: String]?

    public struct InsertedStatus: Codable {
        public let dailyActivity: Bool?
        public let sleep: Bool?
        public let workout: Bool?

        enum CodingKeys: String, CodingKey {
            case dailyActivity = "daily_activity"
            case sleep
            case workout
        }
    }
}
