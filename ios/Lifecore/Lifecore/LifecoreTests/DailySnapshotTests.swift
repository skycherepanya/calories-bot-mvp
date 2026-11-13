import XCTest
import Combine
import Foundation
@testable import Lifecore

@MainActor
final class DailySnapshotTests: XCTestCase {

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

    private var budapestCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Budapest")!
        return cal
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        second: Int,
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

    // MARK: - 1. Shared Revision & Plan Across Two Subscribers

    func testTwoSubscribersObserveSameRevisionAndPlanInLowBatteryConfluenceFixture() async {
        let cal = utcCalendar
        let nowDate = makeDate(year: 2026, month: 11, day: 13, hour: 8, minute: 30, second: 0, in: cal)
        let day = DietaryDay.containing(nowDate, calendar: cal)

        let vitals = makeOptimalVitals()
        let workload = makeWorkloadEvaluation(daysCount: 28, dailyTrimp: 58.0, anchorDate: nowDate)
        let queueState = RollingQueueState(currentIndex: 1) // .cruiseThresholdIntervals (quality session)

        let rawInputs = DailySnapshotRawInputs(
            day: day,
            queueState: queueState,
            goalConfig: TrainingGoalConfig(),
            vitalsEvaluation: vitals,
            readinessScore: 54,
            morningBodyBattery: 32, // < 40% triggers .downgradedByVitalsOrBattery
            currentBodyBattery: 30,
            workloadEvaluation: workload,
            restingHr: 49.0,
            maxHr: 192.0
        )

        let dataSource = StaticSnapshotDataSource(inputs: rawInputs)
        let coordinator = DailySnapshotCoordinator(
            dataSource: dataSource,
            calendar: cal,
            now: { nowDate }
        )

        var subscriberASnapshots: [DailyDashboardSnapshot] = []
        var subscriberBSnapshots: [DailyDashboardSnapshot] = []

        coordinator.$state
            .compactMap(\.value)
            .sink { subscriberASnapshots.append($0) }
            .store(in: &cancellables)

        coordinator.$state
            .compactMap(\.value)
            .sink { subscriberBSnapshots.append($0) }
            .store(in: &cancellables)

        await coordinator.refresh()

        XCTAssertEqual(subscriberASnapshots.count, 1)
        XCTAssertEqual(subscriberBSnapshots.count, 1)

        let snapA = try! XCTUnwrap(subscriberASnapshots.last)
        let snapB = try! XCTUnwrap(subscriberBSnapshots.last)

        XCTAssertEqual(snapA.revision, snapB.revision)
        XCTAssertEqual(snapA.requestGeneration, snapB.requestGeneration)
        XCTAssertEqual(snapA.prescriptionPlan, snapB.prescriptionPlan)
        XCTAssertEqual(snapA.morningBodyBattery, 32)
        XCTAssertTrue(snapA.unavailabilityReasons.isEmpty)

        let plan = try! XCTUnwrap(snapA.prescriptionPlan)
        XCTAssertEqual(plan.today.adaptationReason, .downgradedByVitalsOrBattery)
        XCTAssertEqual(plan.today.maxAllowedZone, .zone2Easy)
        XCTAssertEqual(plan.today.archetype, .recoveryFlush)
        XCTAssertEqual(plan.today.preservedQueuedArchetype, .cruiseThresholdIntervals)
    }

    // MARK: - 2. Missing Inputs -> Nil Plan & Explicit Unavailability Reasons

