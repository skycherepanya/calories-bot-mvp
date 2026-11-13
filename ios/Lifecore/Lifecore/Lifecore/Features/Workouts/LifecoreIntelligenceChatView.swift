import SwiftUI

public struct LifecoreIntelligenceChatView: View {
    public let dossier: AssembledHealthDossier
    public let initialQuestion: String?

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isInputFocused: Bool
    @StateObject private var viewModel: CoachViewModel

    @State private var showMemorySheet: Bool = false
    @State private var showEvidenceSheet: Bool = false

    public init(
        dossier: AssembledHealthDossier,
        initialQuestion: String? = nil,
        viewModel: CoachViewModel? = nil
    ) {
        self.dossier = dossier
        self.initialQuestion = initialQuestion
        if let injected = viewModel {
            _viewModel = StateObject(wrappedValue: injected)
        } else {
            _viewModel = StateObject(wrappedValue: CoachViewModel(dossier: dossier))
        }
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top Evidence Context Indicator Bar
                evidenceContextBar

                // Chat Messages Feed
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            welcomeCard

                            ForEach(viewModel.messages) { msg in
                                if msg.sender == "user" {
                                    userBubble(msg)
                                } else {
                                    assistantCard(msg)
                                }
                            }

                            if viewModel.isSubmitting {
                                loadingBubble
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .scrollBounceBehavior(.always)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isInputFocused {
                            isInputFocused = false
                            hideKeyboard()
                        }
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        if let lastId = viewModel.messages.last?.id {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }

                // Contextual Suggestion Chips (from last assistant message)
                if let lastSuggestions = viewModel.messages.last(where: { $0.sender == "assistant" })?.turnResponse?.suggestedFollowUpsUk,
                   !lastSuggestions.isEmpty && !viewModel.isSubmitting {
                    suggestionChips(lastSuggestions)
                }

                if let errorUk = viewModel.lastErrorMessageUk, !errorUk.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(LifecoreTheme.statusDanger)
                        Text(errorUk)
                            .font(.system(size: 12))
                            .foregroundStyle(LifecoreTheme.statusDanger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(LifecoreTheme.statusDanger.opacity(0.08))
                    .accessibilityIdentifier("coach_chat_error_banner")
                }

                LifecoreHairlineDivider()

                // Message Input Bar
                inputBar
            }
            .background(LifecoreTheme.paperCanvas.ignoresSafeArea())
            .navigationTitle("Тренер Lifecore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 12) {
                        Button(action: {
                            showMemorySheet = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "brain.head.profile")
                                Text("Пам'ять (\(viewModel.confirmedMemories.count))")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(LifecoreTheme.inkSecondary)
                        }
                        .accessibilityIdentifier("btn_open_memory_review")

                        Button(action: {
                            showEvidenceSheet = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.shield")
                                Text("Докази")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(LifecoreTheme.inkSecondary)
                        }
                        .accessibilityIdentifier("btn_open_evidence_sheet")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(LifecoreTheme.accentPrimary)
                    .accessibilityIdentifier("btn_close_chat")
                }
            }
            .sheet(isPresented: $showMemorySheet) {
                NavigationStack {
                    MemoryReviewView(viewModel: viewModel)
                }
            }
            .sheet(isPresented: $showEvidenceSheet) {
                NavigationStack {
                    CoachEvidenceView(viewModel: viewModel)
                }
            }
            .task {
                viewModel.refreshMemories()
                if viewModel.messages.isEmpty {
                    if let initQ = initialQuestion, !initQ.isEmpty {
                        await viewModel.submit(initQ)
                    }
                }
            }
        }
        .lifecoreKeyboardDismissToolbar()
    }

    // MARK: - Evidence Context Bar

    private var evidenceContextBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                contextPill(
                    icon: "figure.run",
                    title: dossier.workoutAnalysis != nil ? "\(String(format: "%.1f", dossier.workoutAnalysis!.distanceKm)) км" : "Сесія",
                    color: LifecoreTheme.accentTeal
                )

                if dossier.acuteNutrition.loggedMealsCount > 0 && dossier.acuteNutrition.last24hCarbsG > 0 {
                    let carbs = Int(dossier.acuteNutrition.last24hCarbsG)
                    contextPill(
                        icon: "fork.knife",
                        title: "\(carbs)г вуглеводів",
                        color: LifecoreTheme.statusOptimal
                    )
                } else if dossier.acuteNutrition.loggedMealsCount == 0 {
                    contextPill(
                        icon: "fork.knife",
                        title: "Раціон не записано",
                        color: LifecoreTheme.inkTertiary
                    )
                }

                if let rhr = dossier.recoveryContext?.morningRhrBpm {
                    contextPill(
                        icon: "heart.fill",
                        title: "\(Int(rhr)) bpm RHR",
                        color: LifecoreTheme.statusDanger
                    )
                }

                contextPill(
                    icon: "brain.head.profile",
                    title: "\(viewModel.confirmedMemories.count) фактів пам'яті",
                    color: LifecoreTheme.accentIndigo
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(LifecoreTheme.paperWell)
    }

    private func contextPill(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(LifecoreTheme.inkPrimary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(LifecoreTheme.paperCard)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(LifecoreTheme.ruleHairline, lineWidth: 1))
    }

    // MARK: - Feed Cards

    private var welcomeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LifecoreTheme.accentPrimary)
                Text("Спортивний аналітик Lifecore")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LifecoreTheme.inkPrimary)
            }

            Text("Я аналізую всю картину твого стану: спліти тренування, кардіо-динаміку, харчування, нічні Vitals та твої підтверджені цілі. Запитай мене будь-що про сьогоднішню сесію чи відновлення.")
                .font(.system(size: 12))
                .foregroundStyle(LifecoreTheme.inkSecondary)
                .lineSpacing(3)
        }
        .lifecoreGlassCard(cornerRadius: 16, padding: 14)
    }

    private func userBubble(_ msg: CoachChatMessage) -> some View {
        HStack {
            Spacer(minLength: 40)
            Text(msg.text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(LifecoreTheme.inkPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .id(msg.id)
    }

    private func assistantCard(_ msg: CoachChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let resp = msg.turnResponse {
                // Headline
                Text(resp.answerHeadlineUk)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(LifecoreTheme.inkPrimary)

                // Cited metrics pills
                if !resp.citedMetrics.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(resp.citedMetrics) { pill in
                                HStack(spacing: 4) {
                                    Text(pill.labelUk)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(LifecoreTheme.inkTertiary)
                                    Text(pill.valueUk)
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundStyle(colorForTone(pill.tone))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(LifecoreTheme.paperWell)
                                .clipShape(Capsule())
                            }
                        }
                    }
                }

                // Answer Body
                Text(resp.answerBodyUk)
                    .font(.system(size: 13))
                    .foregroundStyle(LifecoreTheme.inkPrimary)
                    .lineSpacing(3)

                // Actionable Takeaway Box
                if let takeaway = resp.actionableTakeawayUk, !takeaway.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LifecoreTheme.statusOptimal)
                            .padding(.top, 2)
                        Text(takeaway)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(LifecoreTheme.inkPrimary)
                            .lineSpacing(2)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LifecoreTheme.paperWell)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                // Candidate memory banner
                if let memory = resp.extractedMemoryFactUk, !memory.isEmpty {
                    Button(action: {
                        showMemorySheet = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Збережено кандидата в пам'ять: «\(memory)»")
                                .font(.system(size: 10, weight: .medium))
                            Spacer()
                            Text("Перевірити")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(LifecoreTheme.accentIndigo)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(LifecoreTheme.accentIndigo.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text(msg.text)
                    .font(.system(size: 13))
                    .foregroundStyle(LifecoreTheme.inkPrimary)
            }
        }
        .lifecoreGlassCard(cornerRadius: 18, padding: 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .id(msg.id)
    }

    private var loadingBubble: some View {
        HStack(spacing: 8) {
            ProgressView()
                .tint(LifecoreTheme.accentPrimary)
            Text("Аналізую досьє атлета...")
                .font(.system(size: 12))
                .foregroundStyle(LifecoreTheme.inkSecondary)
        }
        .padding(12)
        .lifecoreGlassCard(cornerRadius: 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func suggestionChips(_ suggestions: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { question in
                    Button(action: {
                        isInputFocused = false
                        hideKeyboard()
                        Task { await viewModel.submit(question) }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 10))
                            Text(question)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(LifecoreTheme.paperCard)
                        .foregroundStyle(LifecoreTheme.inkPrimary)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(LifecoreTheme.ruleHairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Запитай про пульс, спліти чи їжу...", text: $viewModel.draftText)
                .focused($isInputFocused)
                .font(.system(size: 14))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(LifecoreTheme.paperWell)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .submitLabel(.send)
                .onSubmit {
                    handleSubmitCurrentInput()
                }

            if !viewModel.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button(action: {
                    handleSubmitCurrentInput()
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(LifecoreTheme.accentPrimary)
                }
                .disabled(viewModel.isSubmitting)
                .accessibilityIdentifier("btn_send_chat_message")
            } else if isInputFocused {
                Button(action: {
                    isInputFocused = false
                    hideKeyboard()
                }) {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(LifecoreTheme.inkSecondary)
                        .frame(width: 32, height: 32)
                        .background(LifecoreTheme.paperWell)
                        .clipShape(Circle())
                }
                .accessibilityIdentifier("btn_hide_chat_keyboard")
            } else {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(LifecoreTheme.inkTertiary.opacity(0.35))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(LifecoreTheme.paperCard.ignoresSafeArea(edges: .bottom))
    }

    private func handleSubmitCurrentInput() {
        let trimmed = viewModel.draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.draftText = ""
        isInputFocused = false
        hideKeyboard()
        Task { await viewModel.submit(trimmed) }
    }

    private func colorForTone(_ tone: String) -> Color {
        switch tone {
        case "optimal": return LifecoreTheme.statusOptimal
        case "teal": return LifecoreTheme.accentTeal
        case "warning": return LifecoreTheme.statusWarning
        case "danger": return LifecoreTheme.statusDanger
        default: return LifecoreTheme.inkPrimary
        }
    }
}
