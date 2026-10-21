import Foundation
import SwiftUI
import Combine

@MainActor
public final class MealStorageService: ObservableObject {
    public static let shared = MealStorageService()

    private let storageKey = "LIFECORE_SAVED_MEALS_V1"
    private let hasSeededKey = "LIFECORE_HAS_SEEDED_MEALS_V1"

    @Published public private(set) var allMeals: [MealRecord] = []

    private init() {
        loadMeals()
        let hasSeeded = UserDefaults.standard.bool(forKey: hasSeededKey)
        if allMeals.isEmpty && !hasSeeded {
            seedSampleMeals()
            UserDefaults.standard.set(true, forKey: hasSeededKey)
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

    // MARK: - Mutations

    /// Inserts an optimistic pending meal in <0.2s to deliver instant UI feedback.
    @discardableResult
    public func insertOptimisticPending(name: String, dietaryDate: String) -> MealRecord {
        let record = MealRecord(
            name: name,
            kcal: 0,
            proteinG: 0,
            fatG: 0,
            carbsG: 0,
            weightG: nil,
            tags: ["solid"],
            dietaryDate: dietaryDate,
            createdAt: Date(),
            isOptimisticPending: true
        )
        allMeals.insert(record, at: 0)
        saveMeals()
        return record
    }

    /// Replaces the pending meal with the full analyzed nutrition from Gemini.
    @discardableResult
    public func resolvePending(id: UUID, nutrition: MealNutrition) -> MealRecord? {
        guard let index = allMeals.firstIndex(where: { $0.id == id }) else { return nil }
        let existing = allMeals[index]

        let resolved = MealRecord(
            id: existing.id,
            name: nutrition.mealName,
            kcal: nutrition.kcal,
            proteinG: nutrition.protein,
            fatG: nutrition.fat,
            carbsG: nutrition.carbs,
            weightG: nutrition.weightG,
            tags: nutrition.tags,
            micronutrients: nutrition.micronutrients,
            aminoAcids: nutrition.aminoAcids,
            dietaryDate: existing.dietaryDate,
            createdAt: existing.createdAt,
            isOptimisticPending: false
        )

        allMeals[index] = resolved
        saveMeals()
        return resolved
    }

    /// Direct addition of a completed meal.
    @discardableResult
    public func addMeal(nutrition: MealNutrition, dietaryDate: String) -> MealRecord {
        let record = MealRecord(
            name: nutrition.mealName,
            kcal: nutrition.kcal,
            proteinG: nutrition.protein,
            fatG: nutrition.fat,
            carbsG: nutrition.carbs,
            weightG: nutrition.weightG,
            tags: nutrition.tags,
            micronutrients: nutrition.micronutrients,
            aminoAcids: nutrition.aminoAcids,
            dietaryDate: dietaryDate,
            createdAt: Date(),
            isOptimisticPending: false
        )
        allMeals.insert(record, at: 0)
        saveMeals()
        return record
    }

    public func deleteMeal(id: UUID) {
        objectWillChange.send()
        allMeals.removeAll(where: { $0.id == id })
        saveMeals()
    }

    public func restoreMeal(_ meal: MealRecord) {
        objectWillChange.send()
        if !allMeals.contains(where: { $0.id == meal.id }) {
            allMeals.insert(meal, at: 0)
            saveMeals()
        }
    }

    // MARK: - Persistence

    private func saveMeals() {
        if let data = try? JSONEncoder().encode(allMeals) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadMeals() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let list = try? JSONDecoder().decode([MealRecord].self, from: data) else {
            return
        }
        self.allMeals = list
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

        self.allMeals = [m1, m2, m3]
        saveMeals()
    }
}