    func testNoRequiredInputsProducesNilPrescriptionPlanAndExplicitUnavailabilityReasons() async {
        let cal = utcCalendar
        let nowDate = makeDate(year: 2026, month: 11, day: 13, hour: 9, minute: 0, second: 0, in: cal)
        let day = DietaryDay.containing(nowDate, calendar: cal)

        let emptyInputs = DailySnapshotRawInputs(day: day)
        let coordinator = DailySnapshotCoordinator(
            dataSource: StaticSnapshotDataSource(inputs: emptyInputs),
            calendar: cal,
            now: { nowDate }
        )

        await coordinator.refresh()

        let snapshot = try! XCTUnwrap(coordinator.state.value)
        XCTAssertNil(snapshot.prescriptionPlan)
        XCTAssertNil(snapshot.readinessScore)
        XCTAssertNil(snapshot.morningBodyBattery)
        XCTAssertTrue(snapshot.unavailabilityReasons.contains(.noObservationsAvailable))
        XCTAssertTrue(snapshot.unavailabilityReasons.contains(.missingOvernightVitals))
        XCTAssertTrue(snapshot.unavailabilityReasons.contains(.missingWorkloadHistory))

        // Also verify partial unavailability in TrainingPrescriptionService directly
        let vitalsOnlyOutcome = TrainingPrescriptionService.evaluate(
            queueState: RollingQueueState(),
            vitalsEvaluation: makeOptimalVitals(),
            morningBodyBattery: 84,
            workloadEvaluation: nil,
            restingHr: 49.0,
            maxHr: 192.0
        )
        XCTAssertNil(vitalsOnlyOutcome.plan)
        XCTAssertEqual(vitalsOnlyOutcome.unavailabilityReasons, [.missingWorkloadHistory])

        let workloadOnlyOutcome = TrainingPrescriptionService.evaluate(
            queueState: RollingQueueState(),
            vitalsEvaluation: nil,
            morningBodyBattery: nil,
            workloadEvaluation: makeWorkloadEvaluation(daysCount: 28, anchorDate: nowDate),
            restingHr: 49.0,
            maxHr: 192.0
        )
        XCTAssertNil(workloadOnlyOutcome.plan)
        XCTAssertEqual(workloadOnlyOutcome.unavailabilityReasons, [.missingOvernightVitals])

        // Insufficient workload coverage must also fail unavailability guard
        let insufficientWorkload = TrainingLoadAndBatteryEngine.computeEWMAWorkload(dailyLoads: [])
        let insufficientOutcome = TrainingPrescriptionService.evaluate(
            queueState: RollingQueueState(),
            vitalsEvaluation: makeOptimalVitals(),
            morningBodyBattery: 84,
            workloadEvaluation: insufficientWorkload,
            restingHr: 49.0,
            maxHr: 192.0
        )
        XCTAssertNil(insufficientOutcome.plan)
        XCTAssertEqual(insufficientOutcome.unavailabilityReasons, [.missingWorkloadHistory])

        // Missing HR baselines must produce explicit unavailability instead of fallback HR bounds
        let missingHROutcome = TrainingPrescriptionService.evaluate(
            queueState: RollingQueueState(),
            vitalsEvaluation: makeOptimalVitals(),
            morningBodyBattery: 84,
            workloadEvaluation: makeWorkloadEvaluation(daysCount: 28, anchorDate: nowDate),
            restingHr: nil,
            maxHr: nil
        )
        XCTAssertNil(missingHROutcome.plan)
        XCTAssertEqual(missingHROutcome.unavailabilityReasons, [.missingHeartRateBaselines])
    }

    // MARK: - 3. Generation Guard & Cached Content Retention During Refresh

    func testDelayedOldRequestCannotOverwriteNewerSnapshotAndRetainsCachedContentDuringRefresh() async {
        let cal = utcCalendar
        let nowDate = makeDate(year: 2026, month: 11, day: 13, hour: 10, minute: 0, second: 0, in: cal)
        let day = DietaryDay.containing(nowDate, calendar: cal)
        let vitals = makeOptimalVitals()
        let workload = makeWorkloadEvaluation(daysCount: 28, anchorDate: nowDate)

        func makeInputs(readiness: Int, battery: Int) -> DailySnapshotRawInputs {
            DailySnapshotRawInputs(
                day: day,
                vitalsEvaluation: vitals,
                readinessScore: readiness,
                morningBodyBattery: battery,
                currentBodyBattery: battery,
                workloadEvaluation: workload,
                restingHr: 49.0,
                maxHr: 192.0
            )
        }

        let dataSource = ControllableSnapshotDataSource(
            plans: [
                1: .immediate(makeInputs(readiness: 78, battery: 76)),
                2: .suspended(makeInputs(readiness: 60, battery: 58)),
                3: .immediate(makeInputs(readiness: 91, battery: 90))
            ]
        )
        let coordinator = DailySnapshotCoordinator(
            dataSource: dataSource,
            calendar: cal,
            now: { nowDate }
        )

        // 1. Seed initial cached snapshot (call 1)
        await coordinator.refresh()
        let initialSnapshot = try! XCTUnwrap(coordinator.state.value)
        XCTAssertEqual(initialSnapshot.readinessScore, 78)
        XCTAssertEqual(initialSnapshot.requestGeneration, 1)
        XCTAssertFalse(coordinator.state.isRefreshing)

        // 2. Start slow older forced request (call 2) and wait until it is suspended in flight
        let slowTask = Task {
            await coordinator.refresh(force: true)
        }
        await dataSource.waitUntilEntered(call: 2)

        // Cached content must remain visible with isRefreshing == true while awaiting
        XCTAssertTrue(coordinator.state.isRefreshing)
        XCTAssertEqual(coordinator.state.value?.revision, initialSnapshot.revision)
        XCTAssertEqual(coordinator.state.value?.readinessScore, 78)

        // 3. Fire newer fast forced request (call 3) and await completion
        await coordinator.refresh(force: true)
        let newerSnapshot = try! XCTUnwrap(coordinator.state.value)
        XCTAssertEqual(newerSnapshot.readinessScore, 91)
        XCTAssertEqual(newerSnapshot.requestGeneration, 3)
        XCTAssertFalse(coordinator.state.isRefreshing)

        // 4. Release delayed call 2; it must NOT overwrite call 3's snapshot
        await dataSource.resume(call: 2)
        await slowTask.value

        let finalSnapshot = try! XCTUnwrap(coordinator.state.value)
        XCTAssertEqual(finalSnapshot.revision, newerSnapshot.revision)
        XCTAssertEqual(finalSnapshot.requestGeneration, 3)
        XCTAssertEqual(finalSnapshot.readinessScore, 91)
    }

