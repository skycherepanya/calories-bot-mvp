import SwiftUI
import HealthKit

public struct TodayView: View {
    @StateObject private var viewModel: TodayViewModel
    public var onNavigateToWorkouts: () -> Void

    public init(
        viewModel: TodayViewModel? = nil,
        onNavigateToWorkouts: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(wrappedValue: viewModel ?? TodayViewModel())
        self.onNavigateToWorkouts = onNavigateToWorkouts
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                ScreenStateView(
                    state: viewModel.state,
                    emptyTitle: "Немає фізіологічних даних",
                    emptyMessage: "Очікування нічних вимірювань Apple Watch або першого тренування.",
                    emptySystemImage: "bolt.heart",
                    retryTitle: "Оновити",
                    onRetry: {
                        Task { await viewModel.refresh(force: true) }
                    }
                ) { snapshot in
                    dashboardContent(snapshot)
                }
                .padding(.horizontal, LifecoreLayout.spacing16)
                .padding(.vertical, LifecoreLayout.spacing12)
            }
            .accessibilityIdentifier("today_scroll_view")
            .background(LifecoreTheme.paperCanvas.ignoresSafeArea())
            .navigationTitle("Lifecore")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.isShowingProfile = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .foregroundStyle(LifecoreTheme.accentPrimary)
                    }
                    .accessibilityIdentifier("btn_open_profile")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.refresh(force: true) }
                    } label: {
                        if viewModel.isRefreshing {
                            ProgressView()
                                .tint(LifecoreTheme.accentPrimary)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(LifecoreTheme.accentPrimary)
                        }
                    }
                    .accessibilityLabel("Оновити дані")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    SettingsToolbarButton()
                }
            }
            .sheet(isPresented: $viewModel.isShowingProfile) {
                AthleteProfileSheet(coordinator: viewModel.coordinator)
            }
            .sheet(isPresented: $viewModel.isShowingEvidence) {
                if let snapshot = viewModel.snapshot {
                    PhysiologicalEvidenceSheet(snapshot: snapshot)
                }
            }
            .refreshable {
                await viewModel.refresh(force: true)
            }
            .task {
                await viewModel.refresh(force: false)
            }
        }
    }

    // MARK: - Dashboard Content

    @ViewBuilder
    private func dashboardContent(_ snapshot: DailyDashboardSnapshot) -> some View {
        VStack(spacing: LifecoreLayout.spacing16) {
            // 1. Date & Freshness Header Row + Profile Button
            dateAndFreshnessRow(snapshot)

            // 2. Primary Readiness Score & Explanation Card
            readinessCockpitCard(snapshot)

            // 3. Tactical Next-Session Action Card
            TacticalPrescriptionCard(
                snapshot: snapshot,
                onNavigateToWorkouts: {
                    viewModel.openWorkout(onNavigate: onNavigateToWorkouts)
                }
            )

            // 4. Compact Sleep Architecture
            compactSleepSection(snapshot)

            // 5. Overnight Vitals Radar & Corridor
            OvernightVitalsCard(snapshot: snapshot)

            // 6. Activity & Pure NEAT & Nutrition
            activityAndNutritionSection(snapshot)

            // 7. Latest Workout Row
            latestWorkoutSection(snapshot)

            // 8. Physiological Evidence Trigger Button
            evidenceDisclosureRow(snapshot)
        }
    }

    // MARK: - Subviews

    private func dateAndFreshnessRow(_ snapshot: DailyDashboardSnapshot) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(formattedDietaryDayUk(snapshot.day))
                    .font(.headline)
                    .foregroundStyle(LifecoreTheme.inkPrimary)

                if viewModel.isStale {
                    LifecoreGlowPill(
                        text: "Застарілі дані",
                        systemIcon: "exclamationmark.arrow.triangle.2.circlepath",
                        color: LifecoreTheme.statusWarning
                    )
                } else if viewModel.isRefreshing {
                    LifecoreGlowPill(
                        text: "Оновлення...",
                        systemIcon: "arrow.triangle.2.circlepath",
                        color: LifecoreTheme.accentPrimary
                    )
                }
            }

            Spacer()

            Button {
                viewModel.isShowingProfile = true
            } label: {
                Image(systemName: "person.crop.circle")
                    .font(.title2)
                    .foregroundStyle(LifecoreTheme.accentPrimary)
                    .frame(minWidth: LifecoreLayout.minTouchTarget, minHeight: LifecoreLayout.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("btn_athlete_profile")
        }
    }

    private func readinessCockpitCard(_ snapshot: DailyDashboardSnapshot) -> some View {
        Group {
            if let score = snapshot.readinessScore {
                HStack(spacing: 16) {
                    let recoveryColor: Color = score >= 80 ? LifecoreTheme.statusOptimal :
                                               (score >= 60 ? LifecoreTheme.statusWarning : LifecoreTheme.statusDanger)
                    let recoverySubtitle: String = {
                        if score >= 80 { return "Оптимально" }
                        if score >= 60 { return "Адаптивно" }
                        return "Відпочинок"
                    }()

                    BevelRingView(
                        title: "Відновлення",
                        value: "\(score)%",
                        subtitle: recoverySubtitle,
                        progress: Double(score) / 100.0,
                        ringColor: recoveryColor
                    )
                    .frame(width: 84)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Індекс готовності")
                            .font(.headline)
                            .foregroundStyle(LifecoreTheme.inkPrimary)

                        if let headline = snapshot.vitalsEvaluation?.headline {
                            Text(headline)
                                .font(.subheadline)
                                .foregroundStyle(LifecoreTheme.inkSecondary)
                                .lineLimit(2)
                        } else {
                            Text(recoverySubtitle)
                                .font(.subheadline)
                                .foregroundStyle(recoveryColor)
                        }

                        if let battery = snapshot.currentBodyBattery ?? snapshot.morningBodyBattery {
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.fill")
                                    .font(.caption2)
                                    .foregroundStyle(LifecoreTheme.accentTeal)
                                Text("Батарея: \(battery)%")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .monospacedDigit()
                                    .foregroundStyle(LifecoreTheme.inkSecondary)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.text.square")
                            .font(.title3)
                            .foregroundStyle(LifecoreTheme.inkTertiary)
                        Text("Готовність очікує вимірювань")
                            .font(.headline)
                            .foregroundStyle(LifecoreTheme.inkPrimary)
                    }

                    Text("Для розрахунку індексу відновлення потрібні нічні вимірювання Apple Watch (HRV та пульс спокою).")
                        .font(.subheadline)
                        .foregroundStyle(LifecoreTheme.inkSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
        }
        .lifecoreGlassCard()
    }

    private func compactSleepSection(_ snapshot: DailyDashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: LifecoreLayout.spacing8) {
            SectionHeader(title: "Сон", subtitle: "Архітектура останньої ночі")

            if let sleep = snapshot.sleepEpisode {
                HStack(spacing: LifecoreLayout.spacing12) {
                    compactSleepPill(
                        title: "Всього",
                        value: String(format: "%.1f год", sleep.totalSleepHours),
                        color: LifecoreTheme.accentIndigo
                    )
                    compactSleepPill(
                        title: "Глибокий",
                        value: String(format: "%.1f год", sleep.deepDurationSeconds / 3600.0),
                        color: Color(red: 0.35, green: 0.35, blue: 0.95)
                    )
                    compactSleepPill(
                        title: "REM",
                        value: String(format: "%.1f год", sleep.remDurationSeconds / 3600.0),
                        color: Color(red: 0.7, green: 0.35, blue: 0.95)
                    )
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "moon.fill")
                        .foregroundStyle(LifecoreTheme.inkTertiary)
                    Text("Очікування даних сну Apple Watch...")
                        .font(.subheadline)
                        .foregroundStyle(LifecoreTheme.inkSecondary)
                    Spacer()
                }
                .padding(.vertical, LifecoreLayout.spacing4)
            }
        }
        .lifecoreGlassCard()
    }

    private func compactSleepPill(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(LifecoreTheme.inkTertiary)
            Text(value)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(LifecoreTheme.inkPrimary)
            Capsule()
                .fill(color)
                .frame(height: 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func activityAndNutritionSection(_ snapshot: DailyDashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: LifecoreLayout.spacing8) {
            SectionHeader(title: "Активність та харчування")

            VStack(spacing: LifecoreLayout.spacing8) {
                if let workload = snapshot.workloadEvaluation {
                    MetricRow(
                        title: "ACWR Навантаження",
                        value: String(format: "%.2f", workload.ratio),
                        detail: "\(workload.titleUk)\(snapshot.isProvisionalWorkload ? " (попереднє)" : "")",
                        systemImage: "chart.line.uptrend.xyaxis",
                        statusTone: acwrStatusTone(workload.zone)
                    )
                }

                if let adaptive = snapshot.adaptiveSnapshot {
                    MetricRow(
                        title: "Адаптивний BMR",
                        value: "\(Int(round(adaptive.dynamicTDEE.learnedBmrKcal))) ккал",
                        detail: "Впевненість моделі: \(adaptive.confidencePct)%",
                        systemImage: "flame.fill",
                        statusTone: .teal
                    )
                }

                let mealsCount = snapshot.confirmedMealsCount
                let intakeKcal = snapshot.confirmedIntakeKcal
                MetricRow(
                    title: "Калорійність харчування",
                    value: intakeKcal != nil ? "\(Int(round(intakeKcal!))) ккал" : "0 ккал",
                    detail: "\(mealsCount) підтверджених страв",
                    systemImage: "fork.knife",
                    statusTone: mealsCount > 0 ? .optimal : .neutral
                )
            }
        }
        .lifecoreGlassCard()
    }

    private func latestWorkoutSection(_ snapshot: DailyDashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: LifecoreLayout.spacing8) {
            SectionHeader(
                title: "Останнє тренування",
                actionTitle: "Всі",
                action: {
                    viewModel.openWorkout(onNavigate: onNavigateToWorkouts)
                }
            )

            if let workout = snapshot.latestWorkout {
                Button {
                    viewModel.openWorkout(onNavigate: onNavigateToWorkouts)
                } label: {
                    HStack(spacing: LifecoreLayout.spacing12) {
                        Image(systemName: workout.isRunning ? "figure.run" : "figure.cross.training")
                            .font(.title2)
                            .foregroundStyle(LifecoreTheme.accentPrimary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(workout.isRunning ? "Бігова сесія" : "Тренування")
                                .font(.body.weight(.bold))
                                .foregroundStyle(LifecoreTheme.inkPrimary)

                            HStack(spacing: 8) {
                                Text("\(Int(workout.durationSeconds / 60)) хв")
                                if let trimp = workout.trimp {
                                    Text("• TRIMP \(Int(round(trimp)))")
                                }
                                if let ef = workout.efficiencyFactor {
                                    Text("• EF \(String(format: "%.2f", ef))")
                                }
                            }
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(LifecoreTheme.inkSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LifecoreTheme.inkTertiary)
                    }
                }
                .buttonStyle(.plain)
            } else {
                HStack {
                    Text("Сьогодні ще немає зафіксованих тренувань.")
                        .font(.subheadline)
                        .foregroundStyle(LifecoreTheme.inkSecondary)
                    Spacer()
                }
                .padding(.vertical, LifecoreLayout.spacing4)
            }
        }
        .lifecoreGlassCard()
    }

    private func evidenceDisclosureRow(_ snapshot: DailyDashboardSnapshot) -> some View {
        Button {
            viewModel.openEvidence()
        } label: {
            HStack(spacing: LifecoreLayout.spacing8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifecoreTheme.accentPrimary)
                Text("Фізіологічна доказова база (деталі)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifecoreTheme.accentPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LifecoreTheme.inkTertiary)
            }
            .frame(maxWidth: .infinity, minHeight: LifecoreLayout.minTouchTarget)
            .padding(.horizontal, LifecoreLayout.spacing16)
            .padding(.vertical, LifecoreLayout.spacing12)
            .background(LifecoreTheme.semanticCard)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("btn_open_evidence")
    }

    // MARK: - Helpers

    private func formattedDietaryDayUk(_ day: DietaryDay) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk_UA")
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: day.interval.start).capitalized
    }

    private func acwrStatusTone(_ zone: ACWRZone) -> MetricStatusTone {
        switch zone {
        case .undertraining: return .teal
        case .sweetSpot: return .optimal
        case .caution: return .warning
        case .dangerSpike: return .danger
        }
    }
}

