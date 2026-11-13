import Foundation
import SwiftUI
import Combine
import SwiftData

@MainActor
public final class MealStorageService: ObservableObject {
    public static let shared = MealStorageService()

    public let legacyStorageKey = "LIFECORE_SAVED_MEALS_V1"
    private let hasSeededKey = "LIFECORE_HAS_SEEDED_MEALS_V2"

    @Published public private(set) var allMeals: [MealRecord] = []

    /// Fault injection hook for testing durable save error recovery (Audit F10/F11).
    public var simulatedSaveError: Error? = nil

    private var context: ModelContext {
        LifecoreDataStore.shared.context
    }

    public init() {
        try? migrateFromUserDefaultsIfNeeded()
        loadMealsFromSwiftData()
        try? removeLegacySeedMealsIfNeeded()
    }

    // MARK: - Query

    public func meals(for dietaryDate: String) -> [MealRecord] {
        allMeals
            .filter { $0.dietaryDate == dietaryDate }
            .sorted(by: { $0.createdAt > $1.createdAt })
    }

    /// Fetches meals logged in the 36-hour acute window up to and including the workout execution time.
    public static func fetchAcuteNutritionMeals(for date: Date = Date()) -> [MealRecord] {
        let windowStart = date.addingTimeInterval(-36.0 * 3600.0)
        let windowEnd = date.addingTimeInterval(3600.0) // Small 1h tolerance for post-workout logging
        return shared.allMeals.filter {
            !$0.isOptimisticPending && $0.createdAt >= windowStart && $0.createdAt <= windowEnd
        }
    }

    public func dailyTotals(for dietaryDate: String) -> (kcal: Double, protein: Double, fat: Double, carbs: Double, sodiumMg: Double, leucineG: Double, wholeFoodCount: Int, ultraProcessedCount: Int) {
        let dayMeals = meals(for: dietaryDate).filter { !$0.isOptimisticPending }
        var totalKcal: Double = 0
        var totalProtein: Double = 0
        var totalFat: Double = 0
        var totalCarbs: Double = 0
        var totalSodium: Double = 0
        var totalLeucine: Double = 0
        var wholeFood = 0
        var ultraProc = 0

        for m in dayMeals {
            totalKcal += m.kcal
            totalProtein += m.proteinG
            totalFat += m.fatG
            totalCarbs += m.carbsG

            if let s = m.micronutrients?.sodiumMg { totalSodium += s }
            if let l = m.aminoAcids?.leucineG { totalLeucine += l }
            if m.isWholeFood { wholeFood += 1 }
            if m.isUltraProcessed { ultraProc += 1 }
        }

        return (
            kcal: round(totalKcal),
            protein: round(totalProtein),
            fat: round(totalFat),
            carbs: round(totalCarbs),
            sodiumMg: round(totalSodium),
            leucineG: round(totalLeucine * 10) / 10,
            wholeFoodCount: wholeFood,
            ultraProcessedCount: ultraProc
        )
    }

    // MARK: - SwiftData Load & Migration

    public func loadMealsFromSwiftData() {
        let descriptor = FetchDescriptor<MealEntity>(
            predicate: #Predicate { !$0.isDeleted },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        do {
            let entities = try context.fetch(descriptor)
            self.allMeals = entities.map { $0.toRecord() }
        } catch {
            print("⚠️ Failed to fetch MealEntity from SwiftData: \(error)")
        }
    }

    @discardableResult
    public func migrateFromUserDefaultsIfNeeded(userDefaults: UserDefaults = .standard) throws -> MigrationResult {
        guard !AppEnvironment.current.isFixtureMode else {
            return MigrationResult(migratedCount: 0, skippedDuplicateCount: 0, verifiedCount: 0, sourceBytesRetained: false)
        }
        let result = try PersistenceRecovery.migrateUserDefaults(
            key: legacyStorageKey,
            in: context,
            userDefaults: userDefaults,
            testSaveOverride: simulatedSaveError != nil ? { throw self.simulatedSaveError! } : nil
        )
        if result.migratedCount > 0 {
            loadMealsFromSwiftData()
            print("✅ Successfully migrated \(result.migratedCount) meals from UserDefaults to SwiftData")
        }
        return result
    }

