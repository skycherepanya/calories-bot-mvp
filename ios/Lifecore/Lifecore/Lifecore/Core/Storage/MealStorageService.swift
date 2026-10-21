import Foundation
import SwiftUI
import Combine
import SwiftData

@MainActor
public final class MealStorageService: ObservableObject {
    public static let shared = MealStorageService()

    private let legacyStorageKey = "LIFECORE_SAVED_MEALS_V1"
    private let hasSeededKey = "LIFECORE_HAS_SEEDED_MEALS_V2"

    @Published public private(set) var allMeals: [MealRecord] = []

    private var context: ModelContext {
        LifecoreDataStore.shared.context
    }

    private init() {
        migrateFromUserDefaultsIfNeeded()
        loadMealsFromSwiftData()

        let hasSeeded = UserDefaults.standard.bool(forKey: hasSeededKey)
        if allMeals.isEmpty && !hasSeeded {
            seedSampleMeals()
            UserDefaults.standard.set(true, forKey: hasSeededKey)
            loadMealsFromSwiftData()
        }
    }

    // MARK: - Query

    public func meals(for dietaryDate: String) -> [MealRecord] {
        allMeals
            .filter { $0.dietaryDate == dietaryDate }
            .sorted(by: { $0.createdAt > $1.createdAt })
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

    private func loadMealsFromSwiftData() {
        let descriptor = FetchDescriptor<MealEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        do {
            let entities = try context.fetch(descriptor)
            self.allMeals = entities.map { $0.toRecord() }
        } catch {
            print("⚠️ Failed to fetch MealEntity from SwiftData: \(error)")
        }
    }

    private func migrateFromUserDefaultsIfNeeded() {
        guard let data = UserDefaults.standard.data(forKey: legacyStorageKey),
              let list = try? JSONDecoder().decode([MealRecord].self, from: data),
              !list.isEmpty else {
            return
        }

        for record in list {
            let entity = MealEntity(record: record)
            context.insert(entity)
        }
        try? context.save()
        UserDefaults.standard.removeObject(forKey: legacyStorageKey)
        print("✅ Successfully migrated \(list.count) meals from UserDefaults to SwiftData")
    }

    // MARK: - Mutations

    /// Inserts an optimistic pending meal in <0.2s to deliver instant UI feedback.
    @discardableResult
    public func insertOptimisticPending(name: String, dietaryDate: String) -> MealRecord {
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
            isOptimisticPending: true,
            syncedToCloud: false
        )
        context.insert(entity)
        try? context.save()

        let record = entity.toRecord()
        allMeals.insert(record, at: 0)
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
        entity.isOptimisticPending = false
        entity.syncedToCloud = false

        try? context.save()

        loadMealsFromSwiftData()
        return entity.toRecord()
    }

    /// Direct addition of a completed meal.
    @discardableResult
    public func addMeal(nutrition: MealNutrition, dietaryDate: String) -> MealRecord {
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
            isOptimisticPending: false,
            syncedToCloud: false
        )
        context.insert(entity)
        try? context.save()

        let record = entity.toRecord()
        allMeals.insert(record, at: 0)
        return record
    }

    public func deleteMeal(id: UUID) {
        objectWillChange.send()
        allMeals.removeAll(where: { $0.id == id })

        let descriptor = FetchDescriptor<MealEntity>(
            predicate: #Predicate { $0.id == id }
        )
        if let entities = try? context.fetch(descriptor) {
            for e in entities {
                context.delete(e)
            }
            try? context.save()
        }
    }

    public func restoreMeal(_ meal: MealRecord) {
        objectWillChange.send()
        if !allMeals.contains(where: { $0.id == meal.id }) {
            allMeals.insert(meal, at: 0)
            let entity = MealEntity(record: meal)
            context.insert(entity)
            try? context.save()
        }
    }

    // MARK: - Cloud Sync Helpers

    public func fetchUnsyncedMeals() -> [MealEntity] {
        let descriptor = FetchDescriptor<MealEntity>(
            predicate: #Predicate { !$0.syncedToCloud && !$0.isOptimisticPending }
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
            context.insert(MealEntity(record: m))
        }
        try? context.save()
    }
}
