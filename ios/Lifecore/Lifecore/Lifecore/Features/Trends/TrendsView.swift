import SwiftUI
import HealthKit

public enum TrendsCategory: String, CaseIterable, Identifiable {
    case adaptation = "Адаптація"
    case workload = "Навантаження"
    case body = "Тіло & Вага"
    case cardio = "Кардіо & ВНС"

    public var id: String { rawValue }

    public var systemIcon: String {
        switch self {
        case .adaptation: return "brain.head.profile"
        case .workload: return "flame.fill"
        case .body: return "scalemass.fill"
        case .cardio: return "waveform.path.ecg"
        }
    }
}

public struct TrendsView: View {
    @StateObject private var viewModel: TrendsViewModel
    @State private var selectedRange: TrendsTimeRange = .days30
    @State private var selectedCategory: TrendsCategory = .adaptation
    @State private var isDiagnosticsExpanded: Bool = false

    public init() {
        self._viewModel = StateObject(wrappedValue: TrendsViewModel())
    }

    public init(viewModel: TrendsViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 1. Time Range Selector
                    TrendsRangePickerView(selectedRange: $selectedRange)
                        .padding(.top, 4)

                    // 2. Liquid Glass Category Segmented Switcher
                    categorySwitcher

                    // 3. Category Content View
                    contentView
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .accessibilityIdentifier("trends_scroll_view")
            .accessibilityIdentifier("screen_trends")
            .background(LifecoreTheme.paperCanvas.ignoresSafeArea())
            .navigationTitle("Тренди та Аналітика")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        Task { await viewModel.load(rangeDays: selectedRange.rawValue) }
                    }) {
                        if viewModel.state.isLoading || viewModel.state.isRefreshing {
                            ProgressView()
                                .tint(LifecoreTheme.accentPrimary)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(LifecoreTheme.accentPrimary)
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.load(rangeDays: selectedRange.rawValue)
            }
            .task(id: selectedRange) {
                await viewModel.load(rangeDays: selectedRange.rawValue)
            }
        }
    }

    // MARK: - Category Switcher

    private var categorySwitcher: some View {
        HStack(spacing: 6) {
            ForEach(TrendsCategory.allCases) { cat in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = cat
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: cat.systemIcon)
                            .font(.system(size: 10, weight: .bold))
                        Text(cat.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(selectedCategory == cat ? LifecoreTheme.inkPrimary : LifecoreTheme.inkSecondary)
                    .background(
                        selectedCategory == cat ?
                            LifecoreTheme.paperCard : Color.clear
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(selectedCategory == cat ? LifecoreTheme.ruleHairline : Color.clear, lineWidth: 1.0)
                    )
                }
                .accessibilityIdentifier({
                    switch cat {
                    case .adaptation: return "tab_trend_adaptation"
                    case .workload: return "tab_trend_workload"
                    case .body: return "tab_trend_body"
                    case .cardio: return "tab_trend_cardio"
                    }
                }())
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(LifecoreTheme.paperWell)
        )
    }

    // MARK: - Main Content Switcher

    @ViewBuilder
    private var contentView: some View {
        if viewModel.state.isLoading && viewModel.state.value == nil {
            VStack(spacing: 12) {
                ProgressView()
                    .tint(LifecoreTheme.accentPrimary)
                Text("Завантаження фізіологічних трендів...")
                    .font(.caption)
                    .foregroundStyle(LifecoreTheme.inkSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        } else if let snapshot = viewModel.state.value {
            switch selectedCategory {
            case .adaptation:
                adaptationSection(snapshot: snapshot)

            case .workload:
                workloadSection(snapshot: snapshot)

            case .body:
                bodySection(snapshot: snapshot)

            case .cardio:
                cardioSection(snapshot: snapshot)
            }
        } else if case .failed(let message, _) = viewModel.state {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(LifecoreTheme.statusDanger)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(LifecoreTheme.statusDanger)
                    .multilineTextAlignment(.center)
                Button("Спробувати знову") {
                    Task { await viewModel.load(rangeDays: selectedRange.rawValue) }
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
    }

    // MARK: - Category Sections

    private func adaptationSection(snapshot: TrendsSnapshot) -> some View {
        VStack(spacing: 16) {
            ChartSummary(
                title: "Адаптивний TDEE",
                value: snapshot.adaptiveSnapshot.map { "\(Int($0.dynamicTDEE.learnedDailyTdeeKcal)) ккал" } ?? "—",
                coverage: snapshot.dynamicTdeeCoverage,
                deltaText: snapshot.adaptiveSnapshot.map { String(format: "%+.0f ккал адаптація", $0.dynamicTDEE.metabolicAdaptationKcal) }
            )

            CorrelationInsightsCard(
                insights: snapshot.correlationInsights,
                coverage: snapshot.correlationCoverage
            )

            if let adaptive = snapshot.adaptiveSnapshot {
                DisclosureGroup(isExpanded: $isDiagnosticsExpanded) {
                    AdaptiveEngineStatusCard(snapshot: adaptive)
                        .padding(.top, 8)
                } label: {
                    HStack {
                        Label("Діагностика адаптації ядра", systemImage: "gearshape.2")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(LifecoreTheme.inkPrimary)
                        Spacer()
                        LifecoreGlowPill(
                            text: "\(adaptive.confidencePct)% точності",
                            systemIcon: "checkmark.seal.fill",
                            color: adaptive.confidencePct >= 70 ? LifecoreTheme.statusOptimal : LifecoreTheme.accentTeal
                        )
                    }
                }
                .padding(14)
                .lifecoreGlassCard()
            }
        }
    }

    private func workloadSection(snapshot: TrendsSnapshot) -> some View {
        VStack(spacing: 16) {
            ChartSummary(
                title: "Навантаження EWMA ACWR",
                value: snapshot.acwrEvaluation.map { String(format: "%.2f", $0.ratio) } ?? "—",
                coverage: snapshot.acwrCoverage,
                deltaText: snapshot.acwrEvaluation?.zone.titleUk
            )

            ACWRWorkloadTrendCard(
                evaluation: snapshot.acwrEvaluation,
                dailyLoads: snapshot.dailyTrimpLoads
            )
        }
    }

    private func bodySection(snapshot: TrendsSnapshot) -> some View {
        VStack(spacing: 16) {
            let latestPoint = snapshot.weightPoints.last
            let net7dDelta: Double? = {
                guard snapshot.weightPoints.count >= 7,
                      let current7d = snapshot.weightPoints.last?.rolling7dKg,
                      let prior7d = snapshot.weightPoints[max(0, snapshot.weightPoints.count - 8)].rolling7dKg else {
                    return nil
                }
                return round((current7d - prior7d) * 100) / 100
            }()

            ChartSummary(
                title: "Динаміка ваги (7d/14d фільтр)",
                value: latestPoint.map { String(format: "%.1f кг", $0.rawWeightKg) } ?? "—",
                coverage: snapshot.weightCoverage,
                deltaText: net7dDelta.map { String(format: "%+.1f кг (7d)", $0) }
            )

            WeightTrendCard(points: snapshot.weightPoints)
        }
    }

    private func cardioSection(snapshot: TrendsSnapshot) -> some View {
        VStack(spacing: 16) {
            let latestAutonomic = snapshot.autonomicSamples.last
            let hrvDiff: Double? = {
                guard let hrv = latestAutonomic?.hrvMs, let base = latestAutonomic?.hrvBaselineMean else { return nil }
                return hrv - base
            }()

            ChartSummary(
                title: "Нічний HRV та Пульс Спокою",
                value: latestAutonomic?.hrvMs.map { String(format: "%.0f мс", $0) } ?? "—",
                coverage: snapshot.autonomicCoverage,
                deltaText: hrvDiff.map { String(format: "%+.0f мс vs база", $0) }
            )

            AutonomicTrendCard(samples: snapshot.autonomicSamples)

            AerobicEfficiencyTrendCard(samples: snapshot.efSamples)
        }
    }
}

#Preview {
    TrendsView()
        .preferredColorScheme(.light)
}
