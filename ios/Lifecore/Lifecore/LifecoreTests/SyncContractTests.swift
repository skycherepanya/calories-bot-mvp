import XCTest
import SwiftData
@testable import Lifecore

@MainActor
final class SyncContractTests: XCTestCase {

    private var isolatedContainer: ModelContainer!
    private var isolatedContext: ModelContext!
    private var outbox: SyncOutbox!

    override func setUp() async throws {
        try await super.setUp()
        let fixture = AppEnvironment.fixture()
        AppEnvironment.current = fixture
        isolatedContainer = fixture.modelContainer
        isolatedContext = ModelContext(isolatedContainer)
        outbox = SyncOutbox()
    }

    override func tearDown() async throws {
        outbox = nil
        isolatedContext = nil
        isolatedContainer = nil
        AppEnvironment.reset()
        try await super.tearDown()
    }

    // MARK: - 1. WorkoutAnalysisCloudDTO 006 Schema & Lossless Unit Conversions

    func testWorkoutAnalysisCloudDTORoundTrips006SchemaColumnsAndUnitConversions() throws {
        let workoutUUID = UUID()
        let entityID = UUID()
        let startedAt = Date(timeIntervalSince1970: 1_763_020_800.25)
        let createdAt = Date(timeIntervalSince1970: 1_763_024_400.50)
        let updatedAt = Date(timeIntervalSince1970: 1_763_024_500.75)

        let splits = [
            SplitMetric(
                km: 1,
                durationSeconds: 300.0,
                paceMinPerKm: 5.0,
                avgHeartRate: 146.0,
                maxHeartRate: 155.0,
                elevationDiffMeters: 14.5,
                avgCadence: 174.0,
                startDate: nil
            ),
            SplitMetric(
                km: 2,
                durationSeconds: 294.0,
                paceMinPerKm: 4.9,
                avgHeartRate: 154.0,
                maxHeartRate: 162.0,
                elevationDiffMeters: -6.0,
                avgCadence: 176.0,
                startDate: nil
            )
        ]
        let laps = [
            LapIntervalMetric(
                lapIndex: 1,
                lapType: "work",
                durationSeconds: 240.0,
                distanceMeters: 1000.0,
                paceMinPerKm: 4.0,
                avgHeartRate: 168.0,
                maxHeartRate: 176.0,
                hrRecoveryDropBpm: 25.0
            )
        ]

        let entity = WorkoutAnalysisEntity(
            id: entityID,
            workoutUUID: workoutUUID,
            workoutType: "running",
            startedAt: startedAt,
            distanceMeters: 10_425.0,
            durationSeconds: 3_150.0,
            avgPaceSecPerKm: 302.16,
            avgHeartRate: 151.5,
            maxHeartRate: 176.0,
            elevationGainMeters: 142.5,
            efficiencyFactor: 1.842,
            cardiacDriftPercentage: 3.75,
            splitsJson: WorkoutAnalysisEntity.serializeSplits(splits),
            lapsJson: WorkoutAnalysisEntity.serializeLaps(laps),
            aiCoachReport: "Аеробна база стабільна, серцевий дрейф 3.75%.",
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncedToCloud: false
        )

        let dto = WorkoutAnalysisCloudDTO(from: entity, userId: 472025574, revision: 3)

        // Verify exact lossless metric conversions (m -> km, s -> min)
        XCTAssertEqual(dto.distanceKm ?? 0, 10.425, accuracy: 1e-9)
        XCTAssertEqual(dto.durationMin, 52.5, accuracy: 1e-9)
        XCTAssertEqual(dto.avgPaceMinKm ?? 0, 302.16 / 60.0, accuracy: 1e-9)
        XCTAssertEqual(dto.revision, 3)

        let encodedData = try CloudJSONCoding.makeEncoder().encode(dto)
        let jsonDict = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: encodedData) as? [String: Any]
        )

        // Assert exact 006_workout_analyses.sql + R7 snake_case keys
        let expectedKeys: Set<String> = [
            "id",
            "user_id",
            "healthkit_workout_uuid",
            "workout_type",
            "started_at",
            "distance_km",
            "duration_min",
            "avg_pace_min_km",
            "avg_hr",
            "max_hr",
            "elevation_gain_m",
            "efficiency_factor",
            "aerobic_decoupling_pct",
            "splits_json",
            "laps_json",
            "ai_coach_report",
            "revision",
            "created_at",
            "updated_at"
        ]
        XCTAssertEqual(Set(jsonDict.keys), expectedKeys)
        XCTAssertEqual(jsonDict["healthkit_workout_uuid"] as? String, workoutUUID.uuidString)
        XCTAssertEqual(jsonDict["revision"] as? Int, 3)

        let decodedDTO = try CloudJSONCoding.makeDecoder().decode(WorkoutAnalysisCloudDTO.self, from: encodedData)
        XCTAssertEqual(decodedDTO.id, dto.id)
        XCTAssertEqual(decodedDTO.userId, 472025574)
        XCTAssertEqual(decodedDTO.healthkitWorkoutUUID, workoutUUID)
        XCTAssertEqual(decodedDTO.workoutType, "running")
        XCTAssertEqual(decodedDTO.distanceKm ?? 0, 10.425, accuracy: 1e-9)
        XCTAssertEqual(decodedDTO.durationMin, 52.5, accuracy: 1e-9)
        XCTAssertEqual(decodedDTO.avgPaceMinKm ?? 0, 302.16 / 60.0, accuracy: 1e-9)
        XCTAssertEqual(decodedDTO.avgHr, 151.5)
        XCTAssertEqual(decodedDTO.maxHr, 176.0)
        XCTAssertEqual(decodedDTO.elevationGainM, 142.5)
        XCTAssertEqual(decodedDTO.efficiencyFactor, 1.842)
        XCTAssertEqual(decodedDTO.aerobicDecouplingPct, 3.75)
        XCTAssertEqual(decodedDTO.aiCoachReport, entity.aiCoachReport)
        XCTAssertEqual(decodedDTO.revision, 3)
        XCTAssertEqual(decodedDTO.splitsJson.count, 2)
        XCTAssertEqual(decodedDTO.lapsJson.count, 1)

        // Convert back to local entity losslessly
        let roundTripped = decodedDTO.toEntity(syncedToCloud: true)
        XCTAssertEqual(roundTripped.workoutUUID, workoutUUID)
        XCTAssertEqual(roundTripped.distanceMeters, 10_425.0, accuracy: 1e-6)
        XCTAssertEqual(roundTripped.durationSeconds, 3_150.0, accuracy: 1e-6)
        XCTAssertEqual(roundTripped.avgPaceSecPerKm ?? 0, 302.16, accuracy: 1e-6)
        XCTAssertEqual(roundTripped.splits.count, 2)
        XCTAssertEqual(roundTripped.laps.count, 1)
        XCTAssertEqual(roundTripped.splits.first?.paceMinPerKm, 5.0)
        XCTAssertEqual(roundTripped.laps.first?.hrRecoveryDropBpm, 25.0)
        XCTAssertTrue(roundTripped.syncedToCloud)
    }

    // MARK: - 2. MealCloudDTO Nullable Weight, Optional Micronutrients & 0-100 Confidence

    func testMealCloudDTOPreservesNullableWeightOptionalMicronutrientsAnd0To100Confidence() throws {
        // Confidence canonicalization helper checks
        XCTAssertNil(MealCloudDTO.normalizeConfidenceTo100(nil))
        XCTAssertEqual(MealCloudDTO.normalizeConfidenceTo100(0.87) ?? -1, 87.0, accuracy: 1e-9)
        XCTAssertEqual(MealCloudDTO.normalizeConfidenceTo100(0.0) ?? -1, 0.0, accuracy: 1e-9)
        XCTAssertEqual(MealCloudDTO.normalizeConfidenceTo100(94.5) ?? -1, 94.5, accuracy: 1e-9)
        XCTAssertEqual(MealCloudDTO.normalizeConfidenceTo100(120.0) ?? -1, 100.0, accuracy: 1e-9)

        // Case A: nil weight_g, nil micronutrients/aminoAcids, normalized 0.87 confidence -> 87.0
        let clientUUIDA = UUID()
        let createdA = Date(timeIntervalSince1970: 1_763_010_000.0)
        let dtoA = MealCloudDTO(
            id: nil,
            userId: 472025574,
            clientUUID: clientUUIDA,
            mealName: "Еспресо з молоком",
            kcal: 45,
            kcalExact: 40,
            bufferVersion: 1,
            protein: 2.0,
            fat: 2.0,
            carbs: 4.0,
            weightG: nil,
            confidence: 0.87,
            tags: ["liquid", "fast_absorbing"],
            micronutrients: nil,
            aminoAcids: nil,
            dietaryDate: "2026-11-13",
            revision: 1,
            provenance: "text",
            isDeleted: false,
            createdAt: createdA,
            updatedAt: createdA
        )

        XCTAssertEqual(dtoA.confidence ?? -1, 87.0, accuracy: 1e-9)
        XCTAssertNil(dtoA.weightG)

        let dataA = try CloudJSONCoding.makeEncoder().encode(dtoA)
        let dictA = try XCTUnwrap(try JSONSerialization.jsonObject(with: dataA) as? [String: Any])
        XCTAssertNil(dictA["id"], "Server-assigned id must be omitted when nil")
        XCTAssertTrue(dictA["weight_g"] is NSNull || dictA["weight_g"] == nil)
        XCTAssertEqual(dictA["confidence"] as? Double, 87.0)
        XCTAssertEqual(dictA["kcal_exact"] as? Double, 40.0)
        XCTAssertEqual(dictA["buffer_version"] as? Int, 1)

        let decodedA = try CloudJSONCoding.makeDecoder().decode(MealCloudDTO.self, from: dataA)
        XCTAssertNil(decodedA.weightG)
        XCTAssertNil(decodedA.micronutrients)
        XCTAssertNil(decodedA.aminoAcids)
        XCTAssertEqual(decodedA.confidence ?? -1, 87.0, accuracy: 1e-9)
        XCTAssertEqual(decodedA.clientUUID, clientUUIDA)

        // Also ensure empty `{}` JSONB from Postgres decodes to nil micronutrients/amino_acids
        let legacyEmptyJsonbPayload = """
        {
          "id": 101,
          "user_id": 472025574,
          "client_uuid": "\(clientUUIDA.uuidString)",
          "meal_name": "Legacy Meal",
          "kcal": 300,
          "protein": 20,
          "fat": 10,
          "carbs": 30,
          "weight_g": null,
          "confidence": 0.91,
          "tags": ["whole_food"],
          "micronutrients": {},
          "amino_acids": {},
          "dietary_date": "2026-11-13",
          "created_at": "2026-11-13T08:00:00Z"
        }
        """.data(using: .utf8)!
        let decodedLegacy = try CloudJSONCoding.makeDecoder().decode(MealCloudDTO.self, from: legacyEmptyJsonbPayload)
        XCTAssertNil(decodedLegacy.weightG)
        XCTAssertNil(decodedLegacy.micronutrients)
        XCTAssertNil(decodedLegacy.aminoAcids)
        XCTAssertEqual(decodedLegacy.confidence ?? -1, 91.0, accuracy: 1e-9)

        // Case B: full micronutrients, amino acids, weight_g, canonical confidence
        let clientUUIDB = UUID()
        let dtoB = MealCloudDTO(
            id: 505,
            userId: 472025574,
            clientUUID: clientUUIDB,
            mealName: "Лосось з рисом",
            kcal: 585,
            kcalExact: 520,
            bufferVersion: 1,
            protein: 38,
            fat: 22,
            carbs: 42,
            weightG: 340,
            confidence: 95.0,
            tags: ["whole_food", "solid"],
            micronutrients: Micronutrients(fiberG: 2.1, sodiumMg: 290, potassiumMg: 520, vitaminCMg: 2, ironMg: 1.8, calciumMg: 35),
            aminoAcids: AminoAcids(bcaaG: 7.2, leucineG: 3.3),
            dietaryDate: "2026-11-13",
            revision: 2,
            provenance: "camera",
            isDeleted: false,
            createdAt: createdA,
            updatedAt: createdA
        )

        let dataB = try CloudJSONCoding.makeEncoder().encode(dtoB)
        let decodedB = try CloudJSONCoding.makeDecoder().decode(MealCloudDTO.self, from: dataB)
        XCTAssertEqual(decodedB.weightG, 340)
        XCTAssertEqual(decodedB.confidence, 95.0)
        XCTAssertEqual(decodedB.micronutrients, dtoB.micronutrients)
        XCTAssertEqual(decodedB.aminoAcids, dtoB.aminoAcids)

        let roundTrippedEntity = decodedB.toEntity(syncedToCloud: true)
        XCTAssertEqual(roundTrippedEntity.micronutrients, dtoB.micronutrients)
        XCTAssertEqual(roundTrippedEntity.aminoAcids, dtoB.aminoAcids)
        XCTAssertEqual(roundTrippedEntity.confidence, 95.0)
        XCTAssertEqual(roundTrippedEntity.kcalExact, 520)
    }

    // MARK: - 3. Outbox Serialization, Concurrent Flush Coalescing & Stale Ack Guard

    func testOutboxSerializationEditDuringUploadAndStaleAckDoesNotClearNewerLocalRevision() async throws {
        let transport = MockCloudSyncTransport()
        let hkTransport = MockHealthKitMealExportTransport()
        let coordinator = SyncCoordinator(
            userId: 472025574,
            transport: transport,
            healthKitTransport: hkTransport,
            outbox: outbox,
            context: isolatedContext
        )

        let mealID = UUID()
        let entity = MealEntity(
            id: mealID,
            clientUUID: mealID,
            name: "Вівсянка v1",
            kcal: 360,
            kcalExact: 320,
            bufferVersion: 1,
            proteinG: 14,
            fatG: 7,
            carbsG: 58,
            weightG: 280,
            confidence: 90,
            tags: ["whole_food", "solid"],
            dietaryDate: "2026-11-13",
            createdAt: Date(),
            updatedAt: Date(),
            status: .confirmed,
            revision: 1,
            provenance: "manual",
            isDeleted: false,
            isOptimisticPending: false,
            syncedToCloud: false,
            remoteId: nil
        )
        isolatedContext.insert(entity)

        let op1 = try outbox.enqueue(
            entityID: entity.id,
            entityType: SyncEntityType.meal.rawValue,
            operationKind: SyncOperationKind.upsert.rawValue,
            revision: 1,
            payloadJson: MealSyncPayload(from: entity).toJsonString(),
            in: isolatedContext
        )
        try isolatedContext.save()

        await transport.armFirstPushPause()

        // Launch two concurrent flushOutbox() callers — must coalesce to a single in-flight upload
        let flushTask1 = Task { @MainActor in
            await coordinator.flushOutbox()
        }
        let flushTask2 = Task { @MainActor in
            await coordinator.flushOutbox()
        }

        await transport.waitUntilFirstPushStarted()

        // While rev 1 is still uploading, mutate local entity to rev 2 and enqueue op2
        entity.name = "Вівсянка з горіхами v2"
        entity.kcal = 495
        entity.revision = 2
        entity.syncedToCloud = false
        entity.updatedAt = Date()

        let op2 = try outbox.enqueue(
            entityID: entity.id,
            entityType: SyncEntityType.meal.rawValue,
            operationKind: SyncOperationKind.upsert.rawValue,
            revision: 2,
            payloadJson: MealSyncPayload(from: entity).toJsonString(),
            in: isolatedContext
        )
        try isolatedContext.save()

        // Release suspended rev 1 upload
        await transport.releasePausedPush(assignedRemoteId: 777)

        let result1 = await flushTask1.value
        let result2 = await flushTask2.value

        // Both concurrent callers coalesced onto the same flush result
        XCTAssertEqual(result1, result2)
        XCTAssertEqual(result1.succeededOperationIDs, [op1.operationID])
        XCTAssertEqual(result1.pendingOperationIDs, [op2.operationID])
        XCTAssertFalse(result1.isCleanSuccess, "Flush result must not claim clean success while rev 2 remains pending")

        let pushCountAfterFirstFlush = await transport.pushedMeals.count
        let maxConcurrentAfterFirstFlush = await transport.maxConcurrentPushes
        XCTAssertEqual(pushCountAfterFirstFlush, 1, "Concurrent callers must coalesce without duplicate push")
        XCTAssertEqual(maxConcurrentAfterFirstFlush, 1)

        // CRITICAL: Stale ack for rev 1 MUST NOT set syncedToCloud = true when local is already rev 2
        XCTAssertEqual(entity.revision, 2)
        XCTAssertEqual(entity.remoteId, 777)
        XCTAssertFalse(entity.syncedToCloud, "Stale rev 1 ack must leave syncedToCloud == false for newer local rev 2")
        XCTAssertEqual(op1.parsedStatus, .completed)
        XCTAssertEqual(op2.parsedStatus, .pending)

        // Second flush uploads rev 2 with expectedServerRevision == 1 and clears syncedToCloud
        let resultAfterSecondFlush = await coordinator.flushOutbox()
        XCTAssertTrue(resultAfterSecondFlush.isCleanSuccess)
        XCTAssertEqual(resultAfterSecondFlush.succeededOperationIDs, [op2.operationID])
        XCTAssertTrue(entity.syncedToCloud)
        XCTAssertEqual(op2.parsedStatus, .completed)

        let pushedMeals = await transport.pushedMeals
        XCTAssertEqual(pushedMeals.count, 2)
        XCTAssertEqual(pushedMeals[0].dto.revision, 1)
        XCTAssertNil(pushedMeals[0].expectedServerRevision)
        XCTAssertEqual(pushedMeals[1].dto.revision, 2)
        XCTAssertEqual(pushedMeals[1].expectedServerRevision, 1)
        XCTAssertEqual(pushedMeals[1].dto.mealName, "Вівсянка з горіхами v2")
    }

    // MARK: - 4. 409 Conflict Retention & Non-2xx Retryable Queue Semantics

    func testConflict409RetainsBothVersionsAndNon2xxRetainsRetryableQueue() async throws {
        let transport = MockCloudSyncTransport()
        let coordinator = SyncCoordinator(
            userId: 472025574,
            transport: transport,
            healthKitTransport: MockHealthKitMealExportTransport(),
            outbox: outbox,
            context: isolatedContext
        )

        // Subcase A: 409 Conflict retains both local & remote payloads without silent overwrite
        let conflictMealID = UUID()
        let conflictEntity = MealEntity(
            id: conflictMealID,
            clientUUID: conflictMealID,
            name: "Локальна версія страви",
            kcal: 510,
            proteinG: 40,
            fatG: 15,
            carbsG: 50,
            dietaryDate: "2026-11-13",
            revision: 2,
            provenance: "manual",
            syncedToCloud: false,
            remoteId: 88
        )
        isolatedContext.insert(conflictEntity)

        let conflictOp = try outbox.enqueue(
            entityID: conflictEntity.id,
            entityType: SyncEntityType.meal.rawValue,
            operationKind: SyncOperationKind.upsert.rawValue,
            revision: 2,
            payloadJson: MealSyncPayload(from: conflictEntity).toJsonString(),
            in: isolatedContext
        )
        try isolatedContext.save()

        let remoteDTO = MealCloudDTO(
            id: 88,
            userId: 472025574,
            clientUUID: conflictMealID,
            mealName: "Віддалена версія страви",
            kcal: 640,
            protein: 45,
            fat: 20,
            carbs: 65,
            dietaryDate: "2026-11-13",
            revision: 3,
            provenance: "camera",
            createdAt: Date()
        )
        let remoteJson = CloudJSONCoding.encodeToString(remoteDTO)
        await transport.setNextPushError(
            .conflict(remoteRevision: 3, remotePayloadJson: remoteJson)
        )

        let conflictResult = await coordinator.flushOutbox()
        XCTAssertFalse(conflictResult.isCleanSuccess)
        XCTAssertEqual(conflictResult.errorClassification, .conflict)
        XCTAssertEqual(conflictResult.failedOperationIDs, [conflictOp.operationID])
        XCTAssertEqual(conflictResult.conflicts.count, 1)

        let recordedConflict = try XCTUnwrap(conflictResult.conflicts.first)
        XCTAssertEqual(recordedConflict.entityID, conflictMealID)
        XCTAssertEqual(recordedConflict.localRevision, 2)
        XCTAssertEqual(recordedConflict.remoteRevision, 3)
        XCTAssertTrue(recordedConflict.localPayloadJson.contains("Локальна версія страви"))
        XCTAssertTrue(recordedConflict.remotePayloadJson.contains("Віддалена версія страви"))
        XCTAssertEqual(conflictOp.parsedStatus, .failed)
        XCTAssertEqual(conflictEntity.name, "Локальна версія страви", "409 conflict must not silently overwrite local entity")
        XCTAssertFalse(conflictEntity.syncedToCloud)

        // Subcase B: Transient non-2xx errors (401, 429, 503, networkUnavailable) keep op pending & retryable
        let retryMealID = UUID()
        let retryEntity = MealEntity(
            id: retryMealID,
            clientUUID: retryMealID,
            name: "Тимчасово не синхронізована страва",
            kcal: 420,
            proteinG: 30,
            fatG: 12,
            carbsG: 48,
            dietaryDate: "2026-11-13",
            revision: 1,
            provenance: "manual",
            syncedToCloud: false
        )
        isolatedContext.insert(retryEntity)

        let retryOp = try outbox.enqueue(
            entityID: retryEntity.id,
            entityType: SyncEntityType.meal.rawValue,
            operationKind: SyncOperationKind.upsert.rawValue,
            revision: 1,
            payloadJson: MealSyncPayload(from: retryEntity).toJsonString(),
            in: isolatedContext
        )
        try isolatedContext.save()

        let transientScenarios: [(CloudSyncTransportError, SyncErrorClassification)] = [
            (.unauthorized(statusCode: 401, message: "JWT expired"), .unauthorized),
            (.rateLimited(retryAfterSeconds: 30, message: "Too many requests"), .rateLimited),
            (.serverError(statusCode: 503, message: "Service unavailable"), .serverError),
            (.networkUnavailable("The Internet connection appears to be offline."), .networkUnavailable)
        ]

        for (index, scenario) in transientScenarios.enumerated() {
            await transport.setNextPushError(scenario.0)
            let res = await coordinator.flushOutbox()
            XCTAssertFalse(res.isCleanSuccess)
            XCTAssertEqual(res.errorClassification, scenario.1)
            XCTAssertEqual(res.pendingOperationIDs, [retryOp.operationID])
            XCTAssertTrue(res.conflicts.isEmpty)
            XCTAssertEqual(retryOp.parsedStatus, .pending, "Transient error \(scenario.1) must keep op retryable (.pending)")
            XCTAssertEqual(retryOp.attempts, index + 1)
            XCTAssertNotNil(retryOp.lastAttemptAt)
        }

        // Clear error and verify recovery succeeds cleanly on retry
        await transport.setNextPushError(nil)
        let recoveryResult = await coordinator.flushOutbox()
        XCTAssertTrue(recoveryResult.isCleanSuccess)
        XCTAssertEqual(recoveryResult.succeededOperationIDs, [retryOp.operationID])
        XCTAssertEqual(retryOp.parsedStatus, .completed)
        XCTAssertTrue(retryEntity.syncedToCloud)
    }

    // MARK: - 5. Paginated Pull (>60 Meals & >30 Workouts) into Non-Empty Store

    func testPaginatedPullRoundTripsMoreThan60MealsAndMoreThan30WorkoutsIntoNonEmptyStore() async throws {
        let baseDate = Date(timeIntervalSince1970: 1_763_000_000)

        // Seed NON-EMPTY local store before pull
        let syncedUpdateMealUUID = UUID()
        let syncedLocalMeal = MealEntity(
            id: syncedUpdateMealUUID,
            clientUUID: syncedUpdateMealUUID,
            name: "Стара назва (синхронізована)",
            kcal: 300,
            proteinG: 20,
            fatG: 10,
            carbsG: 30,
            dietaryDate: "2026-11-12",
            createdAt: baseDate,
            updatedAt: baseDate,
            revision: 1,
            provenance: "manual",
            syncedToCloud: true,
            remoteId: 1
        )

        let unsyncedHigherRevMealUUID = UUID()
        let unsyncedLocalMeal = MealEntity(
            id: unsyncedHigherRevMealUUID,
            clientUUID: unsyncedHigherRevMealUUID,
            name: "Локальна несинхронізована зміна rev 5",
            kcal: 710,
            proteinG: 50,
            fatG: 20,
            carbsG: 80,
            dietaryDate: "2026-11-13",
            createdAt: baseDate,
            updatedAt: baseDate.addingTimeInterval(500),
            revision: 5,
            provenance: "manual",
            syncedToCloud: false,
            remoteId: 2
        )

        let unsyncedWorkoutUUID = UUID()
        let unsyncedLocalWorkout = WorkoutAnalysisEntity(
            workoutUUID: unsyncedWorkoutUUID,
            workoutType: "running",
            startedAt: baseDate,
            distanceMeters: 12_345,
            durationSeconds: 3_600,
            aiCoachReport: "Локальний несинхронізований звіт",
            createdAt: baseDate,
            updatedAt: baseDate.addingTimeInterval(600),
            syncedToCloud: false
        )

        isolatedContext.insert(syncedLocalMeal)
        isolatedContext.insert(unsyncedLocalMeal)
        isolatedContext.insert(unsyncedLocalWorkout)
        try isolatedContext.save()

        // Build 75 remote meals (>60) including updates for syncedLocalMeal (rev 2) & stale rev 3 for unsyncedLocalMeal
        var remoteMeals: [MealCloudDTO] = [
            MealCloudDTO(
                id: 1,
                userId: 472025574,
                clientUUID: syncedUpdateMealUUID,
                mealName: "Оновлена назва з сервера rev 2",
                kcal: 340,
                protein: 24,
                fat: 11,
                carbs: 34,
                weightG: nil,
                confidence: 92,
                tags: ["whole_food"],
                dietaryDate: "2026-11-12",
                revision: 2,
                provenance: "manual",
                createdAt: baseDate,
                updatedAt: baseDate.addingTimeInterval(10)
            ),
            MealCloudDTO(
                id: 2,
                userId: 472025574,
                clientUUID: unsyncedHigherRevMealUUID,
                mealName: "Застаріла серверна назва rev 3",
                kcal: 500,
                protein: 30,
                fat: 15,
                carbs: 60,
                dietaryDate: "2026-11-13",
                revision: 3,
                provenance: "manual",
                createdAt: baseDate,
                updatedAt: baseDate.addingTimeInterval(20)
            )
        ]

        for idx in 3...75 {
            remoteMeals.append(
                MealCloudDTO(
                    id: Int64(idx),
                    userId: 472025574,
                    clientUUID: UUID(),
                    mealName: "Remote Meal #\(idx)",
                    kcal: Double(300 + idx),
                    protein: 25,
                    fat: 10,
                    carbs: 40,
                    weightG: idx % 2 == 0 ? 250.0 : nil,
                    confidence: 88,
                    tags: ["whole_food"],
                    dietaryDate: "2026-11-13",
                    revision: 1,
                    provenance: "camera",
                    createdAt: baseDate.addingTimeInterval(Double(idx)),
                    updatedAt: baseDate.addingTimeInterval(Double(idx))
                )
            )
        }

        // Build 42 remote workout analyses (>30) including a stale version of unsyncedLocalWorkout
        var remoteWorkouts: [WorkoutAnalysisCloudDTO] = [
            WorkoutAnalysisCloudDTO(
                id: UUID(),
                userId: 472025574,
                healthkitWorkoutUUID: unsyncedWorkoutUUID,
                workoutType: "running",
                startedAt: baseDate,
                distanceKm: 10.0,
                durationMin: 50.0,
                avgPaceMinKm: 5.0,
                avgHr: 145,
                maxHr: 165,
                elevationGainM: 50,
                efficiencyFactor: 1.7,
                aerobicDecouplingPct: 4.0,
                splitsJson: [],
                lapsJson: [],
                aiCoachReport: "Застарілий серверний звіт",
                revision: 1,
                createdAt: baseDate,
                updatedAt: baseDate
            )
        ]

        for idx in 2...42 {
            remoteWorkouts.append(
                WorkoutAnalysisCloudDTO(
                    id: UUID(),
                    userId: 472025574,
                    healthkitWorkoutUUID: UUID(),
                    workoutType: "running",
                    startedAt: baseDate.addingTimeInterval(Double(idx * 3600)),
                    distanceKm: 8.5 + Double(idx) * 0.1,
                    durationMin: 42.0 + Double(idx) * 0.5,
                    avgPaceMinKm: 4.9,
                    avgHr: 150,
                    maxHr: 172,
                    elevationGainM: 80,
                    efficiencyFactor: 1.82,
                    aerobicDecouplingPct: 2.8,
                    splitsJson: [],
                    lapsJson: [],
                    aiCoachReport: "Workout #\(idx)",
                    revision: 1,
                    createdAt: baseDate.addingTimeInterval(Double(idx * 3600)),
                    updatedAt: baseDate.addingTimeInterval(Double(idx * 3600))
                )
            )
        }

        let transport = MockCloudSyncTransport(remoteMeals: remoteMeals, remoteWorkouts: remoteWorkouts)
        let coordinator = SyncCoordinator(
            userId: 472025574,
            transport: transport,
            healthKitTransport: MockHealthKitMealExportTransport(),
            outbox: outbox,
            context: isolatedContext
        )

        let pullResult = await coordinator.pullIncrementalAll(since: nil, pageSize: 25)
        XCTAssertEqual(pullResult.errorClassification, .none)
        // 75 meals / 25 = 3 pages (plus empty page 4 since 75 is exact multiple of 25 -> 4 pages) + 42 workouts / 25 = 2 pages
        XCTAssertGreaterThanOrEqual(pullResult.pagesFetched, 5)
        XCTAssertEqual(pullResult.mealsPulled, 74, "73 new + 1 synced update; 1 unsynced higher-rev skipped")
        XCTAssertEqual(pullResult.workoutsPulled, 41, "41 new; 1 unsynced local workout skipped")
        XCTAssertEqual(pullResult.skippedLocalNewerCount, 2)

        let localMeals = try isolatedContext.fetch(FetchDescriptor<MealEntity>())
        let localWorkouts = try isolatedContext.fetch(FetchDescriptor<WorkoutAnalysisEntity>())
        XCTAssertEqual(localMeals.count, 75)
        XCTAssertEqual(localWorkouts.count, 42)

        // Verify synced meal updated from server
        XCTAssertEqual(syncedLocalMeal.name, "Оновлена назва з сервера rev 2")
        XCTAssertEqual(syncedLocalMeal.revision, 2)
        XCTAssertTrue(syncedLocalMeal.syncedToCloud)

        // Verify unsynced higher-revision meal was NOT clobbered
        XCTAssertEqual(unsyncedLocalMeal.name, "Локальна несинхронізована зміна rev 5")
        XCTAssertEqual(unsyncedLocalMeal.revision, 5)
        XCTAssertFalse(unsyncedLocalMeal.syncedToCloud)

        // Verify unsynced workout analysis was NOT clobbered
        XCTAssertEqual(unsyncedLocalWorkout.distanceMeters, 12_345, accuracy: 1e-6)
        XCTAssertEqual(unsyncedLocalWorkout.aiCoachReport, "Локальний несинхронізований звіт")
        XCTAssertFalse(unsyncedLocalWorkout.syncedToCloud)
    }

    // MARK: - 6. Serialized HealthKit Export Queue (save -> delete -> save)

    func testHealthKitExportSerializesDeleteAndUndoWhileExportInFlight() async throws {
        let hkTransport = MockHealthKitMealExportTransport()
        let coordinator = SyncCoordinator(
            userId: 472025574,
            transport: MockCloudSyncTransport(),
            healthKitTransport: hkTransport,
            outbox: outbox,
            context: isolatedContext
        )

        let clientUUID = UUID()
        let meal = MealRecord(
            id: clientUUID,
            name: "Сирники з ягодами",
            kcal: 450,
            proteinG: 28,
            fatG: 14,
            carbsG: 48,
            tags: ["whole_food", "solid"],
            micronutrients: Micronutrients(fiberG: 3.2, sodiumMg: 180),
            dietaryDate: "2026-11-13",
            createdAt: Date()
        )

        // 1. Enqueue initial upsert and start in-flight HealthKit export
        let opSave1 = try coordinator.enqueueHealthKitMealUpsert(meal: meal, clientUUID: clientUUID, revision: 1)
        try isolatedContext.save()

        await hkTransport.armFirstExportPause()
        let task1 = Task { @MainActor in
            await coordinator.flushHealthKitMealExports()
        }

        await hkTransport.waitUntilFirstExportStarted()

        // 2. While initial save is in flight, user deletes then immediately undoes delete
        let opDelete = try coordinator.enqueueHealthKitMealDelete(clientUUID: clientUUID, revision: 2)
        let opUndoSave = try coordinator.enqueueHealthKitMealUpsert(meal: meal, clientUUID: clientUUID, revision: 3)
        try isolatedContext.save()

        let task2 = Task { @MainActor in
            await coordinator.flushHealthKitMealExports()
        }

        // 3. Release initial export and await completion of serialized queue
        await hkTransport.releasePausedExport()

        let res1 = await task1.value
        let res2 = await task2.value

        XCTAssertTrue(res1.isCleanSuccess)
        XCTAssertTrue(res2.isCleanSuccess)

        let events = await hkTransport.recordedEvents
        let maxConcurrent = await hkTransport.maxConcurrentExecutions
        XCTAssertEqual(maxConcurrent, 1, "HealthKit exports/deletes must execute serially with zero concurrency")
        XCTAssertEqual(events, [
            .export(clientUUID: clientUUID, name: "Сирники з ягодами", kcal: 450),
            .delete(clientUUID: clientUUID),
            .export(clientUUID: clientUUID, name: "Сирники з ягодами", kcal: 450)
        ])

        XCTAssertEqual(opSave1.parsedStatus, .completed)
        XCTAssertEqual(opDelete.parsedStatus, .completed)
        XCTAssertEqual(opUndoSave.parsedStatus, .completed)
    }
}

