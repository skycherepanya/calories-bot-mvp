import XCTest
import SwiftData
@testable import Lifecore

// MARK: - Test Doubles

@MainActor
final class FlowMockAIProvider: AIProvider, @unchecked Sendable {
    let isMock: Bool = true
    var shouldFail: Bool = false
    var failureError: Error = NSError(domain: "FlowMockAI", code: 500, userInfo: [NSLocalizedDescriptionKey: "AI service unreachable"])
    var nextNutrition: MealNutrition? = nil
    var callCount: Int = 0
    var lastPreservedText: String? = nil
    var lastPreservedData: Data? = nil

    func analyzeFoodDescription(_ text: String) async throws -> MealNutrition {
        try await analyzeFood(imageJpegData: nil, textDescription: text)
    }

    func analyzeFood(imageJpegData: Data?, textDescription: String?) async throws -> MealNutrition {
        callCount += 1
        lastPreservedText = textDescription
        lastPreservedData = imageJpegData

        if shouldFail {
            throw failureError
        }

        if let next = nextNutrition {
            return next
        }

        return MealNutrition(
            mealName: textDescription ?? "Гречка з куркою",
            kcal: 450.0, // Buffered (+12.5% applied deterministically from 400.0 exact)
            protein: 35.0,
            fat: 10.0,
            carbs: 45.0,
            weightG: 320.0,
            confidence: 0.92,
            tags: ["whole_food", "solid"]
        )
    }

    func generateDebrief(dossier: AssembledHealthDossier) async throws -> StructuredWorkoutDebrief {
        fatalError("generateDebrief is unused in nutrition flow tests")
    }
}

@MainActor
final class FlowMockHealthProvider: HealthDataProvider, @unchecked Sendable {
    let isMock: Bool = true
    var savedMealsCount: Int = 0
    var deletedMealsCount: Int = 0
    var lastSavedMeal: MealRecord? = nil

    func requestAuthorization() async throws {}

    func saveMeal(id: UUID, name: String, calories: Double, proteinGrams: Double, fatGrams: Double, carbsGrams: Double, sodiumMg: Double, date: Date) async throws {
        savedMealsCount += 1
    }

    func saveMeal(meal: MealRecord) async throws {
        savedMealsCount += 1
        lastSavedMeal = meal
    }

    func deleteMeal(mealId: UUID) async throws {
        deletedMealsCount += 1
    }
}

// MARK: - Nutrition Flow Integration Tests