    // MARK: - 4. Invalidation Reasons & 04:00 Dietary Day Rollover

    func testInvalidationOnProfileMealWorkoutAnd0400DietaryDayRollover() async {
        let cal = budapestCalendar
        let initialTime = makeDate(year: 2026, month: 11, day: 13, hour: 3, minute: 55, second: 0, in: cal)
        let clock = MutableClock(now: initialTime)
        let vitals = makeOptimalVitals()
        let workload = makeWorkloadEvaluation(daysCount: 28, anchorDate: initialTime)

        let dataSource = DynamicSnapshotDataSource { day in
            DailySnapshotRawInputs(
                day: day,
                vitalsEvaluation: vitals,
                readinessScore: 85,
                morningBodyBattery: 82,
                currentBodyBattery: 80,
                workloadEvaluation: workload,
                restingHr: 49.0,
                maxHr: 192.0,
                confirmedMealsCount: day.key == "2026-11-12" ? 3 : 0,
                confirmedIntakeKcal: day.key == "2026-11-12" ? 2150.0 : nil,
                latestWorkout: PhysiologyWorkoutSample(startedAt: clock.now, durationSeconds: 2400, trimp: 64.0)
            )
        }

        let coordinator = DailySnapshotCoordinator(
            dataSource: dataSource,
            calendar: cal,
            now: { clock.now }
        )

        await coordinator.refresh()
        XCTAssertEqual(coordinator.currentDay.key, "2026-11-12", "03:55 belongs to previous DietaryDay")
        let rev0 = coordinator.state.value?.revision

        // Profile updated invalidation
        await coordinator.invalidate(reason: .profileUpdated)
        XCTAssertEqual(coordinator.lastInvalidationReason, .profileUpdated)
        let rev1 = coordinator.state.value?.revision
        XCTAssertNotEqual(rev1, rev0)

        // Meal mutated invalidation
        await coordinator.invalidate(reason: .mealMutated)
        XCTAssertEqual(coordinator.lastInvalidationReason, .mealMutated)
        let rev2 = coordinator.state.value?.revision
        XCTAssertNotEqual(rev2, rev1)
        XCTAssertEqual(coordinator.state.value?.confirmedMealsCount, 3)

        // Workout mutated invalidation
        await coordinator.invalidate(reason: .workoutMutated)
        XCTAssertEqual(coordinator.lastInvalidationReason, .workoutMutated)
        let rev3 = coordinator.state.value?.revision
        XCTAssertNotEqual(rev3, rev2)
        XCTAssertNotNil(coordinator.state.value?.latestWorkout)

        // 03:59:59 is still same DietaryDay -> no rollover
        clock.now = makeDate(year: 2026, month: 11, day: 13, hour: 3, minute: 59, second: 59, in: cal)
        let didRollBefore4 = await coordinator.checkDietaryDayRolloverIfNeeded()
        XCTAssertFalse(didRollBefore4)
        XCTAssertEqual(coordinator.currentDay.key, "2026-11-12")
        XCTAssertEqual(coordinator.lastInvalidationReason, .workoutMutated)

        // 04:00:00 crosses boundary -> rolls over to 2026-11-13 and invalidates
        clock.now = makeDate(year: 2026, month: 11, day: 13, hour: 4, minute: 0, second: 0, in: cal)
        let didRollAt4 = await coordinator.checkDietaryDayRolloverIfNeeded()
        XCTAssertTrue(didRollAt4)
        XCTAssertEqual(coordinator.currentDay.key, "2026-11-13")
        XCTAssertEqual(coordinator.lastInvalidationReason, .dietaryDayRollover)
        XCTAssertEqual(coordinator.state.value?.day.key, "2026-11-13")
        XCTAssertEqual(coordinator.state.value?.confirmedMealsCount, 0)
    }

