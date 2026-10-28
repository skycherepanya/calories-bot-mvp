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
                    // Rolling Stimulus Horizon Deck (Lifecore v3.2 - Bevel Fitness Cockpit)
                    RollingHorizonDeckView(pastWorkouts: workouts)

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
            .background(LifecoreTheme.paperCanvas.ignoresSafeArea())
            .navigationTitle("Тренування")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        Task { await loadWorkouts() }
                    }) {
                        if isLoading {
                            ProgressView().tint(LifecoreTheme.accentPrimary)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(LifecoreTheme.accentPrimary)
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
                    let isSelected = selectedCategory == cat
                    Button(action: {
                        selectedCategory = cat
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(cat.titleUk)
                                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(isSelected ? LifecoreTheme.inkPrimary : LifecoreTheme.paperCard)
                        )
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? Color.clear : LifecoreTheme.ruleHairline, lineWidth: 1.0)
                        )
                        .foregroundStyle(isSelected ? Color.white : LifecoreTheme.inkSecondary)
                    }
                    .buttonStyle(.plain)
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
                    .foregroundStyle(LifecoreTheme.inkTertiary)
                Text("Приховати побутові прогулянки")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(LifecoreTheme.inkSecondary)
            }
        }
        .tint(LifecoreTheme.accentPrimary)
        .lifecoreGlassCard(cornerRadius: 14, padding: 12)
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
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(typeColor)
                    Text(title(for: workout.workoutActivityType))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(LifecoreTheme.inkPrimary)
                }

                Spacer()

                let loadLabel: String = {
                    if trimp >= 80 { return "Високе" }
                    else if trimp >= 45 { return "Помірне" }
                    else { return "Легке" }
                }()

                LifecoreGlowPill(text: loadLabel, systemIcon: "flame.fill", color: typeColor)

                Text(formattedDate(workout.startDate))
                    .font(.system(size: 11))
                    .foregroundStyle(LifecoreTheme.inkTertiary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LifecoreTheme.inkTertiary)
            }

            LifecoreHairlineDivider()

            // Metrics Grid (4-column layout)
            HStack(spacing: 12) {
                metricColumn(
                    title: "Час",
                    value: String(format: "%.0f хв", durationMin),
                    color: LifecoreTheme.inkPrimary
                )

                if let dist = distanceKm, dist > 0.01 {
                    metricColumn(
                        title: "Дистанція",
                        value: String(format: "%.2f км", dist),
                        color: LifecoreTheme.accentTeal
                    )

                    let pace = durationMin / dist
                    if pace.isFinite && pace > 0 {
                        let totalSecs = max(0, Int(round(pace * 60.0)))
                        let mins = totalSecs / 60
                        let secs = totalSecs % 60
                        metricColumn(
                            title: "Темп",
                            value: String(format: "%d:%02d", mins, secs),
                            color: LifecoreTheme.statusOptimal
                        )
                    }
                }

                if let kcal = calories {
                    metricColumn(
                        title: "Спалено",
                        value: "\(Int(kcal)) ккал",
                        color: LifecoreTheme.statusWarning
                    )
                }

                if let hr = avgHr {
                    metricColumn(
                        title: "Сер. ЧСС",
                        value: "\(Int(hr)) bpm",
                        color: LifecoreTheme.statusDanger
                    )
                }
            }
        }
        .lifecoreGlassCard(cornerRadius: 18)
    }

    private func metricColumn(title: String, value: String, color: Color = LifecoreTheme.inkPrimary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(LifecoreTheme.inkTertiary)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Loading & Empty States

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView().tint(LifecoreTheme.accentPrimary)
            Text("Завантажую сесії з Apple Watch...")
                .font(.system(size: 12))
                .foregroundStyle(LifecoreTheme.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 44))
                .foregroundStyle(LifecoreTheme.inkTertiary)
            Text("Тренувань не знайдено")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(LifecoreTheme.inkPrimary)
            Text("У цій категорії за останні 30 днів немає записаних сесій в Apple Health.")
                .font(.system(size: 12))
                .foregroundStyle(LifecoreTheme.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .lifecoreGlassCard(cornerRadius: 18, padding: 32)
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
        case .running: return LifecoreTheme.statusOptimal
        case .cycling: return LifecoreTheme.accentTeal
        case .walking: return LifecoreTheme.accentIndigo
        case .traditionalStrengthTraining, .functionalStrengthTraining: return LifecoreTheme.statusWarning
        case .highIntensityIntervalTraining: return LifecoreTheme.statusDanger
        case .swimming: return LifecoreTheme.accentTeal
        default: return LifecoreTheme.inkSecondary
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
        .preferredColorScheme(.light)
}
