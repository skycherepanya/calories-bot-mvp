import SwiftUI

public struct LifecoreIntelligenceChatView: View {
    public let dossier: AssembledHealthDossier
    public let initialQuestion: String?

    @Environment(\.dismiss) private var dismiss
    @State private var messages: [AnalystChatMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var showMemoryBank: Bool = false
    @State private var storedFacts: [AthleteMemoryEntity] = []

    public init(dossier: AssembledHealthDossier, initialQuestion: String? = nil) {
        self.dossier = dossier
        self.initialQuestion = initialQuestion
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top RAG Active Context Indicator Bar
                ragContextBar

                // Expandable Memory Drawer (if toggled)
                if showMemoryBank {
                    memoryBankDrawer
                }

                // Chat Messages Feed
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // Welcome message
                            welcomeCard

                            ForEach(messages) { msg in
                                if msg.sender == "user" {
                                    userBubble(msg)
                                } else {
                                    assistantCard(msg)
                                }
                            }

                            if isLoading {
                                loadingBubble
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let lastId = messages.last?.id {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }

                // Contextual Suggestion Chips (if last assistant response has suggestions)
                if let lastSuggestions = messages.last(where: { $0.sender == "assistant" })?.turnResponse?.suggestedFollowUpsUk,
                   !lastSuggestions.isEmpty && !isLoading {
                    suggestionChips(lastSuggestions)
                }

                LifecoreHairlineDivider()

                // Message Input Bar
                inputBar
            }
            .background(LifecoreTheme.paperCanvas.ignoresSafeArea())
            .navigationTitle("Lifecore Intelligence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showMemoryBank.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "brain.head.profile")
                            Text("Пам'ять")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(showMemoryBank ? LifecoreTheme.accentPrimary : LifecoreTheme.inkSecondary)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(LifecoreTheme.accentPrimary)
                }
            }
            .task {
                refreshMemoryBank()
                if messages.isEmpty {
                    if let initQ = initialQuestion, !initQ.isEmpty {
                        await sendMessage(initQ)
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private var ragContextBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                contextPill(
                    icon: "figure.run",
                    title: dossier.workoutAnalysis != nil ? "\(String(format: "%.1f", dossier.workoutAnalysis!.distanceKm)) км" : "Сесія",
                    color: LifecoreTheme.accentTeal
                )

                let carbs = Int(dossier.acuteNutrition.last24hCarbsG)
                contextPill(
                    icon: "fork.knife",
                    title: "\(carbs)г вуглеводів",
                    color: LifecoreTheme.statusOptimal
                )

                if let rhr = dossier.recoveryContext?.morningRhrBpm {
                    contextPill(
                        icon: "heart.fill",
                        title: "\(Int(rhr)) bpm RHR",
                        color: LifecoreTheme.statusDanger
                    )
                }

                contextPill(
                    icon: "brain.head.profile",
                    title: "\(storedFacts.count) фактів пам'яті",
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

    private var memoryBankDrawer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Епізодична пам'ять атлета (L3 RAG)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(LifecoreTheme.inkPrimary)
                Spacer()
                Text("\(storedFacts.count) збережено")
                    .font(.system(size: 11))
                    .foregroundStyle(LifecoreTheme.inkTertiary)
            }

            if storedFacts.isEmpty {
                Text("Lifecore ще не зберіг особистих фактів. Напиши тренеру про цілі, травми або взуття.")
                    .font(.system(size: 11))
                    .foregroundStyle(LifecoreTheme.inkSecondary)
            } else {
                ForEach(storedFacts) { fact in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: fact.isPinnedGoal ? "star.fill" : "circle.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(fact.isPinnedGoal ? LifecoreTheme.statusWarning : LifecoreTheme.accentPrimary)
                            .padding(.top, 4)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(fact.factTextUk)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(LifecoreTheme.inkPrimary)
                            Text(fact.category)
                                .font(.system(size: 9))
                                .foregroundStyle(LifecoreTheme.inkTertiary)
                        }

                        Spacer()

                        Button(action: {
                            AthleteMemoryStorageService.deleteFact(id: fact.id)
                            refreshMemoryBank()
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                                .foregroundStyle(LifecoreTheme.inkTertiary)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .padding(12)
        .background(LifecoreTheme.paperWell)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(LifecoreTheme.ruleHairline), alignment: .bottom)
    }

    private var welcomeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LifecoreTheme.accentPrimary)
                Text("Багаторівневий спортивний аналітик")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LifecoreTheme.inkPrimary)
            }

            Text("Я володію повною картиною твого стану: сплити сьогоднішньої сесії, вчорашні вуглеводи й натрій, нічні Vitals, Body Battery та твої особисті цілі. Запитай мене будь-що про тренування чи самопочуття.")
                .font(.system(size: 12))
                .foregroundStyle(LifecoreTheme.inkSecondary)
                .lineSpacing(3)
        }
        .lifecoreGlassCard(cornerRadius: 16, padding: 14)
    }

