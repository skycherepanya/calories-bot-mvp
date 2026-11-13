import XCTest
import SwiftData
@testable import Lifecore

@MainActor
final class PersistenceTests: XCTestCase {

    private var isolatedContainer: ModelContainer!
    private var isolatedContext: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        let fixture = AppEnvironment.fixture()
        AppEnvironment.current = fixture
        isolatedContainer = fixture.modelContainer
        isolatedContext = ModelContext(isolatedContainer)
        MealStorageService.shared.simulatedSaveError = nil
    }

    override func tearDown() async throws {
        MealStorageService.shared.simulatedSaveError = nil
        isolatedContext = nil
        isolatedContainer = nil
        AppEnvironment.reset()
        try await super.tearDown()
    }

    // MARK: - 1. Injected Save Failure / Container Failure (Audit F10, F11)

    func testInjectedSaveFailureThrowsErrorAndPreventsFalseUIAcknowledgment() throws {
        let storage = MealStorageService.shared
        storage.simulatedSaveError = nil

        let testNutrition = MealNutrition(
            mealName: "Вівсянка перед стартом",
            kcal: 400,
            protein: 20,
            fat: 8,
            carbs: 60,
            weightG: 250,
            confidence: 0.95,
            tags: ["whole_food", "solid"]
        )

        let initialMeal = storage.addMeal(nutrition: testNutrition, dietaryDate: "2026-11-13")
        XCTAssertTrue(storage.allMeals.contains(where: { $0.id == initialMeal.id }))

        // Inject simulated failure
        let diskFullError = NSError(domain: "SwiftDataDomain", code: 999, userInfo: [NSLocalizedDescriptionKey: "Disk quota exceeded"])
        storage.simulatedSaveError = diskFullError

        // Attempt delete with injected failure
        XCTAssertThrowsError(try storage.deleteMeal(id: initialMeal.id)) { error in
            guard case PersistenceError.saveFailed(let reason) = error else {
                XCTFail("Expected PersistenceError.saveFailed, got: \(error)")
                return
            }
            XCTAssertTrue(reason.contains("Disk quota exceeded"))
        }

        // CRITICAL (Audit F10): Meal must NOT be removed from allMeals on failure!
        XCTAssertTrue(
            storage.allMeals.contains(where: { $0.id == initialMeal.id }),
            "Failed save must NOT produce false positive UI acknowledgment by removing meal from active state"
        )

        // Clear injected failure and verify clean operation
        storage.simulatedSaveError = nil
        try storage.deleteMeal(id: initialMeal.id)
        XCTAssertFalse(storage.allMeals.contains(where: { $0.id == initialMeal.id }))
    }

    func testContainerCreationPropagatesTypedError() {
        let invalidConfig = ModelConfiguration(url: URL(fileURLWithPath: "/non_existent_read_only_root/lifecore_invalid.store"))
        XCTAssertThrowsError(try PersistenceRecovery.createContainer(inMemory: false, configurations: [invalidConfig])) { error in
            guard case PersistenceError.containerUnavailable = error else {
                XCTFail("Expected PersistenceError.containerUnavailable, got \(error)")
                return
            }
        }
    }

    // MARK: - 2. Safe UserDefaults Migration (Audit F11, F25)

    func testUserDefaultsMigrationRetainsSourceOnSaveFailureAndDeduplicatesOnRetry() throws {
        let testDefaults = UserDefaults(suiteName: "PersistenceTestsMigration_\(UUID().uuidString)")!
        defer { testDefaults.removePersistentDomain(forName: testDefaults.description) }

        let testKey = "TEST_LEGACY_MEALS_KEY"
        let legacyMeal1 = MealRecord(
            id: UUID(),
            name: "Гречка з індичкою",
            kcal: 439, // Specific buffered kcal to verify preservation
            proteinG: 35,
            fatG: 7,
            carbsG: 50,
            weightG: 300,
            tags: ["whole_food"],
            dietaryDate: "2026-11-10",
            createdAt: Date()
        )
        let legacyMeal2 = MealRecord(
            id: UUID(),
            name: "Сир кисломолочний з ягодами",
            kcal: 280,
            proteinG: 30,
            fatG: 4,
            carbsG: 22,
            weightG: 200,
            tags: ["whole_food"],
            dietaryDate: "2026-11-10",
            createdAt: Date()
        )

        let initialData = try JSONEncoder().encode([legacyMeal1, legacyMeal2])
        testDefaults.set(initialData, forKey: testKey)

        // Phase A: Simulate save failure during migration
        XCTAssertThrowsError(
            try PersistenceRecovery.migrateUserDefaults(
                key: testKey,
                in: isolatedContext,
                userDefaults: testDefaults,
                testSaveOverride: {
                    throw NSError(domain: "TestDomain", code: 101, userInfo: [NSLocalizedDescriptionKey: "Simulated SQLite locked"])
                }
            )
        ) { error in
            guard case PersistenceError.saveFailed = error else {
                XCTFail("Expected PersistenceError.saveFailed, got \(error)")
                return
            }
        }

        // Assert source bytes remain 100% intact after save failure (Audit F11)
        let retainedBytes = testDefaults.data(forKey: testKey)
        XCTAssertNotNil(retainedBytes, "UserDefaults source data MUST NOT be deleted when migration fails")
        XCTAssertEqual(retainedBytes, initialData)

        // Phase B: Retry migration without failure
        let result = try PersistenceRecovery.migrateUserDefaults(
            key: testKey,
            in: isolatedContext,
            userDefaults: testDefaults
        )

        XCTAssertEqual(result.migratedCount, 2)
        XCTAssertEqual(result.skippedDuplicateCount, 0)
        XCTAssertEqual(result.verifiedCount, 2)
        XCTAssertFalse(result.sourceBytesRetained)
        XCTAssertNil(testDefaults.data(forKey: testKey), "UserDefaults source data must be purged only after verified reread")

        // Phase C: Verify preserved buffered calories (do not recalculate existing kcal)
        let descriptor = FetchDescriptor<MealEntity>(
            predicate: #Predicate { $0.id == legacyMeal1.id }
        )
        let fetched = try isolatedContext.fetch(descriptor).first
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.kcal, 439, "Preserve already-buffered calories for legacy meals without recalculation")
        XCTAssertEqual(fetched?.provenance, "legacy")
        XCTAssertEqual(fetched?.bufferVersion, 1)

        // Phase D: Rerun migration with residual data to test deduplication
        testDefaults.set(initialData, forKey: testKey)
        let retryResult = try PersistenceRecovery.migrateUserDefaults(
            key: testKey,
            in: isolatedContext,
            userDefaults: testDefaults
        )

        XCTAssertEqual(retryResult.migratedCount, 0, "No new entities should be inserted on retry")
        XCTAssertEqual(retryResult.skippedDuplicateCount, 2, "Duplicate legacy records must be skipped by stable ID")

        let allEntities = try isolatedContext.fetch(FetchDescriptor<MealEntity>())
        XCTAssertEqual(allEntities.count, 2, "SwiftData must contain exactly 2 entities without duplication")
    }

    // MARK: - 3. Seed Meal Deletion (Audit F25)

    func testSeedMealDeletionPurgesOnlyFixtureAndSeedProvenance() throws {
        let testDefaults = UserDefaults(suiteName: "PersistenceTestsSeed_\(UUID().uuidString)")!
        defer { testDefaults.removePersistentDomain(forName: testDefaults.description) }

        let sameName = "Вівсянка з бананом та протеїном"

        // 1. Legitimate user-created meal sharing the demo name
        let userMeal = MealEntity(
            id: UUID(),
            name: sameName,
            kcal: 420,
            proteinG: 30,
            fatG: 8,
            carbsG: 55,
            tags: ["whole_food"],
            dietaryDate: "2026-11-13",
            provenance: "manual" // User logged manually
        )

        // 2. Another user meal logged via camera
        let cameraMeal = MealEntity(
            id: UUID(),
            name: "Куряче філе з гречкою та огірком",
            kcal: 500,
            proteinG: 45,
            fatG: 10,
            carbsG: 50,
            tags: ["whole_food"],
            dietaryDate: "2026-11-13",
            provenance: "camera" // User scanned
        )

        // 3. Built-in legacy seed meal
        let seedMeal = MealEntity(
            id: UUID(),
            name: sameName,
            kcal: 390,
            proteinG: 34,
            fatG: 7,
            carbsG: 56,
            tags: ["whole_food"],
            dietaryDate: "2026-11-12",
            provenance: "legacy_seed" // System seed
        )

        // 4. Test fixture meal
        let fixtureMeal = MealEntity(
            id: UUID(),
            name: "Лосось на пару з рисом басматі",
            kcal: 520,
            proteinG: 38,
            fatG: 22,
            carbsG: 42,
            tags: ["whole_food"],
            dietaryDate: "2026-11-12",
            provenance: "fixture" // Fixture
        )

        isolatedContext.insert(userMeal)
        isolatedContext.insert(cameraMeal)
        isolatedContext.insert(seedMeal)
        isolatedContext.insert(fixtureMeal)
        try isolatedContext.save()

        // Execute seed purge
        let purgedCount = try PersistenceRecovery.purgeSeedMeals(
            in: isolatedContext,
            userDefaults: testDefaults,
            cleanedFlagKey: "test_cleaned_seeds_flag"
        )

        XCTAssertEqual(purgedCount, 2, "Must purge exactly 2 seed/fixture items")

        let remaining = try isolatedContext.fetch(FetchDescriptor<MealEntity>())
        let remainingIDs = Set(remaining.map { $0.id })

        XCTAssertTrue(remainingIDs.contains(userMeal.id), "User-created meal MUST be preserved despite sharing a seed name!")
        XCTAssertTrue(remainingIDs.contains(cameraMeal.id), "Camera user meal MUST be preserved!")
        XCTAssertFalse(remainingIDs.contains(seedMeal.id), "Legacy seed meal must be purged")
        XCTAssertFalse(remainingIDs.contains(fixtureMeal.id), "Fixture meal must be purged")
    }

    // MARK: - 4. Outbox Persistence & Queue Mechanics

    func testOutboxPersistenceEnqueueRevisionAdvanceAndSurvivesSimulatedRestart() throws {
        let outbox = SyncOutbox()
        let mealID = UUID()

        // 1. Enqueue initial upsert
        let op1 = try outbox.enqueue(
            entityID: mealID,
            entityType: SyncEntityType.meal.rawValue,
            operationKind: SyncOperationKind.upsert.rawValue,
            revision: 1,
            payloadJson: "{\"name\":\"Сніданок\",\"kcal\":350}",
            in: isolatedContext
        )
        try isolatedContext.save()

        XCTAssertEqual(op1.parsedStatus, .pending)
        XCTAssertEqual(op1.revision, 1)

        // 2. Advance revision and enqueue update
        let op2 = try outbox.enqueue(
            entityID: mealID,
            entityType: SyncEntityType.meal.rawValue,
            operationKind: SyncOperationKind.upsert.rawValue,
            revision: 2,
            payloadJson: "{\"name\":\"Сніданок змінений\",\"kcal\":380}",
            in: isolatedContext
        )
        try isolatedContext.save()

        XCTAssertNotEqual(op1.operationID, op2.operationID, "Each queue operation must have a unique operation ID")
        XCTAssertEqual(op2.revision, 2)

        // 3. Simulate app restart: construct new context from same container
        let restartedContext = ModelContext(isolatedContainer)
        let restartedOutbox = SyncOutbox()

        let pendingOps = try restartedOutbox.fetchPendingOperations(for: "meal", in: restartedContext)
        XCTAssertEqual(pendingOps.count, 2, "Outbox operations must survive restart")
        XCTAssertEqual(pendingOps.map { $0.revision }, [1, 2])

        // 4. Mark processing and record attempt
        let targetOpID = pendingOps[0].operationID
        try restartedOutbox.markProcessing(operationID: targetOpID, in: restartedContext)
        XCTAssertEqual(pendingOps[0].parsedStatus, .processing)
        XCTAssertEqual(pendingOps[0].attempts, 1)
        XCTAssertNotNil(pendingOps[0].lastAttemptAt)

        // 5. Mark completed and purge
        try restartedOutbox.markCompleted(operationID: targetOpID, in: restartedContext)
        try restartedOutbox.purgeCompleted(in: restartedContext)

        let remainingPending = try restartedOutbox.fetchPendingOperations(in: restartedContext)
        XCTAssertEqual(remainingPending.count, 1)
        XCTAssertEqual(remainingPending.first?.operationID, op2.operationID)
    }

    // MARK: - 5. Confirm / Delete / Undo Lifecycle Transitions

    func testMealLifecycleTransitionsConfirmDeleteUndo() throws {
        let storage = MealStorageService.shared
        storage.simulatedSaveError = nil

        let initialName = "Омлет з шпинатом"
        let dietaryDate = "2026-11-13"

        // Step 1: Draft / Analyzing meal (optimistic pending)
        let pending = storage.insertOptimisticPending(name: initialName, dietaryDate: dietaryDate)
        XCTAssertTrue(pending.isOptimisticPending)

        let entityDescriptor = FetchDescriptor<MealEntity>(
            predicate: #Predicate { $0.id == pending.id }
        )
        guard let draftEntity = try LifecoreDataStore.shared.context.fetch(entityDescriptor).first else {
            XCTFail("Draft entity not found in context")
            return
        }
        XCTAssertEqual(draftEntity.lifecycleState, .analyzing)
        XCTAssertEqual(draftEntity.revision, 1)
        XCTAssertFalse(draftEntity.isDeleted)

        // Step 2: Confirm meal
        let confirmed = try storage.confirmMeal(id: pending.id)
        XCTAssertFalse(confirmed.isOptimisticPending)

        let confirmedEntity = try LifecoreDataStore.shared.context.fetch(entityDescriptor).first
        XCTAssertEqual(confirmedEntity?.lifecycleState, .confirmed)
        XCTAssertEqual(confirmedEntity?.revision, 2, "Confirming meal must advance revision")

        // Verify outbox has upsert operation for revision 2
        let outboxOps1 = try SyncOutbox.shared.fetchPendingOperations()
        let upsertOp = outboxOps1.first(where: { $0.entityID == pending.id && $0.revision == 2 })
        XCTAssertNotNil(upsertOp)
        XCTAssertEqual(upsertOp?.operationKind, "upsert")

        // Step 3: Delete meal (soft delete tombstone)
        try storage.deleteMeal(id: pending.id)
        let deletedEntity = try LifecoreDataStore.shared.context.fetch(entityDescriptor).first
        XCTAssertEqual(deletedEntity?.isDeleted, true, "Meal must be soft-deleted")
        XCTAssertEqual(deletedEntity?.lifecycleState, .cancelled)
        XCTAssertEqual(deletedEntity?.revision, 3, "Deleting meal must advance revision")
        XCTAssertFalse(storage.allMeals.contains(where: { $0.id == pending.id }), "Deleted meal must be absent from active list")

        // Verify outbox has delete operation for revision 3
        let outboxOps2 = try SyncOutbox.shared.fetchPendingOperations()
        let deleteOp = outboxOps2.first(where: { $0.entityID == pending.id && $0.revision == 3 })
        XCTAssertNotNil(deleteOp)
        XCTAssertEqual(deleteOp?.operationKind, "delete")

        // Step 4: Undo delete (restore)
        let restored = try storage.undoDeleteMeal(id: pending.id)
        let restoredEntity = try LifecoreDataStore.shared.context.fetch(entityDescriptor).first
        XCTAssertEqual(restoredEntity?.isDeleted, false, "Meal must be un-deleted")
        XCTAssertEqual(restoredEntity?.lifecycleState, .confirmed)
        XCTAssertEqual(restoredEntity?.revision, 4, "Restoring meal must advance revision")
        XCTAssertTrue(storage.allMeals.contains(where: { $0.id == pending.id }), "Restored meal must reappear in active list")
        XCTAssertEqual(restored.id, pending.id)

        // Verify outbox has upsert operation for revision 4
        let outboxOps3 = try SyncOutbox.shared.fetchPendingOperations()
        let restoreOp = outboxOps3.first(where: { $0.entityID == pending.id && $0.revision == 4 })
        XCTAssertNotNil(restoreOp)
        XCTAssertEqual(restoreOp?.operationKind, "upsert")
    }
}
