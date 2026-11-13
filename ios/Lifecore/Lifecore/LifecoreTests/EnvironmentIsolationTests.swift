import XCTest
import SwiftData
@testable import Lifecore

@MainActor
final class EnvironmentIsolationTests: XCTestCase {

    override func tearDown() {
        AppEnvironment.reset()
        super.tearDown()
    }

    func testFixtureModeResolvesInUnitTestHost() {
        XCTAssertTrue(
            AppEnvironment.isFixtureLaunchRequested,
            "Unit tests must automatically resolve to fixture mode via XCTest environment"
        )
        let env = AppEnvironment.current
        XCTAssertEqual(env.mode, .fixture)
        XCTAssertTrue(env.isFixtureMode)
    }

    func testFixtureModeProvidesIsolatedModelContainers() throws {
        let env1 = AppEnvironment.fixture()
        let env2 = AppEnvironment.fixture()

        let context1 = ModelContext(env1.modelContainer)
        let context2 = ModelContext(env2.modelContainer)

        let meal = MealEntity(
            id: UUID(),
            name: "Isolation Meal",
            kcal: 500,
            proteinG: 30,
            fatG: 15,
            carbsG: 60,
            tags: ["solid"],
            dietaryDate: "2026-11-12",
            createdAt: Date()
        )
        context1.insert(meal)
        try context1.save()

        let fetchDescriptor = FetchDescriptor<MealEntity>()
        let mealsInContext1 = try context1.fetch(fetchDescriptor)
        let mealsInContext2 = try context2.fetch(fetchDescriptor)

        XCTAssertEqual(mealsInContext1.count, 1)
        XCTAssertEqual(mealsInContext2.count, 0, "Independent fixture containers must remain completely isolated")
    }

    func testFixtureProvidersAreDeterministicMocks() async throws {
        let env = AppEnvironment.fixture()
        XCTAssertTrue(env.healthProvider.isMock)
        XCTAssertTrue(env.aiProvider.isMock)
        XCTAssertTrue(env.syncProvider.isMock)

        guard let mockHealth = env.healthProvider as? MockHealthDataProvider else {
            XCTFail("Fixture healthProvider must be MockHealthDataProvider")
            return
        }

        try await mockHealth.requestAuthorization()
        let countBefore = await mockHealth.savedMealsCount
        XCTAssertEqual(countBefore, 0)

        let mealId = UUID()
        try await mockHealth.saveMeal(
            id: mealId,
            name: "Oatmeal",
            calories: 350,
            proteinGrams: 12,
            fatGrams: 6,
            carbsGrams: 60,
            sodiumMg: 100,
            date: Date()
        )
        let countAfterSave = await mockHealth.savedMealsCount
        XCTAssertEqual(countAfterSave, 1)

        try await mockHealth.deleteMeal(mealId: mealId)
        let countAfterDelete = await mockHealth.deletedMealsCount
        XCTAssertEqual(countAfterDelete, 1)

        // Verify deterministic offline AI output without network
        let offlineMeal = try await env.aiProvider.analyzeFoodDescription("Вівсянка з ягодами 300г")
        XCTAssertFalse(offlineMeal.mealName.isEmpty)
        XCTAssertGreaterThan(offlineMeal.kcal, 0)

        let offlineDebrief = try await env.aiProvider.generateDebrief(dossier: TestFixtures.sampleAssembledDossier())
        XCTAssertFalse(offlineDebrief.headlineUk.isEmpty)

        // Verify mock sync does not initiate network calls
        let syncedMeals = try await env.syncProvider.syncPendingMeals()
        let syncedAnalyses = try await env.syncProvider.syncPendingAnalyses()
        XCTAssertEqual(syncedMeals, 0)
        XCTAssertEqual(syncedAnalyses, 0)
    }

    func testLiveEnvironmentConstructsLiveProviders() {
        let env = AppEnvironment.live()
        XCTAssertEqual(env.mode, .live)
        XCTAssertFalse(env.isFixtureMode)
        XCTAssertFalse(env.healthProvider.isMock)
        XCTAssertFalse(env.aiProvider.isMock)
        XCTAssertFalse(env.syncProvider.isMock)
    }

