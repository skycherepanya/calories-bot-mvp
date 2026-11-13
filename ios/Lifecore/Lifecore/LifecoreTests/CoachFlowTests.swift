import XCTest
import SwiftData
@testable import Lifecore

// MARK: - Test AI Provider Spy (@MainActor final class)

@MainActor
final class SpyingCoachAIProvider: CoachChatAIProvider {
    let isMock: Bool = true
    var chatCallCount: Int = 0
    var debriefCallCount: Int = 0
    var shouldDelayChat: Bool = false
    var delayNanoseconds: UInt64 = 50_000_000 // 50ms

    var chatResponseToReturn: AnalystChatTurnResponse = AnalystChatTurnResponse(
        answerHeadlineUk: "Тестовий аналіз",
        answerBodyUk: "Тестове тіло відповіді тренера.",
        citedMetrics: [],
        actionableTakeawayUk: "Продовжуй відновлення.",
        suggestedFollowUpsUk: ["Як мій сон?", "Чи варто бігати завтра?"],
        extractedMemoryFactUk: nil,
        extractedMemoryCategory: nil,
        isOfflineFallback: true
    )

    var debriefResponseToReturn: StructuredWorkoutDebrief = StructuredWorkoutDebrief(
        headlineUk: "Тестовий звіт тренера",
        regimeBadgeUk: "Аеробна база",
        regimeTone: "teal",
        executionAnalysisUk: "Спліти були рівномірними.",
        benchmarkComparisonUk: "Показники відповідають нормі.",
        rootCauseAndDirectiveUk: "24-годинний план: відпочинок.",
        evidencePills: [],
        followUpQuestionsUk: [],
        isOfflineFallback: false
    )

    var chatErrorToThrow: Error? = nil
    var debriefErrorToThrow: Error? = nil

    func analyzeFoodDescription(_ text: String) async throws -> MealNutrition {
        MealNutrition(
            mealName: text,
            kcal: 300,
            protein: 10,
            fat: 5,
            carbs: 45,
            weightG: 200,
            tags: ["whole_food"]
        )
    }

    func analyzeFood(imageJpegData: Data?, textDescription: String?) async throws -> MealNutrition {
        try await analyzeFoodDescription(textDescription ?? "Страва")
    }

    func generateDebrief(dossier: AssembledHealthDossier) async throws -> StructuredWorkoutDebrief {
        debriefCallCount += 1
        if let err = debriefErrorToThrow {
            throw err
        }
        return debriefResponseToReturn
    }

    func sendAnalystChatMessage(
        userQuery: String,
        history: [AnalystChatMessage],
        dossier: AssembledHealthDossier
    ) async throws -> AnalystChatTurnResponse {
        chatCallCount += 1
        if shouldDelayChat {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
        if let err = chatErrorToThrow {
            throw err
        }
        return chatResponseToReturn
    }
}

// MARK: - CoachFlowTests

@MainActor
final class CoachFlowTests: XCTestCase {

    private var isolatedContainer: ModelContainer!
    private var isolatedContext: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        isolatedContainer = AppEnvironment.makeIsolatedModelContainer()
        isolatedContext = ModelContext(isolatedContainer)
        AppEnvironment.current = AppEnvironment.fixture(container: isolatedContainer)
    }

    override func tearDown() async throws {
        isolatedContainer = nil
        isolatedContext = nil
        AppEnvironment.reset()
        try await super.tearDown()
    }

    // MARK: - (a) Rapid Duplicate Submit Deduplication

    func testRapidDuplicateSubmitInvokesAIProviderOnce() async throws {
        let provider = SpyingCoachAIProvider()
        provider.shouldDelayChat = true
        provider.delayNanoseconds = 100_000_000 // 100ms

        let viewModel = CoachViewModel(
            aiProvider: provider,
            modelContext: isolatedContext,
            dossier: TestFixtures.sampleAssembledDossier()
        )

        // Launch first submission in a concurrent task
        let task1 = Task {
            await viewModel.submit("Який мій середній темп?")
        }

        // Give task1 enough time to start and set isSubmitting = true
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        XCTAssertTrue(viewModel.isSubmitting, "isSubmitting should be true while task 1 is in-flight")

        // Immediately attempt duplicate submission (simulating double-tap / keyboard enter race)
        await viewModel.submit("Який мій середній темп?")

        _ = await task1.value

        XCTAssertFalse(viewModel.isSubmitting, "isSubmitting should be false after completion")
        XCTAssertEqual(provider.chatCallCount, 1, "AIProvider must receive exactly ONE request due to isSubmitting guard")
        XCTAssertEqual(viewModel.messages.count, 2, "There should be 1 user and 1 assistant message")
    }

    // MARK: - (b) Chronological Turn Ordering

