import AppIntents
import Foundation
import SwiftData

// MARK: - LogMealOutcome

public struct LogMealOutcome: Equatable, Sendable {
    public let dialog: String
    public let draftRecord: MealRecord?
    public let isReviewNeeded: Bool
    public let isRecoverableDraft: Bool

    public init(
        dialog: String,
        draftRecord: MealRecord? = nil,
        isReviewNeeded: Bool = false,
        isRecoverableDraft: Bool = false
    ) {
        self.dialog = dialog
        self.draftRecord = draftRecord
        self.isReviewNeeded = isReviewNeeded
        self.isRecoverableDraft = isRecoverableDraft
    }

    public static func == (lhs: LogMealOutcome, rhs: LogMealOutcome) -> Bool {
        lhs.dialog == rhs.dialog &&
        lhs.draftRecord?.id == rhs.draftRecord?.id &&
        lhs.isReviewNeeded == rhs.isReviewNeeded &&
        lhs.isRecoverableDraft == rhs.isRecoverableDraft
    }
}

// MARK: - LogMealIntentHandler (Injectable Coordinator)

@MainActor
public enum LogMealIntentHandler {
    public static func handle(
        mealDescription: String,
        aiProvider: (any AIProvider)? = nil,
        storageService: MealStorageService? = nil,
        date: Date = Date()
    ) async -> LogMealOutcome {
        let storageService = storageService ?? .shared
        let trimmed = mealDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return LogMealOutcome(
                dialog: "⚠️ Будь ласка, вкажи що саме ти з'їв.",
                draftRecord: nil,
                isReviewNeeded: false,
                isRecoverableDraft: false
            )
        }

        let dietaryDate = FoodPrompt.dietaryDate(for: date)

        // 1. Durable draft persistence (<0.2s) in MealStorageService
        let pending = storageService.insertOptimisticPending(
            name: trimmed,
            dietaryDate: dietaryDate,
            provenance: "shortcuts"
        )

        let provider = aiProvider ?? AppEnvironment.current.aiProvider

        // 2. AI Nutrition Analysis
        do {
            let nutrition = try await provider.analyzeFoodDescription(trimmed)

            // AI Succeeded: update draft to review-needed state.
            // NOT auto-confirmed and NOT exported to HealthKit until reviewed.
            let context = LifecoreDataStore.shared.context
            let descriptor = FetchDescriptor<MealEntity>(
                predicate: #Predicate { $0.id == pending.id }
            )
            if let entity = try? context.fetch(descriptor).first {
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

                entity.lifecycleState = .review
                entity.isOptimisticPending = true
                entity.syncedToCloud = false
                entity.revision += 1
                entity.updatedAt = Date()
                try? context.save()
                storageService.loadMealsFromSwiftData()
            }

            let summary = "🔍 Проаналізовано (потребує підтвердження в Lifecore): \(nutrition.mealName) — \(Int(nutrition.kcal)) ккал (Б: \(Int(nutrition.protein))г, Ж: \(Int(nutrition.fat))г, В: \(Int(nutrition.carbs))г)"
            let record = storageService.allMeals.first(where: { $0.id == pending.id })
            return LogMealOutcome(
                dialog: summary,
                draftRecord: record,
                isReviewNeeded: true,
                isRecoverableDraft: false
            )
        } catch {
            // AI Failed (missing key, offline, or cascade error):
            // Persist as a recoverable text draft.
            // NEVER claim "Записано" or "Страву збережено" as confirmed!
            let context = LifecoreDataStore.shared.context
            let descriptor = FetchDescriptor<MealEntity>(
                predicate: #Predicate { $0.id == pending.id }
            )
            if let entity = try? context.fetch(descriptor).first {
                entity.lifecycleState = .draft
                entity.isOptimisticPending = true
                try? context.save()
                storageService.loadMealsFromSwiftData()
            }

            let failureDialog = "⚠️ Не вдалося розпізнати страву зараз. Чернетку збережено в Lifecore для повтору."
            let record = storageService.allMeals.first(where: { $0.id == pending.id })
            return LogMealOutcome(
                dialog: failureDialog,
                draftRecord: record,
                isReviewNeeded: false,
                isRecoverableDraft: true
            )
        }
    }
}

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
        let outcome = await LogMealIntentHandler.handle(mealDescription: mealDescription)
        return .result(dialog: IntentDialog(stringLiteral: outcome.dialog))
    }
}
