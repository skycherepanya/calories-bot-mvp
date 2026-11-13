import Combine
import Foundation
import SwiftData
import SwiftUI

// MARK: - Coach Report State

/// Explicit lifecycle states for workout debrief generation.
public enum CoachReportState: Equatable, Sendable {
    case idle
    case generating
    case unavailableProvider(messageUk: String)
    case rateLimited(messageUk: String)
    case staleReport(StructuredWorkoutDebrief, reasonUk: String)
    case completed(StructuredWorkoutDebrief, isOfflineFallback: Bool)
    case failed(messageUk: String, preservedDraftReport: StructuredWorkoutDebrief?)

    public var debrief: StructuredWorkoutDebrief? {
        switch self {
        case .completed(let debrief, _):
            return debrief
        case .staleReport(let debrief, _):
            return debrief
        case .failed(_, let preserved):
            return preserved
        case .idle, .generating, .unavailableProvider, .rateLimited:
            return nil
        }
    }

    public var isGenerating: Bool {
        if case .generating = self { return true }
        return false
    }
}

// MARK: - Scoped Coach Evidence Item

/// User-facing, scoped evidence record explaining what data was analyzed by the coach.
public struct CoachEvidenceItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let domainUk: String
    public let sourceUk: String
    public let windowUk: String
    public let coverageUk: String
    public let statusTone: MetricStatusTone
    public let pills: [MetricEvidencePill]
    public let isAvailable: Bool

    public init(
        id: String,
        domainUk: String,
        sourceUk: String,
        windowUk: String,
        coverageUk: String,
        statusTone: MetricStatusTone = .neutral,
        pills: [MetricEvidencePill] = [],
        isAvailable: Bool = true
    ) {
        self.id = id
        self.domainUk = domainUk
        self.sourceUk = sourceUk
        self.windowUk = windowUk
        self.coverageUk = coverageUk
        self.statusTone = statusTone
        self.pills = pills
        self.isAvailable = isAvailable
    }
}

// MARK: - Coach Chat Message

/// Chronologically ordered chat message with monotonic turn index.
public struct CoachChatMessage: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let turnId: Int
    public let sender: String // "user" or "assistant"
    public let text: String
    public let turnResponse: AnalystChatTurnResponse?
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        turnId: Int,
        sender: String,
        text: String,
        turnResponse: AnalystChatTurnResponse? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.turnId = turnId
        self.sender = sender
        self.text = text
        self.turnResponse = turnResponse
        self.timestamp = timestamp
    }

    public var asAnalystMessage: AnalystChatMessage {
        AnalystChatMessage(
            id: id,
            sender: sender,
            text: text,
            turnResponse: turnResponse,
            timestamp: timestamp
        )
    }
}

// MARK: - Coach Chat AI Provider Protocol

/// Extended AIProvider interface supporting conversational sports analyst turns.
public protocol CoachChatAIProvider: AIProvider {
    func sendAnalystChatMessage(
        userQuery: String,
        history: [AnalystChatMessage],
        dossier: AssembledHealthDossier
    ) async throws -> AnalystChatTurnResponse
}

// MARK: - Default Provider Conformances

extension MockAIProvider: CoachChatAIProvider {
    public func sendAnalystChatMessage(
        userQuery: String,
        history: [AnalystChatMessage],
        dossier: AssembledHealthDossier
    ) async throws -> AnalystChatTurnResponse {
        AnalystChatTurnResponse(
            answerHeadlineUk: "Аналіз тренування (fixture)",
            answerBodyUk: "Відповідь тренера на запитання «\(userQuery)» у тестовому режимі.",
            citedMetrics: [],
            actionableTakeawayUk: "Продовжуй дотримуватись плану відновлення.",
            suggestedFollowUpsUk: [],
            extractedMemoryFactUk: nil,
            extractedMemoryCategory: nil,
            isOfflineFallback: true
        )
    }
}

