import Foundation
import SwiftData

// MARK: - MealEntity (SwiftData Local Model)

@Model
public final class MealEntity {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var kcal: Double             // Stores final calories including +12.5% deficit buffer
    public var proteinG: Double
    public var fatG: Double
    public var carbsG: Double
    public var weightG: Double?
    public var confidence: Double?
    public var tags: [String]
    public var micronutrientsJson: String?
    public var aminoAcidsJson: String?
    public var dietaryDate: String      // YYYY-MM-DD adhering to 04:00 AM day shift
    public var createdAt: Date
    public var isOptimisticPending: Bool
    public var syncedToCloud: Bool
    public var remoteId: Int64?

    public init(
        id: UUID = UUID(),
        name: String,
        kcal: Double,
        proteinG: Double,
        fatG: Double,
        carbsG: Double,
        weightG: Double? = nil,
        confidence: Double? = nil,
        tags: [String] = [],
        micronutrientsJson: String? = nil,
        aminoAcidsJson: String? = nil,
        dietaryDate: String,
        createdAt: Date = Date(),
        isOptimisticPending: Bool = false,
        syncedToCloud: Bool = false,
        remoteId: Int64? = nil
    ) {
        self.id = id
        self.name = name
        self.kcal = kcal
        self.proteinG = proteinG
        self.fatG = fatG
        self.carbsG = carbsG
        self.weightG = weightG
        self.confidence = confidence
        self.tags = tags
        self.micronutrientsJson = micronutrientsJson
        self.aminoAcidsJson = aminoAcidsJson
        self.dietaryDate = dietaryDate
        self.createdAt = createdAt
        self.isOptimisticPending = isOptimisticPending
        self.syncedToCloud = syncedToCloud
        self.remoteId = remoteId
    }

    public convenience init(record: MealRecord, syncedToCloud: Bool = false, remoteId: Int64? = nil) {
        let microJson: String? = {
            guard let m = record.micronutrients, let data = try? JSONEncoder().encode(m) else { return nil }
            return String(data: data, encoding: .utf8)
        }()
        let aminoJson: String? = {
            guard let a = record.aminoAcids, let data = try? JSONEncoder().encode(a) else { return nil }
            return String(data: data, encoding: .utf8)
        }()

        self.init(
            id: record.id,
            name: record.name,
            kcal: record.kcal,
            proteinG: record.proteinG,
            fatG: record.fatG,
            carbsG: record.carbsG,
            weightG: record.weightG,
            confidence: nil,
            tags: record.tags,
            micronutrientsJson: microJson,
            aminoAcidsJson: aminoJson,
            dietaryDate: record.dietaryDate,
            createdAt: record.createdAt,
            isOptimisticPending: record.isOptimisticPending,
            syncedToCloud: syncedToCloud,
            remoteId: remoteId
        )
    }

    public var micronutrients: Micronutrients? {
        guard let json = micronutrientsJson, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Micronutrients.self, from: data)
    }

    public var aminoAcids: AminoAcids? {
        guard let json = aminoAcidsJson, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AminoAcids.self, from: data)
    }

    public func toRecord() -> MealRecord {
        MealRecord(
            id: id,
            name: name,
            kcal: kcal,
            proteinG: proteinG,
            fatG: fatG,
            carbsG: carbsG,
            weightG: weightG,
            tags: tags,
            micronutrients: micronutrients,
            aminoAcids: aminoAcids,
            dietaryDate: dietaryDate,
            createdAt: createdAt,
            isOptimisticPending: isOptimisticPending
        )
    }
}

// MARK: - WorkoutAnalysisEntity (SwiftData Local Model)

@Model
public final class WorkoutAnalysisEntity {
    @Attribute(.unique) public var id: UUID
    public var workoutUUID: UUID        // Associated HKWorkout UUID
    public var workoutType: String
    public var startedAt: Date
    public var distanceMeters: Double
    public var durationSeconds: Double
    public var avgPaceSecPerKm: Double?
    public var avgHeartRate: Double?
    public var maxHeartRate: Double?
    public var elevationGainMeters: Double?
    public var efficiencyFactor: Double?
    public var cardiacDriftPercentage: Double?
    public var splitsJson: String       // JSON serialized [Split1km]
    public var lapsJson: String         // JSON serialized [IntervalLap]
    public var aiCoachReport: String?   // Markdown text from Gemini
    public var createdAt: Date
    public var updatedAt: Date
    public var syncedToCloud: Bool

    public init(
        id: UUID = UUID(),
        workoutUUID: UUID,
        workoutType: String,
        startedAt: Date,
        distanceMeters: Double,
        durationSeconds: Double,
        avgPaceSecPerKm: Double? = nil,
        avgHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        elevationGainMeters: Double? = nil,
        efficiencyFactor: Double? = nil,
        cardiacDriftPercentage: Double? = nil,
        splitsJson: String = "[]",
        lapsJson: String = "[]",
        aiCoachReport: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncedToCloud: Bool = false
    ) {
        self.id = id
        self.workoutUUID = workoutUUID
        self.workoutType = workoutType
        self.startedAt = startedAt
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.avgPaceSecPerKm = avgPaceSecPerKm
        self.avgHeartRate = avgHeartRate
        self.maxHeartRate = maxHeartRate
        self.elevationGainMeters = elevationGainMeters
        self.efficiencyFactor = efficiencyFactor
        self.cardiacDriftPercentage = cardiacDriftPercentage
        self.splitsJson = splitsJson
        self.lapsJson = lapsJson
        self.aiCoachReport = aiCoachReport
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncedToCloud = syncedToCloud
    }

