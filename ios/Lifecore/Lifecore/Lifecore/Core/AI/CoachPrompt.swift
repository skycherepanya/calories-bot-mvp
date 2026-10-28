import Foundation

// MARK: - Structured Debrief & Chat Analyst Schemas (Lifecore v3.4)

public struct MetricEvidencePill: Codable, Sendable, Equatable, Identifiable {
    public var id: String { "\(labelUk):\(valueUk)" }
    public let labelUk: String
    public let valueUk: String
    public let tone: String // "optimal", "teal", "warning", "danger", "neutral"

    public init(labelUk: String, valueUk: String, tone: String = "neutral") {
        self.labelUk = labelUk
        self.valueUk = valueUk
        self.tone = tone
    }
}

public struct StructuredWorkoutDebrief: Codable, Sendable, Equatable {
    public let headlineUk: String
    public let regimeBadgeUk: String
    public let regimeTone: String
    public let executionAnalysisUk: String      // 70% Pacing execution, split details, drift
    public let benchmarkComparisonUk: String    // 15% Effort-normalized delta analysis
    public let rootCauseAndDirectiveUk: String  // 15% 48h nutrition & sleep causality + 24h directive
    public let evidencePills: [MetricEvidencePill]
    public let followUpQuestionsUk: [String]

    public init(
        headlineUk: String,
        regimeBadgeUk: String,
        regimeTone: String = "teal",
        executionAnalysisUk: String,
        benchmarkComparisonUk: String,
        rootCauseAndDirectiveUk: String,
        evidencePills: [MetricEvidencePill] = [],
        followUpQuestionsUk: [String] = []
    ) {
        self.headlineUk = headlineUk
        self.regimeBadgeUk = regimeBadgeUk
        self.regimeTone = regimeTone
        self.executionAnalysisUk = executionAnalysisUk
        self.benchmarkComparisonUk = benchmarkComparisonUk
        self.rootCauseAndDirectiveUk = rootCauseAndDirectiveUk
        self.evidencePills = evidencePills
        self.followUpQuestionsUk = followUpQuestionsUk
    }
}

public struct AnalystChatTurnResponse: Codable, Sendable, Equatable {
    public let answerHeadlineUk: String
    public let answerBodyUk: String
    public let citedMetrics: [MetricEvidencePill]
    public let actionableTakeawayUk: String?
    public let suggestedFollowUpsUk: [String]
    public let extractedMemoryFactUk: String?
    public let extractedMemoryCategory: String?

    public init(
        answerHeadlineUk: String,
        answerBodyUk: String,
        citedMetrics: [MetricEvidencePill] = [],
        actionableTakeawayUk: String? = nil,
        suggestedFollowUpsUk: [String] = [],
        extractedMemoryFactUk: String? = nil,
        extractedMemoryCategory: String? = nil
    ) {
        self.answerHeadlineUk = answerHeadlineUk
        self.answerBodyUk = answerBodyUk
        self.citedMetrics = citedMetrics
        self.actionableTakeawayUk = actionableTakeawayUk
        self.suggestedFollowUpsUk = suggestedFollowUpsUk
        self.extractedMemoryFactUk = extractedMemoryFactUk
        self.extractedMemoryCategory = extractedMemoryCategory
    }
}

public struct AnalystChatMessage: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let sender: String // "user" or "assistant"
    public let text: String
    public let turnResponse: AnalystChatTurnResponse?
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        sender: String,
        text: String,
        turnResponse: AnalystChatTurnResponse? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.sender = sender
        self.text = text
        self.turnResponse = turnResponse
        self.timestamp = timestamp
    }
}

// MARK: - Recent Recovery Context

public struct RecentRecoveryContext: Sendable, Codable {
    public let lastNightSleepHours: Double?
    public let lastNightDeepHours: Double?
    public let lastNightRemHours: Double?
    public let morningHrvMs: Double?
    public let baselineHrvMs: Double?
    public let morningRhrBpm: Double?
    public let baselineRhrBpm: Double?
    public let yesterdayActiveKcal: Double?
    public let recoveryScore: Int?
    public let vitalsConfluenceState: String?
    public let acwrRatio: Double?
    public let acwrZoneTitleUk: String?
    public let wristTempDeltaC: Double?
    public let topCorrelationInsightUk: String?