    // MARK: - 5. Provisional Workload Caps Aggressive Progression & Target ACWR

    func testProvisionalWorkloadCapsAggressiveProgressionAndTargetACWR() async {
        let cal = utcCalendar
        let nowDate = makeDate(year: 2026, month: 11, day: 13, hour: 9, minute: 0, second: 0, in: cal)
        let day = DietaryDay.containing(nowDate, calendar: cal)
        let vitals = makeOptimalVitals()

        let provisionalWorkload = makeWorkloadEvaluation(daysCount: 10, dailyTrimp: 50.0, anchorDate: nowDate)
        XCTAssertEqual(provisionalWorkload.coverage.confidence, .provisional)

        let fullWorkload = makeWorkloadEvaluation(daysCount: 28, dailyTrimp: 50.0, anchorDate: nowDate)
        XCTAssertEqual(fullWorkload.coverage.confidence, .fullConfidence)

        let aggressiveConfig = TrainingGoalConfig(
            weeklyRunDaysTarget: 5,
            maxSessionDurationMin: 60.0,
            targetACWRRatio: 1.20
        )

        let provisionalOutcome = TrainingPrescriptionService.evaluate(
            queueState: RollingQueueState(currentIndex: 0),
            config: aggressiveConfig,
            vitalsEvaluation: vitals,
            morningBodyBattery: 90,
            workloadEvaluation: provisionalWorkload,
            efSamples: [1.15, 1.18, 1.21, 1.24],
            recentLongRunDriftsPct: [2.0, 2.5, 2.2],
            efDelta30dPct: 4.5,
            restingHr: 49.0,
            maxHr: 192.0
        )

        let fullOutcome = TrainingPrescriptionService.evaluate(
            queueState: RollingQueueState(currentIndex: 0),
            config: aggressiveConfig,
            vitalsEvaluation: vitals,
            morningBodyBattery: 90,
            workloadEvaluation: fullWorkload,
            efSamples: [1.15, 1.18, 1.21, 1.24],
            recentLongRunDriftsPct: [2.0, 2.5, 2.2],
            efDelta30dPct: 4.5,
            restingHr: 49.0,
            maxHr: 192.0
        )

        XCTAssertTrue(provisionalOutcome.isProvisionalWorkload)
        XCTAssertFalse(fullOutcome.isProvisionalWorkload)

        let provisionalPlan = try! XCTUnwrap(provisionalOutcome.plan)
        let fullPlan = try! XCTUnwrap(fullOutcome.plan)

        XCTAssertNotEqual(
            provisionalPlan.today.adaptationReason,
            .efficiencyUnlocked,
            "Provisional history (<28 days) must not unlock efficiency duration scaling"
        )
        XCTAssertEqual(fullPlan.today.adaptationReason, .efficiencyUnlocked)

        let expectedCappedTrimp = round(
            TrainingPrescriptionEngine.computeDailyTRIMPCap(
                previousAcuteLoad: provisionalWorkload.acuteLoad,
                previousChronicLoad: provisionalWorkload.chronicLoad,
                targetACWR: 1.00
            )
        )
        XCTAssertEqual(provisionalPlan.today.targetTrimp, expectedCappedTrimp, accuracy: 0.01)
        XCTAssertLessThan(
            provisionalPlan.today.targetTrimp,
            fullPlan.today.targetTrimp,
            "Provisional workload must cap targetACWRRatio to <= 1.00 instead of allowing 1.20"
        )

        // Verify propagation through DailySnapshotCoordinator as well
        let coordinator = DailySnapshotCoordinator(
            dataSource: StaticSnapshotDataSource(
                inputs: DailySnapshotRawInputs(
                    day: day,
                    goalConfig: aggressiveConfig,
                    vitalsEvaluation: vitals,
                    readinessScore: 88,
                    morningBodyBattery: 90,
                    currentBodyBattery: 88,
                    workloadEvaluation: provisionalWorkload,
                    efSamples: [1.15, 1.18, 1.21, 1.24],
                    recentLongRunDriftsPct: [2.0, 2.5, 2.2],
                    efDelta30dPct: 4.5,
                    restingHr: 49.0,
                    maxHr: 192.0
                )
            ),
            calendar: cal,
            now: { nowDate }
        )

        await coordinator.refresh()
        let snapshot = try! XCTUnwrap(coordinator.state.value)
        XCTAssertTrue(snapshot.isProvisionalWorkload)
        XCTAssertNotEqual(snapshot.prescriptionPlan?.today.adaptationReason, .efficiencyUnlocked)
    }