extension LiveAIProvider: CoachChatAIProvider {
    public func sendAnalystChatMessage(
        userQuery: String,
        history: [AnalystChatMessage],
        dossier: AssembledHealthDossier
    ) async throws -> AnalystChatTurnResponse {
        try await GeminiService.shared.sendAnalystChatMessage(
            userQuery: userQuery,
            history: history,
            dossier: dossier
        )
    }
}

// MARK: - CoachEvidenceBuilder Extension

extension CoachEvidenceBuilder {

    /// Produces a human-readable, domain-scoped evidence breakdown for UI presentation.
    public static func buildEvidenceItems(from dossier: AssembledHealthDossier) -> [CoachEvidenceItem] {
        var items: [CoachEvidenceItem] = []

        // 1. Workout Telemetry
        if let w = dossier.workoutAnalysis {
            var pills: [MetricEvidencePill] = []
            pills.append(MetricEvidencePill(labelUk: "Дистанція", valueUk: String(format: "%.1f км", w.distanceKm), tone: "teal"))
            pills.append(MetricEvidencePill(labelUk: "Темп", valueUk: w.formattedAvgPace, tone: "neutral"))
            if let hr = w.avgHeartRate {
                pills.append(MetricEvidencePill(labelUk: "Сер. ЧСС", valueUk: "\(Int(hr)) bpm", tone: "warning"))
            }
            if let ef = w.efficiencyFactor {
                pills.append(MetricEvidencePill(labelUk: "EF", valueUk: String(format: "%.2f", ef), tone: "teal"))
            }
            if let drift = w.aerobicDecouplingPct {
                pills.append(MetricEvidencePill(labelUk: "Дрейф ЧСС", valueUk: String(format: "%.1f%%", drift), tone: drift > 5.0 ? "warning" : "optimal"))
            }

            let coverage = "\(w.splits.count) сплітів, \(String(format: "%.1f", w.distanceKm)) км, \(w.laps.count) відрізків"
            items.append(CoachEvidenceItem(
                id: "workout_telemetry",
                domainUk: "Тренування",
                sourceUk: "Apple Health (Тренування)",
                windowUk: "Сьогоднішня сесія",
                coverageUk: coverage,
                statusTone: .optimal,
                pills: pills,
                isAvailable: true
            ))
        } else {
            items.append(CoachEvidenceItem(
                id: "workout_telemetry",
                domainUk: "Тренування",
                sourceUk: "Apple Health (Тренування)",
                windowUk: "Сесія не обрана",
                coverageUk: "Дані тренування відсутні",
                statusTone: .neutral,
                pills: [],
                isAvailable: false
            ))
        }

        // 2. Scoped Nutrition
        let nut = dossier.acuteNutrition
        if nut.loggedMealsCount > 0 {
            var pills: [MetricEvidencePill] = []
            pills.append(MetricEvidencePill(labelUk: "Калорії", valueUk: "\(Int(nut.last24hKcal)) ккал", tone: "neutral"))
            pills.append(MetricEvidencePill(labelUk: "Вуглеводи", valueUk: "\(Int(nut.last24hCarbsG))г", tone: "teal"))
            pills.append(MetricEvidencePill(labelUk: "Білки", valueUk: "\(Int(nut.last24hProteinG))г", tone: "neutral"))
            pills.append(MetricEvidencePill(labelUk: "Жири", valueUk: "\(Int(nut.last24hFatG))г", tone: "neutral"))

            let coverage = "\(nut.loggedMealsCount) прийомів їжі, \(Int(nut.last24hCarbsG))г вуглеводів, \(nut.wholeFoodRatioPct)% цільної їжі"
            items.append(CoachEvidenceItem(
                id: "scoped_nutrition",
                domainUk: "Харчування",
                sourceUk: "Журнал Lifecore",
                windowUk: nut.windowLabelUk,
                coverageUk: coverage,
                statusTone: .optimal,
                pills: pills,
                isAvailable: true
            ))
        } else {
            items.append(CoachEvidenceItem(
                id: "scoped_nutrition",
                domainUk: "Харчування",
                sourceUk: "Журнал Lifecore",
                windowUk: nut.windowLabelUk,
                coverageUk: "0 записів за вікно спостереження",
                statusTone: .neutral,
                pills: [],
                isAvailable: false
            ))
        }

        // 3. Overnight Vitals & Recovery
        if let rec = dossier.recoveryContext {
            var pills: [MetricEvidencePill] = []
            if let hrv = rec.morningHrvMs {
                pills.append(MetricEvidencePill(labelUk: "HRV", valueUk: "\(Int(hrv)) мс", tone: "teal"))
            }
            if let rhr = rec.morningRhrBpm {
                pills.append(MetricEvidencePill(labelUk: "RHR", valueUk: "\(Int(rhr)) bpm", tone: "neutral"))
            }
            if let sleep = rec.lastNightSleepHours {
                pills.append(MetricEvidencePill(labelUk: "Сон", valueUk: String(format: "%.1f год", sleep), tone: "teal"))
            }
            if let acwr = rec.acwrRatio {
                pills.append(MetricEvidencePill(labelUk: "ACWR", valueUk: String(format: "%.2f", acwr), tone: acwr > 1.5 ? "danger" : "optimal"))
            }

            var parts: [String] = []
            if let hrv = rec.morningHrvMs { parts.append("HRV \(Int(hrv)) мс") }
            if let rhr = rec.morningRhrBpm { parts.append("RHR \(Int(rhr)) bpm") }
            if let s = rec.lastNightSleepHours { parts.append("Сон \(String(format: "%.1f", s))г") }
            let coverage = parts.isEmpty ? "Часткові показники відновлення" : parts.joined(separator: ", ")

            items.append(CoachEvidenceItem(
                id: "overnight_vitals",
                domainUk: "Нічні показники (Vitals)",
                sourceUk: "Apple Health (Vitals)",
                windowUk: "Минула ніч",
                coverageUk: coverage,
                statusTone: .optimal,
                pills: pills,
                isAvailable: true
            ))
        } else {
            items.append(CoachEvidenceItem(
                id: "overnight_vitals",
                domainUk: "Нічні показники (Vitals)",
                sourceUk: "Apple Health (Vitals)",
                windowUk: "Минула ніч",
                coverageUk: "Нічні показники не зафіксовано",
                statusTone: .neutral,
                pills: [],
                isAvailable: false
            ))
        }

        // 4. Episodic Memory
        let memories = dossier.retrievedMemories
        if !memories.isEmpty {
            let coverage = "\(memories.count) збережених фактів про цілі та контекст атлета"
            items.append(CoachEvidenceItem(
                id: "athlete_memory",
                domainUk: "Пам'ять атлета",
                sourceUk: "Локальна пам'ять Lifecore",
                windowUk: "Довготривала історія",
                coverageUk: coverage,
                statusTone: .optimal,
                pills: [],
                isAvailable: true
            ))
        } else {
            items.append(CoachEvidenceItem(
                id: "athlete_memory",
                domainUk: "Пам'ять атлета",
                sourceUk: "Локальна пам'ять Lifecore",
                windowUk: "Довготривала історія",
                coverageUk: "Немає підтверджених особистих фактів",
                statusTone: .neutral,
                pills: [],
                isAvailable: false
            ))
        }

        return items
    }
}

