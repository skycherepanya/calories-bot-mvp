import SwiftUI
import HealthKit

public struct WorkoutDetailView: View {
    @StateObject private var viewModel: WorkoutDetailViewModel

    public var workout: HKWorkout {
        viewModel.workout
    }

    public init(workout: HKWorkout) {
        _viewModel = StateObject(wrappedValue: WorkoutDetailViewModel(workout: workout))
    }

    public init(viewModel: WorkoutDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 1. Header Overview Card
                headerOverviewCard

                if viewModel.isLoading {
                    loadingCard
                } else if let err = viewModel.errorMessage {
                    errorCard(err)
                } else {
                    sportSpecificContent
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(LifecoreTheme.paperCanvas.ignoresSafeArea())
        .navigationTitle(viewModel.summary.titleUk)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel.series == nil && viewModel.analysis == nil {
                await viewModel.loadWorkoutTelemetry()
            }
        }
    }

    // MARK: - Sport-Specific Sections

    @ViewBuilder
    private var sportSpecificContent: some View {
        if viewModel.isRunning {
            runningContent
        } else if viewModel.isCycling {
            cyclingContent
        } else {
            strengthAndOtherContent
        }
    }

    // MARK: - Running Content

    @ViewBuilder
    private var runningContent: some View {
        // EF & Cardiac Drift Metrics Row
        HStack(spacing: 12) {
            EfficiencyFactorCard(efficiencyFactor: viewModel.runningPresentation?.efficiencyFactor)
            CardiacDriftCard(driftPct: viewModel.runningPresentation?.aerobicDecouplingPct)
        }

        // Telemetry Visualizer (Swift Charts)
        if let series = viewModel.series {
            WorkoutChartsView(
                series: series,
                avgPaceMinKm: viewModel.analysis?.avgPaceMinKm,
                avgHeartRate: viewModel.analysis?.avgHeartRate
            )
        }

        // 1km Auto-Splits Table
        SplitsTableView(splits: viewModel.runningPresentation?.splits ?? [])

        // Structured Interval Laps (if present)
        if let laps = viewModel.runningPresentation?.laps, !laps.isEmpty {
            IntervalLapsTableView(laps: laps)
        }

        // Historical Benchmark Comparison
        BenchmarkComparisonCard(benchmark: viewModel.runningPresentation?.benchmarkDelta)

        // Stream signal status note
        StreamSignalNoteCard(noteUk: viewModel.streamSignalNoteUk)

        // 70/15/15 AI Coach Report Card
        if let analysis = viewModel.analysis {
            CoachReportView(
                analysis: analysis,
                workoutDate: workout.startDate,
                recoveryContext: viewModel.recoveryContext
            )
        }
    }

    // MARK: - Cycling Content

    @ViewBuilder
    private var cyclingContent: some View {
        if let cycling = viewModel.cyclingPresentation {
            CyclingMetricsCard(metrics: cycling)
        }

        // Telemetry Visualizer (Swift Charts)
        if let series = viewModel.series {
            WorkoutChartsView(
                series: series,
                avgPaceMinKm: viewModel.analysis?.avgPaceMinKm,
                avgHeartRate: viewModel.analysis?.avgHeartRate
            )
        }

        // Historical Benchmark Comparison (if present)
        if let delta = viewModel.analysis?.benchmarkDelta {
            BenchmarkComparisonCard(benchmark: delta)
        }

        // Stream signal status note
        StreamSignalNoteCard(noteUk: viewModel.streamSignalNoteUk)

        // AI Coach Report
        if let analysis = viewModel.analysis {
            CoachReportView(
                analysis: analysis,
                workoutDate: workout.startDate,
                recoveryContext: viewModel.recoveryContext
            )
        }
    }

    // MARK: - Strength & Other Content

    @ViewBuilder
    private var strengthAndOtherContent: some View {
        if let strength = viewModel.strengthPresentation {
            StrengthMetricsCard(metrics: strength, titleUk: viewModel.summary.titleUk)
        }

        // Stream signal note
        StreamSignalNoteCard(noteUk: viewModel.streamSignalNoteUk)

        // Telemetry Visualizer (if HR points exist)
        if let series = viewModel.series, series.samples.contains(where: { $0.heartRateBpm != nil }) {
            WorkoutChartsView(
                series: series,
                avgPaceMinKm: nil,
                avgHeartRate: viewModel.analysis?.avgHeartRate
            )
        }

        // AI Coach Report (if analysis exists)
        if let analysis = viewModel.analysis {
            CoachReportView(
                analysis: analysis,
                workoutDate: workout.startDate,
                recoveryContext: viewModel.recoveryContext
            )
        }
    }

    // MARK: - Header Overview Card

    private var headerOverviewCard: some View {
        let summary = viewModel.summary
        let typeColor = workoutColor(for: summary.activityType)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: summary.sportKind.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(typeColor)
                    Text(summary.titleUk)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(LifecoreTheme.inkPrimary)
                }

                Spacer()

                Text(formattedDate(summary.startDate))
                    .font(.system(size: 12))
                    .foregroundStyle(LifecoreTheme.inkTertiary)
            }

            LifecoreHairlineDivider()

            HStack(spacing: 12) {
                metricCell(
                    title: "Тривалість",
                    value: String(format: "%.0f хв", summary.durationMinutes),
                    highlight: LifecoreTheme.inkPrimary
                )

                if let distKm = summary.distanceKm, distKm > 0.01 {
                    metricCell(
                        title: "Дистанція",
                        value: String(format: "%.2f км", distKm),
                        highlight: LifecoreTheme.accentTeal
                    )
                }

                if summary.sportKind == .cycling, summary.durationSeconds > 0, let distKm = summary.distanceKm {
                    let speed = distKm / (summary.durationSeconds / 3600.0)
                    metricCell(
                        title: "Швидкість",
                        value: String(format: "%.1f км/г", speed),
                        highlight: LifecoreTheme.statusOptimal
                    )
                }

                if let kcal = summary.caloriesKcal {
                    metricCell(
                        title: "Калорії",
                        value: "\(Int(kcal)) ккал",
                        highlight: LifecoreTheme.statusWarning
                    )
                }

                if let hr = summary.avgHeartRate {
                    metricCell(
                        title: "Сер. ЧСС",
                        value: "\(Int(hr)) bpm",
                        highlight: LifecoreTheme.statusDanger
                    )
                }

                if let elev = summary.elevationGainMeters, elev > 0 {
                    metricCell(
                        title: "Висота",
                        value: "\(Int(elev)) м",
                        highlight: LifecoreTheme.accentIndigo
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

    // MARK: - Loading & Error States

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
                    await viewModel.loadWorkoutTelemetry()
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

    // MARK: - Helpers

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
