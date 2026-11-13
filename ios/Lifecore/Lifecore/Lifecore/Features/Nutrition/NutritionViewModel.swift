import Foundation
import SwiftUI
import Combine

// MARK: - Meal Capture State

public enum MealCaptureState: Equatable, Sendable {
    case idle
    case draft(text: String, imageData: Data?)
    case analyzing(text: String, imageData: Data?)
    case review(MealReviewDraft)
    case failed(messageUk: String, preservedText: String, preservedImageData: Data?)
}

// MARK: - Meal Review Draft

public struct MealReviewDraft: Equatable, Sendable {
    public var mealName: String
    /// Buffered calories with the deterministic +12.5% safety buffer applied.
    public var kcal: Double
    /// Unbuffered raw exact calorie estimate.
    public var kcalExact: Double
    public var protein: Double
    public var fat: Double
    public var carbs: Double
    public var weightG: Double?
    public var confidence: Double?
    public var tags: [String]
    public var micronutrients: Micronutrients?
    public var aminoAcids: AminoAcids?
    public var preservedText: String?
    public var preservedImageData: Data?

    public init(
        mealName: String = "",
        kcalExact: Double = 0,
        kcal: Double? = nil,
        protein: Double = 0,
        fat: Double = 0,
        carbs: Double = 0,
        weightG: Double? = nil,
        confidence: Double? = nil,
        tags: [String] = ["whole_food", "solid"],
        micronutrients: Micronutrients? = nil,
        aminoAcids: AminoAcids? = nil,
        preservedText: String? = nil,
        preservedImageData: Data? = nil
    ) {
        self.mealName = mealName
        self.kcalExact = max(0, kcalExact)
        // Deterministically apply +12.5% deficit buffer if not explicitly passed
        self.kcal = kcal ?? round(max(0, kcalExact) * 1.125)
        self.protein = max(0, protein)
        self.fat = max(0, fat)
        self.carbs = max(0, carbs)
        self.weightG = weightG.map { max(0, $0) }
        self.confidence = confidence
        self.tags = NutritionNormalizer.normalizeTags(tags)
        self.micronutrients = micronutrients
        self.aminoAcids = aminoAcids
        self.preservedText = preservedText
        self.preservedImageData = preservedImageData
    }

    /// Creates draft from already normalized `MealNutrition` (which already carries the buffered `kcal`).
    public init(
        nutrition: MealNutrition,
        preservedText: String? = nil,
        preservedImageData: Data? = nil
    ) {
        self.mealName = nutrition.mealName
        self.kcal = nutrition.kcal
        // Unbuffered base exact estimate derived from buffered kcal
        self.kcalExact = round(nutrition.kcal / 1.125)
        self.protein = nutrition.protein
        self.fat = nutrition.fat
        self.carbs = nutrition.carbs
        self.weightG = nutrition.weightG
        self.confidence = nutrition.confidence
        self.tags = NutritionNormalizer.normalizeTags(nutrition.tags)
        self.micronutrients = nutrition.micronutrients
        self.aminoAcids = nutrition.aminoAcids
        self.preservedText = preservedText
        self.preservedImageData = preservedImageData
    }

    /// Mutates exact calories and updates buffered calories deterministically (+12.5%).
    public mutating func updateKcalExact(_ newExact: Double) {
        let nonNeg = max(0, newExact)
        self.kcalExact = nonNeg
        self.kcal = round(nonNeg * 1.125)
    }

    /// Mutates buffered calories and back-derives the exact base.
    public mutating func updateBufferedKcal(_ newBuffered: Double) {
        let nonNeg = max(0, newBuffered)
        self.kcal = nonNeg
        self.kcalExact = round(nonNeg / 1.125)
    }

    /// Converts the draft to an immutable `MealNutrition` model for persistent storage.
    public func toMealNutrition() -> MealNutrition {
        MealNutrition(
            mealName: mealName.trimmingCharacters(in: .whitespacesAndNewlines),
            kcal: kcal,
            protein: protein,
            fat: fat,
            carbs: carbs,
            weightG: weightG,
            confidence: confidence,
            tags: NutritionNormalizer.normalizeTags(tags),
            micronutrients: micronutrients,
            aminoAcids: aminoAcids
        )
    }
}

// MARK: - Nutrition View Model

@MainActor
public final class NutritionViewModel: ObservableObject {
    @Published public var captureState: MealCaptureState = .idle
    @Published public var selectedDietaryDate: String
    @Published public var recentlyDeletedMeal: MealRecord? = nil
    @Published public var errorMessage: String? = nil