// MARK: - Test Mocks

@MainActor
private final class MockCloudSyncTransport: CloudSyncTransport {
    struct PushedMealInvocation: Sendable {
        let dto: MealCloudDTO
        let expectedServerRevision: Int?
    }

    private(set) var pushedMeals: [PushedMealInvocation] = []
    private(set) var pushedWorkouts: [WorkoutAnalysisCloudDTO] = []
    private(set) var maxConcurrentPushes: Int = 0

    private var inFlightPushes: Int = 0
    private var nextPushError: CloudSyncTransportError?
    private var shouldPauseNextPush: Bool = false
    private var firstPushStarted: Bool = false
    private var startWaiter: CheckedContinuation<Void, Never>?
    private var pauseGate: CheckedContinuation<Int64?, Never>?

    private let remoteMeals: [MealCloudDTO]
    private let remoteWorkouts: [WorkoutAnalysisCloudDTO]

    init(remoteMeals: [MealCloudDTO] = [], remoteWorkouts: [WorkoutAnalysisCloudDTO] = []) {
        self.remoteMeals = remoteMeals
        self.remoteWorkouts = remoteWorkouts
    }

    func setNextPushError(_ error: CloudSyncTransportError?) {
        nextPushError = error
    }

    func armFirstPushPause() {
        shouldPauseNextPush = true
        firstPushStarted = false
    }

