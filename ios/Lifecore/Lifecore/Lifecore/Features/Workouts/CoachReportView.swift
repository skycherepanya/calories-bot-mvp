import SwiftUI

public struct CoachReportView: View {
    public let analysis: WorkoutAnalysisResult
    public let workoutDate: Date
    public let recoveryContext: RecentRecoveryContext?
    public let assembledDossier: AssembledHealthDossier?

    @StateObject private var viewModel: CoachViewModel
    @State private var showChatSheet = false
    @State private var showEvidenceSheet = false
    @State private var selectedQuestionForChat: String? = nil

    public init(
        analysis: WorkoutAnalysisResult,
        workoutDate: Date = Date(),
        recoveryContext: RecentRecoveryContext? = nil,
        assembledDossier: AssembledHealthDossier? = nil,
        viewModel: CoachViewModel? = nil
    ) {
        self.analysis = analysis
        self.workoutDate = workoutDate
        self.recoveryContext = recoveryContext
        self.assembledDossier = assembledDossier

        let dossier: AssembledHealthDossier
        if let d = assembledDossier {
            dossier = d
        } else {
            let meals = MealStorageService.fetchAcuteNutritionMeals(for: workoutDate, hoursBefore: 36.0)
            dossier = LifecoreContextRAG.assembleDossier(
                workoutAnalysis: analysis,
                recoveryContext: recoveryContext,
                meals: meals,
                anchorDate: workoutDate,
                nutritionWindowHours: 36
            )
        }

        if let injected = viewModel {
            _viewModel = StateObject(wrappedValue: injected)
        } else {
            _viewModel = StateObject(wrappedValue: CoachViewModel(
                dossier: dossier,
                workoutUUID: analysis.workoutUUID
            ))
        }
    }

    private var activeDossier: AssembledHealthDossier {
        viewModel.dossier
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: Lifecore Intelligence + Evidence Disclosure Button
            HStack {
                Label("Тренерський розбір", systemImage: "sparkles")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(LifecoreTheme.accentPrimary)

                Spacer()

                Button(action: {
                    showEvidenceSheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Доказова база")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(LifecoreTheme.accentPrimary.opacity(0.12))
                    .foregroundStyle(LifecoreTheme.accentPrimary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("btn_open_evidence")
            }

            // Main State Switcher
            switch viewModel.reportState {
            case .generating:
                generatingCard

            case .unavailableProvider(let messageUk):
                unavailableProviderCard(messageUk: messageUk)

            case .rateLimited(let messageUk):
                rateLimitedCard(messageUk: messageUk)

            case .staleReport(let debrief, let reasonUk):
                staleNotice(reasonUk: reasonUk)
                debriefContent(debrief, isOfflineFallback: debrief.isOfflineFallback)

            case .failed(let messageUk, let preserved):
                if let preserved {
                    failedWithPreservedNotice(messageUk: messageUk)
                    debriefContent(preserved, isOfflineFallback: preserved.isOfflineFallback)
                } else {
                    failedCard(messageUk: messageUk)
                }

            case .completed(let debrief, let isOfflineFallback):
                debriefContent(debrief, isOfflineFallback: isOfflineFallback)

            case .idle:
                initialCtaCard
            }
        }
        .lifecoreGlassCard(cornerRadius: 20)
        .sheet(isPresented: $showChatSheet) {
            LifecoreIntelligenceChatView(
                dossier: activeDossier,
                initialQuestion: selectedQuestionForChat,
                viewModel: viewModel
            )
        }
        .sheet(isPresented: $showEvidenceSheet) {
            NavigationStack {
                CoachEvidenceView(viewModel: viewModel)
            }
        }
        .task {
            if viewModel.reportState == .idle {
                viewModel.loadCachedReport()
            }
        }
    }

    // MARK: - Debrief Content View

    @ViewBuilder
    private func debriefContent(_ d: StructuredWorkoutDebrief, isOfflineFallback: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Headline & Regime Badge
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(d.headlineUk)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(LifecoreTheme.inkPrimary)
                        .lineSpacing(2)

                    Spacer()

                    HStack(spacing: 4) {
                        if isOfflineFallback {
                            Text("Автономно")
                                .font(.system(size: 9, weight: .medium))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(LifecoreTheme.paperWell)
                                .foregroundStyle(LifecoreTheme.inkTertiary)
                                .clipShape(Capsule())
                        }

                        Text(d.regimeBadgeUk)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(colorForTone(d.regimeTone).opacity(0.12))
                            .foregroundStyle(colorForTone(d.regimeTone))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.top, 2)

            // Metric Evidence Pills Strip
            if !d.evidencePills.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(d.evidencePills) { pill in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pill.labelUk)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(LifecoreTheme.inkTertiary)
                                Text(pill.valueUk)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(colorForTone(pill.tone))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(LifecoreTheme.paperWell)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            // Section 1: 70% Execution (Pacing, Splits, Drift)
            if !d.executionAnalysisUk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                LifecoreHairlineDivider()
                sectionBlock(
                    icon: "figure.run",
                    title: "Виконання та розкладка сил",
                    content: d.executionAnalysisUk,
                    iconColor: LifecoreTheme.accentTeal
                )
            }

            // Section 2: 15% Benchmark Dynamics (omitted honestly if not computed)
            if !d.benchmarkComparisonUk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                LifecoreHairlineDivider()
                sectionBlock(
                    icon: "arrow.left.arrow.right",
                    title: "Динаміка форми та режим зусиль",
                    content: d.benchmarkComparisonUk,
                    iconColor: LifecoreTheme.accentIndigo
                )
            }

            // Section 3: 15% Root Cause & 24h Directive (omitted honestly if empty)
            if !d.rootCauseAndDirectiveUk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                LifecoreHairlineDivider()
                sectionBlock(
                    icon: "target",
                    title: "Фізіологічні причини та план на 24г",
                    content: d.rootCauseAndDirectiveUk,
                    iconColor: LifecoreTheme.statusOptimal
                )
            }