    func testOutOfOrderResponsesMaintainChronologicalTurnOrder() async throws {
        let provider = SpyingCoachAIProvider()
        let viewModel = CoachViewModel(
            aiProvider: provider,
            modelContext: isolatedContext,
            dossier: TestFixtures.sampleAssembledDossier()
        )

        provider.chatResponseToReturn = AnalystChatTurnResponse(
            answerHeadlineUk: "Відповідь 1",
            answerBodyUk: "Тіло 1",
            citedMetrics: [],
            actionableTakeawayUk: nil,
            suggestedFollowUpsUk: [],
            extractedMemoryFactUk: nil,
            extractedMemoryCategory: nil
        )
        await viewModel.submit("Перше запитання")

        provider.chatResponseToReturn = AnalystChatTurnResponse(
            answerHeadlineUk: "Відповідь 2",
            answerBodyUk: "Тіло 2",
            citedMetrics: [],
            actionableTakeawayUk: nil,
            suggestedFollowUpsUk: [],
            extractedMemoryFactUk: nil,
            extractedMemoryCategory: nil
        )
        await viewModel.submit("Друге запитання")

        XCTAssertEqual(viewModel.messages.count, 4)
        XCTAssertEqual(viewModel.messages[0].turnId, 1)
        XCTAssertEqual(viewModel.messages[0].sender, "user")
        XCTAssertEqual(viewModel.messages[1].turnId, 1)
        XCTAssertEqual(viewModel.messages[1].sender, "assistant")
        XCTAssertEqual(viewModel.messages[2].turnId, 2)
        XCTAssertEqual(viewModel.messages[2].sender, "user")
        XCTAssertEqual(viewModel.messages[3].turnId, 2)
        XCTAssertEqual(viewModel.messages[3].sender, "assistant")
    }

    // MARK: - (c) Provider Failure Retains Draft and Prior Turns

    func testProviderFailureRetainsDraftTextAndPriorChatTurns() async throws {
        let provider = SpyingCoachAIProvider()
        let viewModel = CoachViewModel(
            aiProvider: provider,
            modelContext: isolatedContext,
            dossier: TestFixtures.sampleAssembledDossier()
        )

        // Turn 1 succeeds
        await viewModel.submit("Успішне початкове запитання")
        XCTAssertEqual(viewModel.messages.count, 2)
        XCTAssertNil(viewModel.lastErrorMessageUk)

        // Configure failure for Turn 2
        provider.chatErrorToThrow = GeminiError.httpError(statusCode: 503, message: "Service Unavailable")
        viewModel.draftText = "Неуспішне запитання, яке треба зберегти"

        await viewModel.submit(viewModel.draftText)

        // Draft text is preserved so the user doesn't lose their input
        XCTAssertEqual(viewModel.draftText, "Неуспішне запитання, яке треба зберегти")
        // Earlier successful turns are fully preserved
        XCTAssertEqual(viewModel.messages.count, 2, "Prior successful turns must be preserved on subsequent turn failure")
        XCTAssertFalse(viewModel.isSubmitting)
        XCTAssertNotNil(viewModel.lastErrorMessageUk)
    }

    // MARK: - (d) Missing API Key Maps to Unavailable Without Overwriting

    func testMissingApiKeyOrUnavailableProviderMapsToUnavailableStateWithoutOverwritingStoredReport() async throws {
        let workoutUUID = UUID()
        let storedReportJson = """
        {
            "headlineUk": "Справжній збережений розбір",
            "regimeBadgeUk": "Аеробна база",
            "regimeTone": "teal",
            "executionAnalysisUk": "Збережений аналіз сплітів.",
            "benchmarkComparisonUk": "Стабільний темп.",
            "rootCauseAndDirectiveUk": "План на 24г: легкий біг.",
            "evidencePills": [],
            "followUpQuestionsUk": [],
            "isOfflineFallback": false
        }
        """

        // Pre-populate storage with a legitimate report
        _ = WorkoutStorageService.saveOrUpdate(
            workoutUUID: workoutUUID,
            workoutType: "OutdoorRunning",
            startedAt: Date(),
            distanceMeters: 5000,
            durationSeconds: 1500,
            avgPaceSecPerKm: 300,
            avgHeartRate: 145,
            maxHeartRate: 160,
            elevationGainMeters: 30,
            efficiencyFactor: 1.45,
            cardiacDriftPercentage: 3.2,
            splits: [],
            laps: [],
            aiCoachReport: storedReportJson
        )

        let provider = SpyingCoachAIProvider()
        provider.debriefErrorToThrow = GeminiError.missingApiKey

        let viewModel = CoachViewModel(
            aiProvider: provider,
            modelContext: isolatedContext,
            dossier: TestFixtures.sampleAssembledDossier(),
            workoutUUID: workoutUUID
        )

        // Stored report is read correctly on init
        if case .completed(let debrief, _) = viewModel.reportState {
            XCTAssertEqual(debrief.headlineUk, "Справжній збережений розбір")
        } else {
            XCTFail("Expected stored report to be loaded initially")
        }

        // Try generating debrief with missing API key
        await viewModel.generateDebrief()

        // State maps to unavailableProvider
        if case .unavailableProvider(let msg) = viewModel.reportState {
            XCTAssertTrue(msg.contains("Gemini API ключ"), "Message should mention missing Gemini key")
        } else {
            XCTFail("Expected .unavailableProvider state, got \(viewModel.reportState)")
        }

        // Verify storage was NOT overwritten with a fabricated fallback
        let analysisInDb = WorkoutStorageService.fetchAnalysis(for: workoutUUID)
        XCTAssertEqual(analysisInDb?.aiCoachReport, storedReportJson, "Original stored report must not be overwritten on provider failure")
    }

