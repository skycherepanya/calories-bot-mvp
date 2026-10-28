import SwiftUI
import HealthKit

public struct WorkoutDetailView: View {
    public let workout: HKWorkout

    @State private var series: WorkoutTelemetrySeries?
    @State private var analysis: WorkoutAnalysisResult?
    @State private var recoveryContext: RecentRecoveryContext?
    @State private var isLoading = true
    @State private var errorMessage: String?

    public init(workout: HKWorkout) {
        self.workout = workout
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 1. Header Overview Card
                headerOverviewCard

                if isLoading {
                    loadingCard
                } else if let analysis = analysis {
                    // 2. EF & Cardiac Drift Metrics Row
                    HStack(spacing: 12) {
                        EfficiencyFactorCard(efficiencyFactor: analysis.efficiencyFactor)
                        CardiacDriftCard(driftPct: analysis.aerobicDecouplingPct)
                    }

                    // 3. Telemetry Visualizer (Swift Charts)
                    if let series = series {
                        WorkoutChartsView(
                            series: series,
                            avgPaceMinKm: analysis.avgPaceMinKm,
                            avgHeartRate: analysis.avgHeartRate
                        )
                    }

                    // 4. 1km Auto-Splits Table
                    SplitsTableView(splits: analysis.splits)

                    // 5. Structured Interval Laps (if present)
                    if !analysis.laps.isEmpty {
                        IntervalLapsTableView(laps: analysis.laps)
                    }

                    // 6. Historical Benchmark Comparison
                    BenchmarkComparisonCard(benchmark: analysis.benchmarkDelta)

                    // 7. 70/15/15 AI Coach Report Card
                    CoachReportView(
                        analysis: analysis,
                        workoutDate: workout.startDate,
                        recoveryContext: recoveryContext
                    )
                } else if let err = errorMessage {
                    errorCard(err)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(LifecoreTheme.paperCanvas.ignoresSafeArea())
        .navigationTitle(workoutTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadWorkoutTelemetry()
        }
    }

    // MARK: - Header Card

    private var workoutTitle: String {
        switch workout.workoutActivityType {
        case .running: return "Біг"
        case .cycling: return "Велосипед"
        case .walking: return "Прогулянка"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "Силове тренування"
        case .highIntensityIntervalTraining: return "HIIT"
        case .swimming: return "Плавання"
        default: return "Тренування"
        }
    }

    private var headerOverviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: iconName(for: workout.workoutActivityType))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(LifecoreTheme.statusOptimal)
                    Text(workoutTitle)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(LifecoreTheme.inkPrimary)
                }

                Spacer()

                Text(formattedDate(workout.startDate))
                    .font(.system(size: 12))
                    .foregroundStyle(LifecoreTheme.inkTertiary)
            }

            LifecoreHairlineDivider()

            HStack(spacing: 12) {
                metricCell(
                    title: "Тривалість",
                    value: String(format: "%.0f хв", workout.duration / 60.0),
                    highlight: LifecoreTheme.inkPrimary
                )

                if let dist = workout.totalDistance?.doubleValue(for: .meter()) {
                    metricCell(
                        title: "Дистанція",
                        value: String(format: "%.2f км", dist / 1000.0),
                        highlight: LifecoreTheme.accentTeal
                    )
                }

                if let kcal = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                    metricCell(
                        title: "Калорії",
                        value: "\(Int(kcal)) ккал",
                        highlight: LifecoreTheme.statusWarning
                    )
                }

                if let hr = workout.statistics(for: HKQuantityType(.heartRate))?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) {
                    metricCell(
                        title: "Сер. ЧСС",
                        value: "\(Int(hr)) bpm",
                        highlight: LifecoreTheme.statusDanger
                    )
                }
            }
        }
        .lifecoreGlassCard(cornerRadius: 20)
    }

    private func metricCell(title: String, value: String, highlight: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(LifecoreTheme.inkTertiary)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(highlight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loadingCard: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(LifecoreTheme.accentPrimary)
            Text("Витягую детальну телеметрію з Apple Watch...")
                .font(.system(size: 12))
                .foregroundStyle(LifecoreTheme.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .lifecoreGlassCard(cornerRadius: 20)
    }

    private func errorCard(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(LifecoreTheme.statusWarning)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(LifecoreTheme.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Button(action: {
                Task {
                    await loadWorkoutTelemetry()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Спробувати знову")
                }
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(LifecoreTheme.paperWell)
                .foregroundStyle(LifecoreTheme.inkPrimary)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .lifecoreGlassCard(cornerRadius: 20)
    }

    // MARK: - Actions

    private func loadWorkoutTelemetry() async {
        isLoading = true
        errorMessage = nil

        do {
            // 0. Ensure HealthKit permissions are determined
            try await HealthKitManager.shared.requestAuthorization()

            // 1. Extract raw continuous series
            let series = try await WorkoutTelemetryExtractor.shared.extractTelemetry(for: workout)
            self.series = series

            // 2. Query historical benchmarks (matching workouts within ±25% distance)
            let benchmarks = (try? await HealthKitManager.shared.fetchHistoricalSimilarWorkouts(to: workout)) ?? []

            // 3. Query 48h recovery context
            let recovery = await HealthKitManager.shared.fetchRecentRecoveryContext(for: workout.startDate)
            self.recoveryContext = recovery

            // 4. Run deterministic pure Swift Math Engine
            let analysisResult = WorkoutMathEngine.analyze(
                series: series,
                historicalWorkouts: benchmarks
            )
            self.analysis = analysisResult

            // 5. Persist to SwiftData
            let distanceM = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
            let cached = WorkoutStorageService.fetchAnalysis(for: workout.uuid)
            WorkoutStorageService.saveOrUpdate(
                workoutUUID: workout.uuid,
                workoutType: workoutTitle,
                startedAt: workout.startDate,
                distanceMeters: distanceM,
                durationSeconds: workout.duration,
                avgPaceSecPerKm: analysisResult.avgPaceMinKm * 60.0,
                avgHeartRate: analysisResult.avgHeartRate,
                maxHeartRate: analysisResult.maxHeartRate,
                elevationGainMeters: analysisResult.elevationGainMeters,
                efficiencyFactor: analysisResult.efficiencyFactor,
                cardiacDriftPercentage: analysisResult.aerobicDecouplingPct,
                splits: analysisResult.splits,
                laps: analysisResult.laps,
                aiCoachReport: cached?.aiCoachReport
            )

        } catch {
            self.errorMessage = "Помилка читання телеметрії: \(error.localizedDescription)"
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

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM, HH:mm"
        formatter.locale = Locale(identifier: "uk_UA")
        return formatter.string(from: date)
    }
}