// MARK: - CoachViewModel

@MainActor
public final class CoachViewModel: ObservableObject {

    // MARK: - Published State

    @Published public var draftText: String = ""
    @Published public private(set) var isSubmitting: Bool = false
    @Published public private(set) var messages: [CoachChatMessage] = []
    @Published public private(set) var reportState: CoachReportState = .idle
    @Published public private(set) var evidenceItems: [CoachEvidenceItem] = []
    @Published public private(set) var candidateMemories: [AthleteMemoryEntity] = []
    @Published public private(set) var confirmedMemories: [AthleteMemoryEntity] = []
    @Published public private(set) var lastErrorMessageUk: String? = nil

    // MARK: - Injected Dependencies

    public let aiProvider: any AIProvider
    public let modelContext: ModelContext
    public private(set) var dossier: AssembledHealthDossier
    public let workoutUUID: UUID?

    private var turnSequence: Int = 0

    // MARK: - Initializer

    public init(
        aiProvider: any AIProvider = AppEnvironment.current.aiProvider,
        modelContext: ModelContext? = nil,
        dossier: AssembledHealthDossier? = nil,
        workoutUUID: UUID? = nil
    ) {
        self.aiProvider = aiProvider
        self.modelContext = modelContext ?? ModelContext(AppEnvironment.current.modelContainer)
        let resolvedDossier = dossier ?? AssembledHealthDossier()
        self.dossier = resolvedDossier
        self.workoutUUID = workoutUUID
        self.evidenceItems = CoachEvidenceBuilder.buildEvidenceItems(from: resolvedDossier)
        refreshMemories()
        if workoutUUID != nil {
            loadCachedReport()
        }
    }