    @discardableResult
    public func removeLegacySeedMealsIfNeeded(userDefaults: UserDefaults = .standard) throws -> Int {
        guard !AppEnvironment.current.isFixtureMode else { return 0 }
        let cleanedKey = "lifecore_cleaned_seed_meals_v2"
        if !userDefaults.bool(forKey: cleanedKey) {
            let purged = try PersistenceRecovery.purgeSeedMeals(
                in: context,
                userDefaults: userDefaults,
                cleanedFlagKey: cleanedKey
            )
            if purged > 0 {
                loadMealsFromSwiftData()
            }
            return purged
        }
        return 0
    }

    // MARK: - Durable Mutations (Audit F10, F11)

    /// Inserts an optimistic pending meal in <0.2s to deliver instant UI feedback.
    @discardableResult
    public func insertOptimisticPending(name: String, dietaryDate: String, provenance: String = "manual") -> MealRecord {
        let entity = MealEntity(
            name: name,
            kcal: 0,
            proteinG: 0,
            fatG: 0,
            carbsG: 0,
            weightG: nil,
            confidence: nil,
            tags: ["solid"],
            micronutrientsJson: nil,
            aminoAcidsJson: nil,
            dietaryDate: dietaryDate,
            createdAt: Date(),
            updatedAt: Date(),
            status: .analyzing,
            revision: 1,
            provenance: provenance,
            isDeleted: false,
            isOptimisticPending: true,
            syncedToCloud: false
        )
        context.insert(entity)
        try? context.save()

        let record = entity.toRecord()
        allMeals.insert(record, at: 0)
        return record
    }

    /// Confirms a meal atomically saving state and enqueuing an outbox sync intent.
    @discardableResult
    public func confirmMeal(id: UUID) throws -> MealRecord {
        let descriptor = FetchDescriptor<MealEntity>(
            predicate: #Predicate { $0.id == id }
        )
        guard let entity = try context.fetch(descriptor).first else {
            throw PersistenceError.entityNotFound(id)
        }

        entity.lifecycleState = .confirmed
        entity.isOptimisticPending = false
        entity.isDeleted = false
        entity.revision += 1
        entity.updatedAt = Date()

        // Atomically enqueue outbox mutation intent
        try SyncOutbox.shared.enqueue(
            entityID: entity.id,
            entityType: "meal",
            operationKind: "upsert",
            revision: entity.revision,
            payloadJson: MealSyncPayload(from: entity).toJsonString(),
            in: context
        )

        // Injectable fault hook
        if let error = simulatedSaveError {
            context.rollback()
            throw PersistenceError.saveFailed(error.localizedDescription)
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            throw PersistenceError.saveFailed(error.localizedDescription)
        }

        let record = entity.toRecord()
        objectWillChange.send()
        if let idx = allMeals.firstIndex(where: { $0.id == id }) {
            allMeals[idx] = record
        } else {
            allMeals.insert(record, at: 0)
            allMeals.sort(by: { $0.createdAt > $1.createdAt })
        }
        return record
    }

    /// Deletes a meal (soft delete tombstone), advancing revision and enqueuing an outbox delete operation.
    public func deleteMeal(id: UUID) throws {
        let descriptor = FetchDescriptor<MealEntity>(
            predicate: #Predicate { $0.id == id }
        )
        guard let entity = try context.fetch(descriptor).first else {
            throw PersistenceError.entityNotFound(id)
        }

        entity.isDeleted = true
        entity.lifecycleState = .cancelled
        entity.revision += 1
        entity.updatedAt = Date()

        // Atomically enqueue outbox delete tombstone
        try SyncOutbox.shared.enqueue(
            entityID: entity.id,
            entityType: "meal",
            operationKind: "delete",
            revision: entity.revision,
            payloadJson: MealSyncPayload(from: entity).toJsonString(),
            in: context
        )

        // Injectable fault hook
        if let error = simulatedSaveError {
            context.rollback()
            throw PersistenceError.saveFailed(error.localizedDescription)
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            throw PersistenceError.saveFailed(error.localizedDescription)
        }

        // Only update UI state after durable save succeeded
        objectWillChange.send()
        allMeals.removeAll(where: { $0.id == id })

        Task {
            guard !AppEnvironment.current.isFixtureMode else { return }
            try? await HealthKitManager.shared.deleteMealFromHealthKit(mealId: id)
        }
    }