    func testMockAIProviderDoesNotAccessGeminiShared() async throws {
        let countBefore = GeminiService.sharedAccessCount
        let provider = MockAIProvider()
        _ = try await provider.analyzeFoodDescription("Вівсянка з ягодами 300г")
        _ = try await provider.generateDebrief(dossier: TestFixtures.sampleAssembledDossier())
        XCTAssertEqual(
            GeminiService.sharedAccessCount,
            countBefore,
            "MockAIProvider must never access or trigger GeminiService.shared"
        )
    }

    func testMealStorageUsesFixtureContainerAndDoesNotTouchPersistentStore() throws {
        let fixtureEnv = AppEnvironment.fixture()
        AppEnvironment.current = fixtureEnv
        XCTAssertTrue(AppEnvironment.current.isFixtureMode)

        let uniqueMealName = "Fixture Isolation Meal \(UUID().uuidString)"
        let nutrition = MealNutrition(
            mealName: uniqueMealName,
            kcal: 420,
            protein: 30,
            fat: 10,
            carbs: 50,
            weightG: 300,
            confidence: 0.95,
            tags: ["whole_food"],
            micronutrients: nil,
            aminoAcids: nil
        )

        let addedRecord = MealStorageService.shared.addMeal(nutrition: nutrition, dietaryDate: "2026-11-12")

        let fixtureContext = ModelContext(fixtureEnv.modelContainer)
        let descriptor = FetchDescriptor<MealEntity>(
            predicate: #Predicate { $0.id == addedRecord.id }
        )
        let fixtureMatches = try fixtureContext.fetch(descriptor)
        XCTAssertEqual(fixtureMatches.count, 1, "Meal must be written to AppEnvironment.current.modelContainer in fixture mode")
    }

    func testFixtureModePreventsRealHealthKitWritesAndNetworkSync() async throws {
        let fixtureEnv = AppEnvironment.fixture()
        AppEnvironment.current = fixtureEnv
        XCTAssertTrue(AppEnvironment.current.isFixtureMode)

        let initialHKWrites = HealthKitManager.writeAttemptCount
        let initialHKAuths = HealthKitManager.authorizationAttemptCount
        let initialNetworkRequests = SupabaseSyncService.networkRequestAttemptCount

        // 1. Storage deletion in fixture mode must not trigger HealthKit writes
        let testMeal = MealRecord(
            name: "Test Meal",
            kcal: 300,
            proteinG: 20,
            fatG: 10,
            carbsG: 30,
            tags: [],
            dietaryDate: "2026-11-12"
        )
        try? MealStorageService.shared.deleteMeal(id: testMeal.id)
        MealStorageService.shared.restoreMeal(testMeal)

        // 2. Direct calls to HealthKit in fixture mode must safe no-op
        try await HealthKitManager.shared.requestAuthorization()
        try await HealthKitManager.shared.saveMealToHealthKit(meal: testMeal)
        try await HealthKitManager.shared.deleteMealFromHealthKit(mealId: testMeal.id)

        // 3. Direct calls to Supabase sync in fixture mode must safe no-op
        _ = try await SupabaseSyncService.shared.syncPendingMeals()
        _ = try await SupabaseSyncService.shared.syncPendingWorkoutAnalyses()

        XCTAssertEqual(
            HealthKitManager.writeAttemptCount,
            initialHKWrites,
            "HealthKit write operations must safe no-op with 0 writes in fixture mode"
        )
        XCTAssertEqual(
            HealthKitManager.authorizationAttemptCount,
            initialHKAuths,
            "HealthKit authorization requests must safe no-op in fixture mode"
        )
        XCTAssertEqual(
            SupabaseSyncService.networkRequestAttemptCount,
            initialNetworkRequests,
            "Supabase sync must produce 0 network requests in fixture mode"
        )
    }
}