    public let aiProvider: AIProvider
    public let storage: MealStorageService
    public let healthProvider: HealthDataProvider

    private var cancellables = Set<AnyCancellable>()
    private var undoDismissTask: Task<Void, Never>? = nil

    public init(
        aiProvider: AIProvider = AppEnvironment.current.aiProvider,
        storage: MealStorageService = .shared,
        healthProvider: HealthDataProvider = AppEnvironment.current.healthProvider,
        initialDate: Date = Date()
    ) {
        self.aiProvider = aiProvider
        self.storage = storage
        self.healthProvider = healthProvider
        self.selectedDietaryDate = FoodPrompt.dietaryDate(for: initialDate, offsetDays: 0)

        // Observe storage mutations to keep UI reactively fresh
        storage.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Query Accessors

    public var selectedDietaryDay: DietaryDay {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if let d = formatter.date(from: selectedDietaryDate) {
            let midday = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: d) ?? d
            return DietaryDay.containing(midday, calendar: .current)
        }
        return DietaryDay.containing(Date(), calendar: .current)
    }

    public var currentMeals: [MealRecord] {
        storage.meals(for: selectedDietaryDate)
    }

    public var confirmedMeals: [MealRecord] {
        currentMeals.filter { !$0.isOptimisticPending }
    }

    public var dailyTotals: (kcal: Double, protein: Double, fat: Double, carbs: Double, sodiumMg: Double, leucineG: Double, wholeFoodCount: Int, ultraProcessedCount: Int) {
        storage.dailyTotals(for: selectedDietaryDate)
    }

    public var isDayEmpty: Bool {
        confirmedMeals.isEmpty
    }

    // MARK: - Date Navigation

    public var canGoNext: Bool {
        let today = FoodPrompt.dietaryDate(for: Date(), offsetDays: 0)
        return selectedDietaryDate < today
    }

    public var isYesterdaySelected: Bool {
        let yesterday = FoodPrompt.dietaryDate(for: Date(), offsetDays: -1)
        return selectedDietaryDate == yesterday
    }

