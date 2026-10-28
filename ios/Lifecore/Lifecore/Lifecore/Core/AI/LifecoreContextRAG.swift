import Foundation
import SwiftData

// MARK: - Core RAG Data Types (Lifecore v3.4)

public struct RetrievedMemoryNode: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let factTextUk: String
    public let category: String
    public let tags: [String]
    public let relevanceScore: Double
    public let ageDays: Int
    public let isPinnedGoal: Bool

    public init(
        id: UUID = UUID(),
        factTextUk: String,
        category: String,
        tags: [String] = [],
        relevanceScore: Double = 0.0,
        ageDays: Int = 0,
        isPinnedGoal: Bool = false
    ) {
        self.id = id
        self.factTextUk = factTextUk
        self.category = category
        self.tags = tags
        self.relevanceScore = relevanceScore
        self.ageDays = ageDays
        self.isPinnedGoal = isPinnedGoal
    }
}

public struct AcuteNutritionSlice: Codable, Sendable, Equatable {
    public let last24hKcal: Double
    public let last24hCarbsG: Double
    public let last24hProteinG: Double
    public let last24hFatG: Double
    public let last24hSodiumMg: Double
    public let wholeFoodRatioPct: Int
    public let hadLateMealAfter2130: Bool
    public let recentMealNames: [String]

    public init(
        last24hKcal: Double = 0,
        last24hCarbsG: Double = 0,
        last24hProteinG: Double = 0,
        last24hFatG: Double = 0,
        last24hSodiumMg: Double = 0,
        wholeFoodRatioPct: Int = 85,
        hadLateMealAfter2130: Bool = false,
        recentMealNames: [String] = []
    ) {
        self.last24hKcal = last24hKcal
        self.last24hCarbsG = last24hCarbsG
        self.last24hProteinG = last24hProteinG
        self.last24hFatG = last24hFatG
        self.last24hSodiumMg = last24hSodiumMg
        self.wholeFoodRatioPct = wholeFoodRatioPct
        self.hadLateMealAfter2130 = hadLateMealAfter2130
        self.recentMealNames = recentMealNames
    }
}

public struct AssembledHealthDossier: Codable, Sendable {
    public let workoutAnalysis: WorkoutAnalysisResult?
    public let recoveryContext: RecentRecoveryContext?
    public let acuteNutrition: AcuteNutritionSlice
    public let adaptiveSensitivitiesSummaryUk: String
    public let next24hPrescriptionSummaryUk: String
    public let retrievedMemories: [RetrievedMemoryNode]

    public init(
        workoutAnalysis: WorkoutAnalysisResult? = nil,
        recoveryContext: RecentRecoveryContext? = nil,
        acuteNutrition: AcuteNutritionSlice = .init(),
        adaptiveSensitivitiesSummaryUk: String = "",
        next24hPrescriptionSummaryUk: String = "",
        retrievedMemories: [RetrievedMemoryNode] = []
    ) {
        self.workoutAnalysis = workoutAnalysis
        self.recoveryContext = recoveryContext
        self.acuteNutrition = acuteNutrition
        self.adaptiveSensitivitiesSummaryUk = adaptiveSensitivitiesSummaryUk
        self.next24hPrescriptionSummaryUk = next24hPrescriptionSummaryUk
        self.retrievedMemories = retrievedMemories
    }
}

// MARK: - LifecoreContextRAG Engine

public enum LifecoreContextRAG {

    /// Normalizes Ukrainian and athletic terms into search tokens
    public static func tokenize(_ text: String) -> Set<String> {
        let lowered = text.lowercased()
        let clean = lowered.map { ch -> Character in
            if ch.isLetter || ch.isNumber { return ch }
            return " "
        }
        let words = String(clean)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count >= 2 }

