import XCTest
import SwiftData
@testable import Lifecore

// MARK: - Test Doubles (@MainActor final class conforming to Lifecore protocols)

@MainActor
final class FailingMockAIProvider: AIProvider {
    let isMock: Bool = true
    let simulatedError: Error

    init(simulatedError: Error = GeminiServiceError.missingAPIKey) {
        self.simulatedError = simulatedError
    }

    func analyzeFoodDescription(_ text: String) async throws -> MealNutrition {
        throw simulatedError
    }

    func analyzeFood(imageJpegData: Data?, textDescription: String?) async throws -> MealNutrition {
        throw simulatedError
    }

    func generateDebrief(dossier: AssembledHealthDossier) async throws -> StructuredWorkoutDebrief {
        throw simulatedError
    }
}

@MainActor
final class SuccessfulMockAIProvider: AIProvider {
    let isMock: Bool = true
    let nutrition: MealNutrition

    init(nutrition: MealNutrition) {
        self.nutrition = nutrition
    }

    func analyzeFoodDescription(_ text: String) async throws -> MealNutrition {
        nutrition
    }

    func analyzeFood(imageJpegData: Data?, textDescription: String?) async throws -> MealNutrition {
        nutrition
    }

    func generateDebrief(dossier: AssembledHealthDossier) async throws -> StructuredWorkoutDebrief {
        StructuredWorkoutDebrief(
            headlineUk: "Аналіз",
            regimeBadgeUk: "Аеробна база",
            regimeTone: "teal",
            executionAnalysisUk: "Темп і пульс стабільні.",
            benchmarkComparisonUk: "Форма на рівні попередніх сесій.",
            rootCauseAndDirectiveUk: "Повноцінне відновлення.",
            evidencePills: [],
            followUpQuestionsUk: []
        )
    }
}

@MainActor
final class MockIntentHealthProvider: HealthDataProvider {
    let isMock: Bool = true
    var shouldFailAuth: Bool = false

    init(shouldFailAuth: Bool = false) {
        self.shouldFailAuth = shouldFailAuth
    }

    func requestAuthorization() async throws {
        if shouldFailAuth {
            throw NSError(
                domain: "com.lifecore.healthkit",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "HealthKit authorization restricted"]
            )
        }
    }

    func saveMeal(id: UUID, name: String, calories: Double, proteinGrams: Double, fatGrams: Double, carbsGrams: Double, sodiumMg: Double, date: Date) async throws {}
    func saveMeal(meal: MealRecord) async throws {}
    func deleteMeal(mealId: UUID) async throws {}
}

@MainActor
final class MockOfflineCloudSyncTransport: CloudSyncTransport {
    func pushMeal(_ dto: MealCloudDTO, expectedServerRevision: Int?) async throws -> MealCloudDTO {
        throw CloudSyncTransportError.networkUnavailable("The Internet connection appears to be offline.")
    }

    func pushWorkoutAnalysis(_ dto: WorkoutAnalysisCloudDTO, expectedServerRevision: Int?) async throws -> WorkoutAnalysisCloudDTO {
        throw CloudSyncTransportError.networkUnavailable("The Internet connection appears to be offline.")
    }

    func fetchMealsPage(userId: Int64, since: Date?, cursor: String?, limit: Int) async throws -> CloudPage<MealCloudDTO> {
        throw CloudSyncTransportError.networkUnavailable("The Internet connection appears to be offline.")
    }

    func fetchWorkoutAnalysesPage(userId: Int64, since: Date?, cursor: String?, limit: Int) async throws -> CloudPage<WorkoutAnalysisCloudDTO> {
        throw CloudSyncTransportError.networkUnavailable("The Internet connection appears to be offline.")
    }
}

// MARK: - IntentOutcomeTests

@MainActor
final class IntentOutcomeTests: XCTestCase {

