import XCTest
@testable import Lifecore

final class LongitudinalTests: XCTestCase {

    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private var budapestCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Budapest")!
        return cal
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 12,
        minute: Int = 0,
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

    private func dateKey(from date: Date, in calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }

    // MARK: - 1. Sparse Dates (T+5 Spacing) Produce Zero T -> T+1 Insights

    func testSparseDatesTPlus5SpacingProduceZeroInsights() {
        let cal = utcCalendar
        let start = makeDate(year: 2026, month: 10, day: 1, hour: 12, in: cal)

        var records: [DailyJoinedPhysiologyRecord] = []
        for i in 0..<10 {
            let day = cal.date(byAdding: .day, value: i * 5, to: start)!
            let key = dateKey(from: day, in: cal)
            let isHigh = (i % 2 == 1)

            records.append(DailyJoinedPhysiologyRecord(
                dateString: key,
                date: day,
                weightKg: isHigh ? 79.2 : 77.8,
                rollingWeight7dKg: 78.0,
                sodiumMg: isHigh ? 4500.0 : 1500.0,
                carbsG: isHigh ? 320.0 : 120.0,
                proteinG: 160.0,
                fatG: 60.0,
                wholeFoodRatio: isHigh ? 0.95 : 0.35,
                ultraProcessedRatio: isHigh ? 0.05 : 0.65,
                hasLateMealAfter2130: isHigh,
                hasHighSodiumMeal: isHigh,
                overnightHrvMs: isHigh ? 72.0 : 102.0,
                overnightRhrBpm: isHigh ? 55.0 : 47.0,
                deepSleepHours: isHigh ? 1.8 : 1.0,
                remSleepHours: 1.5,
                workoutTrimp: 45.0,
                runningCardiacDriftPct: isHigh ? 2.5 : 7.0,
                runningEf: 1.2,
                loggedMealsCount: 3,
                hasConfirmedNutrition: true,
                confirmedKcal: 2300.0
            ))
        }

        let insights = CorrelationEngine.computeInsights(records: records)
        XCTAssertTrue(insights.isEmpty, "Sparse T+5 records have no consecutive T -> T+1 calendar pairs and must yield 0 insights")

        let sensitivities = AdaptivePhysiologyEngine.computeLearnedSensitivities(records: records)
        XCTAssertEqual(sensitivities, LearnedSensitivities(), "Sparse T+5 records with zero T -> T+1 pairs must keep prior sensitivities")
    }

    // MARK: - 2. Negative Whole-Food -> Deep Sleep Sign Consistency & No Canned Magnitudes

    func testNegativeWholeFoodCorrelationMatchesNegativeSignAndOmitsCannedPhrases() {
        let cal = utcCalendar
        let start = makeDate(year: 2026, month: 10, day: 1, hour: 12, in: cal)

        var records: [DailyJoinedPhysiologyRecord] = []
        for i in 0..<8 {
            let day = cal.date(byAdding: .day, value: i, to: start)!
            let key = dateKey(from: day, in: cal)

            // Day T wholeFoodRatio increases from 0.20 to 0.90;
            // Day T+1 deepSleepHours decreases linearly so paired (wholeFood[T], deepSleep[T+1]) has r = -1.0.
            let wholeRatio = 0.20 + Double(i) * 0.10
            let deepSleep = 2.2 - Double(i) * 0.20

            records.append(DailyJoinedPhysiologyRecord(
                dateString: key,
                date: day,
                sodiumMg: 2000.0,
                carbsG: 200.0,
                proteinG: 150.0,
                fatG: 65.0,
                wholeFoodRatio: wholeRatio,
                ultraProcessedRatio: 1.0 - wholeRatio,
                hasLateMealAfter2130: (i % 2 == 0),
                overnightHrvMs: 90.0,
                overnightRhrBpm: (i % 2 == 0) ? 50.0 : 51.0,
                deepSleepHours: deepSleep,
                remSleepHours: 1.5,
                workoutTrimp: 50.0,
                loggedMealsCount: 3,
                hasConfirmedNutrition: true,
                confirmedKcal: 2200.0
            ))
        }

        let insights = CorrelationEngine.computeInsights(records: records)
        guard let recoveryInsight = insights.first(where: { $0.category == .nutritionRecovery }) else {
            XCTFail("Expected nutritionRecovery insight for 7 consecutive matched pairs")
            return
        }

        XCTAssertEqual(recoveryInsight.pearsonR, -1.0, accuracy: 0.001)
        XCTAssertEqual(recoveryInsight.sampleCount, 7)
        XCTAssertEqual(recoveryInsight.dateRangeLabel, "2026-10-01…2026-10-07")
        XCTAssertEqual(recoveryInsight.associationLabelUk, "Спостережуваний зв'язок")

        XCTAssertFalse(recoveryInsight.effectDescriptionUk.contains("збільшенням"), "Negative r must never emit positive wording")
        XCTAssertFalse(recoveryInsight.effectDescriptionUk.contains("15–25 хвилин"), "Must never emit canned 15–25 хвилин")
        XCTAssertFalse(recoveryInsight.actionDirectiveUk.contains("15–25 хвилин"), "Directive must never emit canned 15–25 хвилин")
        XCTAssertTrue(recoveryInsight.effectDescriptionUk.contains("меншою тривалістю"))
        XCTAssertTrue(recoveryInsight.effectDescriptionUk.contains("-1.00"))
        XCTAssertTrue(recoveryInsight.effectDescriptionUk.contains("n = 7"))
        XCTAssertTrue(recoveryInsight.effectDescriptionUk.contains("2026-10-01…2026-10-07"))

        // Also ensure no insight anywhere emits canned "2.5–4 bpm"
        for insight in insights {
            XCTAssertFalse(insight.effectDescriptionUk.contains("2.5–4 bpm"))
            XCTAssertFalse(insight.actionDirectiveUk.contains("2.5–4 bpm"))
        }
    }

