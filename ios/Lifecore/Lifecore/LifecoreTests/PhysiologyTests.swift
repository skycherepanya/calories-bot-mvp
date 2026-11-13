import XCTest
import Foundation
@testable import Lifecore

final class PhysiologyTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AppEnvironment.current = AppEnvironment.fixture()
    }

    // MARK: - 1. ACWR: 28-Day Stable vs Spike & Empty History Coverage (Audit F02)

    func testEmptyHistoryYieldsInsufficientCoverageOrNil() {
        // Empty DailyLoadSeries must return nil (never synthetic 1.0 / sweetSpot)
        let seriesResult = TrainingLoadAndBatteryEngine.computeEWMAWorkload(series: [])
        XCTAssertNil(seriesResult, "Empty series must return nil, NOT synthetic 1.0 / sweetSpot")

        // Unobserved entries only must also return nil
        let unobservedResult = TrainingLoadAndBatteryEngine.computeEWMAWorkload(series: [
            .unobserved(date: Date())
        ])
        XCTAssertNil(unobservedResult, "Series with only unobserved days must return nil")

        // Legacy dailyLoads array with empty input must yield insufficient coverage with ratio 0.0
        let legacyResult = TrainingLoadAndBatteryEngine.computeEWMAWorkload(dailyLoads: [])
        XCTAssertEqual(legacyResult.ratio, 0.0, "Empty daily loads must not produce ratio 1.0")
        XCTAssertEqual(legacyResult.coverage.confidence, .insufficient, "Empty history must yield insufficient coverage")
        XCTAssertFalse(legacyResult.coverage.isAggressiveProgressionAllowed)
    }

    func testStableHistoryVsSpikeACWR() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        // Construct 28 consecutive days of stable 50 TRIMP
        // Using 12:00 UTC to ensure clean DietaryDay containment
        let t0 = Date(timeIntervalSince1970: 1_700_000_000) // stable anchor
        var series: [DailyLoadSeries] = []
        for d in 0..<28 {
            let dayDate = t0.addingTimeInterval(Double(d) * 86400.0)
            series.append(DailyLoadSeries(date: dayDate, trimpLoad: 50.0, isKnownRestDay: false, isObserved: true))
        }

        guard let stableEval = TrainingLoadAndBatteryEngine.computeEWMAWorkload(series: series, calendar: calendar) else {
            XCTFail("28 days of observed data must produce an ACWR evaluation")
            return
        }

        // 28 days of steady 50 TRIMP must yield ratio ~ 1.0 (sweetSpot)
        XCTAssertEqual(stableEval.zone, .sweetSpot)
        XCTAssertEqual(stableEval.ratio, 1.0, accuracy: 0.05, "28 stable days of 50 TRIMP must yield ratio near 1.0")
        XCTAssertEqual(stableEval.coverage.confidence, .fullConfidence)
        XCTAssertEqual(stableEval.coverage.observedDaysCount, 28)
        XCTAssertEqual(stableEval.coverage.consecutiveDaysCount, 28)
        XCTAssertTrue(stableEval.coverage.isAggressiveProgressionAllowed)

        // Day 29: Spike with 250 TRIMP
        let day29Date = t0.addingTimeInterval(28.0 * 86400.0)
        series.append(DailyLoadSeries(date: day29Date, trimpLoad: 250.0, isKnownRestDay: false, isObserved: true))

        guard let spikeEval = TrainingLoadAndBatteryEngine.computeEWMAWorkload(series: series, calendar: calendar) else {
            XCTFail("29 days with spike must produce an ACWR evaluation")
            return
        }

        // Regression assertion: 250 TRIMP spike must yield ratio significantly differing from stable history (1.0)
        XCTAssertGreaterThan(spikeEval.ratio, 1.45, "A spike of 250 TRIMP after 28 stable days must significantly exceed 1.0")
        XCTAssertEqual(spikeEval.zone, .dangerSpike)
        XCTAssertEqual(spikeEval.coverage.confidence, .fullConfidence)
        XCTAssertFalse(spikeEval.coverage.isAggressiveProgressionAllowed, "Aggressive progression is prohibited during danger spike")
    }

    func testProvisionalHistoryForUnder28Days() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        var series: [DailyLoadSeries] = []
        for d in 0..<14 {
            let dayDate = t0.addingTimeInterval(Double(d) * 86400.0)
            series.append(.observed(date: dayDate, trimpLoad: 60.0))
        }

        guard let eval = TrainingLoadAndBatteryEngine.computeEWMAWorkload(series: series, calendar: calendar) else {
            XCTFail("14 days should evaluate")
            return
        }

        // Under 28 days must be provisional and exclude aggressive progression
        XCTAssertEqual(eval.coverage.confidence, .provisional)
        XCTAssertEqual(eval.coverage.consecutiveDaysCount, 14)
        XCTAssertFalse(eval.coverage.isAggressiveProgressionAllowed, "Provisional history (< 28 days) must not allow aggressive progression")
        XCTAssertTrue(eval.titleUk.contains("Попередньо"))
    }

    func testKnownRestDaysContributeZeroTrimpAndMaintainConsecutiveStreak() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        var series: [DailyLoadSeries] = []
        for d in 0..<28 {
            let dayDate = t0.addingTimeInterval(Double(d) * 86400.0)
            if d % 7 == 6 {
                // Known rest day: trimp is strictly 0.0, observed is true
                series.append(.restDay(date: dayDate))
            } else {
                series.append(.observed(date: dayDate, trimpLoad: 70.0))
            }
        }

        guard let eval = TrainingLoadAndBatteryEngine.computeEWMAWorkload(series: series, calendar: calendar) else {
            XCTFail("Series with known rest days must evaluate")
            return
        }

        // Rest days do not break consecutive streak
        XCTAssertEqual(eval.coverage.consecutiveDaysCount, 28)
        XCTAssertEqual(eval.coverage.confidence, .fullConfidence)
    }

    func testUnobservedGapBreaksConsecutiveStreak() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        var series: [DailyLoadSeries] = []

        // 14 days observed
        for d in 0..<14 {
            let dayDate = t0.addingTimeInterval(Double(d) * 86400.0)
            series.append(.observed(date: dayDate, trimpLoad: 50.0))
        }

        // 5 days unobserved gap (e.g. watch not worn)
        // Then 10 days observed
        for d in 19..<29 {
            let dayDate = t0.addingTimeInterval(Double(d) * 86400.0)
            series.append(.observed(date: dayDate, trimpLoad: 50.0))
        }

        guard let eval = TrainingLoadAndBatteryEngine.computeEWMAWorkload(series: series, calendar: calendar) else {
            XCTFail("Should evaluate")
            return
        }

        // Trailing consecutive days streak is only 10, so it remains provisional (< 28)
        XCTAssertEqual(eval.coverage.consecutiveDaysCount, 10)
        XCTAssertEqual(eval.coverage.confidence, .provisional)
    }

    // MARK: - 2. Body Battery: Workout Event Timing & Drain Intervals (Audit F02)

    func testBatteryDrainTiming0700Vs1900() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let refDate = Date(timeIntervalSince1970: 1_700_000_000)

        // Workout A: Morning session at 07:00 (TRIMP 90)
        let morningEvent = WorkoutBatteryEvent(hour: 7, trimp: 90.0, calendar: calendar, referenceDate: refDate)
        let morningEval = TrainingLoadAndBatteryEngine.computeEnergyBankTimeline(
            wakeRecoveryScore: 90,
            sleepHours: 8.0,
            targetSleepHours: 8.0,
            pureNeatKcal: 400.0,
            events: [morningEvent],
            immuneState: .optimal,
            currentHour: 12,
            calendar: calendar,
            referenceDate: refDate
        )

        // Workout B: Evening session at 19:00 (TRIMP 90)
        let eveningEvent = WorkoutBatteryEvent(hour: 19, trimp: 90.0, calendar: calendar, referenceDate: refDate)
        let eveningEval = TrainingLoadAndBatteryEngine.computeEnergyBankTimeline(
            wakeRecoveryScore: 90,
            sleepHours: 8.0,
            targetSleepHours: 8.0,
            pureNeatKcal: 400.0,
            events: [eveningEvent],
            immuneState: .optimal,
            currentHour: 12,
            calendar: calendar,
            referenceDate: refDate
        )

        // At hour 6 (before both workouts): batteries must be identical (wake baseline)
        let morningHour6 = morningEval.timeline.first(where: { $0.hour == 6 })?.batteryLevel ?? 0
        let eveningHour6 = eveningEval.timeline.first(where: { $0.hour == 6 })?.batteryLevel ?? 0
        XCTAssertEqual(morningHour6, eveningHour6)

        // At hour 7: Morning workout has drained substantially; Evening workout has only basal drain
        let morningHour7 = morningEval.timeline.first(where: { $0.hour == 7 })?.batteryLevel ?? 0
        let eveningHour7 = eveningEval.timeline.first(where: { $0.hour == 7 })?.batteryLevel ?? 0
        XCTAssertLessThan(morningHour7, eveningHour7, "07:00 workout must drain battery at hour 7")
        XCTAssertGreaterThan(eveningHour7 - morningHour7, 20, "Morning workout drop must be >= 20% compared to basal-only drain")

        // At hour 18: Evening workout has NOT drained yet
        let eveningHour18 = eveningEval.timeline.first(where: { $0.hour == 18 })?.batteryLevel ?? 0
        let eveningHour19 = eveningEval.timeline.first(where: { $0.hour == 19 })?.batteryLevel ?? 0
        XCTAssertGreaterThan(eveningHour18 - eveningHour19, 25, "19:00 workout must drain heavily during hour 19, not before")

        // At currentHour 12: morning workout is already reflected, evening workout is not
        XCTAssertLessThan(morningEval.currentBattery, eveningEval.currentBattery)
    }

    func testEarlyMorningWorkout0600DrainsHour6() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let refDate = Date(timeIntervalSince1970: 1_700_000_000)

        let earlyEvent = WorkoutBatteryEvent(hour: 6, trimp: 60.0, calendar: calendar, referenceDate: refDate)
        let eval = TrainingLoadAndBatteryEngine.computeEnergyBankTimeline(
            wakeRecoveryScore: 90,
            sleepHours: 8.0,
            pureNeatKcal: 400.0,
            events: [earlyEvent],
            immuneState: .optimal,
            currentHour: 7,
            calendar: calendar,
            referenceDate: refDate
        )

        let hour5 = eval.timeline.first(where: { $0.hour == 5 })?.batteryLevel ?? 0
        let hour6 = eval.timeline.first(where: { $0.hour == 6 })?.batteryLevel ?? 0
        XCTAssertLessThan(hour6, hour5, "06:00 workout must drain battery during hour 6")
        XCTAssertEqual(hour5, eval.wakeBattery, "Hour 5 must remain at wake baseline")
    }

    func testMultipleWorkoutsTiming() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let refDate = Date(timeIntervalSince1970: 1_700_000_000)

        let w1 = WorkoutBatteryEvent(hour: 9, trimp: 50.0, calendar: calendar, referenceDate: refDate)
        let w2 = WorkoutBatteryEvent(hour: 18, trimp: 50.0, calendar: calendar, referenceDate: refDate)

        let eval = TrainingLoadAndBatteryEngine.computeEnergyBankTimeline(
            wakeRecoveryScore: 90,
            sleepHours: 8.0,
            pureNeatKcal: 400.0,
            events: [w1, w2],
            immuneState: .optimal,
            currentHour: 20,
            calendar: calendar,
            referenceDate: refDate
        )

        let h8 = eval.timeline.first(where: { $0.hour == 8 })?.batteryLevel ?? 0
        let h9 = eval.timeline.first(where: { $0.hour == 9 })?.batteryLevel ?? 0
        let drop9 = h8 - h9
        XCTAssertGreaterThan(drop9, 15, "Hour 9 must experience first workout drop")

        let h17 = eval.timeline.first(where: { $0.hour == 17 })?.batteryLevel ?? 0
        let h18 = eval.timeline.first(where: { $0.hour == 18 })?.batteryLevel ?? 0
        let drop18 = h17 - h18
        XCTAssertGreaterThan(drop18, 15, "Hour 18 must experience second workout drop")
    }

    // MARK: - 3. Vitals & Illness Confluence: Method Matching & Confluence Boundaries (Audit F04)

    func testMissingVitalsRemainUnmeasuredAndAreNeverSubstituted() {
        let baseline = NocturnalVitalsBaseline(
            hrvMeanMs: 102.0,
            rhrMeanBpm: 49.0,
            wristTempMeanCelsius: 36.40,
            respiratoryRateMeanBpm: 14.2,
            spo2MeanPct: 97.8
        )

        // Only HRV and RHR provided; temp, resp, spo2 are unmeasured (nil)
        let input = NocturnalVitalsInput(
            hrvMs: 100.0,
            rhrBpm: 49.0,
            wristTempCelsius: nil,
            wristTempDeltaCelsius: nil,
            respiratoryRateBpm: nil,
            spo2Pct: nil
        )

        let eval = VitalsAndIllnessEngine.evaluateOvernightVitals(input: input, baseline: baseline)

        XCTAssertNil(eval.tempPillar, "Missing wrist temperature must remain nil, not substituted with baseline")
        XCTAssertNil(eval.respPillar, "Missing respiratory rate must remain nil, not substituted with baseline")
        XCTAssertNil(eval.spo2Pillar, "Missing SpO2 must remain nil, not substituted with baseline")
        XCTAssertEqual(eval.allPillars.count, 2, "allPillars must only contain measured pillars")
        XCTAssertEqual(eval.state, .optimal)
    }

    func testSingleMetricNormalVarianceIsTrainingFatigue() {
        let baseline = NocturnalVitalsBaseline(
            hrvMeanMs: 102.0,
            rhrMeanBpm: 49.0,
            wristTempMeanCelsius: 36.40
        )

        // Single metric deviation: depressed HRV (70 ms vs 102 ms baseline, outlier), but RHR and temp normal
        let input = NocturnalVitalsInput(
            hrvMs: 70.0,
            rhrBpm: 49.0,
            wristTempCelsius: 36.45,
            wristTempDeltaCelsius: 0.05
        )

        let eval = VitalsAndIllnessEngine.evaluateOvernightVitals(input: input, baseline: baseline)

        XCTAssertEqual(eval.outliersCount, 1)
        XCTAssertEqual(eval.state, .trainingFatigue, "Single-metric deviation without fever is training fatigue, NOT illness alarm")
    }

    func testThreeOrMoreDeviatingVitalsTriggersIllnessProdrome() {
        let baseline = NocturnalVitalsBaseline(
            hrvMeanMs: 102.0,
            rhrMeanBpm: 49.0,
            wristTempMeanCelsius: 36.40,
            respiratoryRateMeanBpm: 14.2,
            spo2MeanPct: 97.8
        )

        // 3 outliers: depressed HRV (55ms), elevated RHR (56bpm), elevated respiration (16.5)
        let input = NocturnalVitalsInput(
            hrvMs: 55.0,
            rhrBpm: 56.0,
            wristTempCelsius: 36.45,
            wristTempDeltaCelsius: 0.05,
            respiratoryRateBpm: 16.5,
            spo2Pct: 97.5
        )

        let eval = VitalsAndIllnessEngine.evaluateOvernightVitals(input: input, baseline: baseline)

        XCTAssertGreaterThanOrEqual(eval.outliersCount, 3)
        XCTAssertEqual(eval.state, .illnessProdrome, ">= 3 deviating vitals must trigger illnessProdrome")
    }

    func testWristTempDeltaOutlierWithAutonomicShiftTriggersIllnessProdrome() {
        let baseline = NocturnalVitalsBaseline(
            hrvMeanMs: 102.0,
            rhrMeanBpm: 49.0,
            wristTempMeanCelsius: 36.40
        )

        // Wrist temp delta +0.45°C (outlier) converging with autonomic shift (HRV 58ms outlier)
        let input = NocturnalVitalsInput(
            hrvMs: 58.0,
            rhrBpm: 50.0,
            wristTempCelsius: 36.85,
            wristTempDeltaCelsius: 0.45
        )

        let eval = VitalsAndIllnessEngine.evaluateOvernightVitals(input: input, baseline: baseline)

        XCTAssertEqual(eval.tempPillar?.status, .outlier)
        XCTAssertEqual(eval.hrvPillar.status, .outlier)
        XCTAssertEqual(eval.state, .illnessProdrome, "Wrist temp delta >= +0.40°C with autonomic shift must trigger illnessProdrome")
    }

    func testHrvMethodConsistencyNeverComparesRmssdToSdnnBaseline() {
        // SDNN baseline (typical ~102 ms)
        let sdnnBaseline = NocturnalVitalsBaseline(
            hrvMeanMs: 102.0,
            hrvStdDevMs: 15.0,
            hrvMethod: .sdnn,
            rhrMeanBpm: 49.0
        )

        // RMSSD observation of 52 ms (normal for RMSSD, but would be -4.5 Z-score outlier if compared to SDNN 102 ms)
        let input = NocturnalVitalsInput(
            hrvMs: 52.0,
            hrvMethod: .rmssd,
            rhrBpm: 49.0
        )

        let eval = VitalsAndIllnessEngine.evaluateOvernightVitals(input: input, baseline: sdnnBaseline)

        // Incompatible method must be treated as unmeasured, NOT a false outlier
        XCTAssertEqual(eval.hrvPillar.status, .unmeasured, "Mismatched HRV method must not compare RMSSD to SDNN baseline")
        XCTAssertNil(eval.hrvPillar.zScore, "Z-Score must be nil for mismatched HRV method")
        XCTAssertEqual(eval.outliersCount, 0, "Mismatched HRV must not generate a false outlier")
        XCTAssertEqual(eval.state, .optimal)
    }

    func testISO8601FractionalSecondsWorkoutTimestampParsing() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let isoFractional = ISO8601DateFormatter()
        isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoStandard = ISO8601DateFormatter()

        let rawDateStringWithFraction = "2026-11-13T08:30:15.456Z"
        let parsed = isoFractional.date(from: rawDateStringWithFraction) ?? isoStandard.date(from: rawDateStringWithFraction)
        XCTAssertNotNil(parsed, "ISO8601 string with fractional seconds must parse successfully")

        if let date = parsed {
            let hour = calendar.component(.hour, from: date)
            XCTAssertEqual(hour, 8, "Parsed hour must be 8:00 AM, not fallback 17:00")
        }
    }
}