    public var splits: [SplitMetric] {
        guard let data = splitsJson.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([SplitMetric].self, from: data)) ?? []
    }

    public var laps: [LapIntervalMetric] {
        guard let data = lapsJson.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([LapIntervalMetric].self, from: data)) ?? []
    }

    public static func serializeSplits(_ splits: [SplitMetric]) -> String {
        guard let data = try? JSONEncoder().encode(splits),
              let str = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return str
    }

    public static func serializeLaps(_ laps: [LapIntervalMetric]) -> String {
        guard let data = try? JSONEncoder().encode(laps),
              let str = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return str
    }
}

// MARK: - LifecoreDataStore (Shared ModelContainer Provider)

@MainActor
public final class LifecoreDataStore {
    public static let shared = LifecoreDataStore()
    public let container: ModelContainer

    public var context: ModelContext {
        container.mainContext
    }

    private init() {
        let schema = Schema([
            MealEntity.self,
            WorkoutAnalysisEntity.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            self.container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            print("⚠️ Failed to initialize persistent ModelContainer: \(error). Falling back to memory store.")
            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            self.container = try! ModelContainer(for: schema, configurations: [fallbackConfig])
        }
    }
}

// MARK: - WorkoutStorageService (SwiftData Access for Workout Analyses)

@MainActor
public enum WorkoutStorageService {
    public static func fetchAnalysis(for workoutUUID: UUID) -> WorkoutAnalysisEntity? {
        let context = LifecoreDataStore.shared.context
        let descriptor = FetchDescriptor<WorkoutAnalysisEntity>(
            predicate: #Predicate { $0.workoutUUID == workoutUUID }
        )
        return (try? context.fetch(descriptor))?.first
    }

    @discardableResult
    public static func saveOrUpdate(
        workoutUUID: UUID,
        workoutType: String,
        startedAt: Date,
        distanceMeters: Double,
        durationSeconds: Double,
        avgPaceSecPerKm: Double?,
        avgHeartRate: Double?,
        maxHeartRate: Double?,
        elevationGainMeters: Double?,
        efficiencyFactor: Double?,
        cardiacDriftPercentage: Double?,
        splits: [SplitMetric],
        laps: [LapIntervalMetric],
        aiCoachReport: String? = nil
    ) -> WorkoutAnalysisEntity {
        let context = LifecoreDataStore.shared.context
        let splitsJson = WorkoutAnalysisEntity.serializeSplits(splits)
        let lapsJson = WorkoutAnalysisEntity.serializeLaps(laps)

        if let existing = fetchAnalysis(for: workoutUUID) {
            existing.distanceMeters = distanceMeters
            existing.durationSeconds = durationSeconds
            existing.avgPaceSecPerKm = avgPaceSecPerKm
            existing.avgHeartRate = avgHeartRate
            existing.maxHeartRate = maxHeartRate
            existing.elevationGainMeters = elevationGainMeters
            existing.efficiencyFactor = efficiencyFactor
            existing.cardiacDriftPercentage = cardiacDriftPercentage
            existing.splitsJson = splitsJson
            existing.lapsJson = lapsJson
            if let report = aiCoachReport {
                existing.aiCoachReport = report
            }
            existing.updatedAt = Date()
            existing.syncedToCloud = false
            try? context.save()
            return existing
        } else {
            let newEntity = WorkoutAnalysisEntity(
                workoutUUID: workoutUUID,
                workoutType: workoutType,
                startedAt: startedAt,
                distanceMeters: distanceMeters,
                durationSeconds: durationSeconds,
                avgPaceSecPerKm: avgPaceSecPerKm,
                avgHeartRate: avgHeartRate,
                maxHeartRate: maxHeartRate,
                elevationGainMeters: elevationGainMeters,
                efficiencyFactor: efficiencyFactor,
                cardiacDriftPercentage: cardiacDriftPercentage,
                splitsJson: splitsJson,
                lapsJson: lapsJson,
                aiCoachReport: aiCoachReport,
                createdAt: Date(),
                updatedAt: Date(),
                syncedToCloud: false
            )
            context.insert(newEntity)
            try? context.save()
            return newEntity
        }
    }

    public static func updateCoachReport(for workoutUUID: UUID, report: String) {
        let context = LifecoreDataStore.shared.context
        if let existing = fetchAnalysis(for: workoutUUID) {
            existing.aiCoachReport = report
            existing.updatedAt = Date()
            existing.syncedToCloud = false
            try? context.save()
        }
    }

    public static func fetchUnsyncedAnalyses() -> [WorkoutAnalysisEntity] {
        let context = LifecoreDataStore.shared.context
        let descriptor = FetchDescriptor<WorkoutAnalysisEntity>(
            predicate: #Predicate { !$0.syncedToCloud }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    public static func markAnalysisSynced(workoutUUID: UUID) {
        let context = LifecoreDataStore.shared.context
        if let existing = fetchAnalysis(for: workoutUUID) {
            existing.syncedToCloud = true
            try? context.save()
        }
    }
}


