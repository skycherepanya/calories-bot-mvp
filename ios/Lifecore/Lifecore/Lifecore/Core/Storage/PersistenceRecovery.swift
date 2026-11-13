import Foundation
import SwiftData

// MARK: - Persistence Errors

public enum PersistenceError: LocalizedError, Equatable {
    case entityNotFound(UUID)
    case saveFailed(String)
    case migrationFailed(String)
    case invalidStateTransition(from: String, to: String)
    case containerUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case .entityNotFound(let id):
            return "Entity with ID \(id) was not found."
        case .saveFailed(let reason):
            return "Failed to durably save state: \(reason)"
        case .migrationFailed(let reason):
            return "Migration failed: \(reason)"
        case .invalidStateTransition(let from, let to):
            return "Invalid meal lifecycle transition from \(from) to \(to)."
        case .containerUnavailable(let reason):
            return "Persistent container unavailable: \(reason)"
        }
    }
}

// MARK: - Migration Result

public struct MigrationResult: Equatable, Sendable {
    public let migratedCount: Int
    public let skippedDuplicateCount: Int
    public let verifiedCount: Int
    public let sourceBytesRetained: Bool

    public init(
        migratedCount: Int,
        skippedDuplicateCount: Int,
        verifiedCount: Int,
        sourceBytesRetained: Bool
    ) {
        self.migratedCount = migratedCount
        self.skippedDuplicateCount = skippedDuplicateCount
        self.verifiedCount = verifiedCount
        self.sourceBytesRetained = sourceBytesRetained
    }
}

// MARK: - PersistenceRecovery Engine

@MainActor
public enum PersistenceRecovery {

    public static let legacySeedNames: Set<String> = [
        "Вівсянка з бананом та протеїном",
        "Куряче філе з гречкою та огірком",
        "Лосось на пару з рисом басматі"
    ]

    /// Migrates legacy UserDefaults meal records to SwiftData.
    ///
    /// Safety rules (Audit F11 & F25):
    /// 1. Never delete source bytes in UserDefaults until the save succeeds and reread verification confirms records exist in SwiftData.
    /// 2. Deduplicate on retry using stable legacy identity (`id`/`clientUUID`).
    /// 3. Preserve already-buffered calories without recalculation.
    @discardableResult
    public static func migrateUserDefaults(
        key: String,
        in context: ModelContext,
        userDefaults: UserDefaults = .standard,
        testSaveOverride: (() throws -> Void)? = nil
    ) throws -> MigrationResult {
        guard let data = userDefaults.data(forKey: key), !data.isEmpty else {
            return MigrationResult(migratedCount: 0, skippedDuplicateCount: 0, verifiedCount: 0, sourceBytesRetained: false)
        }

        let records: [MealRecord]
        do {
            records = try JSONDecoder().decode([MealRecord].self, from: data)
        } catch {
            throw PersistenceError.migrationFailed("Failed to decode legacy meals: \(error.localizedDescription)")
        }

        guard !records.isEmpty else {
            userDefaults.removeObject(forKey: key)
            return MigrationResult(migratedCount: 0, skippedDuplicateCount: 0, verifiedCount: 0, sourceBytesRetained: false)
        }

        // Fetch existing IDs for deduplication
        let existingDescriptor = FetchDescriptor<MealEntity>()
        let existingEntities = (try? context.fetch(existingDescriptor)) ?? []
        let existingIDs = Set(existingEntities.map { $0.id })

        var migratedEntities: [MealEntity] = []
        var skippedDuplicates = 0

        for record in records {
            if existingIDs.contains(record.id) {
                skippedDuplicates += 1
                continue
            }

            let microJson: String? = {
                guard let m = record.micronutrients, let d = try? JSONEncoder().encode(m) else { return nil }
                return String(data: d, encoding: .utf8)
            }()
            let aminoJson: String? = {
                guard let a = record.aminoAcids, let d = try? JSONEncoder().encode(a) else { return nil }
                return String(data: d, encoding: .utf8)
            }()

            // Preserve already-buffered calories for legacy meals (do not recalculate existing kcal)
            let entity = MealEntity(
                id: record.id,
                clientUUID: record.id,
                name: record.name,
                kcal: record.kcal,
                kcalExact: nil,
                bufferVersion: 1,
                proteinG: record.proteinG,
                fatG: record.fatG,
                carbsG: record.carbsG,
                weightG: record.weightG,
                confidence: record.confidence,
                tags: record.tags,
                micronutrientsJson: microJson,
                aminoAcidsJson: aminoJson,
                dietaryDate: record.dietaryDate,
                createdAt: record.createdAt,
                updatedAt: record.createdAt,
                status: record.isOptimisticPending ? .analyzing : .confirmed,
                revision: 1,
                provenance: "legacy",
                isDeleted: false,
                isOptimisticPending: record.isOptimisticPending,
                syncedToCloud: false,
                remoteId: nil
            )

            context.insert(entity)
            migratedEntities.append(entity)
        }

        // Allow test fault injection
        if let override = testSaveOverride {
            do {
                try override()
            } catch {
                context.rollback()
                // Retain source bytes on error!
                throw PersistenceError.saveFailed(error.localizedDescription)
            }
        }

        // Durable commit
        do {
            try context.save()
        } catch {
            context.rollback()
            // Retain source bytes on error!
            throw PersistenceError.saveFailed(error.localizedDescription)
        }

        // Reread verification: confirm all newly inserted records exist in SwiftData
        let newlyInsertedIDs = Set(migratedEntities.map { $0.id })
        let verifyDescriptor = FetchDescriptor<MealEntity>()
        let rereadEntities = try context.fetch(verifyDescriptor)
        let rereadIDs = Set(rereadEntities.map { $0.id })

        for id in newlyInsertedIDs {
            guard rereadIDs.contains(id) else {
                // Reread failed! Do not remove source data!
                throw PersistenceError.migrationFailed("Reread verification failed: record \(id) not found after save")
            }
        }

        // Only delete source bytes after successful save and reread confirmation
        userDefaults.removeObject(forKey: key)

        return MigrationResult(
            migratedCount: migratedEntities.count,
            skippedDuplicateCount: skippedDuplicates,
            verifiedCount: newlyInsertedIDs.count,
            sourceBytesRetained: false
        )
    }