    private func userBubble(_ msg: AnalystChatMessage) -> some View {
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

    private func assistantCard(_ msg: AnalystChatMessage) -> some View {
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

                // Memory Saved Badge (if extracted)
                if let memory = resp.extractedMemoryFactUk, !memory.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Збережено в пам'ять: «\(memory)»")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(LifecoreTheme.accentIndigo)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(LifecoreTheme.accentIndigo.opacity(0.10))
                    .clipShape(Capsule())
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
                        Task { await sendMessage(question) }
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

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Запитай про пульс, спліти чи їжу...", text: $inputText)
                .font(.system(size: 14))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(LifecoreTheme.paperWell)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .submitLabel(.send)
                .onSubmit {
                    guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    let query = inputText
                    inputText = ""
                    Task { await sendMessage(query) }
                }

            Button(action: {
                let query = inputText
                inputText = ""
                Task { await sendMessage(query) }
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? LifecoreTheme.inkTertiary : LifecoreTheme.accentPrimary)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(LifecoreTheme.paperCard)
    }

    // MARK: - Actions

    private func refreshMemoryBank() {
        storedFacts = AthleteMemoryStorageService.fetchAllFacts()
    }

    private func sendMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let userMsg = AnalystChatMessage(sender: "user", text: trimmed)
        messages.append(userMsg)
        isLoading = true

        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.prepare()

        do {
            let response = try await GeminiService.shared.sendAnalystChatMessage(
                userQuery: trimmed,
                history: messages,
                dossier: dossier
            )
            impact.impactOccurred()

            let assistantMsg = AnalystChatMessage(
                sender: "assistant",
                text: response.answerBodyUk,
                turnResponse: response
            )
            messages.append(assistantMsg)

            // Save extracted memory fact if detected
            if let fact = response.extractedMemoryFactUk, !fact.isEmpty {
                AthleteMemoryStorageService.saveFact(
                    factTextUk: fact,
                    category: response.extractedMemoryCategory ?? "workout_feel",
                    tags: ["chat", "insight"]
                )
                refreshMemoryBank()
            }
        } catch {
            let fallback = GeminiService.shared.generateOfflineAnalystChatResponse(
                userQuery: trimmed,
                dossier: dossier
            )
            impact.impactOccurred()
            let assistantMsg = AnalystChatMessage(
                sender: "assistant",
                text: fallback.answerBodyUk,
                turnResponse: fallback
            )
            messages.append(assistantMsg)

            if let fact = fallback.extractedMemoryFactUk, !fact.isEmpty {
                AthleteMemoryStorageService.saveFact(
                    factTextUk: fact,
                    category: fallback.extractedMemoryCategory ?? "workout_feel",
                    tags: ["chat", "insight"]
                )
                refreshMemoryBank()
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
        default: return LifecoreTheme.inkPrimary
        }
    }
}