    func waitUntilFirstPushStarted() async {
        if firstPushStarted { return }
        await withCheckedContinuation { continuation in
            startWaiter = continuation
        }
    }

    func releasePausedPush(assignedRemoteId: Int64?) {
        pauseGate?.resume(returning: assignedRemoteId)
        pauseGate = nil
    }

    func pushMeal(_ dto: MealCloudDTO, expectedServerRevision: Int?) async throws -> MealCloudDTO {
        inFlightPushes += 1
        maxConcurrentPushes = max(maxConcurrentPushes, inFlightPushes)
        defer { inFlightPushes -= 1 }

        if let err = nextPushError {
            nextPushError = nil
            throw err
        }

        var assignedRemoteId = dto.id
        if shouldPauseNextPush {
            shouldPauseNextPush = false
            firstPushStarted = true
            startWaiter?.resume()
            startWaiter = nil

            assignedRemoteId = await withCheckedContinuation { continuation in
                pauseGate = continuation
            }
        }

        pushedMeals.append(PushedMealInvocation(dto: dto, expectedServerRevision: expectedServerRevision))
        return MealCloudDTO(
            id: assignedRemoteId ?? dto.id ?? 1,
            userId: dto.userId,
            clientUUID: dto.clientUUID,
            mealName: dto.mealName,
            kcal: dto.kcal,
            kcalExact: dto.kcalExact,
            bufferVersion: dto.bufferVersion,
            protein: dto.protein,
            fat: dto.fat,
            carbs: dto.carbs,
            weightG: dto.weightG,
            confidence: dto.confidence,
            tags: dto.tags,
            micronutrients: dto.micronutrients,
            aminoAcids: dto.aminoAcids,
            dietaryDate: dto.dietaryDate,
            revision: dto.revision,
            provenance: dto.provenance,
            isDeleted: dto.isDeleted,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }

    func pushWorkoutAnalysis(_ dto: WorkoutAnalysisCloudDTO, expectedServerRevision: Int?) async throws -> WorkoutAnalysisCloudDTO {
        if let err = nextPushError {
            nextPushError = nil
            throw err
        }
        pushedWorkouts.append(dto)
        return dto
    }

    func fetchMealsPage(userId: Int64, since: Date?, cursor: String?, limit: Int) async throws -> CloudPage<MealCloudDTO> {
        let offset = max(0, Int(cursor ?? "0") ?? 0)
        let filtered = remoteMeals.filter { $0.userId == userId }
        guard offset < filtered.count else {
            return CloudPage(items: [], nextCursor: nil, hasMore: false)
        }
        let end = min(filtered.count, offset + limit)
        let slice = Array(filtered[offset..<end])
        let hasMore = slice.count == limit
        return CloudPage(items: slice, nextCursor: hasMore ? String(end) : nil, hasMore: hasMore)
    }

    func fetchWorkoutAnalysesPage(userId: Int64, since: Date?, cursor: String?, limit: Int) async throws -> CloudPage<WorkoutAnalysisCloudDTO> {
        let offset = max(0, Int(cursor ?? "0") ?? 0)
        let filtered = remoteWorkouts.filter { $0.userId == userId }
        guard offset < filtered.count else {
            return CloudPage(items: [], nextCursor: nil, hasMore: false)
        }
        let end = min(filtered.count, offset + limit)
        let slice = Array(filtered[offset..<end])
        let hasMore = slice.count == limit
        return CloudPage(items: slice, nextCursor: hasMore ? String(end) : nil, hasMore: hasMore)
    }
}

@MainActor
private final class MockHealthKitMealExportTransport: HealthKitMealExportTransport {
    enum RecordedEvent: Equatable, Sendable {
        case export(clientUUID: UUID, name: String, kcal: Double)
        case delete(clientUUID: UUID)
    }