    /// Purges legacy seed and fixture meals.
    ///
    /// Audit F25 Rule:
    /// Replaces name-based deletion with proven fixture identifiers / `provenance == "fixture" || provenance == "legacy_seed"`.
    /// NEVER deletes real user meals simply because they share a name with a seed meal.
    @discardableResult
    public static func purgeSeedMeals(
        in context: ModelContext,
        userDefaults: UserDefaults = .standard,
        cleanedFlagKey: String = "lifecore_cleaned_seed_meals_v2"
    ) throws -> Int {
        let descriptor = FetchDescriptor<MealEntity>()
        let allEntities = try context.fetch(descriptor)

        var purgedCount = 0
        for entity in allEntities {
            // Provenance-based deletion strictly: only "fixture" or "legacy_seed"
            let isSeedProvenance = entity.provenance == "legacy_seed" || entity.provenance == "fixture"
            if isSeedProvenance {
                context.delete(entity)
                purgedCount += 1
            }
        }

        if purgedCount > 0 {
            try context.save()
        }

        userDefaults.set(true, forKey: cleanedFlagKey)
        return purgedCount
    }

    /// Creates a persistent or in-memory ModelContainer, propagating errors without silent fallback.
    public static func createContainer(
        inMemory: Bool = false,
        configurations: [ModelConfiguration] = []
    ) throws -> ModelContainer {
        let schema = Schema([
            MealEntity.self,
            WorkoutAnalysisEntity.self,
            AthleteTrainingPlanState.self,
            AthleteMemoryEntity.self,
            SyncOperationEntity.self
        ])

        let configs: [ModelConfiguration]
        if configurations.isEmpty {
            configs = [ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)]
        } else {
            configs = configurations
        }

        do {
            return try ModelContainer(for: schema, configurations: configs)
        } catch {
            throw PersistenceError.containerUnavailable(error.localizedDescription)
        }
    }
}