    // MARK: - 3. Unlogged Meal Days Excluded From Nutrition Correlations

    func testUnloggedMealDaysExcludedFromNutritionCorrelations() {
        let cal = utcCalendar
        let start = makeDate(year: 2026, month: 10, day: 1, hour: 12, in: cal)

        var records: [DailyJoinedPhysiologyRecord] = []
        for i in 0..<10 {
            let day = cal.date(byAdding: .day, value: i, to: start)!
            let key = dateKey(from: day, in: cal)

            // Only first 4 days have confirmed nutrition; remaining 6 days are unlogged.
            let isLogged = i < 4
            records.append(DailyJoinedPhysiologyRecord(
                dateString: key,
                date: day,
                weightKg: 78.0 + (i % 2 == 0 ? 0.5 : -0.3),
                rollingWeight7dKg: 78.0,
                sodiumMg: isLogged ? (i % 2 == 0 ? 1500.0 : 4000.0) : 0.0,
                carbsG: isLogged ? Double(150 + i * 30) : 0.0,
                proteinG: isLogged ? 150.0 : 0.0,
                fatG: isLogged ? 60.0 : 0.0,
                wholeFoodRatio: isLogged ? (0.4 + Double(i) * 0.15) : 1.0,
                ultraProcessedRatio: 0.0,
                hasLateMealAfter2130: isLogged && (i % 2 == 1),
                overnightHrvMs: 95.0,
                overnightRhrBpm: (i % 2 == 0) ? 53.0 : 48.0,
                deepSleepHours: 1.2 + Double(i % 3) * 0.25,
                workoutTrimp: 40.0,
                runningCardiacDriftPct: 3.0 + Double(i % 4),
                loggedMealsCount: isLogged ? 3 : 0,
                hasConfirmedNutrition: isLogged,
                confirmedKcal: isLogged ? 2100.0 : nil
            ))
        }

        let insights = CorrelationEngine.computeInsights(records: records)
        XCTAssertTrue(insights.isEmpty, "Unlogged meal days must be excluded, leaving < 6 valid nutrition pairs")
    }

    // MARK: - 4. Confirmed Zero Intake Distinct From Unlogged