    // MARK: - Dossier & Evidence Management

    public func updateDossier(_ newDossier: AssembledHealthDossier) {
        self.dossier = newDossier
        self.evidenceItems = CoachEvidenceBuilder.buildEvidenceItems(from: newDossier)
    }

    public func refreshEvidence() {
        self.evidenceItems = CoachEvidenceBuilder.buildEvidenceItems(from: dossier)
    }

    public func evidenceItem(for id: String) -> CoachEvidenceItem? {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return evidenceItems.first(where: { $0.id == trimmed })
    }

    // MARK: - Chat Submission

    public func submit(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Guard against duplicate concurrent calls while a request is in flight
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        lastErrorMessageUk = nil
        turnSequence += 1
        let currentTurnId = turnSequence

        let userMsg = CoachChatMessage(
            turnId: currentTurnId,
            sender: "user",
            text: trimmed
        )
        let priorMessages = messages
        messages.append(userMsg)
        sortMessagesChronologically()

        // Tentatively preserve draft input
        let priorDraft = draftText
        draftText = ""

        do {
            let historyForAI = messages.map(\.asAnalystMessage)
            let response: AnalystChatTurnResponse
            if let chatAI = aiProvider as? any CoachChatAIProvider {
                response = try await chatAI.sendAnalystChatMessage(
                    userQuery: trimmed,
                    history: historyForAI,
                    dossier: dossier
                )
            } else {
                response = try await GeminiService.shared.sendAnalystChatMessage(
                    userQuery: trimmed,
                    history: historyForAI,
                    dossier: dossier
                )
            }

            let assistantMsg = CoachChatMessage(
                turnId: currentTurnId,
                sender: "assistant",
                text: response.answerBodyUk,
                turnResponse: response
            )
            messages.append(assistantMsg)
            sortMessagesChronologically()

            // AI-extracted memory is stored strictly as a candidate requiring explicit manual user review
            if let fact = response.extractedMemoryFactUk, !fact.isEmpty {
                AthleteMemoryStorageService.saveCandidateFact(
                    factTextUk: fact,
                    category: response.extractedMemoryCategory ?? "workout_feel",
                    tags: ["chat", "candidate"],
                    in: modelContext
                )
                refreshMemories()
            }
        } catch {
            // Failure: retain prior successful turns and restore draftText so user can retry
            messages = priorMessages
            draftText = trimmed.isEmpty ? priorDraft : trimmed
            lastErrorMessageUk = "Не вдалося отримати відповідь тренера: \(error.localizedDescription)"
        }
    }

    private func sortMessagesChronologically() {
        messages.sort { a, b in
            if a.turnId != b.turnId {
                return a.turnId < b.turnId
            }
            if a.sender == "user" && b.sender != "user" {
                return true
            }
            if a.sender != "user" && b.sender == "user" {
                return false
            }
            return a.timestamp < b.timestamp
        }
    }

    // MARK: - Workout Debrief Generation & Stored Reports