    /// Restores a soft-deleted meal atomically advancing revision and enqueuing outbox upsert.
    @discardableResult
    public func undoDeleteMeal(id: UUID) throws -> MealRecord {
        let descriptor = FetchDescriptor<MealEntity>(
            predicate: #Predicate { $0.id == id }
        )
        guard let entity = try context.fetch(descriptor).first else {
            throw PersistenceError.entityNotFound(id)
        }

        entity.isDeleted = false
        entity.lifecycleState = .confirmed
        entity.revision += 1
        entity.updatedAt = Date()

        // Atomically enqueue outbox upsert intent
        try SyncOutbox.shared.enqueue(
            entityID: entity.id,
            entityType: "meal",
            operationKind: "upsert",
            revision: entity.revision,
            payloadJson: MealSyncPayload(from: entity).toJsonString(),
            in: context
        )

        // Injectable fault hook
        if let error = simulatedSaveError {
            context.rollback()
            throw PersistenceError.saveFailed(error.localizedDescription)
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            throw PersistenceError.saveFailed(error.localizedDescription)
        }

        let record = entity.toRecord()
        objectWillChange.send()
        if !allMeals.contains(where: { $0.id == record.id }) {
            allMeals.insert(record, at: 0)
            allMeals.sort(by: { $0.createdAt > $1.createdAt })
        }

        Task {
            guard !AppEnvironment.current.isFixtureMode else { return }
            try? await HealthKitManager.shared.saveMealToHealthKit(meal: record)
        }
        return record
    }

    /// Replaces the pending meal with the full analyzed nutrition from Gemini.
    @discardableResult
    public func resolvePending(id: UUID, nutrition: MealNutrition) -> MealRecord? {
        let descriptor = FetchDescriptor<MealEntity>(
            predicate: #Predicate { $0.id == id }
        )
        guard let entities = try? context.fetch(descriptor), let entity = entities.first else {
            return nil
        }

        entity.name = nutrition.mealName
        entity.kcal = nutrition.kcal
        entity.proteinG = nutrition.protein
        entity.fatG = nutrition.fat
        entity.carbsG = nutrition.carbs
        entity.weightG = nutrition.weightG
        entity.confidence = nutrition.confidence
        entity.tags = nutrition.tags

        if let micro = nutrition.micronutrients, let data = try? JSONEncoder().encode(micro) {
            entity.micronutrientsJson = String(data: data, encoding: .utf8)
        }
        if let amino = nutrition.aminoAcids, let data = try? JSONEncoder().encode(amino) {
            entity.aminoAcidsJson = String(data: data, encoding: .utf8)
        }
        entity.lifecycleState = .confirmed
        entity.isOptimisticPending = false
        entity.syncedToCloud = false
        entity.revision += 1
        entity.updatedAt = Date()

        try? SyncOutbox.shared.enqueue(
            entityID: entity.id,
            entityType: "meal",
            operationKind: "upsert",
            revision: entity.revision,
            payloadJson: MealSyncPayload(from: entity).toJsonString(),
            in: context
        )

        try? context.save()

        loadMealsFromSwiftData()
        return entity.toRecord()
    }

    /// Direct addition of a completed meal.
    @discardableResult
    public func addMeal(
        nutrition: MealNutrition,
        dietaryDate: String,
        provenance: String = "manual"
    ) -> MealRecord {
        let microJson: String? = {
            guard let m = nutrition.micronutrients, let data = try? JSONEncoder().encode(m) else { return nil }
            return String(data: data, encoding: .utf8)
        }()
        let aminoJson: String? = {
            guard let a = nutrition.aminoAcids, let data = try? JSONEncoder().encode(a) else { return nil }
            return String(data: data, encoding: .utf8)
        }()

        let entity = MealEntity(
            name: nutrition.mealName,
            kcal: nutrition.kcal,
            proteinG: nutrition.protein,
            fatG: nutrition.fat,
            carbsG: nutrition.carbs,
            weightG: nutrition.weightG,
            confidence: nutrition.confidence,
            tags: nutrition.tags,
            micronutrientsJson: microJson,
            aminoAcidsJson: aminoJson,
            dietaryDate: dietaryDate,
            createdAt: Date(),
            updatedAt: Date(),
            status: .confirmed,
            revision: 1,
            provenance: provenance,
            isDeleted: false,
            isOptimisticPending: false,
            syncedToCloud: false
        )
        context.insert(entity)

        try? SyncOutbox.shared.enqueue(
            entityID: entity.id,
            entityType: "meal",
            operationKind: "upsert",
            revision: entity.revision,
            payloadJson: MealSyncPayload(from: entity).toJsonString(),
            in: context
        )

        try? context.save()

        let record = entity.toRecord()
        objectWillChange.send()
        allMeals.insert(record, at: 0)
        return record
    }