// MARK: - Physiological Evidence Sheet

public struct PhysiologicalEvidenceSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let snapshot: DailyDashboardSnapshot

    public init(snapshot: DailyDashboardSnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Нічні вітальні біомаркери")) {
                    if let eval = snapshot.vitalsEvaluation {
                        evidenceRow(label: "Стан імунітету", value: eval.state.titleUk)
                        evidenceRow(label: "Висновок", value: eval.headline)
                        evidenceRow(label: "HRV (поточний)", value: "\(Int(round(eval.hrvPillar.currentValue))) мс")
                        evidenceRow(label: "HRV (базовий)", value: "\(Int(round(eval.hrvPillar.baselineValue))) мс")
                        if let z = eval.hrvPillar.zScore {
                            evidenceRow(label: "HRV Z-Score", value: String(format: "%.2f", z))
                        }
                        evidenceRow(label: "RHR (поточний)", value: String(format: "%.1f уд/хв", eval.rhrPillar.currentValue))
                        evidenceRow(label: "RHR (базовий)", value: String(format: "%.1f уд/хв", eval.rhrPillar.baselineValue))
                        if let temp = eval.tempPillar {
                            evidenceRow(label: "Δ Темп. зап’ястя", value: String(format: "%+.2f °C", temp.delta))
                        }
                        if let resp = eval.respPillar {
                            evidenceRow(label: "Частота дихання", value: String(format: "%.1f дих/хв", resp.currentValue))
                        }
                        if let spo2 = eval.spo2Pillar {
                            evidenceRow(label: "SpO₂", value: String(format: "%.1f%%", spo2.currentValue))
                        }
                    } else {
                        Text("Нічні біомаркери відсутні або ще не синхронізовані.")
                            .foregroundStyle(LifecoreTheme.inkSecondary)
                    }
                }

                Section(header: Text("Тренувальне навантаження (ACWR)")) {
                    if let workload = snapshot.workloadEvaluation {
                        evidenceRow(label: "ACWR Ratio", value: String(format: "%.2f", workload.ratio))
                        evidenceRow(label: "Зона навантаження", value: workload.titleUk)
                        evidenceRow(label: "Гостре навантаження (7d)", value: String(format: "%.1f", workload.acuteLoad))
                        evidenceRow(label: "Хронічне навантаження (28d)", value: String(format: "%.1f", workload.chronicLoad))
                        evidenceRow(label: "Статус вибірки", value: snapshot.isProvisionalWorkload ? "Попередній (мало даних)" : "Повний (28+ днів)")
                    } else {
                        Text("Історія навантаження ще формується.")
                            .foregroundStyle(LifecoreTheme.inkSecondary)
                    }
                }

                if let adaptive = snapshot.adaptiveSnapshot {
                    Section(header: Text("Адаптивна фізіологія")) {
                        evidenceRow(label: "Впевненість моделі", value: "\(adaptive.confidencePct)%")
                        evidenceRow(label: "Днів спостережень", value: "\(adaptive.sampleDaysCount)")
                        evidenceRow(label: "Адаптивний BMR", value: "\(Int(round(adaptive.dynamicTDEE.learnedBmrKcal))) ккал")
                        evidenceRow(label: "Фактор розряду батареї", value: String(format: "%.2f", adaptive.sensitivities.trimpBatteryDrainFactor))
                        evidenceRow(label: "Вуглеводний нахил дрейфу", value: String(format: "%.2f%%/100г", adaptive.sensitivities.carbCardiacDriftSlopePctPer100g))
                    }
                }

                if !snapshot.unavailabilityReasons.isEmpty {
                    Section(header: Text("Причини обмеження плану")) {
                        ForEach(snapshot.unavailabilityReasons, id: \.self) { reason in
                            Text(reason.titleUk)
                                .font(.subheadline)
                                .foregroundStyle(LifecoreTheme.statusWarning)
                        }
                    }
                }

                Section(header: Text("Метадані знімка")) {
                    evidenceRow(label: "Дата дієтичного дня", value: snapshot.day.key)
                    evidenceRow(label: "Ревізія", value: snapshot.revision.uuidString.prefix(8).description)
                }
            }
            .navigationTitle("Фізіологічні докази")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                        .foregroundStyle(LifecoreTheme.accentPrimary)
                }
            }
        }
    }

    private func evidenceRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(LifecoreTheme.inkPrimary)
            Spacer()
            Text(value)
                .foregroundStyle(LifecoreTheme.inkSecondary)
                .monospacedDigit()
        }
    }
}

// MARK: - Bevel Ring Component (Daylight Surface)

public struct BevelRingView: View {
    public let title: String
    public let value: String
    public let subtitle: String
    public let progress: Double
    public let ringColor: Color

    public init(
        title: String,
        value: String,
        subtitle: String,
        progress: Double,
        ringColor: Color
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.progress = progress
        self.ringColor = ringColor
    }

    public var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Background Track
                Circle()
                    .stroke(ringColor.opacity(0.14), lineWidth: 7)

                // Animated Progress Ring
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(1.0, max(0.02, progress))))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [ringColor.opacity(0.7), ringColor]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                // Center Value
                VStack(spacing: 1) {
                    Text(value)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(LifecoreTheme.inkPrimary)
                    Text(title)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(LifecoreTheme.inkTertiary)
                }
            }
            .frame(width: 80, height: 80)

            Text(subtitle)
                .font(.system(size: 10, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(LifecoreTheme.inkSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

#Preview {
    TodayView()
        .preferredColorScheme(.light)
}
