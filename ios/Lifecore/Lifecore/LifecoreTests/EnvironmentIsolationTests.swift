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
}