    public func restoreMeal(_ meal: MealRecord) {
        if let _ = try? undoDeleteMeal(id: meal.id) {
            return
        }
        objectWillChange.send()
        if !allMeals.contains(where: { $0.id == meal.id }) {
            allMeals.insert(meal, at: 0)
            let entity = MealEntity(record: meal)
            context.insert(entity)
            try? context.save()

            Task {
                guard !AppEnvironment.current.isFixtureMode else { return }
                try? await HealthKitManager.shared.saveMealToHealthKit(meal: meal)
            }
        }
    }

    // MARK: - Cloud Sync Helpers

    public func fetchAllMeals() -> [MealRecord] {
        allMeals
    }

    public static func fetchTodayMeals() -> [MealRecord] {
        MealStorageService.shared.allMeals
    }

    public func insertHydratedMeal(_ record: MealRecord, syncedToCloud: Bool = true, remoteId: Int64? = nil) {
        objectWillChange.send()
        let entity = MealEntity(record: record, syncedToCloud: syncedToCloud, remoteId: remoteId)
        context.insert(entity)
        try? context.save()
        loadMealsFromSwiftData()
    }

    public func fetchUnsyncedMeals() -> [MealEntity] {
        let descriptor = FetchDescriptor<MealEntity>(
            predicate: #Predicate { !$0.syncedToCloud && !$0.isOptimisticPending && !$0.isDeleted }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    public func markMealSynced(id: UUID, remoteId: Int64) {
        let descriptor = FetchDescriptor<MealEntity>(
            predicate: #Predicate { $0.id == id }
        )
        if let entity = (try? context.fetch(descriptor))?.first {
            entity.syncedToCloud = true
            entity.remoteId = remoteId
            try? context.save()
        }
    }

    private func seedSampleMeals() {
        let today = FoodPrompt.dietaryDate(for: Date(), offsetDays: 0)
        let yesterday = FoodPrompt.dietaryDate(for: Date(), offsetDays: -1)

        let m1 = MealRecord(
            name: "Вівсянка з бананом та протеїном",
            kcal: round(390 * 1.125), // +12.5% buffer
            proteinG: 34,
            fatG: 7,
            carbsG: 56,
            weightG: 320,
            tags: ["whole_food", "solid", "slow_absorbing"],
            micronutrients: .init(fiberG: 5.5, sodiumMg: 120, potassiumMg: 420, vitaminCMg: 9, ironMg: 2.4, calciumMg: 110),
            aminoAcids: .init(bcaaG: 6.8, leucineG: 3.2),
            dietaryDate: today,
            createdAt: Date().addingTimeInterval(-14400),
            isOptimisticPending: false
        )

        let m2 = MealRecord(
            name: "Куряче філе з гречкою та огірком",
            kcal: round(460 * 1.125),
            proteinG: 46,
            fatG: 10,
            carbsG: 48,
            weightG: 350,
            tags: ["whole_food", "solid", "slow_absorbing"],
            micronutrients: .init(fiberG: 4.8, sodiumMg: 380, potassiumMg: 610, vitaminCMg: 14, ironMg: 3.5, calciumMg: 45),
            aminoAcids: .init(bcaaG: 8.4, leucineG: 3.8),
            dietaryDate: today,
            createdAt: Date().addingTimeInterval(-7200),
            isOptimisticPending: false
        )

        let m3 = MealRecord(
            name: "Лосось на пару з рисом басматі",
            kcal: round(520 * 1.125),
            proteinG: 38,
            fatG: 22,
            carbsG: 42,
            weightG: 340,
            tags: ["whole_food", "solid", "slow_absorbing"],
            micronutrients: .init(fiberG: 2.1, sodiumMg: 290, potassiumMg: 520, vitaminCMg: 2, ironMg: 1.8, calciumMg: 35),
            aminoAcids: .init(bcaaG: 7.2, leucineG: 3.3),
            dietaryDate: yesterday,
            createdAt: Date().addingTimeInterval(-86400),
            isOptimisticPending: false
        )

        for m in [m1, m2, m3] {
            context.insert(MealEntity(record: m, provenance: "legacy_seed"))
        }
        try? context.save()
    }
}