    // MARK: - 6. Refresh Coalescing, Cancellation Reset, and Notification Invalidation

    func testRefreshCoalescingCancellationAndMutationInvalidation() async {
        let cal = utcCalendar
        let nowDate = makeDate(year: 2026, month: 11, day: 13, hour: 11, minute: 0, second: 0, in: cal)
        let day = DietaryDay.containing(nowDate, calendar: cal)
        let vitals = makeOptimalVitals()
        let workload = makeWorkloadEvaluation(daysCount: 28, anchorDate: nowDate)

        let baseInputs = DailySnapshotRawInputs(
            day: day,
            vitalsEvaluation: vitals,
            readinessScore: 86,
            morningBodyBattery: 84,
            currentBodyBattery: 82,
            workloadEvaluation: workload,
            restingHr: 49.0,
            maxHr: 192.0
        )

        // Repeated non-forced refresh within freshness window coalesces to a single query
        let countingSource = ControllableSnapshotDataSource(plans: [
            1: .immediate(baseInputs),
            2: .immediate(baseInputs)
        ])
        let coordinator = DailySnapshotCoordinator(
            dataSource: countingSource,
            calendar: cal,
            now: { nowDate },
            freshnessWindowSeconds: 60.0,
            observeStoreMutations: true
        )

        await coordinator.refresh()
        await coordinator.refresh()
        await coordinator.refresh()
        XCTAssertEqual(countingSource.totalCalls, 1, "Repeated view redraw refreshes must coalesce within freshness window")

        // Posting store mutation notification automatically invalidates & bumps generation
        NotificationCenter.default.post(name: .lifecoreMealDidMutate, object: nil)
        for _ in 0..<20 where coordinator.lastInvalidationReason != .mealMutated || coordinator.requestGeneration < 2 {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(coordinator.lastInvalidationReason, .mealMutated)
        XCTAssertGreaterThanOrEqual(coordinator.requestGeneration, 2)
    }
}

// MARK: - Test Doubles

private struct StaticSnapshotDataSource: DailySnapshotDataSource {
    let inputs: DailySnapshotRawInputs

    func fetchSnapshotInputs(for day: DietaryDay) async throws -> DailySnapshotRawInputs {
        inputs
    }
}

private struct DynamicSnapshotDataSource: DailySnapshotDataSource {
    let builder: @Sendable (DietaryDay) -> DailySnapshotRawInputs

    func fetchSnapshotInputs(for day: DietaryDay) async throws -> DailySnapshotRawInputs {
        builder(day)
    }
}

private final class MutableClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(now: Date) {
        self.current = now
    }

    var now: Date {
        get {
            lock.lock()
            defer { lock.unlock() }
            return current
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            current = newValue
        }
    }
}

@MainActor
private final class ControllableSnapshotDataSource: DailySnapshotDataSource {
    enum Behavior: Sendable {
        case immediate(DailySnapshotRawInputs)
        case suspended(DailySnapshotRawInputs)
    }

    private let plans: [Int: Behavior]
    private(set) var totalCalls = 0
    private var callCount = 0
    private var enteredCalls = Set<Int>()
    private var enteredWaiters: [Int: CheckedContinuation<Void, Never>] = [:]
    private var resumeContinuations: [Int: CheckedContinuation<Void, Never>] = [:]

    init(plans: [Int: Behavior]) {
        self.plans = plans
    }

    func fetchSnapshotInputs(for day: DietaryDay) async throws -> DailySnapshotRawInputs {
        totalCalls += 1
        callCount += 1
        let currentCall = callCount
        enteredCalls.insert(currentCall)
        if let waiter = enteredWaiters.removeValue(forKey: currentCall) {
            waiter.resume()
        }

        switch plans[currentCall] {
        case .immediate(let inputs):
            return inputs
        case .suspended(let inputs):
            await withCheckedContinuation { continuation in
                resumeContinuations[currentCall] = continuation
            }
            return inputs
        case .none:
            return DailySnapshotRawInputs(day: day)
        }
    }

    func waitUntilEntered(call: Int) async {
        if enteredCalls.contains(call) { return }
        await withCheckedContinuation { continuation in
            enteredWaiters[call] = continuation
        }
    }

    func resume(call: Int) {
        resumeContinuations.removeValue(forKey: call)?.resume()
    }
}