    func testConfirmedZeroIntakeRemainsDistinctFromUnlogged() {
        let cal = utcCalendar
        let dayDate = makeDate(year: 2026, month: 10, day: 1, hour: 12, in: cal)

        let unlogged = DailyJoinedPhysiologyRecord(
            dateString: "2026-10-01",
            date: dayDate,
            loggedMealsCount: 0,
            hasConfirmedNutrition: false,
            confirmedKcal: nil
        )
        let confirmedZero = DailyJoinedPhysiologyRecord(
            dateString: "2026-10-01",
            date: dayDate,
            loggedMealsCount: 0,
            hasConfirmedNutrition: true,
            confirmedKcal: 0.0
        )

        XCTAssertFalse(unlogged.hasCompleteNutrition, "Unlogged day must not count as complete nutrition")
        XCTAssertTrue(confirmedZero.hasCompleteNutrition, "Confirmed zero intake (fasting) must count as complete nutrition")

        // Verify computeDynamicTDEE treats confirmed zero intake as 0 kcal (not priorTargetKcal and not skipped)
        var baseRecords: [DailyJoinedPhysiologyRecord] = []
        var recordsWithZeroDay: [DailyJoinedPhysiologyRecord] = []
        for i in 0..<8 {
            let d = cal.date(byAdding: .day, value: i, to: dayDate)!
            let key = dateKey(from: d, in: cal)
            let isZero = (i == 4)

            baseRecords.append(DailyJoinedPhysiologyRecord(
                dateString: key,
                date: d,
                weightKg: 80.0,
                rollingWeight7dKg: 80.0,
                carbsG: 250.0,
                proteinG: 160.0,
                fatG: 70.0,
                workoutTrimp: 40.0,
                loggedMealsCount: 3,
                hasConfirmedNutrition: true,
                confirmedKcal: 2600.0
            ))

            recordsWithZeroDay.append(DailyJoinedPhysiologyRecord(
                dateString: key,
                date: d,
                weightKg: 80.0,
                rollingWeight7dKg: 80.0,
                carbsG: isZero ? 0.0 : 250.0,
                proteinG: isZero ? 0.0 : 160.0,
                fatG: isZero ? 0.0 : 70.0,
                workoutTrimp: 40.0,
                loggedMealsCount: isZero ? 0 : 3,
                hasConfirmedNutrition: true,
                confirmedKcal: isZero ? 0.0 : 2600.0
            ))
        }

        let tdeeAllFed = AdaptivePhysiologyEngine.computeDynamicTDEE(
            records: baseRecords,
            priorBmrKcal: 1750.0,
            priorTargetKcal: 3000.0
        )
        let tdeeWithConfirmedZero = AdaptivePhysiologyEngine.computeDynamicTDEE(
            records: recordsWithZeroDay,
            priorBmrKcal: 1750.0,
            priorTargetKcal: 3000.0
        )

        XCTAssertEqual(tdeeWithConfirmedZero.validDaysCount, 8)
        XCTAssertLessThan(
            tdeeWithConfirmedZero.learnedBmrKcal,
            tdeeAllFed.learnedBmrKcal,
            "Confirmed 0 kcal fasting day must reduce empirical intake/BMR rather than substituting priorTargetKcal"
        )
    }

    // MARK: - 5. Dynamic TDEE Calendar Span & Unlogged Skip