    private var isolatedContainer: ModelContainer!
    private var isolatedContext: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        let fixture = AppEnvironment.fixture()
        AppEnvironment.current = fixture
        isolatedContainer = fixture.modelContainer
        isolatedContext = ModelContext(isolatedContainer)
    }

    override func tearDown() async throws {
        AccountSessionManager.shared.signOut(in: isolatedContext)
        isolatedContext = nil
        isolatedContainer = nil
        AppEnvironment.reset()
        try await super.tearDown()
    }

    // MARK: - 1. LogMealIntent AI Failure -> Retry Dialog & Zero Confirmed Meals

    func testLogMealIntentAIErrorProducesRetryDialogAndNoConfirmedMeals() async {
        let failingAI = FailingMockAIProvider(simulatedError: GeminiServiceError.missingAPIKey)
        let storage = MealStorageService.shared

        let outcome = await LogMealIntentHandler.handle(
            mealDescription: "Паста з тунцем та томатами",
            aiProvider: failingAI,
            storageService: storage
        )

        // Truthful failure dialog
        XCTAssertEqual(
            outcome.dialog,
            "⚠️ Не вдалося розпізнати страву зараз. Чернетку збережено в Lifecore для повтору."
        )
        XCTAssertFalse(outcome.dialog.contains("✅ Записано"))
        XCTAssertFalse(outcome.dialog.contains("✅ Страву збережено"))

        // Outcome classification
        XCTAssertTrue(outcome.isRecoverableDraft)
        XCTAssertFalse(outcome.isReviewNeeded)

        // Draft was durably persisted in pending/draft state, NOT confirmed
        guard let draft = outcome.draftRecord else {
            XCTFail("Draft record should have been persisted")
            return
        }
        XCTAssertTrue(draft.isOptimisticPending, "Draft meal must remain optimistic pending / unconfirmed")
        XCTAssertEqual(draft.name, "Паста з тунцем та томатами")

        // Assert swiftdata entity has draft status
        let descriptor = FetchDescriptor<MealEntity>(
            predicate: #Predicate { $0.id == draft.id }
        )
        if let entity = try? isolatedContext.fetch(descriptor).first {
            XCTAssertEqual(entity.lifecycleState, .draft)
            XCTAssertTrue(entity.isOptimisticPending)
        }
    }

    // MARK: - 2. LogMealIntent AI Success -> Review-Needed Dialog Without HK Write

    func testLogMealIntentSuccessProducesReviewNeededDialogWithoutHealthKitWrite() async {
        let nutrition = MealNutrition(
            mealName: "Вівсянка з ягодами та горіхами",
            kcal: 383, // includes +12.5% buffer
            protein: 14.0,
            fat: 9.0,
            carbs: 52.0,
            weightG: 320,
            confidence: 0.94,
            tags: ["whole_food", "solid"],
            micronutrients: nil,
            aminoAcids: nil
        )
        let successfulAI = SuccessfulMockAIProvider(nutrition: nutrition)
        let storage = MealStorageService.shared

        let outcome = await LogMealIntentHandler.handle(
            mealDescription: "вівсянка з ягодами",
            aiProvider: successfulAI,
            storageService: storage
        )

        // Truthful review-needed dialog
        XCTAssertTrue(
            outcome.dialog.contains("🔍 Проаналізовано (потребує підтвердження в Lifecore): Вівсянка з ягодами та горіхами"),
            "Dialog must specify review needed: \(outcome.dialog)"
        )
        XCTAssertTrue(outcome.dialog.contains("383 ккал"))
        XCTAssertFalse(outcome.dialog.contains("✅ Записано"))

        // Outcome flags
        XCTAssertTrue(outcome.isReviewNeeded)
        XCTAssertFalse(outcome.isRecoverableDraft)

        // Draft state check: must be in review state, NOT auto-confirmed
        guard let draft = outcome.draftRecord else {
            XCTFail("Draft record expected")
            return
        }
        XCTAssertTrue(draft.isOptimisticPending, "Must remain optimistic/unconfirmed until user finalizes in UI")
        XCTAssertEqual(draft.name, "Вівсянка з ягодами та горіхами")
        XCTAssertEqual(draft.kcal, 383)
    }

    // MARK: - 3. LogMealIntent Empty Input Validation

    func testLogMealIntentEmptyDescriptionReturnsValidationWarning() async {
        let outcome = await LogMealIntentHandler.handle(
            mealDescription: "   \n  "
        )
        XCTAssertEqual(outcome.dialog, "⚠️ Будь ласка, вкажи що саме ти з'їв.")
        XCTAssertNil(outcome.draftRecord)
        XCTAssertFalse(outcome.isReviewNeeded)
        XCTAssertFalse(outcome.isRecoverableDraft)
    }

    // MARK: - 4. LifecoreSyncIntent Offline/Queued Partial Sync

    func testLifecoreSyncIntentOfflinePartialSyncProducesQueuedDialog() async throws {
        // Enqueue an outbox operation that fails with network unavailable
        try SyncOutbox.shared.enqueue(
            entityID: UUID(),
            entityType: "meal",
            operationKind: "upsert",
            revision: 1,
            payloadJson: "{}",
            in: isolatedContext
        )

        let offlineTransport = MockOfflineCloudSyncTransport()
        let coordinator = SyncCoordinator(
            userId: 472025574,
            transport: offlineTransport,
            context: isolatedContext
        )

        let outcome = await LifecoreSyncIntentHandler.handle(
            healthProvider: MockIntentHealthProvider(),
            syncRunner: { await coordinator.flushOutbox() }
        )

        // Truthful queued offline dialog (NEVER claims fake clean synced when changes remain pending)
        XCTAssertTrue(
            outcome.dialog.contains("⏳ Зміни збережено в черзі Lifecore (очікують мережі)...")
                || outcome.isQueuedOffline
        )
    }

    // MARK: - 5. LifecoreSyncIntent Expired/Missing Auth

    func testLifecoreSyncIntentExpiredAuthProducesAuthDialog() async {
        let expiredSession = SessionState(
            authUserID: UUID(),
            accessToken: "expired_token",
            expiresAt: Date().addingTimeInterval(-100)
        )
        AccountSessionManager.shared.setSession(expiredSession)

        let outcome = await LifecoreSyncIntentHandler.handle(
            healthProvider: MockIntentHealthProvider(),
            syncService: SupabaseSyncService.shared
        )

        XCTAssertTrue(
            outcome.dialog.contains("Необхідно увійти в обліковий запис Lifecore"),
            "Expected auth warning dialog, got: \(outcome.dialog)"
        )
        XCTAssertTrue(outcome.isAuthError)
        XCTAssertFalse(outcome.isCleanSync)
    }

    // MARK: - 6. LifecoreSyncIntent Clean Sync

    func testLifecoreSyncIntentCleanSyncProducesSuccessDialog() async {
        AccountSessionManager.shared.signOut(in: isolatedContext)

        let outcome = await LifecoreSyncIntentHandler.handle(
            healthProvider: MockIntentHealthProvider(),
            syncService: SupabaseSyncService.shared
        )

        XCTAssertTrue(
            outcome.dialog.contains("✅ Lifecore синхронізовано"),
            "Expected clean sync dialog, got: \(outcome.dialog)"
        )
        XCTAssertTrue(outcome.isCleanSync)
        XCTAssertFalse(outcome.isAuthError)
        XCTAssertFalse(outcome.isQueuedOffline)
    }
}
