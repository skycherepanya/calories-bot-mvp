import AppIntents
import Foundation
import SwiftData

// MARK: - LogMealIntent (Siri / Action Button / Shortcuts Nutrition Capture)

public struct LogMealIntent: AppIntent {
    public static var title: LocalizedStringResource = "Log Meal in Lifecore"
    public static var description = IntentDescription("Log what you ate using voice or Shortcuts with automatic +12.5% deficit buffer and 04:00 AM day shift.")

    public static var openAppWhenRun: Bool = false

    @Parameter(
        title: "Опис їжі",
        description: "Що ти з'їв? Наприклад: 2 варені яйця, тост з авокадо та кава",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    public var mealDescription: String

    public init() {}

    public init(mealDescription: String) {
        self.mealDescription = mealDescription
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = mealDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(dialog: "⚠️ Будь ласка, вкажи що саме ти з'їв.")
        }

        let storage = MealStorageService.shared
        let dietaryDate = FoodPrompt.dietaryDate(for: Date())

        // 1. Optimistic insertion (<0.2s)
        let pending = storage.insertOptimisticPending(name: trimmed, dietaryDate: dietaryDate)

        // 2. Background parsing via Gemini
        do {
            let nutrition = try await GeminiService.shared.analyzeFood(
                imageJpegData: nil,
                textDescription: trimmed
            )

            if let resolved = storage.resolvePending(id: pending.id, nutrition: nutrition) {
                // Background HealthKit write-back
                Task.detached {
                    try? await HealthKitManager.shared.saveMealToHealthKit(meal: resolved, date: Date())
                }

                // Asynchronous cloud sync to Supabase
                Task {
                    _ = try? await SupabaseSyncService.shared.syncPendingMeals()
                }

                let summary = "✅ Записано: \(resolved.name) — \(Int(resolved.kcal)) ккал (Б: \(Int(resolved.proteinG))г, Ж: \(Int(resolved.fatG))г, В: \(Int(resolved.carbsG))г)"
                return .result(dialog: IntentDialog(stringLiteral: summary))
            } else {
                return .result(dialog: "✅ Страву додано до списку.")
            }
        } catch {
            return .result(dialog: "✅ Страву збережено: \(trimmed)")
        }
    }
}