    public init(
        lastNightSleepHours: Double? = nil,
        lastNightDeepHours: Double? = nil,
        lastNightRemHours: Double? = nil,
        morningHrvMs: Double? = nil,
        baselineHrvMs: Double? = nil,
        morningRhrBpm: Double? = nil,
        baselineRhrBpm: Double? = nil,
        yesterdayActiveKcal: Double? = nil,
        recoveryScore: Int? = nil,
        vitalsConfluenceState: String? = nil,
        acwrRatio: Double? = nil,
        acwrZoneTitleUk: String? = nil,
        wristTempDeltaC: Double? = nil,
        topCorrelationInsightUk: String? = nil
    ) {
        self.lastNightSleepHours = lastNightSleepHours
        self.lastNightDeepHours = lastNightDeepHours
        self.lastNightRemHours = lastNightRemHours
        self.morningHrvMs = morningHrvMs
        self.baselineHrvMs = baselineHrvMs
        self.morningRhrBpm = morningRhrBpm
        self.baselineRhrBpm = baselineRhrBpm
        self.yesterdayActiveKcal = yesterdayActiveKcal
        self.recoveryScore = recoveryScore
        self.vitalsConfluenceState = vitalsConfluenceState
        self.acwrRatio = acwrRatio
        self.acwrZoneTitleUk = acwrZoneTitleUk
        self.wristTempDeltaC = wristTempDeltaC
        self.topCorrelationInsightUk = topCorrelationInsightUk
    }
}

// MARK: - Coach Prompt Builder

public enum CoachPrompt {

    /// Strict structured JSON coach debrief system prompt (No markdown headers, no emojis, pure sports intelligence)
    public static let structuredDebriefSystemPrompt: String = """
    You are Lifecore Intelligence — an elite endurance running analyst and personal sports scientist.
    Analyze the provided 3-tier health dossier (workout telemetry, 48h nutrition, overnight vitals, and episodic athlete memory) and output a strictly typed JSON object conforming to StructuredWorkoutDebrief.

    RULES:
    1. OUTPUT ONLY RAW VALID JSON: No markdown code blocks, no ```json prefixes, no trailing commentary.
    2. LANGUAGE: Natural, direct Ukrainian (звернення на «ти»). Sharp, respectful, and motivating.
    3. ZERO MARKDOWN HEADERS & ZERO EMOJIS: Do not write '###', '##', or emojis in any field. The UI renders native typography and SF Symbols.
    4. EFFORT-AWARE BENCHMARK DISCIPLINE:
       - If HR delta is significantly elevated (+10 to +30 bpm) alongside faster pace, explicitly explain that the speed was achieved by working in a higher aerobic/threshold zone, not miraculous endurance adaptation on identical effort.
       - If Efficiency Factor (EF) increased or remained steady, praise the biomechanical stability at that higher cardiac output.
    5. HOLISTIC CAUSALITY (70 / 15 / 15):
       - 70% executionAnalysisUk: Split progression (pacing by km, hills, cardiac drift).
       - 15% benchmarkComparisonUk: Effort-aware benchmark evaluation.
       - 15% rootCauseAndDirectiveUk: Tie performance to sleep architecture, resting heart rate, and nutrition ONLY IF logged. Provide ONE decisive athletic directive for the next 24h.
    6. STRICT NUTRITION INTEGRITY (ZERO HALLUCINATIONS):
       - If Status is '0 meals logged' or Carbohydrates is 0g because no meals were logged, DO NOT invent carbohydrate intake, DO NOT claim glycogen depletion from fasting, and DO NOT include carbohydrates in evidence pills! State honestly that nutrition was not logged, or focus solely on sleep and pacing.
       - Only discuss carbohydrate availability if logged meals > 0 and carbs > 0.
    7. EVIDENCE PILLS: Provide 3 to 5 key numeric metrics directly from the provided data (e.g. "EF", "Дрейф ЧСС", "Нічний RHR", "Глибокий сон"). Never include carbohydrates if 0 meals are logged.
    8. FOLLOW-UP QUESTIONS: 3 relevant questions the runner can ask the conversational analyst.
    """

    /// Conversational analyst system prompt for multi-turn chat
    public static let analystChatSystemPrompt: String = """
    You are Lifecore Intelligence — an expert conversational sports scientist and athletic coach like Bevel Intelligence.
    You have complete access to the athlete's 3-tier health dossier (telemetry, nutrition, vitals, mesocycle trends, and episodic memory).
    Answer the user's specific questions with deep physiological reasoning and cite exact numbers from their dossier.

    RULES:
    1. OUTPUT ONLY RAW VALID JSON conforming to AnalystChatTurnResponse:
       {
         "answerHeadlineUk": "...",
         "answerBodyUk": "...",
         "citedMetrics": [{"labelUk": "...", "valueUk": "...", "tone": "optimal|teal|warning|danger|neutral"}],
         "actionableTakeawayUk": "...",
         "suggestedFollowUpsUk": ["...", "..."],
         "extractedMemoryFactUk": "... or null",
         "extractedMemoryCategory": "goal|injury_note|nutrition_habit|workout_feel or null"
       }
    2. TONE & GROUNDING: Sharp, direct Ukrainian, athletic, supportive. Zero generic platitudes.
    3. ZERO NUTRITION HALLUCINATIONS: Never invent or hallucinate calories or carbohydrates. If the athlete asks about their nutrition or carbs, but 0 meals are logged in their dossier, explicitly tell them: "У додатку ще немає записів їжі за цей період. Запиши прийом їжі у вкладці «Харчування», щоб я міг проаналізувати надходження вуглеводів."
    4. MEMORY EXTRACTION: If the runner mentions a goal, a physical discomfort/injury, specific running shoes, or a lifestyle change, extract it into extractedMemoryFactUk so it is permanently remembered in their profile.
    """