    private(set) var recordedEvents: [RecordedEvent] = []
    private(set) var maxConcurrentExecutions: Int = 0

    private var inFlightCount: Int = 0
    private var shouldPauseFirstExport: Bool = false
    private var firstExportStarted: Bool = false
    private var startWaiter: CheckedContinuation<Void, Never>?
    private var pauseGate: CheckedContinuation<Void, Never>?

    func armFirstExportPause() {
        shouldPauseFirstExport = true
        firstExportStarted = false
    }

    func waitUntilFirstExportStarted() async {
        if firstExportStarted { return }
        await withCheckedContinuation { continuation in
            startWaiter = continuation
        }
    }

    func releasePausedExport() {
        pauseGate?.resume()
        pauseGate = nil
    }

    func exportMeal(
        clientUUID: UUID,
        name: String,
        kcal: Double,
        proteinG: Double,
        fatG: Double,
        carbsG: Double,
        sodiumMg: Double?,
        fiberG: Double?,
        date: Date
    ) async throws {
        inFlightCount += 1
        maxConcurrentExecutions = max(maxConcurrentExecutions, inFlightCount)
        defer { inFlightCount -= 1 }

        if shouldPauseFirstExport {
            shouldPauseFirstExport = false
            firstExportStarted = true
            startWaiter?.resume()
            startWaiter = nil
            await withCheckedContinuation { continuation in
                pauseGate = continuation
            }
        }

        recordedEvents.append(.export(clientUUID: clientUUID, name: name, kcal: kcal))
    }

    func deleteMeal(clientUUID: UUID) async throws {
        inFlightCount += 1
        maxConcurrentExecutions = max(maxConcurrentExecutions, inFlightCount)
        defer { inFlightCount -= 1 }

        recordedEvents.append(.delete(clientUUID: clientUUID))
    }
}
