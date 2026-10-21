import SwiftUI
import HealthKit

public enum WorkoutFilterCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case running = "Running"
    case strength = "Strength"
    case cycling = "Cycling"
    case hiit = "HIIT"
    case walks = "Walks"

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

public struct WorkoutsView: View {
    @State private var workouts: [HKWorkout] = []
    @State private var selectedCategory: WorkoutFilterCategory = .all
    @State private var hideCasualWalks = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    public init() {}

    private var filteredWorkouts: [HKWorkout] {
        workouts.filter { workout in
            if hideCasualWalks && workout.workoutActivityType == .walking {
                return false
            }
            return selectedCategory.matches(workout)
        }
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Category Filter Scroll
                    filterScrollView

                    // Casual walks toggle if "All" is active
                    if selectedCategory == .all {
                        casualWalksToggle
                    }

                    // Workout Cards List
                    if isLoading && workouts.isEmpty {
                        loadingView
                    } else if filteredWorkouts.isEmpty {
                        emptyStateView
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredWorkouts, id: \.uuid) { workout in
                                NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                                    workoutRowCard(for: workout)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(LifecoreTheme.deepVoidBackground.ignoresSafeArea())
            .navigationTitle("Тренування")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        Task { await loadWorkouts() }
                    }) {
                        if isLoading {
                            ProgressView().tint(.cyan)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(.cyan)
                        }
                    }
                    .accessibilityIdentifier("btn_refresh_workouts")
                }
            }
            .refreshable {
                await loadWorkouts()
            }
            .task {
                await loadWorkouts()
            }
        }
    }

    // MARK: - Filters

    private var filterScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(WorkoutFilterCategory.allCases) { cat in
                    Button(action: {
                        selectedCategory = cat
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: cat.icon)
                                .font(.caption)
                            Text(cat.titleUk)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            selectedCategory == cat ? Color.cyan : Color.white.opacity(0.08)
                        )
                        .foregroundStyle(selectedCategory == cat ? Color.black : Color.white)
                        .clipShape(Capsule())
                    }
                    .accessibilityIdentifier("filter_workout_\(cat.rawValue.lowercased())")
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var casualWalksToggle: some View {
        Toggle(isOn: $hideCasualWalks) {
            HStack(spacing: 6) {
                Image(systemName: "figure.walk.motion")
                    .foregroundStyle(.secondary)
                Text("Приховати побутові прогулянки")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(.cyan)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(red: 0.1, green: 0.11, blue: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Workout Card

    private func workoutRowCard(for workout: HKWorkout) -> some View {
        let typeColor = workoutColor(for: workout.workoutActivityType)
        let distanceKm: Double? = workout.totalDistance.map { $0.doubleValue(for: .meter()) / 1000.0 }
        let durationMin = workout.duration / 60.0
        let calories = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
        let avgHr = workout.statistics(for: HKQuantityType(.heartRate))?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))

        let profile = AthleteProfileStore.shared.profile
        let trimp = TrainingLoadAndBatteryEngine.computeBanisterTRIMP(
            durationMin: durationMin,
            avgHr: avgHr ?? 130.0,
            restingHr: profile.restingHeartRateBaselineBpm,
            maxHr: profile.maxHeartRateBpm
        )

        return VStack(alignment: .leading, spacing: 12) {
            // Header: Type + TRIMP badge + Date + Arrow
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: iconName(for: workout.workoutActivityType))
                        .font(.headline)
                        .foregroundStyle(typeColor)
                    Text(title(for: workout.workoutActivityType))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }

                Spacer()

                LifecoreGlowPill(text: "TRIMP \(Int(trimp))", systemIcon: "flame.fill", color: typeColor)

                Text(formattedDate(workout.startDate))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider().background(Color.white.opacity(0.08))

            // Metrics Grid
            HStack(spacing: 16) {
                metricColumn(
                    title: "Час",
                    value: String(format: "%.0f хв", durationMin)
                )

                if let dist = distanceKm, dist > 0.01 {
                    metricColumn(
                        title: "Дистанція",
                        value: String(format: "%.2f км", dist),
                        color: .cyan
                    )

                    let pace = durationMin / dist
                    if pace.isFinite && pace > 0 {
                        let totalSecs = max(0, Int(round(pace * 60.0)))
                        let mins = totalSecs / 60
                        let secs = totalSecs % 60
                        metricColumn(
                            title: "Темп",
                            value: String(format: "%d:%02d", mins, secs),
                            color: .green
                        )
                    }
                }

                if let kcal = calories {
                    metricColumn(
                        title: "Спалено",
                        value: "\(Int(kcal)) ккал",
                        color: .orange
                    )
                }

                if let hr = avgHr {
                    metricColumn(
                        title: "Сер. ЧСС",
                        value: "\(Int(hr)) bpm",
                        color: .red
                    )
                }
            }
        }
        .lifecoreGlassCard(cornerRadius: 18, borderColor: typeColor.opacity(0.25))
    }

    private func metricColumn(title: String, value: String, color: Color = .white) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Loading & Empty States

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView().tint(.cyan)
            Text("Завантажую сесії з Apple Watch...")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Тренувань не знайдено")
                .font(.headline)
                .foregroundStyle(.white)
            Text("У цій категорії за останні 30 днів немає записаних сесій в Apple Health.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
        .background(Color(red: 0.1, green: 0.11, blue: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Helpers

    private func loadWorkouts() async {
        isLoading = true
        errorMessage = nil

        do {
            try await HealthKitManager.shared.requestAuthorization()
            let list = try await HealthKitManager.shared.fetchRecentWorkouts(days: 30, limit: 60)
            self.workouts = list
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func iconName(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "figure.run"
        case .cycling: return "figure.outdoor.cycle"
        case .walking: return "figure.walk"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "figure.strengthtraining.traditional"
        case .highIntensityIntervalTraining: return "figure.hiit"
        case .swimming: return "figure.pool.swim"
        default: return "figure.mixed.cardio"
        }
    }

    private func title(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Біг"
        case .cycling: return "Велосипед"
        case .walking: return "Прогулянка"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "Силове тренування"
        case .highIntensityIntervalTraining: return "HIIT"
        case .swimming: return "Плавання"
        default: return "Тренування"
        }
    }

    private func workoutColor(for type: HKWorkoutActivityType) -> Color {
        switch type {
        case .running: return Color.green
        case .cycling: return Color.cyan
        case .walking: return Color.blue
        case .traditionalStrengthTraining, .functionalStrengthTraining: return Color.purple
        case .highIntensityIntervalTraining: return Color.orange
        case .swimming: return Color.teal
        default: return Color.secondary
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM, HH:mm"
        formatter.locale = Locale(identifier: "uk_UA")
        return formatter.string(from: date)
    }
}

#Preview {
    WorkoutsView()
        .preferredColorScheme(.dark)
}