    func testDynamicTDEEUsesActualCalendarSpanAndSkipsUnloggedDays() {
        let cal = utcCalendar
        let start = makeDate(year: 2026, month: 10, day: 1, hour: 12, in: cal)

        // 6 records spanning 13 calendar days (days 0, 3, 6, 9, 11, 13)
        // Weight drops 80.0 -> 78.7 (-1.3 kg over 13 days => -1.40 kg per 14 days).
        // Old bug used `recent.count - 1 = 5` days, yielding -3.64 kg/14d!
        let offsets = [0, 3, 6, 9, 11, 13]
        let weights = [80.0, 79.7, 79.4, 79.1, 78.9, 78.7]

        var sparseSpanRecords: [DailyJoinedPhysiologyRecord] = []
        for (idx, offset) in offsets.enumerated() {
            let d = cal.date(byAdding: .day, value: offset, to: start)!
            sparseSpanRecords.append(DailyJoinedPhysiologyRecord(
                dateString: dateKey(from: d, in: cal),
                date: d,
                weightKg: weights[idx],
                rollingWeight7dKg: weights[idx],
                carbsG: 200.0,
                proteinG: 150.0,
                fatG: 60.0,
                workoutTrimp: 40.0,
                loggedMealsCount: 3,
                hasConfirmedNutrition: true,
                confirmedKcal: 2300.0
            ))
        }

        let spanResult = AdaptivePhysiologyEngine.computeDynamicTDEE(
            records: sparseSpanRecords,
            priorBmrKcal: 1750.0,
            priorTargetKcal: 2150.0
        )

        XCTAssertEqual(spanResult.trendWeightDelta14dKg, -1.40, accuracy: 0.05)
        XCTAssertEqual(spanResult.validDaysCount, 6)

        // Unlogged days must be skipped rather than substituted with priorTargetKcal
        var mixedLoggedRecords: [DailyJoinedPhysiologyRecord] = []
        for i in 0..<10 {
            let d = cal.date(byAdding: .day, value: i, to: start)!
            let isLogged = i < 5
            mixedLoggedRecords.append(DailyJoinedPhysiologyRecord(
                dateString: dateKey(from: d, in: cal),
                date: d,
                weightKg: 80.0,
                rollingWeight7dKg: 80.0,
                carbsG: isLogged ? 300.0 : 0.0,
                proteinG: isLogged ? 180.0 : 0.0,
                fatG: isLogged ? 90.0 : 0.0,
                workoutTrimp: 30.0,
                loggedMealsCount: isLogged ? 3 : 0,
                hasConfirmedNutrition: isLogged,
                confirmedKcal: isLogged ? 3100.0 : nil
            ))
        }

        let mixedResult = AdaptivePhysiologyEngine.computeDynamicTDEE(
            records: mixedLoggedRecords,
            priorBmrKcal: 1750.0,
            priorTargetKcal: 1500.0
        )
        XCTAssertEqual(mixedResult.validDaysCount, 5, "Only the 5 complete nutrition days must count")
        XCTAssertGreaterThan(
            mixedResult.learnedBmrKcal,
            1750.0,
            "With 3100 kcal maintenance and skipped unlogged days, learned BMR must rise rather than blend in 1500 kcal priorTargetKcal"
        )

        // Short span (< 3 calendar days) must return fallback
        let twoDayRecords = (0..<4).map { i -> DailyJoinedPhysiologyRecord in
            let d = cal.date(byAdding: .day, value: i < 2 ? i : 2, to: start)!
            return DailyJoinedPhysiologyRecord(
                dateString: dateKey(from: d, in: cal),
                date: d,
                weightKg: i == 0 ? 80.0 : (i == 3 ? 78.0 : nil),
                rollingWeight7dKg: nil,
                carbsG: 200.0,
                proteinG: 150.0,
                fatG: 60.0,
                loggedMealsCount: 2,
                hasConfirmedNutrition: true,
                confirmedKcal: 2100.0
            )
        }
        let shortSpanResult = AdaptivePhysiologyEngine.computeDynamicTDEE(records: twoDayRecords)
        XCTAssertEqual(shortSpanResult.metabolicAdaptationKcal, 0.0)
        XCTAssertEqual(shortSpanResult.trendWeightDelta14dKg, 0.0)
    }

    // MARK: - 6. PhysiologyHistoryBuilder DietaryDay Joins & Nil Sleep Stages