    // MARK: - (e) Memory Candidate Confirm and Delete Lifecycle

    func testMemoryLifecyclePersistsAccuratelyInIsolatedContainer() throws {
        let viewModel = CoachViewModel(
            aiProvider: SpyingCoachAIProvider(),
            modelContext: isolatedContext,
            dossier: TestFixtures.sampleAssembledDossier()
        )

        // 1. Save candidate fact
        let candidate = AthleteMemoryStorageService.saveCandidateFact(
            factTextUk: "Підготовка до забігу на 10 км у травні",
            category: "goal",
            tags: ["goal", "target"],
            in: isolatedContext
        )

        viewModel.refreshMemories()
        XCTAssertEqual(viewModel.candidateMemories.count, 1)
        XCTAssertEqual(viewModel.candidateMemories.first?.id, candidate.id)
        XCTAssertEqual(viewModel.candidateMemories.first?.confirmationStatus, "candidate")
        XCTAssertTrue(viewModel.confirmedMemories.isEmpty)

        // 2. Confirm candidate
        viewModel.confirmMemory(id: candidate.id)

        XCTAssertTrue(viewModel.candidateMemories.isEmpty, "Confirmed memory should leave candidates list")
        XCTAssertEqual(viewModel.confirmedMemories.count, 1, "Confirmed memory should appear in confirmed list")
        XCTAssertEqual(viewModel.confirmedMemories.first?.confirmationStatus, "confirmed")

        // Check in ModelContext
        let allConfirmed = AthleteMemoryStorageService.fetchConfirmedFacts(in: isolatedContext)
        XCTAssertEqual(allConfirmed.count, 1)
        XCTAssertEqual(allConfirmed.first?.id, candidate.id)

        // 3. Delete memory
        viewModel.deleteMemory(id: candidate.id)

        XCTAssertTrue(viewModel.candidateMemories.isEmpty)
        XCTAssertTrue(viewModel.confirmedMemories.isEmpty)

        let remaining = AthleteMemoryStorageService.fetchAllFacts(includeCandidates: true, in: isolatedContext)
        XCTAssertTrue(remaining.isEmpty, "Fact must be deleted from isolated storage")
    }

    // MARK: - (f) Empty and Unsupported Evidence ID Handling

    func testEmptyAndUnsupportedEvidenceIDHandling() {
        let emptyDossier = AssembledHealthDossier(
            workoutAnalysis: nil,
            recoveryContext: nil,
            acuteNutrition: AcuteNutritionSlice(loggedMealsCount: 0, last24hCarbsG: 0),
            adaptiveSensitivitiesSummaryUk: "",
            next24hPrescriptionSummaryUk: "",
            retrievedMemories: []
        )

        let viewModel = CoachViewModel(
            aiProvider: SpyingCoachAIProvider(),
            modelContext: isolatedContext,
            dossier: emptyDossier
        )

        // Empty ID returns nil
        XCTAssertNil(viewModel.evidenceItem(for: ""))
        XCTAssertNil(viewModel.evidenceItem(for: "   "))

        // Unsupported/unknown ID returns nil
        XCTAssertNil(viewModel.evidenceItem(for: "non_existent_domain_xyz"))
        XCTAssertNil(viewModel.evidenceItem(for: "synthetic_metric_fake"))

        // Known evidence items are present with honest Ukrainian missing/unavailable descriptions
        let items = viewModel.evidenceItems
        XCTAssertEqual(items.count, 4)

        let workoutItem = viewModel.evidenceItem(for: "workout_telemetry")
        XCTAssertNotNil(workoutItem)
        XCTAssertFalse(workoutItem!.isAvailable)
        XCTAssertEqual(workoutItem!.coverageUk, "Дані тренування відсутні")

        let nutritionItem = viewModel.evidenceItem(for: "scoped_nutrition")
        XCTAssertNotNil(nutritionItem)
        XCTAssertFalse(nutritionItem!.isAvailable)
        XCTAssertEqual(nutritionItem!.coverageUk, "0 записів за вікно спостереження")

        let vitalsItem = viewModel.evidenceItem(for: "overnight_vitals")
        XCTAssertNotNil(vitalsItem)
        XCTAssertFalse(vitalsItem!.isAvailable)
        XCTAssertEqual(vitalsItem!.coverageUk, "Нічні показники не зафіксовано")

        // Citation validator strips pills when underlying metrics are absent
        let fakePills = [
            MetricEvidencePill(labelUk: "Вуглеводи", valueUk: "150г"),
            MetricEvidencePill(labelUk: "Нічний RHR", valueUk: "48 bpm"),
            MetricEvidencePill(labelUk: "Дрейф ЧСС", valueUk: "2.1%")
        ]
        let validated = CoachEvidenceBuilder.validateCitations(fakePills, against: emptyDossier)
        XCTAssertTrue(validated.isEmpty, "All unsupported pills must be stripped when data is absent in dossier")
    }
}