    /// Backward compatibility prompt
    public static let systemPrompt: String = structuredDebriefSystemPrompt

    /// Builds the structured prompt payload from an AssembledHealthDossier
    public static func buildDossierPrompt(dossier: AssembledHealthDossier) -> String {
        var lines: [String] = []

        if let analysis = dossier.workoutAnalysis {
            lines.append("=== TIER L1: WORKOUT TELEMETRY ===")
            lines.append("- Type: \(analysis.workoutType)")
            lines.append("- Distance: \(String(format: "%.2f", analysis.distanceKm)) km")
            lines.append("- Duration: \(String(format: "%.1f", analysis.durationMin)) min")
            lines.append("- Average Pace: \(String(format: "%.2f", analysis.avgPaceMinKm)) min/km (\(analysis.formattedAvgPace))")
            if let avgHr = analysis.avgHeartRate {
                lines.append("- Average Heart Rate: \(Int(round(avgHr))) bpm")
            }
            if let maxHr = analysis.maxHeartRate {
                lines.append("- Max Heart Rate: \(Int(round(maxHr))) bpm")
            }
            lines.append("- Elevation Gain: \(String(format: "%.0f", analysis.elevationGainMeters)) m")
            if let ef = analysis.efficiencyFactor {
                lines.append("- Efficiency Factor (EF): \(String(format: "%.3f", ef)) m/min/bpm")
            }
            if let drift = analysis.aerobicDecouplingPct {
                lines.append("- Aerobic Decoupling / Cardiac Drift: \(String(format: "%+.1f", drift))%")
            }

            if !analysis.splits.isEmpty {
                lines.append("\nPRE-CALCULATED 1KM SPLITS:")
                for s in analysis.splits {
                    let hrText = s.avgHeartRate != nil ? "\(Int(round(s.avgHeartRate!))) bpm" : "N/A"
                    let elevText = String(format: "%+.0f m", s.elevationDiffMeters)
                    let cadText = s.avgCadence != nil ? ", Cadence: \(Int(round(s.avgCadence!))) spm" : ""
                    lines.append("  • Km \(s.km): Pace \(s.formattedPace), Avg HR: \(hrText), Elev: \(elevText)\(cadText)")
                }
            }

            if let b = analysis.benchmarkDelta {
                lines.append("\nHISTORICAL BENCHMARK COMPARISON (Last \(b.comparedWorkoutsCount) sessions):")
                lines.append("- Pace Delta: \(String(format: "%+.1f", b.paceDeltaSecPerKm)) sec/km (negative = faster)")
                lines.append("- Heart Rate Delta: \(String(format: "%+.1f", b.hrDeltaBpm)) bpm")
                lines.append("- Efficiency Factor Shift: \(String(format: "%+.3f", b.efDelta))")
                lines.append("- Benchmark Regime: \(b.regime.rawValue) (\(b.regime.badgeTitleUk))")
                lines.append("- Summary: \(b.narrativeSummary)")
            }
        }

        // Tier L1: Acute Nutrition
        let nut = dossier.acuteNutrition
        lines.append("\n=== TIER L1: ACUTE 24H/48H NUTRITION ===")
        if nut.loggedMealsCount > 0 {
            lines.append("- Athlete Logged Meals: \(nut.loggedMealsCount) meal(s)")
            lines.append("- Logged Energy: \(Int(nut.last24hKcal)) kcal")
            lines.append("- Carbohydrates: \(Int(nut.last24hCarbsG)) g")
            lines.append("- Protein: \(Int(nut.last24hProteinG)) g, Fat: \(Int(nut.last24hFatG)) g")
            lines.append("- Sodium: \(Int(nut.last24hSodiumMg)) mg")
            lines.append("- Whole Food Quality: \(nut.wholeFoodRatioPct)%")
            lines.append("- Late Meal After 21:30: \(nut.hadLateMealAfter2130 ? "YES (potential overnight RHR penalty)" : "NO")")
            if !nut.recentMealNames.isEmpty {
                lines.append("- Recent Meals: \(nut.recentMealNames.joined(separator: ", "))")
            }
        } else {
            lines.append("- Status: 0 meals logged. The athlete has NOT logged nutrition for this window.")
            lines.append("- RULE: DO NOT assume low carbs, fasting, or glycogen depletion. DO NOT invent carbohydrate figures. Focus on sleep and splits.")
        }

        // Tier L1: Vitals & Recovery
        if let rec = dossier.recoveryContext {
            lines.append("\n=== TIER L1: OVERNIGHT VITALS & READINESS ===")
            if let sleep = rec.lastNightSleepHours {
                lines.append("- Sleep Duration: \(String(format: "%.1f", sleep))h (Deep: \(String(format: "%.1f", rec.lastNightDeepHours ?? 0))h, REM: \(String(format: "%.1f", rec.lastNightRemHours ?? 0))h)")
            }
            if let hrv = rec.morningHrvMs, let base = rec.baselineHrvMs {
                lines.append("- Morning HRV: \(Int(round(hrv))) ms (Baseline: \(Int(round(base))) ms, Δ: \(String(format: "%+.0f", hrv - base)) ms)")
            }
            if let rhr = rec.morningRhrBpm, let base = rec.baselineRhrBpm {
                lines.append("- Resting Heart Rate: \(Int(round(rhr))) bpm (Baseline: \(Int(round(base))) bpm, Δ: \(String(format: "%+.0f", rhr - base)) bpm)")
            }
            if let score = rec.recoveryScore {
                lines.append("- Readiness Score: \(score)%")
            }
            if let state = rec.vitalsConfluenceState {
                lines.append("- Vitals State: \(state)")
            }
            if let acwr = rec.acwrRatio {
                lines.append("- EWMA ACWR: \(String(format: "%.2f", acwr)) (\(rec.acwrZoneTitleUk ?? "Sweet Spot"))")
            }
            if let temp = rec.wristTempDeltaC {
                lines.append("- Sleeping Wrist Temp Δ: \(String(format: "%+.2f", temp))°C")
            }
        }

        // Tier L2: Mesocycle & Prescriptions
        if !dossier.adaptiveSensitivitiesSummaryUk.isEmpty {
            lines.append("\n=== TIER L2: LEARNED ADAPTIVE PHYSIOLOGY ===")
            lines.append("- \(dossier.adaptiveSensitivitiesSummaryUk)")
        }
        if !dossier.next24hPrescriptionSummaryUk.isEmpty {
            lines.append("\n=== TIER L2: TACTICAL TRAINING PRESCRIPTION ===")
            lines.append("- \(dossier.next24hPrescriptionSummaryUk)")
        }

        // Tier L3: Episodic Memory
        if !dossier.retrievedMemories.isEmpty {
            lines.append("\n=== TIER L3: EPISODIC ATHLETE MEMORY (RAG) ===")
            for m in dossier.retrievedMemories {
                let pin = m.isPinnedGoal ? "[PINNED GOAL] " : ""
                lines.append("• \(pin)\(m.factTextUk) (Category: \(m.category), Age: \(m.ageDays)d, Relevance: \(m.relevanceScore))")
            }
        }

        lines.append("\nINSTRUCTION: Output raw JSON strictly following the StructuredWorkoutDebrief schema.")
        return lines.joined(separator: "\n")
    }

