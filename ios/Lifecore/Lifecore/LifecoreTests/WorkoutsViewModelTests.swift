import XCTest
import Combine
import Foundation
import HealthKit
@testable import Lifecore

@MainActor
final class WorkoutsViewModelTests: XCTestCase {

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

    private func makeWorkout(
        activityType: HKWorkoutActivityType,
        startDate: Date,
        durationSeconds: Double = 1800,
        distanceMeters: Double? = nil,
        caloriesKcal: Double? = nil
    ) -> HKWorkout {
        let endDate = startDate.addingTimeInterval(durationSeconds)
        let distanceQuantity = distanceMeters.map { HKQuantity(unit: .meter(), doubleValue: $0) }
        let calsQuantity = caloriesKcal.map { HKQuantity(unit: .kilocalorie(), doubleValue: $0) }
        return HKWorkout(
            activityType: activityType,
            start: startDate,
            end: endDate,
            duration: durationSeconds,
            totalEnergyBurned: calsQuantity,
            totalDistance: distanceQuantity,
            metadata: nil
        )
    }

    // MARK: - Test Doubles (MainActor final class per Rule 3)

    @MainActor
    private final class MockSnapshotDataSource: DailySnapshotDataSource {
        var inputsProvider: (@Sendable (DietaryDay) throws -> DailySnapshotRawInputs)?

        init(inputsProvider: (@Sendable (DietaryDay) throws -> DailySnapshotRawInputs)? = nil) {
            self.inputsProvider = inputsProvider
        }

        func fetchSnapshotInputs(for day: DietaryDay) async throws -> DailySnapshotRawInputs {
            if let provider = inputsProvider {
                return try provider(day)
            }
            return DailySnapshotRawInputs(day: day, hasAnyObservation: false)
        }
    }

    // MARK: - 1. Shared Plan Revision Parity with TodayViewModel

    func testSharedPlanRevisionParityWithTodayViewModel() async {
        let cal = utcCalendar
        let anchorDate = makeDate(year: 2026, month: 11, day: 13, hour: 10, minute: 0, in: cal)
        let day = DietaryDay.containing(anchorDate, calendar: cal)

        let dataSource = MockSnapshotDataSource { targetDay in
            DailySnapshotRawInputs(
                day: targetDay,
                hasAnyObservation: false
            )
        }

        let coordinator = DailySnapshotCoordinator(
            dataSource: dataSource,
            calendar: cal,
            now: { anchorDate },
            freshnessWindowSeconds: 0,
            observeStoreMutations: false
        )

        // Inject coordinator into both ViewModels
        let todayVM = TodayViewModel(coordinator: coordinator)
        let workoutsVM = WorkoutsViewModel(
            coordinator: coordinator,
            calendar: cal,
            workoutLoader: { [] }
        )

        // Initial state before refresh
        XCTAssertEqual(todayVM.state.isLoading, true)
        XCTAssertEqual(workoutsVM.snapshotState.isLoading, true)

        await coordinator.refresh(day: day, force: true)

        // Verify revision parity between TodayViewModel and WorkoutsViewModel
        guard let todaySnapshot = todayVM.snapshot else {
            XCTFail("TodayViewModel must have a valid snapshot")
            return
        }
        guard let workoutsSnapshot = workoutsVM.currentSnapshot else {
            XCTFail("WorkoutsViewModel must have a valid snapshot")
            return
        }

        XCTAssertEqual(
            todaySnapshot.revision,
            workoutsSnapshot.revision,
            "RollingHorizonDeckView in WorkoutsViewModel must share the EXACT SAME DailyDashboardSnapshot.revision as TodayViewModel"
        )
        XCTAssertEqual(
            workoutsVM.currentPlanRevision,
            todaySnapshot.revision,
            "WorkoutsViewModel.currentPlanRevision must match TodayViewModel.snapshot.revision"
        )
        XCTAssertEqual(
            todaySnapshot.prescriptionPlan,
            workoutsSnapshot.prescriptionPlan,
            "TrainingPrescriptionPlan must be identical across TodayViewModel and WorkoutsViewModel"
        )
        XCTAssertEqual(
            todaySnapshot.unavailabilityReasons,
            workoutsSnapshot.unavailabilityReasons,
            "Unavailability reasons must match when prescription plan is unavailable"
        )
    }

    // MARK: - 2. 01:00 AM Workout Dietary-Day Assignment (04:00 AM Rollover)

