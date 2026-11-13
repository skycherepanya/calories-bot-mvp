import SwiftUI
import HealthKit

public struct WorkoutsView: View {
    @StateObject private var viewModel: WorkoutsViewModel

    public init(viewModel: WorkoutsViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? WorkoutsViewModel())
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 1. Rolling Stimulus Horizon Deck (Lifecore v3.2 - Bevel Fitness Cockpit)
                    RollingHorizonDeckView(
                        snapshotState: viewModel.snapshotState,
                        pastWorkouts: viewModel.rawWorkouts
                    )

                    // 2. Category Filter Scroll
                    filterScrollView

                    // 3. Casual walks toggle if "All" is active
                    if viewModel.selectedCategory == .all {
                        casualWalksToggle
                    }

                    // 4. Workout Cards List or States
                    contentList
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(LifecoreTheme.paperCanvas.ignoresSafeArea())
            .navigationTitle("Тренування")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        Task { await viewModel.refresh() }
                    }) {
                        if viewModel.workoutsState.isRefreshing || viewModel.snapshotState.isRefreshing {
                            ProgressView().tint(LifecoreTheme.accentPrimary)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(LifecoreTheme.accentPrimary)
                        }
                    }
                    .accessibilityIdentifier("btn_refresh_workouts")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    SettingsToolbarButton()
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                if viewModel.rawWorkouts.isEmpty {
                    await viewModel.loadWorkouts()
                }
            }
        }
    }

    // MARK: - Content List Routing

    @ViewBuilder
    private var contentList: some View {
        if viewModel.workoutsState.isLoading && viewModel.rawWorkouts.isEmpty {
            loadingView
        } else if case .failed(let message, _) = viewModel.workoutsState, viewModel.rawWorkouts.isEmpty {
            errorView(message)
        } else if case .empty = viewModel.workoutsState {
            emptyHistoryView
        } else if viewModel.isFilterEmptyingList {
            filterEmptyStateView
        } else {
            workoutGroupedList
        }
    }

    // MARK: - Filters

    private var filterScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(WorkoutFilterCategory.allCases) { cat in
                    let isSelected = viewModel.selectedCategory == cat
                    Button(action: {
                        viewModel.selectedCategory = cat
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
        Toggle(isOn: $viewModel.hideCasualWalks) {
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

    // MARK: - Workout List Grouped by Dietary Day

    private var workoutGroupedList: some View {
        LazyVStack(spacing: 16) {
            ForEach(viewModel.groupedFilteredWorkouts) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.formattedDayHeader(for: group.day))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LifecoreTheme.inkSecondary)
                        .padding(.horizontal, 4)

                    ForEach(group.workouts, id: \.uuid) { workout in
                        NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                            workoutRowCard(for: workout)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Workout Card

    private func workoutRowCard(for workout: HKWorkout) -> some View {
        let typeColor = workoutColor(for: workout.workoutActivityType)
        let distanceKm: Double? = workout.totalDistance.map { $0.doubleValue(for: .meter()) / 1000.0 }
        let durationMin = workout.duration / 60.0
        let calories = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
        let avgHr = workout.statistics(for: HKQuantityType(.heartRate))?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))

        let profile = AthleteProfileStore.shared.profile
        let trimp: Double?
        if let hr = avgHr, hr > 0 {
            trimp = TrainingLoadAndBatteryEngine.computeBanisterTRIMP(
                durationMin: durationMin,
                avgHr: hr,
                restingHr: profile.restingHeartRateBaselineBpm,
                maxHr: profile.maxHeartRateBpm
            )
        } else {
            trimp = nil
        }

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

                if let load = trimp {
                    let loadLabel: String = {
                        if load >= 80 { return "Високе" }
                        else if load >= 45 { return "Помірне" }
                        else { return "Легке" }
                    }()
                    LifecoreGlowPill(text: loadLabel, systemIcon: "flame.fill", color: typeColor)
                }

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

                    if workout.workoutActivityType == .cycling {
                        let speed = dist / (workout.duration / 3600.0)
                        metricColumn(
                            title: "Швидкість",
                            value: String(format: "%.1f км/г", speed),
                            color: LifecoreTheme.statusOptimal
                        )
                    } else {
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

    private var emptyHistoryView: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 44))
                .foregroundStyle(LifecoreTheme.inkTertiary)
            Text("Тренувань не знайдено")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(LifecoreTheme.inkPrimary)
            Text("За останні 30 днів немає зафіксованих сесій в Apple Health.")
                .font(.system(size: 12))
                .foregroundStyle(LifecoreTheme.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .lifecoreGlassCard(cornerRadius: 18, padding: 32)
    }

    private var filterEmptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 40))
                .foregroundStyle(LifecoreTheme.inkTertiary)
            Text("Немає відповідних тренувань")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(LifecoreTheme.inkPrimary)
            Text("За обраними фільтрами не знайдено жодного тренування.")
                .font(.system(size: 12))
                .foregroundStyle(LifecoreTheme.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button(action: {
                withAnimation(.easeOut(duration: 0.2)) {
                    viewModel.resetFilters()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Скинути фільтри")
                }
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(LifecoreTheme.accentPrimary)
                .foregroundStyle(Color.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("btn_reset_filters")
        }
        .frame(maxWidth: .infinity)
        .lifecoreGlassCard(cornerRadius: 18, padding: 28)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(LifecoreTheme.statusWarning)
            Text("Не вдалося завантажити тренування")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(LifecoreTheme.inkPrimary)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(LifecoreTheme.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button(action: {
                Task { await viewModel.loadWorkouts(force: true) }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Спробувати знову")
                }
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(LifecoreTheme.paperWell)
                .foregroundStyle(LifecoreTheme.inkPrimary)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .lifecoreGlassCard(cornerRadius: 18, padding: 28)
    }

    // MARK: - Helpers

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