    public func previousDay() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if let d = formatter.date(from: selectedDietaryDate),
           let prev = Calendar.current.date(byAdding: .day, value: -1, to: d) {
            selectedDietaryDate = formatter.string(from: prev)
        }
    }

    public func nextDay() {
        guard canGoNext else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if let d = formatter.date(from: selectedDietaryDate),
           let next = Calendar.current.date(byAdding: .day, value: 1, to: d) {
            selectedDietaryDate = formatter.string(from: next)
        }
    }

    public func toggleYesterdayFastLog() {
        let today = FoodPrompt.dietaryDate(for: Date(), offsetDays: 0)
        let yesterday = FoodPrompt.dietaryDate(for: Date(), offsetDays: -1)
        if selectedDietaryDate == yesterday {
            selectedDietaryDate = today
        } else {
            selectedDietaryDate = yesterday
        }
    }

    // MARK: - Capture & Review State Transitions

    public func startDraft(text: String = "", imageData: Data? = nil) {
        captureState = .draft(text: text, imageData: imageData)
        errorMessage = nil
    }

    public func analyze(text: String, imageData: Data?) async {
        captureState = .analyzing(text: text, imageData: imageData)
        errorMessage = nil

        do {
            let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let nutrition = try await aiProvider.analyzeFood(
                imageJpegData: imageData,
                textDescription: cleanText.isEmpty ? nil : cleanText
            )
            let draft = MealReviewDraft(
                nutrition: nutrition,
                preservedText: cleanText.isEmpty ? nil : cleanText,
                preservedImageData: imageData
            )
            captureState = .review(draft)
        } catch {
            let messageUk = "Не вдалося розпізнати страву: \(error.localizedDescription)"
            captureState = .failed(
                messageUk: messageUk,
                preservedText: text,
                preservedImageData: imageData
            )
            errorMessage = messageUk
        }
    }

    public func retryLastAnalysis() async {
        if case .failed(_, let text, let data) = captureState {
            await analyze(text: text, imageData: data)
        }
    }

    public func switchToManualEntry() {
        if case .failed(_, let text, let data) = captureState {
            let fallbackName = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Нова страва" : text
            let draft = MealReviewDraft(
                mealName: fallbackName,
                kcalExact: 0,
                kcal: 0,
                protein: 0,
                fat: 0,
                carbs: 0,
                tags: ["whole_food", "solid"],
                preservedText: text,
                preservedImageData: data
            )
            captureState = .review(draft)
            errorMessage = nil
        }
    }

    public func cancelCapture() {
        captureState = .idle
        errorMessage = nil
    }

    @discardableResult
    public func confirmReview(_ reviewDraft: MealReviewDraft? = nil) async throws -> MealRecord {
        let draft: MealReviewDraft
        if let explicit = reviewDraft {
            draft = explicit
        } else if case .review(let current) = captureState {
            draft = current
        } else {
            throw NutritionNormalizationError.malformedPayload("No draft in review state")
        }

        // 1. Strict validation of fields
        let trimmedName = draft.mealName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            let err = NutritionNormalizationError.emptyMealName
            errorMessage = err.localizedDescription
            throw err
        }
        guard draft.kcal.isFinite else {
            let err = NutritionNormalizationError.nonFiniteValue(field: "kcal")
            errorMessage = err.localizedDescription
            throw err
        }
        guard draft.kcal >= 0 else {
            let err = NutritionNormalizationError.negativeValue(field: "kcal", value: draft.kcal)
            errorMessage = err.localizedDescription
            throw err
        }
        guard draft.protein.isFinite else {
            let err = NutritionNormalizationError.nonFiniteValue(field: "protein")
            errorMessage = err.localizedDescription
            throw err
        }
        guard draft.protein >= 0 else {
            let err = NutritionNormalizationError.negativeValue(field: "protein", value: draft.protein)
            errorMessage = err.localizedDescription
            throw err
        }
        guard draft.fat.isFinite else {
            let err = NutritionNormalizationError.nonFiniteValue(field: "fat")
            errorMessage = err.localizedDescription
            throw err
        }
        guard draft.fat >= 0 else {
            let err = NutritionNormalizationError.negativeValue(field: "fat", value: draft.fat)
            errorMessage = err.localizedDescription
            throw err
        }
        guard draft.carbs.isFinite else {
            let err = NutritionNormalizationError.nonFiniteValue(field: "carbs")
            errorMessage = err.localizedDescription
            throw err
        }
        guard draft.carbs >= 0 else {
            let err = NutritionNormalizationError.negativeValue(field: "carbs", value: draft.carbs)
            errorMessage = err.localizedDescription
            throw err
        }
        if let w = draft.weightG {
            guard w.isFinite else {
                let err = NutritionNormalizationError.nonFiniteValue(field: "weight_g")
                errorMessage = err.localizedDescription
                throw err
            }
            guard w >= 0 else {
                let err = NutritionNormalizationError.negativeValue(field: "weight_g", value: w)
                errorMessage = err.localizedDescription
                throw err
            }
        }

        // 2. Simulated persistence error hook (Audit F10/F11)
        if let simulated = storage.simulatedSaveError {
            let err = PersistenceError.saveFailed(simulated.localizedDescription)
            errorMessage = err.localizedDescription
            throw err
        }

        // 3. Durable persistence via MealStorageService
        let validatedNutrition = draft.toMealNutrition()
        let provenance = draft.preservedImageData != nil ? "ai_vision" : "ai_text"
        let savedMeal = storage.addMeal(
            nutrition: validatedNutrition,
            dietaryDate: selectedDietaryDate,
            provenance: provenance
        )

        // 4. Background HealthKit export
        try? await healthProvider.saveMeal(meal: savedMeal)

        // 5. Clean up state only upon verified success
        captureState = .idle
        errorMessage = nil
        return savedMeal
    }

    // MARK: - Deletion & Undo Lifecycle

    public func deleteMeal(_ meal: MealRecord) throws {
        do {
            try storage.deleteMeal(id: meal.id)
            recentlyDeletedMeal = meal
            errorMessage = nil
            Task { [healthProvider] in
                try? await healthProvider.deleteMeal(mealId: meal.id)
            }
            scheduleUndoDismiss(for: meal.id)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    public func deleteMealSafely(_ meal: MealRecord) {
        do {
            try deleteMeal(meal)
        } catch {
            // errorMessage is surfaced
        }
    }

    public func undoDelete() throws {
        guard let meal = recentlyDeletedMeal else { return }
        do {
            let restored = try storage.undoDeleteMeal(id: meal.id)
            recentlyDeletedMeal = nil
            errorMessage = nil
            Task { [healthProvider] in
                try? await healthProvider.saveMeal(meal: restored)
            }
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    public func undoDeleteSafely() {
        do {
            try undoDelete()
        } catch {
            // errorMessage is surfaced
        }
    }

    private func scheduleUndoDismiss(for mealId: UUID) {
        undoDismissTask?.cancel()
        undoDismissTask = Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            if self.recentlyDeletedMeal?.id == mealId {
                withAnimation {
                    self.recentlyDeletedMeal = nil
                }
            }
        }
    }
}