    func testWorkoutAt0100AMAssignedToPriorDietaryDay() async {
        let cal = utcCalendar
        // 01:00 AM on November 13, 2026
        let earlyMorningDate = makeDate(year: 2026, month: 11, day: 13, hour: 1, minute: 0, in: cal)
        let workout0100 = makeWorkout(
            activityType: .running,
            startDate: earlyMorningDate,
            durationSeconds: 2400,
            distanceMeters: 6000
        )

        let vm = WorkoutsViewModel(
            calendar: cal,
            workoutLoader: { [workout0100] }
        )
        await vm.loadWorkouts()

        XCTAssertEqual(vm.rawWorkouts.count, 1)

        let grouped = vm.groupedWorkouts
        XCTAssertEqual(grouped.count, 1, "There must be exactly 1 dietary day group")

        let group = grouped[0]
        XCTAssertEqual(
            group.day.key,
            "2026-11-12",
            "A workout at 01:00 AM on Nov 13 must belong to prior dietary day 2026-11-12 due to 04:00 AM cutoff"
        )
        XCTAssertTrue(
            group.day.contains(earlyMorningDate),
            "Dietary day interval [04:00 Nov 12, 04:00 Nov 13) must contain 01:00 AM Nov 13"
        )
        XCTAssertEqual(group.workouts.count, 1)
        XCTAssertEqual(group.workouts.first?.uuid, workout0100.uuid)
    }

    // MARK: - 3. Multi-Session Day Grouping

    func testMultiSessionDayGrouping() async {
        let cal = utcCalendar
        // Session 1: Nov 12, 08:30 AM (morning run)
        let date1 = makeDate(year: 2026, month: 11, day: 12, hour: 8, minute: 30, in: cal)
        let w1 = makeWorkout(activityType: .running, startDate: date1, durationSeconds: 2700, distanceMeters: 7000)

        // Session 2: Nov 12, 18:00 PM (evening strength)
        let date2 = makeDate(year: 2026, month: 11, day: 12, hour: 18, minute: 0, in: cal)
        let w2 = makeWorkout(activityType: .traditionalStrengthTraining, startDate: date2, durationSeconds: 3000)

        // Session 3: Nov 13, 01:15 AM (late night walk - belongs to Nov 12 dietary day!)
        let date3 = makeDate(year: 2026, month: 11, day: 13, hour: 1, minute: 15, in: cal)
        let w3 = makeWorkout(activityType: .walking, startDate: date3, durationSeconds: 1200, distanceMeters: 1500)

        let vm = WorkoutsViewModel(
            calendar: cal,
            workoutLoader: { [w1, w2, w3] }
        )
        await vm.loadWorkouts()

        let grouped = vm.groupedWorkouts
        XCTAssertEqual(
            grouped.count,
            1,
            "All three sessions must group into the exact same dietary day 2026-11-12"
        )

        let group = grouped[0]
        XCTAssertEqual(group.day.key, "2026-11-12")
        XCTAssertEqual(group.workouts.count, 3, "All 3 sessions must be present in the day group")

        // Sessions must be sorted descending by start date
        XCTAssertEqual(group.workouts[0].uuid, w3.uuid, "Latest session (01:15 AM) should be first")
        XCTAssertEqual(group.workouts[1].uuid, w2.uuid, "Middle session (18:00 PM) should be second")
        XCTAssertEqual(group.workouts[2].uuid, w1.uuid, "Earliest session (08:30 AM) should be third")
    }

    // MARK: - 4. Filter Transitions All -> hideWalks -> Walks -> All