    /// Builds prompt for multi-turn analyst chat
    public static func buildAnalystChatPrompt(
        userQuery: String,
        history: [AnalystChatMessage],
        dossier: AssembledHealthDossier
    ) -> String {
        var lines: [String] = []
        lines.append(buildDossierPrompt(dossier: dossier))

        if !history.isEmpty {
            lines.append("\n=== PREVIOUS CONVERSATION TURNS ===")
            for msg in history.suffix(6) {
                let role = msg.sender == "user" ? "Athlete" : "Lifecore Coach"
                lines.append("\(role): \(msg.text)")
            }
        }

        lines.append("\n=== CURRENT ATHLETE QUESTION ===")
        lines.append("Athlete: \(userQuery)")
        lines.append("\nINSTRUCTION: Output raw JSON strictly matching the AnalystChatTurnResponse schema.")
        return lines.joined(separator: "\n")
    }

    /// Backward compatibility prompt builder
    public static func buildUserPrompt(
        analysis: WorkoutAnalysisResult,
        recoveryContext: RecentRecoveryContext? = nil,
        adaptiveSummaryUk: String? = nil,
        nextPrescriptionSummaryUk: String? = nil
    ) -> String {
        let dossier = AssembledHealthDossier(
            workoutAnalysis: analysis,
            recoveryContext: recoveryContext,
            acuteNutrition: .init(),
            adaptiveSensitivitiesSummaryUk: adaptiveSummaryUk ?? "",
            next24hPrescriptionSummaryUk: nextPrescriptionSummaryUk ?? "",
            retrievedMemories: []
        )
        return buildDossierPrompt(dossier: dossier)
    }
}
