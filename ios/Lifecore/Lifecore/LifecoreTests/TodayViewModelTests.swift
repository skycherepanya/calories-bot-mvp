import XCTest
import Combine
import Foundation
@testable import Lifecore

@MainActor
final class TodayViewModelTests: XCTestCase {

    private var cancellables = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()
        AppEnvironment.current = AppEnvironment.fixture()
    }

    override func tearDown() {
        cancellables.removeAll()
        AppEnvironment.reset()
        super.tearDown()
    }

    // MARK: - Helpers

    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
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
        return calendar.date(from: comps)!
    }

    private func makeWorkloadEvaluation(
        daysCount: Int,
        dailyTrimp: Double = 55.0,
        anchorDate: Date
    ) -> ACWREvaluation {
        let cal = utcCalendar
        let series: [DailyLoadSeries] = (0..<daysCount).map { offset in
            let d = cal.date(byAdding: .day, value: -(daysCount - 1 - offset), to: anchorDate)!
            return .observed(date: d, trimpLoad: dailyTrimp)
        }
        return TrainingLoadAndBatteryEngine.computeEWMAWorkload(series: series, calendar: cal)!
    }

    private func makeOptimalVitals(hrvMs: Double = 104.0, rhrBpm: Double = 49.0) -> OvernightVitalsEvaluation {
        let input = NocturnalVitalsInput(
            hrvMs: hrvMs,
            hrvMethod: .rmssd,
            rhrBpm: rhrBpm,
            wristTempDeltaCelsius: 0.05,
            respiratoryRateBpm: 14.1,
            spo2Pct: 98.0
        )
        let baseline = NocturnalVitalsBaseline(
            hrvMeanMs: 102.0,
            hrvStdDevMs: 15.0,
            hrvMethod: .rmssd,
            rhrMeanBpm: 49.0,
            rhrStdDevBpm: 2.5,
            wristTempMeanCelsius: 36.40,
            respiratoryRateMeanBpm: 14.2,
            spo2MeanPct: 97.8
        )
        return VitalsAndIllnessEngine.evaluateOvernightVitals(input: input, baseline: baseline)
    }

    private func makeIllnessVitals() -> OvernightVitalsEvaluation {
        let input = NocturnalVitalsInput(
            hrvMs: 65.0,
            hrvMethod: .rmssd,
            rhrBpm: 58.0,
            wristTempCelsius: 37.05,
            wristTempDeltaCelsius: 0.65,
            respiratoryRateBpm: 17.5,
            spo2Pct: 94.0
        )
        let baseline = NocturnalVitalsBaseline(
            hrvMeanMs: 102.0,
            hrvStdDevMs: 15.0,
            hrvMethod: .rmssd,
            rhrMeanBpm: 49.0,
            rhrStdDevBpm: 2.5,
            wristTempMeanCelsius: 36.40,
            respiratoryRateMeanBpm: 14.2,
            spo2MeanPct: 97.8
        )
        return VitalsAndIllnessEngine.evaluateOvernightVitals(input: input, baseline: baseline)
    }

    // MARK: - Test Doubles

    @MainActor
    private final class MockSnapshotDataSource: DailySnapshotDataSource {
        var inputsProvider: (@Sendable (DietaryDay) throws -> DailySnapshotRawInputs)?
        var callCount: Int = 0

        init(inputsProvider: (@Sendable (DietaryDay) throws -> DailySnapshotRawInputs)? = nil) {
            self.inputsProvider = inputsProvider
        }

        func fetchSnapshotInputs(for day: DietaryDay) async throws -> DailySnapshotRawInputs {
            callCount += 1
            if let provider = inputsProvider {
                return try provider(day)
            }
            return DailySnapshotRawInputs(day: day, hasAnyObservation: false)
        }
    }

    // MARK: - Tests

    // (a) no data -> prescriptionPlan == nil, readinessScore == nil, no 85% / .optimal
    func testFixtureA_noData_producesNilPrescriptionAndReadinessWithoutFakeDefaults() async {
        let cal = utcCalendar
        let anchorDate = makeDate(year: 2026, month: 11, day: 13, hour: 9, minute: 0, in: cal)
        let day = DietaryDay.containing(anchorDate, calendar: cal)

        let dataSource = MockSnapshotDataSource { targetDay in
            DailySnapshotRawInputs(day: targetDay, hasAnyObservation: false)
        }

        let coordinator = DailySnapshotCoordinator(
            dataSource: dataSource,
            calendar: cal,
            now: { anchorDate },
            freshnessWindowSeconds: 0,
            observeStoreMutations: false
        )

        let viewModel = TodayViewModel(coordinator: coordinator)
        await viewModel.refresh(force: true)

        guard let snapshot = viewModel.snapshot else {
            XCTFail("Expected non-nil snapshot in content state")
            return
        }

        XCTAssertNil(snapshot.prescriptionPlan, "Prescription plan must be nil when no observations exist")
        XCTAssertNil(snapshot.readinessScore, "Readiness score must never substitute synthetic 85%")
        XCTAssertNil(snapshot.morningBodyBattery, "Morning battery must never substitute synthetic 82%")
        XCTAssertNil(snapshot.currentBodyBattery, "Current battery must be nil without observations")
        XCTAssertNil(snapshot.vitalsEvaluation, "Vitals evaluation must be nil without measurements")

        XCTAssertTrue(snapshot.unavailabilityReasons.contains(.noObservationsAvailable))
        XCTAssertTrue(snapshot.unavailabilityReasons.contains(.missingOvernightVitals))
        XCTAssertTrue(snapshot.unavailabilityReasons.contains(.missingWorkloadHistory))
    }

    // (b) partial night -> missing vitals inhibits prescription
    func testFixtureB_partialNight_missingVitalsInhibitsPrescription() async {
        let cal = utcCalendar
        let anchorDate = makeDate(year: 2026, month: 11, day: 13, hour: 9, minute: 0, in: cal)
        let day = DietaryDay.containing(anchorDate, calendar: cal)

        let sleep = SleepEpisode(
            interval: DateInterval(
                start: makeDate(year: 2026, month: 11, day: 12, hour: 23, minute: 0, in: cal),
                end: makeDate(year: 2026, month: 11, day: 13, hour: 6, minute: 30, in: cal)
            ),
            stages: [],
            totalSleepDurationSeconds: 7.5 * 3600.0,
            hrv: nil,
            restingHeartRate: nil
        )

        let dataSource = MockSnapshotDataSource { targetDay in
            DailySnapshotRawInputs(
                day: targetDay,
                sleepEpisode: sleep,
                vitalsEvaluation: nil,
                readinessScore: nil,
                morningBodyBattery: nil,
                currentBodyBattery: nil,
                workloadEvaluation: nil,
                restingHr: 49.0,
                maxHr: 192.0,
                hasAnyObservation: true
            )
        }

        let coordinator = DailySnapshotCoordinator(
            dataSource: dataSource,
            calendar: cal,
            now: { anchorDate },
            freshnessWindowSeconds: 0,
            observeStoreMutations: false
        )

        let viewModel = TodayViewModel(coordinator: coordinator)
        await viewModel.refresh(force: true)

        guard let snapshot = viewModel.snapshot else {
            XCTFail("Expected non-nil snapshot")
            return
        }

        XCTAssertNil(snapshot.prescriptionPlan, "Prescription must remain nil when nocturnal vitals are missing")
        XCTAssertTrue(snapshot.unavailabilityReasons.contains(.missingOvernightVitals))
    }

    // (c) measured ready day -> optimal prescription and recovery
    func testFixtureC_measuredReadyDay_producesOptimalPrescriptionAndRecovery() async {
        let cal = utcCalendar
        let anchorDate = makeDate(year: 2026, month: 11, day: 13, hour: 9, minute: 0, in: cal)
        let day = DietaryDay.containing(anchorDate, calendar: cal)

        let vitals = makeOptimalVitals()
        let workload = makeWorkloadEvaluation(daysCount: 28, dailyTrimp: 55.0, anchorDate: anchorDate)
        let sleep = SleepEpisode(
            interval: DateInterval(
                start: makeDate(year: 2026, month: 11, day: 12, hour: 23, minute: 0, in: cal),
                end: makeDate(year: 2026, month: 11, day: 13, hour: 7, minute: 0, in: cal)
            ),
            stages: [],
            totalSleepDurationSeconds: 8.0 * 3600.0
        )

        let dataSource = MockSnapshotDataSource { targetDay in
            DailySnapshotRawInputs(
                day: targetDay,
                queueState: RollingQueueState(currentIndex: 0),
                goalConfig: TrainingGoalConfig(),
                sleepEpisode: sleep,
                vitalsEvaluation: vitals,
                readinessScore: 92,
                morningBodyBattery: 88,
                currentBodyBattery: 85,
                workloadEvaluation: workload,
                restingHr: 48.0,
                maxHr: 192.0,
                hasAnyObservation: true
            )
        }

        let coordinator = DailySnapshotCoordinator(
            dataSource: dataSource,
            calendar: cal,
            now: { anchorDate },
            freshnessWindowSeconds: 0,
            observeStoreMutations: false
        )

        let viewModel = TodayViewModel(coordinator: coordinator)
        await viewModel.refresh(force: true)

        guard let snapshot = viewModel.snapshot else {
            XCTFail("Expected non-nil snapshot")
            return
        }

        XCTAssertEqual(snapshot.readinessScore, 92)
        XCTAssertEqual(snapshot.morningBodyBattery, 88)
        XCTAssertNotNil(snapshot.prescriptionPlan)
        XCTAssertTrue(snapshot.unavailabilityReasons.isEmpty)
        XCTAssertEqual(snapshot.prescriptionPlan?.today.adaptationReason, .optimalProgression)
    }

    // (d) low battery / illness confluence day
    func testFixtureD_lowBatteryAndIllnessConfluence_downgradesOrBlocksPrescription() async {
        let cal = utcCalendar
        let anchorDate = makeDate(year: 2026, month: 11, day: 13, hour: 9, minute: 0, in: cal)
        let day = DietaryDay.containing(anchorDate, calendar: cal)

        let vitals = makeIllnessVitals()
        let workload = makeWorkloadEvaluation(daysCount: 28, dailyTrimp: 55.0, anchorDate: anchorDate)

        let dataSource = MockSnapshotDataSource { targetDay in
            DailySnapshotRawInputs(
                day: targetDay,
                queueState: RollingQueueState(currentIndex: 1),
                goalConfig: TrainingGoalConfig(),
                vitalsEvaluation: vitals,
                readinessScore: 42,
                morningBodyBattery: 25,
                currentBodyBattery: 20,
                workloadEvaluation: workload,
                restingHr: 48.0,
                maxHr: 192.0,
                hasAnyObservation: true
            )
        }

        let coordinator = DailySnapshotCoordinator(
            dataSource: dataSource,
            calendar: cal,
            now: { anchorDate },
            freshnessWindowSeconds: 0,
            observeStoreMutations: false
        )

        let viewModel = TodayViewModel(coordinator: coordinator)
        await viewModel.refresh(force: true)

        guard let snapshot = viewModel.snapshot else {
            XCTFail("Expected non-nil snapshot")
            return
        }

        XCTAssertNotNil(snapshot.prescriptionPlan)
        XCTAssertEqual(snapshot.vitalsEvaluation?.state, .illnessProdrome)
        XCTAssertEqual(snapshot.prescriptionPlan?.today.adaptationReason, .blockedByIllnessProdrome)
        XCTAssertEqual(snapshot.prescriptionPlan?.today.totalDurationMin, 0.0)
    }

    // (e) stale cached snapshot retained on refresh error
    func testFixtureE_staleCachedSnapshotRetainedOnRefreshError() async {
        let cal = utcCalendar
        let anchorDate = makeDate(year: 2026, month: 11, day: 13, hour: 9, minute: 0, in: cal)

        var shouldFail = false
        let dataSource = MockSnapshotDataSource { targetDay in
            if shouldFail {
                throw NSError(domain: "TestNetworkError", code: -1009, userInfo: [NSLocalizedDescriptionKey: "Offline"])
            }
            return DailySnapshotRawInputs(
                day: targetDay,
                readinessScore: 84,
                morningBodyBattery: 80,
                restingHr: 48.0,
                maxHr: 192.0,
                hasAnyObservation: true
            )
        }

        let coordinator = DailySnapshotCoordinator(
            dataSource: dataSource,
            calendar: cal,
            now: { anchorDate },
            freshnessWindowSeconds: 0,
            observeStoreMutations: false
        )

        let viewModel = TodayViewModel(coordinator: coordinator)
        await viewModel.refresh(force: true)

        guard let firstSnapshot = viewModel.snapshot else {
            XCTFail("Expected valid first snapshot")
            return
        }
        let initialRevision = firstSnapshot.revision

        // Next refresh fails
        shouldFail = true
        await viewModel.refresh(force: true)

        switch viewModel.state {
        case .failed(let message, let retained):
            XCTAssertEqual(message, "Offline")
            XCTAssertNotNil(retained, "Retained snapshot must be preserved on failure")
            XCTAssertEqual(retained?.revision, initialRevision)
        default:
            XCTFail("Expected failed state with retained snapshot, got \(viewModel.state)")
        }
    }

    // (f) 03:59 -> 04:00 dietary day rollover
    func testFixtureF_dietaryDayRolloverFrom0359To0400() async {
        let cal = utcCalendar
        var simulatedNow = makeDate(year: 2026, month: 11, day: 13, hour: 3, minute: 59, second: 50, in: cal)

        let dataSource = MockSnapshotDataSource { targetDay in
            DailySnapshotRawInputs(day: targetDay, hasAnyObservation: false)
        }

        let coordinator = DailySnapshotCoordinator(
            dataSource: dataSource,
            calendar: cal,
            now: { simulatedNow },
            freshnessWindowSeconds: 0,
            observeStoreMutations: false
        )

        let viewModel = TodayViewModel(coordinator: coordinator)
        await viewModel.refresh(force: true)

        // At 03:59, the dietary day belongs to previous calendar day (Nov 12)
        XCTAssertEqual(viewModel.currentDay.key, "2026-11-12")

        // Advance to 04:00:10
        simulatedNow = makeDate(year: 2026, month: 11, day: 13, hour: 4, minute: 0, second: 10, in: cal)
        let rolledOver = await coordinator.checkDietaryDayRolloverIfNeeded()

        XCTAssertTrue(rolledOver, "Coordinator should detect day rollover at 04:00")
        XCTAssertEqual(coordinator.lastInvalidationReason, .dietaryDayRollover)
        XCTAssertEqual(viewModel.currentDay.key, "2026-11-13")
        XCTAssertEqual(viewModel.snapshot?.day.key, "2026-11-13")
    }

    // (g) profile comma decimal validation + invalidation
    func testFixtureG_profileCommaDecimalValidationAndInvalidation() async {
        // 1. Locale-aware numeric parsing
        XCTAssertEqual(LocaleNumericParser.parseDouble("79,5"), 79.5)
        XCTAssertEqual(LocaleNumericParser.parseDouble("79.5"), 79.5)
        XCTAssertEqual(LocaleNumericParser.parseDouble("  181,2  "), 181.2)
        XCTAssertEqual(LocaleNumericParser.parseDouble("36,40"), 36.40)
        XCTAssertNil(LocaleNumericParser.parseDouble("invalid_string"))
        XCTAssertNil(LocaleNumericParser.parseDouble(""))
        XCTAssertEqual(LocaleNumericParser.parseInt("28"), 28)
        XCTAssertEqual(LocaleNumericParser.parseInt("28.0"), 28)
        XCTAssertNil(LocaleNumericParser.parseInt("invalid"))

        // 2. Profile invalidation flow
        let cal = utcCalendar
        let anchorDate = makeDate(year: 2026, month: 11, day: 13, hour: 10, minute: 0, in: cal)

        let dataSource = MockSnapshotDataSource { targetDay in
            DailySnapshotRawInputs(day: targetDay, hasAnyObservation: false)
        }

        let coordinator = DailySnapshotCoordinator(
            dataSource: dataSource,
            calendar: cal,
            now: { anchorDate },
            freshnessWindowSeconds: 0,
            observeStoreMutations: false
        )

        let viewModel = TodayViewModel(coordinator: coordinator)
        await viewModel.refresh(force: true)

        var profile = AthleteProfileStore.shared.profile
        profile.weightKg = 79.5
        AthleteProfileStore.shared.profile = profile
        AthleteProfileStore.shared.save()

        await coordinator.invalidate(reason: .profileUpdated)

        XCTAssertEqual(coordinator.lastInvalidationReason, .profileUpdated)
        XCTAssertNotNil(viewModel.snapshot)
    }

    // (h) shared revision consistency across subscribers
    func testFixtureH_sharedRevisionConsistencyAcrossSubscribers() async {
        let cal = utcCalendar
        let anchorDate = makeDate(year: 2026, month: 11, day: 13, hour: 10, minute: 0, in: cal)

        let dataSource = MockSnapshotDataSource { targetDay in
            DailySnapshotRawInputs(
                day: targetDay,
                readinessScore: 88,
                morningBodyBattery: 85,
                restingHr: 48.0,
                maxHr: 192.0,
                hasAnyObservation: true
            )
        }

        let coordinator = DailySnapshotCoordinator(
            dataSource: dataSource,
            calendar: cal,
            now: { anchorDate },
            freshnessWindowSeconds: 0,
            observeStoreMutations: false
        )

        let vm1 = TodayViewModel(coordinator: coordinator)
        let vm2 = TodayViewModel(coordinator: coordinator)

        await coordinator.refresh(force: true)

        guard let snap1 = vm1.snapshot, let snap2 = vm2.snapshot else {
            XCTFail("Both ViewModels must observe content snapshots")
            return
        }

        XCTAssertEqual(snap1.revision, snap2.revision, "Both subscribers must observe matching revision UUID")
        XCTAssertEqual(snap1.readinessScore, snap2.readinessScore)

        // Invalidate coordinator
        await coordinator.invalidate(reason: .manual)

        guard let snap1After = vm1.snapshot, let snap2After = vm2.snapshot else {
            XCTFail("Both ViewModels must observe content snapshots after invalidation")
            return
        }

        XCTAssertEqual(snap1After.revision, snap2After.revision, "Both subscribers must maintain matching revision UUID")
        XCTAssertNotEqual(snap1After.revision, snap1.revision, "Revision must update on invalidation")
    }
}