            // Contextual Follow-Up Question Chips
            if !d.followUpQuestionsUk.isEmpty {
                LifecoreHairlineDivider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Швидкі запитання до тренера:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(LifecoreTheme.inkTertiary)

                    ForEach(d.followUpQuestionsUk, id: \.self) { question in
                        Button(action: {
                            selectedQuestionForChat = question
                            showChatSheet = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "bubble.left.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(LifecoreTheme.accentPrimary)
                                Text(question)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(LifecoreTheme.inkPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(LifecoreTheme.inkTertiary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(LifecoreTheme.paperWell)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            LifecoreHairlineDivider()

            // Interactive Conversational Coach Launcher Buttons
            HStack(spacing: 10) {
                Button(action: {
                    selectedQuestionForChat = nil
                    showChatSheet = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left.and.text.bubble.right.fill")
                        Text("Запитати тренера")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(LifecoreTheme.accentPrimary)
                    .foregroundStyle(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("btn_open_coach_chat")

                Button(action: {
                    Task { await viewModel.generateDebrief(forceRefresh: true) }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LifecoreTheme.inkSecondary)
                        .padding(10)
                        .background(LifecoreTheme.paperWell)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("btn_refresh_coach_report")
            }
            .padding(.top, 4)
        }
    }

    // MARK: - State Cards

    private var initialCtaCard: some View {
        VStack(spacing: 12) {
            Text("Спортивний розбір сесії на основі сплітів, кардіо-динаміки, нічних показників відновлення та особистого контексту.")
                .font(.system(size: 12))
                .foregroundStyle(LifecoreTheme.inkSecondary)
                .lineSpacing(2)
                .multilineTextAlignment(.leading)

            Button(action: {
                Task { await viewModel.generateDebrief() }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                    Text("Отримати розбір тренера")
                        .fontWeight(.semibold)
                }
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(LifecoreTheme.accentPrimary)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("btn_generate_coach_report")
        }
    }

    private var generatingCard: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(LifecoreTheme.accentPrimary)
            Text("Аналізую тренування та фізіологію...")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(LifecoreTheme.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func unavailableProviderCard(messageUk: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(LifecoreTheme.statusWarning)
                Text("ШІ-провайдер недоступний")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LifecoreTheme.inkPrimary)
            }

            Text(messageUk)
                .font(.system(size: 12))
                .foregroundStyle(LifecoreTheme.inkSecondary)
                .lineSpacing(2)

            Button(action: {
                Task { await viewModel.generateDebrief() }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Спробувати знову")
                }
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(LifecoreTheme.paperWell)
                .foregroundStyle(LifecoreTheme.inkPrimary)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(LifecoreTheme.paperWell)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func rateLimitedCard(messageUk: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(LifecoreTheme.statusWarning)
                Text("Ліміт запитів")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LifecoreTheme.inkPrimary)
            }

            Text(messageUk)
                .font(.system(size: 12))
                .foregroundStyle(LifecoreTheme.inkSecondary)

            Button("Спробувати пізніше") {
                Task { await viewModel.generateDebrief() }
            }
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(LifecoreTheme.paperWell)
            .foregroundStyle(LifecoreTheme.inkPrimary)
            .clipShape(Capsule())
        }
        .padding(12)
        .background(LifecoreTheme.paperWell)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func staleNotice(reasonUk: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.badge.exclamationmark")
                .foregroundStyle(LifecoreTheme.statusWarning)
            Text("Звіт збережено раніше (\(reasonUk))")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(LifecoreTheme.inkSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(LifecoreTheme.statusWarning.opacity(0.10))
        .clipShape(Capsule())
    }

    private func failedWithPreservedNotice(messageUk: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(LifecoreTheme.statusWarning)
            Text("Не вдалося оновити звіт, відображено збережену версію")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(LifecoreTheme.inkSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(LifecoreTheme.statusWarning.opacity(0.10))
        .clipShape(Capsule())
    }

    private func failedCard(messageUk: String) -> some View {
        VStack(spacing: 10) {
            Text(messageUk)
                .font(.system(size: 12))
                .foregroundStyle(LifecoreTheme.statusDanger)
                .multilineTextAlignment(.center)

            Button(action: {
                Task { await viewModel.generateDebrief() }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Повторити спробу")
                }
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(LifecoreTheme.accentPrimary)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Section View Block

    private func sectionBlock(icon: String, title: String, content: String, iconColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(LifecoreTheme.inkPrimary)
            }

            Text(content)
                .font(.system(size: 13))
                .foregroundStyle(LifecoreTheme.inkPrimary)
                .lineSpacing(3)
        }
    }

    private func colorForTone(_ tone: String) -> Color {
        switch tone {
        case "optimal": return LifecoreTheme.statusOptimal
        case "teal": return LifecoreTheme.accentTeal
        case "warning": return LifecoreTheme.statusWarning
        case "danger": return LifecoreTheme.statusDanger
        default: return LifecoreTheme.inkTertiary
        }
    }
}
