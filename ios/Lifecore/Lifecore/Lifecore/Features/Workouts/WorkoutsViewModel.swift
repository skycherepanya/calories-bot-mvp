import Foundation
import Combine
import HealthKit

// MARK: - Filter Category

public enum WorkoutFilterCategory: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case running = "Running"
    case strength = "Strength"
    case cycling = "Cycling"
    case hiit = "HIIT"
    case walks = "Walks"

    public static let walking: WorkoutFilterCategory = .walks

    public var id: String { rawValue }

    public var titleUk: String {
        switch self {
        case .all: return "Всі"
        case .running: return "Біг"
        case .strength: return "Силові"
        case .cycling: return "Вело"
        case .hiit: return "HIIT"
        case .walks: return "Ходьба"
        }
    }

    public var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .running: return "figure.run"
        case .strength: return "figure.strengthtraining.traditional"
        case .cycling: return "figure.outdoor.cycle"
        case .hiit: return "figure.hiit"
        case .walks: return "figure.walk"
        }
    }

    public func matches(_ workout: HKWorkout) -> Bool {
        switch self {
        case .all:
            return true
        case .running:
            return workout.workoutActivityType == .running
        case .strength:
            return workout.workoutActivityType == .traditionalStrengthTraining ||
                   workout.workoutActivityType == .functionalStrengthTraining
        case .cycling:
            return workout.workoutActivityType == .cycling
        case .hiit:
            return workout.workoutActivityType == .highIntensityIntervalTraining
        case .walks:
            return workout.workoutActivityType == .walking
        }
    }
}

// MARK: - Dietary Day Workout Group

public struct DietaryDayWorkoutGroup: Identifiable, Sendable {
    public var id: String { day.key }
    public let day: DietaryDay
    public let workouts: [HKWorkout]

    public init(day: DietaryDay, workouts: [HKWorkout]) {
        self.day = day
        self.workouts = workouts
    }
}

// MARK: - Workouts View Model

@MainActor
public final class WorkoutsViewModel: ObservableObject {

    @Published public private(set) var snapshotState: ScreenState<DailyDashboardSnapshot> = .loading
    @Published public private(set) var workoutsState: ScreenState<[HKWorkout]> = .loading
    @Published public var selectedCategory: WorkoutFilterCategory = .all
    @Published public var hideCasualWalks: Bool = false
    @Published public private(set) var rawWorkouts: [HKWorkout] = []

    public let coordinator: DailySnapshotCoordinator
    public let calendar: Calendar
    private let workoutLoader: (@Sendable () async throws -> [HKWorkout])?
    private var cancellables = Set<AnyCancellable>()

    public init(
        coordinator: DailySnapshotCoordinator? = nil,
        calendar: Calendar = .current,
        workoutLoader: (@Sendable () async throws -> [HKWorkout])? = nil
    ) {
        self.calendar = calendar
        self.workoutLoader = workoutLoader
        let activeCoordinator = coordinator ?? AppEnvironment.current.snapshotCoordinator
        self.coordinator = activeCoordinator
        self.snapshotState = activeCoordinator.state

        activeCoordinator.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.snapshotState = newState
            }
            .store(in: &cancellables)
    }

    // MARK: - Snapshot Properties Parity

    public var currentSnapshot: DailyDashboardSnapshot? {
        snapshotState.value
    }

    public var currentPlanRevision: UUID? {
        currentSnapshot?.revision
    }

    public var prescriptionPlan: TrainingPrescriptionPlan? {
        currentSnapshot?.prescriptionPlan
    }

    public var unavailabilityReasons: [PrescriptionUnavailabilityReason] {
        currentSnapshot?.unavailabilityReasons ?? []
    }

    // MARK: - Filtering & Grouping

    public var filteredWorkouts: [HKWorkout] {
        rawWorkouts.filter { workout in
            // Casual walks are hidden strictly when "All" is active and hideCasualWalks is true.
            // When specific category (.walks / .walking) is selected, walks MUST remain visible.
            if selectedCategory == .all && hideCasualWalks && workout.workoutActivityType == .walking {
                return false
            }
            return selectedCategory.matches(workout)
        }
    }

    public var isFilterEmptyingList: Bool {
        !rawWorkouts.isEmpty && filteredWorkouts.isEmpty
    }

    public var groupedWorkouts: [DietaryDayWorkoutGroup] {
        groupWorkoutsByDietaryDay(rawWorkouts)
    }

    public var groupedFilteredWorkouts: [DietaryDayWorkoutGroup] {
        groupWorkoutsByDietaryDay(filteredWorkouts)
    }

    public func resetFilters() {
        selectedCategory = .all
        hideCasualWalks = false
    }

    private func groupWorkoutsByDietaryDay(_ list: [HKWorkout]) -> [DietaryDayWorkoutGroup] {
        guard !list.isEmpty else { return [] }

        var dict: [DietaryDay: [HKWorkout]] = [:]
        for workout in list {
            let day = DietaryDay.containing(workout.startDate, calendar: calendar)
            dict[day, default: []].append(workout)
        }

        return dict.map { day, sessions in
            DietaryDayWorkoutGroup(
                day: day,
                workouts: sessions.sorted { $0.startDate > $1.startDate }
            )
        }
        .sorted { $0.day.interval.start > $1.day.interval.start }
    }

    // MARK: - Loading & Refreshing

    public func loadWorkouts(force: Bool = false) async {
        let retained = workoutsState.value
        if let existing = retained {
            workoutsState = .content(existing, isRefreshing: true, isStale: workoutsState.isStale)
        } else {
            workoutsState = .loading
        }

        do {
            let loaded: [HKWorkout]
            if let customLoader = workoutLoader {
                loaded = try await customLoader()
            } else if AppEnvironment.current.isFixtureMode {
                loaded = []
            } else {
                try await HealthKitManager.shared.requestAuthorization()
                loaded = try await HealthKitManager.shared.fetchRecentWorkouts(days: 30, limit: 60)
            }

            self.rawWorkouts = loaded
            if loaded.isEmpty {
                self.workoutsState = .empty
            } else {
                self.workoutsState = .content(loaded, isRefreshing: false, isStale: false)
            }
        } catch {
            self.workoutsState = .failed(message: error.localizedDescription, retained: retained)
        }
    }

    public func refresh() async {
        async let refreshSnapshot: Void = coordinator.refresh(force: true)
        async let refreshWorkouts: Void = loadWorkouts(force: true)
        _ = await (refreshSnapshot, refreshWorkouts)
    }

    // MARK: - UI Formatting

    public func formattedDayHeader(for day: DietaryDay) -> String {
        let todayDay = DietaryDay.containing(Date(), calendar: calendar)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk_UA")

        if day.key == todayDay.key {
            formatter.dateFormat = "d MMMM"
            return "Сьогодні · \(formatter.string(from: day.interval.start))"
        }

        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let yesterdayDay = DietaryDay.containing(yesterday, calendar: calendar)
        if day.key == yesterdayDay.key {
            formatter.dateFormat = "d MMMM"
            return "Вчора · \(formatter.string(from: day.interval.start))"
        }

        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: day.interval.start).capitalized
    }
}
