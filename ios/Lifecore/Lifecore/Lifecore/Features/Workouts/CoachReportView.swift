import SwiftUI

public struct CoachReportView: View {
    public let analysis: WorkoutAnalysisResult
    public let recoveryContext: RecentRecoveryContext?
    public let assembledDossier: AssembledHealthDossier?

    @State private var debrief: StructuredWorkoutDebrief?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showChatSheet = false
    @State private var selectedQuestionForChat: String? = nil

    public init(
        analysis: WorkoutAnalysisResult,
        recoveryContext: RecentRecoveryContext? = nil,
        assembledDossier: AssembledHealthDossier? = nil
    ) {
        self.analysis = analysis
        self.recoveryContext = recoveryContext
        self.assembledDossier = assembledDossier
    }

    private var activeDossier: AssembledHealthDossier {
        if let d = assembledDossier { return d }
        let meals = MealStorageService.fetchTodayMeals()
        return LifecoreContextRAG.assembleDossier(
            workoutAnalysis: analysis,
            recoveryContext: recoveryContext,
            meals: meals
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: Lifecore Intelligence + RAG Badge
            HStack {
                Label("Lifecore Intelligence", systemImage: "sparkles")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(LifecoreTheme.accentPrimary)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 10, weight: .semibold))
                    Text("3 рівні RAG")
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(LifecoreTheme.accentPrimary.opacity(0.12))
                .foregroundStyle(LifecoreTheme.accentPrimary)
                .clipShape(Capsule())
            }

            if let d = debrief {
                // Headline & Regime Badge
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top) {
                        Text(d.headlineUk)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(LifecoreTheme.inkPrimary)
                            .lineSpacing(2)

                        Spacer()

                        Text(d.regimeBadgeUk)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(colorForTone(d.regimeTone).opacity(0.12))
                            .foregroundStyle(colorForTone(d.regimeTone))
                            .clipShape(Capsule())
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

                LifecoreHairlineDivider()

                // Section 1: 70% Execution
                sectionBlock(
                    icon: "figure.run",
                    title: "Виконання та розкладка сил",
                    content: d.executionAnalysisUk,
                    iconColor: LifecoreTheme.accentTeal
                )

                LifecoreHairlineDivider()

                // Section 2: 15% Benchmark Dynamics
                sectionBlock(
                    icon: "arrow.left.arrow.right",
                    title: "Динаміка форми та режим зусиль",
                    content: d.benchmarkComparisonUk,
                    iconColor: LifecoreTheme.accentIndigo
                )

                LifecoreHairlineDivider()

                // Section 3: 15% Root Cause & 24h Directive
                sectionBlock(
                    icon: "target",
                    title: "Фізіологічні причини та план на 24г",
                    content: d.rootCauseAndDirectiveUk,
                    iconColor: LifecoreTheme.statusOptimal
                )

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
                            Text("Запитати Lifecore Intelligence")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(LifecoreTheme.accentPrimary)
                        .foregroundStyle(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        Task { await generateReport() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(LifecoreTheme.inkSecondary)
                            .padding(10)
                            .background(LifecoreTheme.paperWell)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                }
                .padding(.top, 4)

            } else {
                // Initial CTA Card before debrief generation
                VStack(spacing: 12) {
                    Text("Багаторівневий спортивний розбір на основі сплітів, вчорашніх вуглеводів, нічних Vitals та епізодичної пам'яті атлета.")
                        .font(.system(size: 12))
                        .foregroundStyle(LifecoreTheme.inkSecondary)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)

                    if let err = errorMessage {
                        Text(err)
                            .font(.system(size: 11))
                            .foregroundStyle(LifecoreTheme.statusDanger)
                    }

                    Button(action: {
                        Task { await generateReport() }
                    }) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                                Text("Аналізую досьє атлета...")
                                    .fontWeight(.semibold)
                            } else {
                                Image(systemName: "brain.head.profile")
                                Text("Отримати розбір тренера")
                                    .fontWeight(.semibold)
                            }
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(LifecoreTheme.accentPrimary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                }
            }
        }
        .lifecoreGlassCard(cornerRadius: 20)
        .sheet(isPresented: $showChatSheet) {
            LifecoreIntelligenceChatView(
                dossier: activeDossier,
                initialQuestion: selectedQuestionForChat
            )
        }
        .task {
            loadCachedReport()
        }
    }

    // MARK: - Section View

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

    // MARK: - Actions

    private func loadCachedReport() {
        if let cached = WorkoutStorageService.fetchAnalysis(for: analysis.workoutUUID),
           let report = cached.aiCoachReport, !report.isEmpty {
            if let data = report.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(StructuredWorkoutDebrief.self, from: data) {
                self.debrief = decoded
            } else {
                // If legacy text report was stored, construct structured offline fallback
                self.debrief = GeminiService.shared.generateStructuredWorkoutDebriefOffline(dossier: activeDossier)
            }
        }
    }

    private func generateReport() async {
        isLoading = true
        errorMessage = nil

        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.prepare()

        do {
            let result = try await GeminiService.shared.generateStructuredCoachDebrief(
                dossier: activeDossier
            )
            self.debrief = result
            impact.impactOccurred()

            // Persist encoded structured JSON
            if let data = try? JSONEncoder().encode(result),
               let jsonString = String(data: data, encoding: .utf8) {
                WorkoutStorageService.updateCoachReport(for: analysis.workoutUUID, report: jsonString)
            }
        } catch {
            let fallback = GeminiService.shared.generateStructuredWorkoutDebriefOffline(
                dossier: activeDossier
            )
            self.debrief = fallback
            impact.impactOccurred()

            if let data = try? JSONEncoder().encode(fallback),
               let jsonString = String(data: data, encoding: .utf8) {
                WorkoutStorageService.updateCoachReport(for: analysis.workoutUUID, report: jsonString)
            }
        }

        isLoading = false
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