    func testFilterTransitionsAllHideWalksWalksAll() async {
        let cal = utcCalendar
        let now = makeDate(year: 2026, month: 11, day: 13, hour: 12, minute: 0, in: cal)

        let runningW = makeWorkout(activityType: .running, startDate: now.addingTimeInterval(-3600), durationSeconds: 1800, distanceMeters: 5000)
        let walkingW = makeWorkout(activityType: .walking, startDate: now.addingTimeInterval(-7200), durationSeconds: 1500, distanceMeters: 2000)
        let strengthW = makeWorkout(activityType: .traditionalStrengthTraining, startDate: now.addingTimeInterval(-10800), durationSeconds: 2400)

        let vm = WorkoutsViewModel(
            calendar: cal,
            workoutLoader: { [runningW, walkingW, strengthW] }
        )
        await vm.loadWorkouts()

        // 1. Initial State: Category = .all, hideCasualWalks = false
        XCTAssertEqual(vm.selectedCategory, .all)
        XCTAssertFalse(vm.hideCasualWalks)
        XCTAssertEqual(vm.filteredWorkouts.count, 3, "All 3 workouts should be visible")
        XCTAssertFalse(vm.isFilterEmptyingList)

        // 2. Hide Casual Walks under .all
        vm.hideCasualWalks = true
        XCTAssertEqual(vm.filteredWorkouts.count, 2, "Walking workout must be hidden when hideCasualWalks is true under .all")
        XCTAssertFalse(vm.filteredWorkouts.contains(where: { $0.workoutActivityType == .walking }))

        // 3. Switch to .walks while hideCasualWalks is STILL TRUE
        // CRITICAL BUG FIX TEST: Walking sessions MUST remain visible when category is .walks!
        vm.selectedCategory = .walks
        XCTAssertEqual(vm.filteredWorkouts.count, 1, "Walking workout MUST be visible when .walks is selected even with hideCasualWalks == true")
        XCTAssertEqual(vm.filteredWorkouts.first?.workoutActivityType, .walking)

        // Also test .walking alias
        vm.selectedCategory = .walking
        XCTAssertEqual(vm.filteredWorkouts.count, 1, ".walking alias must behave identically to .walks")

        // 4. Switch back to .all with hideCasualWalks still true
        vm.selectedCategory = .all
        XCTAssertEqual(vm.filteredWorkouts.count, 2, "Walks should be hidden again when switching back to .all")

        // 5. Reset Filters
        vm.resetFilters()
        XCTAssertEqual(vm.selectedCategory, .all)
        XCTAssertFalse(vm.hideCasualWalks)
        XCTAssertEqual(vm.filteredWorkouts.count, 3, "All workouts must be visible after resetFilters()")

        // 6. Test isFilterEmptyingList
        let walksOnlyVM = WorkoutsViewModel(
            calendar: cal,
            workoutLoader: { [walkingW] }
        )
        await walksOnlyVM.loadWorkouts()
        walksOnlyVM.hideCasualWalks = true
        XCTAssertTrue(walksOnlyVM.isFilterEmptyingList, "isFilterEmptyingList must be true when filters empty out a non-empty list")
    }

    // MARK: - 5. Sport-Aware Detail Formatting (Running vs Cycling vs Strength)