@MainActor
final class NutritionFlowTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        MealStorageService.shared.simulatedSaveError = nil
    }

    override func tearDown() async throws {
        MealStorageService.shared.simulatedSaveError = nil
        try await super.tearDown()
    }

    // MARK: - Test (a): Draft -> Analyzing -> Review -> Confirmed Lifecycle

    func testDraftAnalyzingReviewConfirmedLifecycleWritesZeroBeforeAndOneAfter() async throws {
        let mockAI = FlowMockAIProvider()
        let mockHealth = FlowMockHealthProvider()
        let storage = MealStorageService.shared
        storage.simulatedSaveError = nil

        let initialMealsCount = storage.allMeals.count
        let initialPendingOps = (try? SyncOutbox.shared.fetchPendingOperations().count) ?? 0
        let initialHKWrites = mockHealth.savedMealsCount

        let viewModel = NutritionViewModel(
            aiProvider: mockAI,
            storage: storage,
            healthProvider: mockHealth
        )

        let testImageData = "dummy_image_data_payload".data(using: .utf8)
        let testInputText = "Гречка з курячим філе 300г"

        // 1. Enter draft state
        viewModel.startDraft(text: testInputText, imageData: testImageData)
        XCTAssertEqual(
            viewModel.captureState,
            .draft(text: testInputText, imageData: testImageData)
        )

        // Invariant: ZERO storage/outbox/HK writes in draft state
        XCTAssertEqual(storage.allMeals.count, initialMealsCount)
        XCTAssertEqual((try? SyncOutbox.shared.fetchPendingOperations().count) ?? 0, initialPendingOps)
        XCTAssertEqual(mockHealth.savedMealsCount, initialHKWrites)

        // 2. Perform AI Analysis
        await viewModel.analyze(text: testInputText, imageData: testImageData)

        guard case .review(let draft) = viewModel.captureState else {
            XCTFail("Expected .review state, got: \(viewModel.captureState)")
            return
        }

        // Verify single deterministic +12.5% buffer semantics
        XCTAssertEqual(draft.mealName, testInputText)
        XCTAssertEqual(draft.kcal, 450.0, accuracy: 0.001)
        XCTAssertEqual(draft.kcalExact, 400.0, accuracy: 0.001)
        XCTAssertEqual(draft.protein, 35.0, accuracy: 0.001)
        XCTAssertEqual(draft.fat, 10.0, accuracy: 0.001)
        XCTAssertEqual(draft.carbs, 45.0, accuracy: 0.001)
        XCTAssertEqual(draft.tags, ["whole_food", "solid"])
        XCTAssertEqual(draft.preservedText, testInputText)
        XCTAssertEqual(draft.preservedImageData, testImageData)

        // CRITICAL INVARIANT: ZERO storage/outbox/HK writes prior to explicit confirm!
        XCTAssertEqual(
            storage.allMeals.count,
            initialMealsCount,
            "Must NOT write meal to storage before explicit confirm"
        )
        XCTAssertEqual(
            (try? SyncOutbox.shared.fetchPendingOperations().count) ?? 0,
            initialPendingOps,
            "Must NOT enqueue outbox sync intent before explicit confirm"
        )
        XCTAssertEqual(
            mockHealth.savedMealsCount,
            initialHKWrites,
            "Must NOT write to HealthKit before explicit confirm"
        )

        // 3. User explicitly confirms the review draft
        let confirmedMeal = try await viewModel.confirmReview()

        // Verify transition to .idle on success
        XCTAssertEqual(viewModel.captureState, .idle)
        XCTAssertNil(viewModel.errorMessage)

        // Invariant: Exactly 1 storage write, 1 HK export write, and outbox op enqueued
        XCTAssertEqual(
            storage.allMeals.count,
            initialMealsCount + 1,
            "Storage must have exactly 1 newly confirmed meal"
        )
        XCTAssertTrue(
            storage.allMeals.contains(where: { $0.id == confirmedMeal.id }),
            "Confirmed meal must exist in active allMeals"
        )
        XCTAssertEqual(confirmedMeal.kcal, 450.0)

        let pendingOps = try SyncOutbox.shared.fetchPendingOperations()
        XCTAssertTrue(
            pendingOps.contains(where: { $0.entityID == confirmedMeal.id && $0.operationKind == "upsert" }),
            "Outbox must hold an upsert operation for the confirmed meal"
        )

        XCTAssertEqual(
            mockHealth.savedMealsCount,
            initialHKWrites + 1,
            "HealthKit must record exactly 1 meal write after confirmation"
        )
        XCTAssertEqual(mockHealth.lastSavedMeal?.id, confirmedMeal.id)

        // Clean up
        try? storage.deleteMeal(id: confirmedMeal.id)
    }

    // MARK: - Test (b): Analyzing -> Failed -> Retry Preserving Text & Image

    func testAnalyzingFailedPreservesRawDataAndRetrySucceeds() async throws {
        let mockAI = FlowMockAIProvider()
        mockAI.shouldFail = true
        let mockHealth = FlowMockHealthProvider()
        let storage = MealStorageService.shared
        let initialMealsCount = storage.allMeals.count

        let viewModel = NutritionViewModel(
            aiProvider: mockAI,
            storage: storage,
            healthProvider: mockHealth
        )

        let testImageData = "sample_preserved_jpeg_bytes".data(using: .utf8)!
        let testInputText = "Омлет із 3 яєць зі шпинатом"

        // 1. Analyze triggers failure
        await viewModel.analyze(text: testInputText, imageData: testImageData)

        guard case .failed(let messageUk, let preservedText, let preservedImageData) = viewModel.captureState else {
            XCTFail("Expected .failed state, got: \(viewModel.captureState)")
            return
        }

        XCTAssertEqual(preservedText, testInputText)
        XCTAssertEqual(preservedImageData, testImageData)
        XCTAssertTrue(messageUk.contains("AI service unreachable"))
        XCTAssertNotNil(viewModel.errorMessage)

        // CRITICAL: No fabricated offline fallback meal inserted into storage!
        XCTAssertEqual(
            storage.allMeals.count,
            initialMealsCount,
            "No fabricated fallback meals may be auto-inserted on AI failure"
        )

        // 2. Clear failure condition and retry
        mockAI.shouldFail = false
        await viewModel.retryLastAnalysis()

        XCTAssertEqual(mockAI.callCount, 2, "Retry must re-invoke AI provider")
        XCTAssertEqual(mockAI.lastPreservedText, testInputText)
        XCTAssertEqual(mockAI.lastPreservedData, testImageData)

        guard case .review(let draft) = viewModel.captureState else {
            XCTFail("Expected .review state after successful retry, got: \(viewModel.captureState)")
            return
        }

        XCTAssertEqual(draft.mealName, testInputText)
        XCTAssertEqual(draft.preservedText, testInputText)
        XCTAssertEqual(draft.preservedImageData, testImageData)
        XCTAssertEqual(draft.kcal, 450.0)
    }

    // MARK: - Test (c): Review -> Cancel Leaves Zero Saved Meals

    func testReviewCancelLeavesZeroSavedMeals() async throws {
        let mockAI = FlowMockAIProvider()
        let mockHealth = FlowMockHealthProvider()
        let storage = MealStorageService.shared
        let initialMealsCount = storage.allMeals.count

        let viewModel = NutritionViewModel(
            aiProvider: mockAI,
            storage: storage,
            healthProvider: mockHealth
        )

        // Analyze food into review draft
        await viewModel.analyze(text: "Піца 4 сири 250г", imageData: nil)

        guard case .review = viewModel.captureState else {
            XCTFail("Expected .review state, got: \(viewModel.captureState)")
            return
        }

        // User discards / cancels
        viewModel.cancelCapture()

        XCTAssertEqual(viewModel.captureState, .idle)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(
            storage.allMeals.count,
            initialMealsCount,
            "Cancelling review must leave 0 meals saved in persistent storage"
        )
        XCTAssertEqual(mockHealth.savedMealsCount, 0)
    }

    // MARK: - Test (d): Delete -> Undo Preserves UUID & Increments Revision

    func testDeleteAndUndoPreservesUUIDAndAdvancesRevision() async throws {
        let mockAI = FlowMockAIProvider()
        let mockHealth = FlowMockHealthProvider()
        let storage = MealStorageService.shared
        storage.simulatedSaveError = nil

        let viewModel = NutritionViewModel(
            aiProvider: mockAI,
            storage: storage,
            healthProvider: mockHealth
        )

        // Create and confirm a meal
        await viewModel.analyze(text: "Сирники з ягодами 200г", imageData: nil)
        let meal = try await viewModel.confirmReview()
        let mealId = meal.id

        XCTAssertTrue(storage.allMeals.contains(where: { $0.id == mealId }))

        let descriptor = FetchDescriptor<MealEntity>(
            predicate: #Predicate { $0.id == mealId }
        )
        guard let initialEntity = try LifecoreDataStore.shared.context.fetch(descriptor).first else {
            XCTFail("Entity not found in context")
            return
        }
        let initialRevision = initialEntity.revision

        // 1. Delete meal
        try viewModel.deleteMeal(meal)
        await Task.yield()

        XCTAssertFalse(
            storage.allMeals.contains(where: { $0.id == mealId }),
            "Deleted meal must be removed from active allMeals"
        )
        XCTAssertEqual(viewModel.recentlyDeletedMeal?.id, mealId)
        XCTAssertEqual(mockHealth.deletedMealsCount, 1)

        let deletedEntity = try LifecoreDataStore.shared.context.fetch(descriptor).first
        XCTAssertEqual(deletedEntity?.isDeleted, true)
        XCTAssertEqual(deletedEntity?.lifecycleState, .cancelled)
        XCTAssertEqual(
            deletedEntity?.revision,
            initialRevision + 1,
            "Deleting meal must advance revision"
        )

        // 2. Undo deletion
        try viewModel.undoDelete()

        XCTAssertTrue(
            storage.allMeals.contains(where: { $0.id == mealId }),
            "Restored meal must reappear in active allMeals"
        )
        XCTAssertNil(viewModel.recentlyDeletedMeal)

        let restoredEntity = try LifecoreDataStore.shared.context.fetch(descriptor).first
        XCTAssertEqual(restoredEntity?.id, mealId, "UUID must be strictly preserved across delete & undo")
        XCTAssertEqual(restoredEntity?.isDeleted, false)
        XCTAssertEqual(restoredEntity?.lifecycleState, .confirmed)
        XCTAssertEqual(
            restoredEntity?.revision,
            initialRevision + 2,
            "Restoring meal must advance revision again"
        )

        // Clean up
        try? storage.deleteMeal(id: mealId)
    }

    // MARK: - Test (e): Simulated Save Failure on Delete/Confirm Rolls Back Visible State

    func testSimulatedSaveFailureOnDeleteAndConfirmRollsBackVisibleSuccessState() async throws {
        let mockAI = FlowMockAIProvider()
        let mockHealth = FlowMockHealthProvider()
        let storage = MealStorageService.shared
        storage.simulatedSaveError = nil

        let viewModel = NutritionViewModel(
            aiProvider: mockAI,
            storage: storage,
            healthProvider: mockHealth
        )

        let diskFullError = NSError(
            domain: "SwiftDataDomain",
            code: 999,
            userInfo: [NSLocalizedDescriptionKey: "Disk quota exceeded"]
        )

        // Subtest 1: Confirm review failure
        await viewModel.analyze(text: "Паста Карбонара 300г", imageData: nil)
        guard case .review(let draft) = viewModel.captureState else {
            XCTFail("Expected .review state")
            return
        }

        storage.simulatedSaveError = diskFullError

        do {
            _ = try await viewModel.confirmReview()
            XCTFail("confirmReview must throw PersistenceError when persistence fails")
        } catch {
            guard case PersistenceError.saveFailed(let reason) = error else {
                XCTFail("Expected PersistenceError.saveFailed, got: \(error)")
                return
            }
            XCTAssertTrue(reason.contains("Disk quota exceeded"))
        }

        // Visible review state must be preserved, NOT falsely closed!
        XCTAssertEqual(
            viewModel.captureState,
            .review(draft),
            "Failed save must NOT falsely close review draft"
        )
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(
            storage.allMeals.contains(where: { $0.name == "Паста Карбонара 300г" }),
            "Meal must not be added to active storage on failure"
        )

        // Clear failure and verify normal confirm succeeds
        storage.simulatedSaveError = nil
        let savedMeal = try await viewModel.confirmReview()
        XCTAssertEqual(viewModel.captureState, .idle)
        XCTAssertTrue(storage.allMeals.contains(where: { $0.id == savedMeal.id }))

        // Subtest 2: Delete failure
        storage.simulatedSaveError = diskFullError

        do {
            try viewModel.deleteMeal(savedMeal)
            XCTFail("deleteMeal must throw PersistenceError when persistence fails")
        } catch {
            guard case PersistenceError.saveFailed(let reason) = error else {
                XCTFail("Expected PersistenceError.saveFailed, got: \(error)")
                return
            }
            XCTAssertTrue(reason.contains("Disk quota exceeded"))
        }

        // Meal must NOT be removed from storage or show false success
        XCTAssertTrue(
            storage.allMeals.contains(where: { $0.id == savedMeal.id }),
            "Failed delete must NOT produce false positive UI acknowledgment"
        )
        XCTAssertNil(
            viewModel.recentlyDeletedMeal,
            "recentlyDeletedMeal must remain nil if delete failed"
        )
        XCTAssertNotNil(viewModel.errorMessage)

        // Clear failure and complete clean deletion
        storage.simulatedSaveError = nil
        try viewModel.deleteMeal(savedMeal)
        XCTAssertFalse(storage.allMeals.contains(where: { $0.id == savedMeal.id }))
    }
}