    func testPhysiologyHistoryBuilderJoinsPostMidnightMealsAndPreservesNilSleepStages() async throws {
        let cal = budapestCalendar

        let day1Start = makeDate(year: 2026, month: 11, day: 12, hour: 4, minute: 0, in: cal)
        let day3End = makeDate(year: 2026, month: 11, day: 15, hour: 4, minute: 0, in: cal)
        let interval = DateInterval(start: day1Start, end: day3End)

        // Post-midnight meal at 01:30 on 2026-11-13 -> belongs to DietaryDay 2026-11-12 and triggers hasLateMealAfter2130
        let postMidnightMealTime = makeDate(year: 2026, month: 11, day: 13, hour: 1, minute: 30, in: cal)
        let postMidnightMeal = MealRecord(
            name: "Нічний перекус",
            kcal: 450.0,
            proteinG: 25.0,
            fatG: 15.0,
            carbsG: 50.0,
            tags: ["whole_food", "solid"],
            dietaryDate: "2026-11-12",
            createdAt: postMidnightMealTime,
            isOptimisticPending: false
        )

        // Optimistic pending meal on 2026-11-13 must NOT count as confirmed nutrition
        let pendingMealTime = makeDate(year: 2026, month: 11, day: 13, hour: 13, minute: 0, in: cal)
        let pendingMeal = MealRecord(
            name: "Аналізується...",
            kcal: 0.0,
            proteinG: 0.0,
            fatG: 0.0,
            carbsG: 0.0,
            dietaryDate: "2026-11-13",
            createdAt: pendingMealTime,
            isOptimisticPending: true
        )

        // Unspecified-only sleep ending morning of 2026-11-13 (DietaryDay 2026-11-13)
        let sleepStart = makeDate(year: 2026, month: 11, day: 12, hour: 23, minute: 30, in: cal)
        let sleepEnd = makeDate(year: 2026, month: 11, day: 13, hour: 7, minute: 30, in: cal)
        let unspecifiedSleep = SleepEpisode(
            interval: DateInterval(start: sleepStart, end: sleepEnd),
            stages: [
                SleepStageSegment(
                    interval: DateInterval(start: sleepStart, end: sleepEnd),
                    stage: .unspecified
                )
            ],
            totalSleepDurationSeconds: 8 * 3600,
            hrv: Observation<Double>(value: 86.0, unit: "ms", observedAt: sleepEnd, source: .healthKit, quality: .measured),
            hrvMethod: .rmssd,
            restingHeartRate: Observation<Double>(value: 49.0, unit: "bpm", observedAt: sleepEnd, source: .healthKit, quality: .measured)
        )

        // Weight observations ONLY on 2026-11-12 and 2026-11-14 (2026-11-13 has no weight observation)
        let w1 = Observation<Double>(
            value: 78.4,
            unit: "kg",
            observedAt: makeDate(year: 2026, month: 11, day: 12, hour: 7, minute: 30, in: cal),
            source: .healthKit,
            quality: .measured
        )
        let w3 = Observation<Double>(
            value: 78.0,
            unit: "kg",
            observedAt: makeDate(year: 2026, month: 11, day: 14, hour: 7, minute: 30, in: cal),
            source: .healthKit,
            quality: .measured
        )

        let records = PhysiologyHistoryBuilder.buildRecords(
            in: interval,
            meals: [postMidnightMeal, pendingMeal],
            weightObservations: [w1, w3],
            sleepEpisodes: [unspecifiedSleep],
            workouts: [],
            confirmedZeroNutritionDates: ["2026-11-14"],
            knownRestDates: ["2026-11-13"],
            calendar: cal
        )

        XCTAssertEqual(records.count, 3)
        XCTAssertEqual(records.map(\.dateString), ["2026-11-12", "2026-11-13", "2026-11-14"])

        let day1 = records[0] // 2026-11-12
        XCTAssertEqual(day1.loggedMealsCount, 1)
        XCTAssertTrue(day1.hasConfirmedNutrition)
        XCTAssertTrue(day1.hasCompleteNutrition)
        XCTAssertTrue(day1.hasLateMealAfter2130, "01:30 post-midnight meal must join previous dietary day and flag late meal")
        XCTAssertEqual(day1.weightKg, 78.4)
        XCTAssertNil(day1.rollingWeight7dKg, "Only 1 weight sample in window so far")

        let day2 = records[1] // 2026-11-13
        XCTAssertEqual(day2.loggedMealsCount, 0, "Pending meal must not count as logged")
        XCTAssertFalse(day2.hasConfirmedNutrition)
        XCTAssertFalse(day2.hasCompleteNutrition)
        XCTAssertNil(day2.weightKg, "Day without weight sample must stay nil")
        XCTAssertNil(day2.rollingWeight7dKg, "7d rolling weight must stay nil when no weight observed on that day")
        XCTAssertNil(day2.deepSleepHours, "Unspecified sleep must preserve nil deepSleepHours without fabricating 0.22")
        XCTAssertNil(day2.remSleepHours, "Unspecified sleep must preserve nil remSleepHours without fabricating 0.23")
        XCTAssertEqual(day2.overnightHrvMs, 86.0)
        XCTAssertEqual(day2.overnightRhrBpm, 49.0)
        XCTAssertTrue(day2.isKnownRestDay)
        XCTAssertEqual(day2.workoutTrimp, 0.0)

        let day3 = records[2] // 2026-11-14
        XCTAssertEqual(day3.loggedMealsCount, 0)
        XCTAssertTrue(day3.hasConfirmedNutrition)
        XCTAssertEqual(day3.confirmedKcal, 0.0)
        XCTAssertTrue(day3.hasCompleteNutrition)
        XCTAssertEqual(day3.weightKg, 78.0)
        XCTAssertEqual(day3.rollingWeight7dKg ?? 0.0, 78.2, accuracy: 0.01)

        // Also exercise async build(in:healthRepository:meals:workouts:calendar:)
        let repo = FixtureHealthRepository(
            weightObservations: [w1, w3],
            sleepEpisodes: [unspecifiedSleep]
        )
        let asyncRecords = try await PhysiologyHistoryBuilder.build(
            in: interval,
            healthRepository: repo,
            meals: [postMidnightMeal, pendingMeal],
            workouts: [],
            calendar: cal
        )
        XCTAssertEqual(asyncRecords.count, 3)
        XCTAssertNil(asyncRecords[1].deepSleepHours)
        XCTAssertTrue(asyncRecords[0].hasLateMealAfter2130)
    }
}