    func testSportAwareDetailFormattingRunningVsCyclingVsStrength() {
        let cal = utcCalendar
        let anchor = makeDate(year: 2026, month: 11, day: 13, hour: 10, minute: 0, in: cal)

        // 1. Running Workout
        let runWorkout = makeWorkout(
            activityType: .running,
            startDate: anchor,
            durationSeconds: 3000,
            distanceMeters: 10000,
            caloriesKcal: 650
        )
        let runAnalysis = WorkoutAnalysisResult(
            workoutUUID: runWorkout.uuid,
            workoutType: "Біг",
            distanceKm: 10.0,
            durationMin: 50.0,
            avgPaceMinKm: 5.0,
            avgHeartRate: 152.0,
            maxHeartRate: 172.0,
            elevationGainMeters: 45.0,
            efficiencyFactor: 1.315,
            aerobicDecouplingPct: 3.8,
            isIndoorTreadmill: false,
            splits: [
                SplitMetric(km: 1, durationSeconds: 300, paceMinPerKm: 5.0, avgHeartRate: 145, maxHeartRate: 155, elevationDiffMeters: 5)
            ],
            laps: [],
            benchmarkDelta: nil
        )

        let runVM = WorkoutDetailViewModel(
            workout: runWorkout,
            analysis: runAnalysis
        )

        XCTAssertTrue(runVM.isRunning)
        XCTAssertFalse(runVM.isCycling)
        XCTAssertFalse(runVM.isStrengthOrOther)
        XCTAssertEqual(runVM.sportKind, .running)

        guard let runningPres = runVM.runningPresentation else {
            XCTFail("runningPresentation must not be nil for running")
            return
        }
        XCTAssertEqual(runningPres.efficiencyFactor, 1.315)
        XCTAssertEqual(runningPres.aerobicDecouplingPct, 3.8)
        XCTAssertEqual(runningPres.elevationGainMeters, 45.0)
        XCTAssertEqual(runningPres.splits.count, 1)
        XCTAssertNil(runVM.cyclingPresentation, "cyclingPresentation must be nil for running")
        XCTAssertNil(runVM.strengthPresentation, "strengthPresentation must be nil for running")

        // 2. Cycling Workout
        let cyclingWorkout = makeWorkout(
            activityType: .cycling,
            startDate: anchor,
            durationSeconds: 3600, // 1 hour
            distanceMeters: 28000, // 28 km
            caloriesKcal: 720
        )
        let cyclingVM = WorkoutDetailViewModel(workout: cyclingWorkout)

        XCTAssertFalse(cyclingVM.isRunning)
        XCTAssertTrue(cyclingVM.isCycling)
        XCTAssertFalse(cyclingVM.isStrengthOrOther)
        XCTAssertEqual(cyclingVM.sportKind, .cycling)

        guard let cyclingPres = cyclingVM.cyclingPresentation else {
            XCTFail("cyclingPresentation must not be nil for cycling")
            return
        }
        XCTAssertEqual(cyclingPres.speedKmH, 28.0, accuracy: 0.01)
        XCTAssertEqual(cyclingPres.distanceKm, 28.0, accuracy: 0.01)
        XCTAssertEqual(cyclingPres.durationMin, 60.0)
        XCTAssertNil(cyclingVM.runningPresentation, "runningPresentation must be nil for cycling")
        XCTAssertNil(cyclingVM.strengthPresentation, "strengthPresentation must be nil for cycling")
        XCTAssertTrue(cyclingVM.streamSignalNoteUk.contains("Бігові спліти не застосовуються"))

        // 3. Strength Workout
        let strengthWorkout = makeWorkout(
            activityType: .traditionalStrengthTraining,
            startDate: anchor,
            durationSeconds: 2700, // 45 min
            caloriesKcal: 380
        )
        let strengthVM = WorkoutDetailViewModel(workout: strengthWorkout)

        XCTAssertFalse(strengthVM.isRunning)
        XCTAssertFalse(strengthVM.isCycling)
        XCTAssertTrue(strengthVM.isStrengthOrOther)
        XCTAssertEqual(strengthVM.sportKind, .strength)

        guard let strengthPres = strengthVM.strengthPresentation else {
            XCTFail("strengthPresentation must not be nil for strength")
            return
        }
        XCTAssertEqual(strengthPres.durationMin, 45.0)
        XCTAssertNil(strengthVM.runningPresentation, "runningPresentation must be nil for strength")
        XCTAssertNil(strengthVM.cyclingPresentation, "cyclingPresentation must be nil for strength")
        XCTAssertTrue(strengthVM.streamSignalNoteUk.contains("силових вправ"))
    }

    // MARK: - 6. Error & Cached/Retained State Handling

    func testErrorAndCachedStateHandling() async {
        let cal = utcCalendar
        let anchor = makeDate(year: 2026, month: 11, day: 13, hour: 10, minute: 0, in: cal)
        let existingWorkout = makeWorkout(activityType: .running, startDate: anchor)

        var shouldThrow = false
        let vm = WorkoutsViewModel(
            calendar: cal,
            workoutLoader: {
                if shouldThrow {
                    throw NSError(domain: "HealthKitError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Apple Watch sync timed out"])
                }
                return [existingWorkout]
            }
        )

        // 1. Initial successful load
        await vm.loadWorkouts()
        XCTAssertEqual(vm.rawWorkouts.count, 1)
        if case .content(let items, _, _) = vm.workoutsState {
            XCTAssertEqual(items.count, 1)
        } else {
            XCTFail("workoutsState must be .content after successful load")
        }

        // 2. Refresh fails: existing workouts must be retained in .failed state!
        shouldThrow = true
        await vm.loadWorkouts(force: true)

        if case .failed(let message, let retained) = vm.workoutsState {
            XCTAssertEqual(message, "Apple Watch sync timed out")
            XCTAssertNotNil(retained, "Previous workouts must be retained on refresh failure")
            XCTAssertEqual(retained?.count, 1)
        } else {
            XCTFail("workoutsState must be .failed on error")
        }

        // 3. True empty history state
        shouldThrow = false
        let emptyVM = WorkoutsViewModel(
            calendar: cal,
            workoutLoader: { [] }
        )
        await emptyVM.loadWorkouts()

        if case .empty = emptyVM.workoutsState {
            XCTAssertTrue(emptyVM.rawWorkouts.isEmpty)
        } else {
            XCTFail("workoutsState must be .empty for empty workout history")
        }
    }
}