    public func loadCachedReport() {
        guard let workoutUUID else { return }
        if let cached = WorkoutStorageService.fetchAnalysis(for: workoutUUID),
           let report = cached.aiCoachReport, !report.isEmpty {
            if let data = report.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(StructuredWorkoutDebrief.self, from: data) {
                self.reportState = .completed(decoded, isOfflineFallback: decoded.isOfflineFallback)
            } else {
                // Legacy text report preserved with explicit legacy provenance
                let legacy = StructuredWorkoutDebrief(
                    headlineUk: "Збережений аналіз тренування",
                    regimeBadgeUk: "Збережено",
                    regimeTone: "teal",
                    executionAnalysisUk: report,
                    benchmarkComparisonUk: "",
                    rootCauseAndDirectiveUk: "",
                    evidencePills: [],
                    followUpQuestionsUk: [],
                    isOfflineFallback: true
                )
                self.reportState = .completed(legacy, isOfflineFallback: true)
            }
        }
    }

    public func generateDebrief(forceRefresh: Bool = false) async {
        let preserved = reportState.debrief
        reportState = .generating

        do {
            // Missing API key in live mode maps directly to .unavailableProvider without synthetic fallback
            if !aiProvider.isMock && (GeminiService.shared.currentApiKey == nil || GeminiService.shared.currentApiKey?.isEmpty == true) {
                let msg = "Gemini API ключ не налаштовано. Додайте ключ у Налаштуваннях."
                reportState = .unavailableProvider(messageUk: msg)
                return
            }

            let result = try await aiProvider.generateDebrief(dossier: dossier)
            let validatedPills = CoachEvidenceBuilder.validateCitations(result.evidencePills, against: dossier)
            let debrief = StructuredWorkoutDebrief(
                headlineUk: result.headlineUk,
                regimeBadgeUk: result.regimeBadgeUk,
                regimeTone: result.regimeTone,
                executionAnalysisUk: result.executionAnalysisUk,
                benchmarkComparisonUk: result.benchmarkComparisonUk,
                rootCauseAndDirectiveUk: result.rootCauseAndDirectiveUk,
                evidencePills: validatedPills,
                followUpQuestionsUk: result.followUpQuestionsUk,
                isOfflineFallback: result.isOfflineFallback
            )

            self.reportState = .completed(debrief, isOfflineFallback: debrief.isOfflineFallback)

            if let workoutUUID {
                if let data = try? JSONEncoder().encode(debrief),
                   let jsonString = String(data: data, encoding: .utf8) {
                    WorkoutStorageService.updateCoachReport(for: workoutUUID, report: jsonString)
                }
            }
        } catch {
            if let geminiError = error as? GeminiError {
                switch geminiError {
                case .missingApiKey:
                    let msg = "Gemini API ключ не налаштовано. Додайте ключ у Налаштуваннях."
                    reportState = .unavailableProvider(messageUk: msg)
                    return
                case .httpError(let code, _) where code == 429:
                    let msg = "Перевищено ліміт запитів до ШІ-провайдера. Спробуйте пізніше."
                    reportState = .rateLimited(messageUk: msg)
                    return
                default:
                    break
                }
            }

            let errDesc = error.localizedDescription
            if errDesc.contains("429") || errDesc.lowercased().contains("rate") {
                let msg = "Перевищено ліміт запитів до ШІ-провайдера. Спробуйте пізніше."
                reportState = .rateLimited(messageUk: msg)
                return
            }

            let failMsg = "Не вдалося сформувати звіт тренера: \(errDesc)"
            // Never overwrite existing stored debrief with a fabricated fallback
            reportState = .failed(messageUk: failMsg, preservedDraftReport: preserved)
        }
    }

    // MARK: - Episodic Memory Management

    public func refreshMemories() {
        let facts = AthleteMemoryStorageService.fetchAllFacts(includeCandidates: true, in: modelContext)
        self.candidateMemories = facts.filter { $0.confirmationStatus == "candidate" }
        self.confirmedMemories = facts.filter { $0.confirmationStatus == "confirmed" }
    }

    public func confirmMemory(id: UUID) {
        _ = AthleteMemoryStorageService.confirmCandidateFact(id: id, in: modelContext)
        refreshMemories()
    }

    public func deleteMemory(id: UUID) {
        AthleteMemoryStorageService.deleteFact(id: id, in: modelContext)
        refreshMemories()
    }
}
