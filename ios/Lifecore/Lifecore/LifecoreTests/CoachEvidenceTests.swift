import XCTest
import SwiftData
@testable import Lifecore

@MainActor
final class CoachEvidenceTests: XCTestCase {

    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    override func setUp() async throws {
        try await super.setUp()
        AppEnvironment.current = AppEnvironment.fixture()
    }

    override func tearDown() async throws {
        AppEnvironment.reset()
        try await super.tearDown()
    }

    private func makeDate(
        year: Int = 2026,
        month: Int = 11,
        day: Int = 13,
        hour: Int,
        minute: Int,
        second: Int = 0,
        in calendar: Calendar
    ) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        comps.second = second
        guard let date = calendar.date(from: comps) else {
            fatalError("Invalid date components: \(comps)")
        }
        return date
    }

    private func makeMeal(
        name: String,
        kcal: Double = 400,
        carbsG: Double = 50,
        proteinG: Double = 25,
        fatG: Double = 10,
        sodiumMg: Double? = 300,
        tags: [String] = ["whole_food", "solid"],
        createdAt: Date,
        isOptimisticPending: Bool = false
    ) -> MealRecord {
        MealRecord(
            name: name,
            kcal: kcal,
            proteinG: proteinG,
            fatG: fatG,
            carbsG: carbsG,
            tags: tags,
            micronutrients: sodiumMg.map { Micronutrients(sodiumMg: $0) },
            dietaryDate: "2026-11-13",
            createdAt: createdAt,
            isOptimisticPending: isOptimisticPending
        )
    }

    // MARK: - 1. Nutrition Window Scoping (24h & 36h)

    func testNutritionWindowExcludesMealsBeforeStartAndAfterAnchor() {
        let cal = utcCalendar
        let anchor = makeDate(hour: 12, minute: 0, in: cal)

        let tooOld24 = anchor.addingTimeInterval(-25 * 3600)
        let inside24 = anchor.addingTimeInterval(-10 * 3600)
        let inside36Only = anchor.addingTimeInterval(-30 * 3600)
        let tooOld36 = anchor.addingTimeInterval(-37 * 3600)
        let futureMeal = anchor.addingTimeInterval(30 * 60)
        let pendingMeal = anchor.addingTimeInterval(-2 * 3600)

        let meals = [
            makeMeal(name: "Too Old 24h", carbsG: 100, createdAt: tooOld24),
            makeMeal(name: "Inside 24h", carbsG: 45, createdAt: inside24),
            makeMeal(name: "Inside 36h Only", carbsG: 60, createdAt: inside36Only),
            makeMeal(name: "Too Old 36h", carbsG: 120, createdAt: tooOld36),
            makeMeal(name: "Future Meal", carbsG: 90, createdAt: futureMeal),
            makeMeal(name: "Pending Meal", carbsG: 80, createdAt: pendingMeal, isOptimisticPending: true)
        ]

        // 24h window
        let window24 = CoachNutritionWindow(endingAt: anchor, windowHours: 24)
        let filtered24 = CoachEvidenceBuilder.filterMeals(meals, in: window24)
        XCTAssertEqual(filtered24.map(\.name), ["Inside 24h"])

        let dossier24 = LifecoreContextRAG.assembleDossier(
            workoutAnalysis: nil,
            recoveryContext: nil,
            meals: meals,
            anchorDate: anchor,
            nutritionWindowHours: 24,
            calendar: cal
        )
        XCTAssertEqual(dossier24.acuteNutrition.loggedMealsCount, 1)
        XCTAssertEqual(dossier24.acuteNutrition.last24hCarbsG, 45)
        XCTAssertEqual(dossier24.acuteNutrition.windowHours, 24)

        // 36h window (includes -10h, -25h, and -30h; still excludes -37h, future, and pending)
        let window36 = CoachNutritionWindow(endingAt: anchor, windowHours: 36)
        let filtered36 = CoachEvidenceBuilder.filterMeals(meals, in: window36)
        XCTAssertEqual(Set(filtered36.map(\.name)), Set(["Inside 24h", "Too Old 24h", "Inside 36h Only"]))

        let dossier36 = LifecoreContextRAG.assembleDossier(
            workoutAnalysis: nil,
            recoveryContext: nil,
            meals: meals,
            anchorDate: anchor,
            nutritionWindowHours: 36,
            calendar: cal
        )
        XCTAssertEqual(dossier36.acuteNutrition.loggedMealsCount, 3)
        XCTAssertEqual(dossier36.acuteNutrition.last24hCarbsG, 205)
        XCTAssertEqual(dossier36.acuteNutrition.windowHours, 36)
    }

    // MARK: - 2. Late Meal Boundary (21:30...03:59)

    func testLateMealDetectionIncludesPostMidnightBefore0400Boundary() {
        let cal = utcCalendar

        let at2129 = makeDate(hour: 21, minute: 29, in: cal)
        let at2130 = makeDate(hour: 21, minute: 30, in: cal)
        let at0030 = makeDate(hour: 0, minute: 30, in: cal)
        let at0359 = makeDate(hour: 3, minute: 59, in: cal)
        let at0400 = makeDate(hour: 4, minute: 0, in: cal)

        XCTAssertFalse(CoachEvidenceBuilder.isLateMeal(at2129, calendar: cal))
        XCTAssertTrue(CoachEvidenceBuilder.isLateMeal(at2130, calendar: cal))
        XCTAssertTrue(CoachEvidenceBuilder.isLateMeal(at0030, calendar: cal))
        XCTAssertTrue(CoachEvidenceBuilder.isLateMeal(at0359, calendar: cal))
        XCTAssertFalse(CoachEvidenceBuilder.isLateMeal(at0400, calendar: cal))
    }

    // MARK: - 3. Zero Logged Meals Integrity

    func testZeroLoggedMealsDoesNotFabricate85PercentWholeFoodOrAllowCarbCitations() {
        let cal = utcCalendar
        let anchor = makeDate(hour: 12, minute: 0, in: cal)

        let dossier = LifecoreContextRAG.assembleDossier(
            workoutAnalysis: nil,
            recoveryContext: RecentRecoveryContext(
                lastNightSleepHours: 7.4,
                morningRhrBpm: 51,
                recoveryScore: 78,
                acwrRatio: 1.05
            ),
            meals: [],
            anchorDate: anchor,
            nutritionWindowHours: 24,
            calendar: cal
        )

        XCTAssertEqual(dossier.acuteNutrition.loggedMealsCount, 0)
        XCTAssertEqual(dossier.acuteNutrition.wholeFoodRatioPct, 0, "Zero logged meals must report 0%, never hardcoded 85%")

        let rawPills: [MetricEvidencePill] = [
            .init(labelUk: "Вуглеводи 24г", valueUk: "180г", tone: "optimal"),
            .init(labelUk: "Ккал", valueUk: "2100 ккал", tone: "neutral"),
            .init(labelUk: "Білок", valueUk: "120г", tone: "optimal"),
            .init(labelUk: "Жири", valueUk: "60г", tone: "neutral"),
            .init(labelUk: "Натрій", valueUk: "1800 мг", tone: "neutral"),
            .init(labelUk: "Якість їжі", valueUk: "85%", tone: "teal"),
            .init(labelUk: "HRV", valueUk: "68 ms", tone: "optimal"),
            .init(labelUk: "Глибокий сон", valueUk: "1.6г", tone: "optimal"),
            .init(labelUk: "REM сон", valueUk: "1.8г", tone: "teal"),
            .init(labelUk: "EF", valueUk: "1.42", tone: "optimal"),
            .init(labelUk: "Дрейф ЧСС", valueUk: "+3.2%", tone: "optimal"),
            .init(labelUk: "Сон", valueUk: "7.4г", tone: "optimal"),
            .init(labelUk: "Нічний RHR", valueUk: "51 bpm", tone: "teal"),
            .init(labelUk: "EWMA ACWR", valueUk: "1.05", tone: "optimal"),
            .init(labelUk: "Готовність", valueUk: "78%", tone: "optimal")
        ]

        let validated = CoachEvidenceBuilder.validateCitations(rawPills, against: dossier)
        let validatedLabels = Set(validated.map(\.labelUk))

        XCTAssertFalse(validatedLabels.contains("Вуглеводи 24г"))
        XCTAssertFalse(validatedLabels.contains("Ккал"))
        XCTAssertFalse(validatedLabels.contains("Білок"))
        XCTAssertFalse(validatedLabels.contains("Жири"))
        XCTAssertFalse(validatedLabels.contains("Натрій"))
        XCTAssertFalse(validatedLabels.contains("Якість їжі"))
        XCTAssertFalse(validatedLabels.contains("HRV"))
        XCTAssertFalse(validatedLabels.contains("Глибокий сон"))
        XCTAssertFalse(validatedLabels.contains("REM сон"))
        XCTAssertFalse(validatedLabels.contains("EF"))
        XCTAssertFalse(validatedLabels.contains("Дрейф ЧСС"))

        XCTAssertTrue(validatedLabels.contains("Сон"))
        XCTAssertTrue(validatedLabels.contains("Нічний RHR"))
        XCTAssertTrue(validatedLabels.contains("EWMA ACWR"))
        XCTAssertTrue(validatedLabels.contains("Готовність"))

        let prompt = CoachPrompt.buildDossierPrompt(dossier: dossier)
        XCTAssertTrue(prompt.contains(dossier.acuteNutrition.windowLabelUk))
        XCTAssertFalse(prompt.contains("24H/48H"))
        XCTAssertFalse(prompt.contains("Deep: 0.0h"), "Missing sleep stages must not be formatted as 0.0h")
        XCTAssertFalse(prompt.contains("REM: 0.0h"), "Missing sleep stages must not be formatted as 0.0h")
    }

    // MARK: - 4. Offline Fallback Grounding

    func testOfflineFallbackDoesNotInventUnmeasuredMetrics() {
        let unmeasuredWorkout = WorkoutAnalysisResult(
            workoutUUID: UUID(),
            workoutType: "Running",
            distanceKm: 6.0,
            durationMin: 33.0,
            avgPaceMinKm: 5.5,
            avgHeartRate: nil,
            maxHeartRate: nil,
            elevationGainMeters: nil,
            efficiencyFactor: nil,
            aerobicDecouplingPct: nil,
            isIndoorTreadmill: false,
            splits: [],
            laps: []
        )

        let dossier = LifecoreContextRAG.assembleDossier(
            workoutAnalysis: unmeasuredWorkout,
            recoveryContext: RecentRecoveryContext(),
            meals: [],
            anchorDate: Date(),
            nutritionWindowHours: 24
        )

        let debrief = GeminiService.shared.generateStructuredWorkoutDebriefOffline(dossier: dossier)
        XCTAssertTrue(debrief.isOfflineFallback)
        XCTAssertFalse(debrief.evidencePills.contains(where: { $0.labelUk.lowercased().contains("пульс") || $0.valueUk.contains("N/A") }))
        XCTAssertFalse(debrief.executionAnalysisUk.contains("N/A"))

        let hrTurn = GeminiService.shared.generateOfflineAnalystChatResponse(
            userQuery: "Чому зріс мій пульс?",
            dossier: dossier
        )
        XCTAssertTrue(hrTurn.isOfflineFallback)
        XCTAssertTrue(hrTurn.citedMetrics.isEmpty)
        XCTAssertFalse(hrTurn.answerBodyUk.contains("150 bpm"))
        XCTAssertFalse(hrTurn.answerBodyUk.contains("7.5"))

        let nutritionTurn = GeminiService.shared.generateOfflineAnalystChatResponse(
            userQuery: "Скільки вуглеводів я поїв?",
            dossier: dossier
        )
        XCTAssertTrue(nutritionTurn.isOfflineFallback)
        XCTAssertTrue(nutritionTurn.citedMetrics.isEmpty)

        let generalTurn = GeminiService.shared.generateOfflineAnalystChatResponse(
            userQuery: "Яка моя поточна форма?",
            dossier: dossier
        )
        XCTAssertTrue(generalTurn.isOfflineFallback)
        XCTAssertFalse(generalTurn.answerBodyUk.contains("1.08"))
        XCTAssertFalse(generalTurn.answerBodyUk.contains("82%"))
        XCTAssertFalse(generalTurn.answerBodyUk.contains("49 bpm"))
        XCTAssertFalse(generalTurn.citedMetrics.contains(where: { $0.valueUk == "1.08" || $0.valueUk == "82%" || $0.valueUk == "49 bpm" }))
    }

    // MARK: - 5. Memory Candidate Lifecycle & Durable Delete

    func testMemoryCandidatesAreExcludedFromRAGUntilConfirmedAndDeleteIsDurable() {
        // Fixture mode must never seed legacy default memories
        AthleteMemoryStorageService.seedDefaultMemoriesIfNeeded()
        XCTAssertTrue(AthleteMemoryStorageService.fetchAllFacts(includeCandidates: true).isEmpty)

        // 1. Save AI-extracted candidate fact
        let candidate = AthleteMemoryStorageService.saveCandidateFact(
            factTextUk: "Болить праве коліно після темпового бігу",
            category: "injury_note",
            tags: ["injury", "knee"]
        )
        XCTAssertEqual(candidate.confirmationStatus, "candidate")
        XCTAssertEqual(candidate.provenance, "ai_extracted")

        XCTAssertEqual(AthleteMemoryStorageService.fetchCandidateFacts().map(\.id), [candidate.id])
        XCTAssertTrue(AthleteMemoryStorageService.fetchConfirmedFacts().isEmpty)
        XCTAssertTrue(AthleteMemoryStorageService.fetchAllFacts().isEmpty)

        // Candidate must NOT be retrieved by RAG before confirmation
        let ragBeforeConfirm = LifecoreContextRAG.retrieveTopMemories(
            query: "болить коліно",
            contextTags: ["injury"]
        )
        XCTAssertTrue(ragBeforeConfirm.isEmpty)

        // 2. Confirm candidate fact
        let confirmed = AthleteMemoryStorageService.confirmCandidateFact(id: candidate.id)
        XCTAssertNotNil(confirmed)
        XCTAssertEqual(confirmed?.confirmationStatus, "confirmed")
        XCTAssertEqual(confirmed?.provenance, "user_confirmed")
        XCTAssertTrue(AthleteMemoryStorageService.fetchCandidateFacts().isEmpty)
        XCTAssertEqual(AthleteMemoryStorageService.fetchConfirmedFacts().map(\.id), [candidate.id])

        // Confirmed fact MUST now be retrieved by RAG
        let ragAfterConfirm = LifecoreContextRAG.retrieveTopMemories(
            query: "болить коліно",
            contextTags: ["injury"]
        )
        XCTAssertEqual(ragAfterConfirm.map(\.id), [candidate.id])

        // 3. Delete fact and verify durable removal
        AthleteMemoryStorageService.deleteFact(id: candidate.id)
        XCTAssertTrue(AthleteMemoryStorageService.fetchConfirmedFacts().isEmpty)
        XCTAssertTrue(AthleteMemoryStorageService.fetchAllFacts(includeCandidates: true).isEmpty)
        XCTAssertTrue(LifecoreContextRAG.retrieveTopMemories(query: "болить коліно", contextTags: ["injury"]).isEmpty)
    }
}