        var stems = Set<String>()
        for w in words {
            // Trim Ukrainian common word endings for robust hybrid BM25 overlap
            var stem = w
            let suffixes = ["ований", "ованого", "ованих", "ий", "ого", "ому", "им", "их", "ами", "ями", "ів", "ев", "ам", "ям", "а", "я", "у", "ю", "е", "і", "и", "о"]
            for s in suffixes {
                if stem.hasSuffix(s) && stem.count > s.count + 2 {
                    stem = String(stem.dropLast(s.count))
                    break
                }
            }
            stems.insert(stem)
            stems.insert(w) // Also keep exact
        }
        return stems
    }

    /// Evaluates the relevance of a single episodic memory node using deterministic BM25 + Tag Overlap + Recency Decay.
    public static func scoreMemoryNode(
        factText: String,
        category: String,
        tags: [String],
        isPinnedGoal: Bool,
        ageDays: Int,
        queryTokens: Set<String>,
        contextTags: [String]
    ) -> Double {
        if isPinnedGoal && (queryTokens.contains("goal") || queryTokens.contains("ціль") || queryTokens.contains("план")) {
            return 1.0
        }

        let docTokens = tokenize(factText)
        let docTags = Set(tags.map { $0.lowercased() })
        let targetTags = Set(contextTags.map { $0.lowercased() })

        // 1. Lexical saturation score (BM25 term overlap simulation)
        let matchingTokens = docTokens.intersection(queryTokens)
        let tokenScore: Double
        if queryTokens.isEmpty {
            tokenScore = 0.0
        } else {
            let overlapRatio = Double(matchingTokens.count) / Double(max(1, queryTokens.count))
            tokenScore = min(1.0, overlapRatio * 1.5)
        }

        // 2. Structured tag overlap score
        let matchingTags = docTags.intersection(targetTags)
        let tagScore: Double
        if targetTags.isEmpty {
            tagScore = 0.0
        } else {
            tagScore = Double(matchingTags.count) / Double(max(1, targetTags.count))
        }

        // 3. Recency decay (half-life of 21 days for general physiological notes)
        let decay: Double
        if isPinnedGoal {
            decay = 1.0
        } else {
            let lambda = log(2.0) / 21.0
            decay = exp(-lambda * Double(max(0, ageDays)))
        }

        let finalScore = (0.45 * tokenScore) + (0.35 * tagScore) + (0.20 * decay)
        return round(finalScore * 1000) / 1000
    }

    /// Retrieves and ranks stored athlete memories for an incoming query and context tags.
    @MainActor
    public static func retrieveTopMemories(
        query: String,
        contextTags: [String] = [],
        limit: Int = 4
    ) -> [RetrievedMemoryNode] {
        let stored = AthleteMemoryStorageService.fetchAllFacts()
        let queryTokens = tokenize(query)
        let now = Date()

        var scoredNodes: [RetrievedMemoryNode] = []

        for item in stored {
            let ageDays = max(0, Int(now.timeIntervalSince(item.createdAt) / 86400.0))
            let score = scoreMemoryNode(
                factText: item.factTextUk,
                category: item.category,
                tags: item.tags,
                isPinnedGoal: item.isPinnedGoal,
                ageDays: ageDays,
                queryTokens: queryTokens,
                contextTags: contextTags
            )

            scoredNodes.append(
                RetrievedMemoryNode(
                    id: item.id,
                    factTextUk: item.factTextUk,
                    category: item.category,
                    tags: item.tags,
                    relevanceScore: score,
                    ageDays: ageDays,
                    isPinnedGoal: item.isPinnedGoal
                )
            )
        }

        // Sort descending by score, breaking ties by isPinnedGoal and recency
        scoredNodes.sort { a, b in
            if abs(a.relevanceScore - b.relevanceScore) > 0.01 {
                return a.relevanceScore > b.relevanceScore
            }
            if a.isPinnedGoal != b.isPinnedGoal {
                return a.isPinnedGoal && !b.isPinnedGoal
            }
            return a.ageDays < b.ageDays
        }

        return Array(scoredNodes.prefix(limit))
    }

    /// Assembles an end-to-end 3-tier health context dossier on-device.
    @MainActor
    public static func assembleDossier(
        workoutAnalysis: WorkoutAnalysisResult?,
        recoveryContext: RecentRecoveryContext?,
        meals: [MealRecord] = [],
        adaptiveSummaryUk: String? = nil,
        prescriptionSummaryUk: String? = nil,
        userQuery: String = ""
    ) -> AssembledHealthDossier {
        // 1. Tier L1: Compute Acute 24h/48h Nutrition Slice
        var totalKcal: Double = 0
        var totalCarbs: Double = 0
        var totalProtein: Double = 0
        var totalFat: Double = 0
        var totalSodium: Double = 0
        var wholeFoodCount = 0
        var totalMeals = 0
        var hadLateMeal = false
        var mealNames: [String] = []

        let calendar = Calendar.current
        for m in meals {
            totalKcal += m.kcal
            totalCarbs += m.carbsG
            totalProtein += m.proteinG
            totalFat += m.fatG
            if let micro = m.micronutrients, let sodium = micro.sodiumMg {
                totalSodium += sodium
            }
            totalMeals += 1
            if m.tags.contains("whole_food") {
                wholeFoodCount += 1
            }
            mealNames.append(m.name)

            let hour = calendar.component(.hour, from: m.createdAt)
            let minute = calendar.component(.minute, from: m.createdAt)
            if (hour > 21 || (hour == 21 && minute >= 30)) && hour < 24 {
                hadLateMeal = true
            }
        }

        let wholeRatioPct = totalMeals > 0 ? Int(round((Double(wholeFoodCount) / Double(totalMeals)) * 100)) : 85
        let nutritionSlice = AcuteNutritionSlice(
            last24hKcal: round(totalKcal),
            last24hCarbsG: round(totalCarbs),
            last24hProteinG: round(totalProtein),
            last24hFatG: round(totalFat),
            last24hSodiumMg: round(totalSodium),
            wholeFoodRatioPct: wholeRatioPct,
            hadLateMealAfter2130: hadLateMeal,
            recentMealNames: Array(mealNames.prefix(5))
        )

        // 2. Build context tags for memory retrieval
        var contextTags: [String] = ["running", "workout"]
        if let analysis = workoutAnalysis {
            if (analysis.aerobicDecouplingPct ?? 0) > 5.0 {
                contextTags.append("hr_drift")
                contextTags.append("carbs")
            }
            if analysis.benchmarkDelta?.regime == .higherIntensityEffort {
                contextTags.append("intensity")
                contextTags.append("pace")
            }
        }
        if hadLateMeal {
            contextTags.append("late_meal")
            contextTags.append("rhr")
        }

        // 3. Tier L3: Retrieve top memories
        let queryCombined = "\(userQuery) \(workoutAnalysis?.workoutType ?? "")"
        let topMemories = retrieveTopMemories(query: queryCombined, contextTags: contextTags, limit: 3)

        return AssembledHealthDossier(
            workoutAnalysis: workoutAnalysis,
            recoveryContext: recoveryContext,
            acuteNutrition: nutritionSlice,
            adaptiveSensitivitiesSummaryUk: adaptiveSummaryUk ?? "",
            next24hPrescriptionSummaryUk: prescriptionSummaryUk ?? "",
            retrievedMemories: topMemories
        )
    }

    /// Deterministic on-device rule to detect and extract athlete facts from conversational messages
    public static func extractCandidateMemoryFact(
        fromUserMessage message: String
    ) -> (factUk: String, category: String, tags: [String])? {
        let lowered = message.lowercased()

        // 1. Discomfort / Pain / Musculoskeletal
        if lowered.contains("болить") || lowered.contains("тягне") || lowered.contains("дискомфорт") || lowered.contains("литка") || lowered.contains("коліно") || lowered.contains("ахілл") {
            let fact = "Повідомлення про дискомфорт: «\(message.prefix(80))»"
            return (fact, "injury_note", ["injury", "discomfort", "recovery"])
        }

        // 2. Goals / Races
        if lowered.contains("готуюся") || lowered.contains("хочу пробігти") || lowered.contains("ціль") || lowered.contains("півмарафон") || lowered.contains("марафон") || lowered.contains("10 км") {
            let fact = "Атлетична ціль: «\(message.prefix(80))»"
            return (fact, "goal", ["goal", "race", "plan"])
        }

        // 3. Equipment / Shoes
        if lowered.contains("кросівк") || lowered.contains("взутт") || lowered.contains("vaporfly") || lowered.contains("pegasus") {
            let fact = "Екіпірування: «\(message.prefix(80))»"
            return (fact, "workout_feel", ["gear", "shoes"])
        }

        // 4. Weather / External
        if lowered.contains("вітер") || lowered.contains("спека") || lowered.contains("дощ") || lowered.contains("траса") || lowered.contains("гірка") {
            let fact = "Умови тренування: «\(message.prefix(80))»"
            return (fact, "workout_feel", ["weather", "terrain"])
        }

        return nil
    }
}
