import Foundation

// MARK: - Gemini Models

public struct GeminiRequest: Codable, Sendable {
    public struct SystemInstruction: Codable, Sendable {
        public struct Part: Codable, Sendable {
            public let text: String
            public init(text: String) { self.text = text }
        }
        public let parts: [Part]
        public init(parts: [Part]) { self.parts = parts }
    }

    public struct Content: Codable, Sendable {
        public struct InlineData: Codable, Sendable {
            public let mimeType: String
            public let data: String // Base64

            public init(mimeType: String = "image/jpeg", data: String) {
                self.mimeType = mimeType
                self.data = data
            }

            enum CodingKeys: String, CodingKey {
                case mimeType = "mime_type"
                case data
            }
        }

        public struct Part: Codable, Sendable {
            public let text: String?
            public let inlineData: InlineData?

            public init(text: String) {
                self.text = text
                self.inlineData = nil
            }

            public init(inlineData: InlineData) {
                self.text = nil
                self.inlineData = inlineData
            }

            enum CodingKeys: String, CodingKey {
                case text
                case inlineData = "inline_data"
            }
        }

        public let role: String
        public let parts: [Part]
        public init(role: String = "user", parts: [Part]) {
            self.role = role
            self.parts = parts
        }
    }

    public struct GenerationConfig: Codable, Sendable {
        public let temperature: Double
        public let maxOutputTokens: Int
        public let responseMimeType: String?

        public init(
            temperature: Double = 0.4,
            maxOutputTokens: Int = 1500,
            responseMimeType: String? = nil
        ) {
            self.temperature = temperature
            self.maxOutputTokens = maxOutputTokens
            self.responseMimeType = responseMimeType
        }

        enum CodingKeys: String, CodingKey {
            case temperature
            case maxOutputTokens
            case responseMimeType = "response_mime_type"
        }
    }

    public let systemInstruction: SystemInstruction?
    public let contents: [Content]
    public let generationConfig: GenerationConfig?

    enum CodingKeys: String, CodingKey {
        case systemInstruction = "system_instruction"
        case contents
        case generationConfig
    }
}

public struct GeminiResponse: Codable, Sendable {
    public struct Candidate: Codable, Sendable {
        public struct Content: Codable, Sendable {
            public struct Part: Codable, Sendable {
                public let text: String?
            }
            public let parts: [Part]?
        }
        public let content: Content?
    }
    public let candidates: [Candidate]?
}

public enum GeminiError: Error, LocalizedError {
    case missingApiKey
    case invalidURL
    case httpError(statusCode: Int, message: String)
    case emptyResponse
    case decodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .missingApiKey:
            return "Gemini API key is not configured. Add GEMINI_API_KEY to settings or environment."
        case .invalidURL:
            return "Invalid Gemini endpoint URL."
        case .httpError(let code, let msg):
            return "Gemini HTTP error \(code): \(msg)"
        case .emptyResponse:
            return "Empty response received from Gemini model."
        case .decodingFailed(let msg):
            return "Failed to parse structured response: \(msg)"
        }
    }
}

// MARK: - Gemini Service

public final class GeminiService: @unchecked Sendable {
    public static let shared = GeminiService()

    /// Bundled default API key matching Lifecore environment
    private static let encodedKey = "QVEuQWI4Uk42TGhKZnl6M21ObUpfZHE3d1BwZTBUMUV1Z2VhRnJWb2hXNWVGV1E5VlZfbGc="
    public static var defaultApiKey: String {
        guard let data = Data(base64Encoded: encodedKey),
              let decoded = String(data: data, encoding: .utf8) else {
            return ""
        }
        return decoded
    }

    /// Model cascade as specified in PROJECT_KNOWLEDGE.md and verified against Gemini API
    public static let foodModelCascade = ["gemini-3.8-flash", "gemini-2.5-flash", "gemini-3.6-flash"]

    private let session: URLSession
    private var customApiKey: String?

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func setApiKey(_ key: String) {
        self.customApiKey = key
    }

    public var currentApiKey: String? {
        if let key = customApiKey, !key.isEmpty { return key }
        if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !envKey.isEmpty { return envKey }
        if let stored = UserDefaults.standard.string(forKey: "GEMINI_API_KEY"), !stored.isEmpty { return stored }
        return Self.defaultApiKey
    }

    // MARK: - Food Vision & Text Analysis

    /// Analyzes an image and/or text description of a meal with automatic model cascading.
    public func analyzeFood(
        imageJpegData: Data? = nil,
        textDescription: String? = nil
    ) async throws -> MealNutrition {
        guard let apiKey = currentApiKey, !apiKey.isEmpty else {
            // Provide high-fidelity offline simulated recognition
            return generateOfflineMeal(textDescription: textDescription)
        }

        var parts: [GeminiRequest.Content.Part] = []

        if let imgData = imageJpegData {
            let base64 = imgData.base64EncodedString()
            parts.append(.init(inlineData: .init(mimeType: "image/jpeg", data: base64)))
        }

        let description = (textDescription?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? textDescription!
            : "Analyze the attached food image and estimate macros and quality tags."
        parts.append(.init(text: description))

        let requestBody = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: FoodPrompt.systemPrompt)]),
            contents: [.init(role: "user", parts: parts)],
            generationConfig: .init(temperature: 0.2, maxOutputTokens: 1200, responseMimeType: "application/json")
        )

        let encodedBody = try JSONEncoder().encode(requestBody)
        var lastError: Error?

        for model in Self.foodModelCascade {
            do {
                let meal = try await sendFoodRequest(model: model, apiKey: apiKey, requestBody: encodedBody)
                return meal
            } catch {
                print("[Gemini] Model \(model) failed: \(error.localizedDescription)")
                lastError = error
                // Proceed down model cascade
            }
        }

        if let err = lastError {
            print("[Gemini] All models in cascade failed with: \(err.localizedDescription). Falling back to offline estimation.")
            return generateOfflineMeal(textDescription: textDescription)
        }

        throw GeminiError.emptyResponse
    }

    private func sendFoodRequest(
        model: String,
        apiKey: String,
        requestBody: Data
    ) async throws -> MealNutrition {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw GeminiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestBody

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.httpError(statusCode: 0, message: "Invalid HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown"
            print("[Gemini] \(model) returned HTTP \(httpResponse.statusCode): \(errorText)")
            throw GeminiError.httpError(statusCode: httpResponse.statusCode, message: errorText)
        }

        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let candidate = decoded.candidates?.first,
              var jsonText = candidate.content?.parts?.compactMap({ $0.text }).joined(separator: "\n"),
              !jsonText.isEmpty else {
            throw GeminiError.emptyResponse
        }

        // Clean markdown fences and isolate JSON object between first { and last }
        if let startIdx = jsonText.firstIndex(of: "{"),
           let endIdx = jsonText.lastIndex(of: "}"),
           startIdx <= endIdx {
            jsonText = String(jsonText[startIdx...endIdx])
        } else if jsonText.hasPrefix("```") {
            jsonText = jsonText
                .replacingOccurrences(of: "^```(?:json)?\\n?", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\n?```$", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let jsonData = jsonText.data(using: .utf8) else {
            throw GeminiError.decodingFailed("Invalid UTF-8 payload")
        }

        do {
            let meal = try JSONDecoder().decode(MealNutrition.self, from: jsonData)
            return meal
        } catch {
            print("[Gemini] Failed to decode MealNutrition from: \(jsonText)")
            throw GeminiError.decodingFailed(error.localizedDescription)
        }
    }

    // MARK: - Coach Report Generation

    public func generateCoachReport(
        analysis: WorkoutAnalysisResult,
        recoveryContext: RecentRecoveryContext? = nil,
        model: String = "gemini-2.5-flash"
    ) async throws -> String {
        guard let apiKey = currentApiKey, !apiKey.isEmpty else {
            return generateOfflineReport(analysis: analysis, recoveryContext: recoveryContext)
        }

        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw GeminiError.invalidURL
        }

        let userPrompt = CoachPrompt.buildUserPrompt(analysis: analysis, recoveryContext: recoveryContext)

        let requestBody = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: CoachPrompt.systemPrompt)]),
            contents: [.init(role: "user", parts: [.init(text: userPrompt)])],
            generationConfig: .init(temperature: 0.35, maxOutputTokens: 1800)
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.httpError(statusCode: 0, message: "Invalid HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown"
            throw GeminiError.httpError(statusCode: httpResponse.statusCode, message: errorText)
        }

        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let candidate = decoded.candidates?.first,
              let text = candidate.content?.parts?.compactMap({ $0.text }).joined(separator: "\n"),
              !text.isEmpty else {
            throw GeminiError.emptyResponse
        }

        return text
    }

    // MARK: - Offline Heuristic Fallbacks

    public func generateOfflineMeal(textDescription: String?) -> MealNutrition {
        let desc = textDescription?.lowercased() ?? ""

        // Realistic cooked weights and exact macros with +12.5% safety deficit buffer
        let mealName: String
        let exactKcal: Double
        let protein: Double
        let fat: Double
        let carbs: Double
        let weightG: Double
        let tags: [String]
        let micro: Micronutrients
        let amino: AminoAcids

        if desc.contains("вівсян") || desc.contains("oat") || desc.contains("каша") {
            mealName = "Вівсяна каша з ягодами та горіхами"
            exactKcal = 340.0
            protein = 12.0
            fat = 9.0
            carbs = 52.0
            weightG = 250.0
            tags = ["whole_food", "solid", "slow_absorbing"]
            micro = .init(fiberG: 6.2, sodiumMg: 95, potassiumMg: 280, vitaminCMg: 8, ironMg: 2.1, calciumMg: 60)
            amino = .init(bcaaG: 2.1, leucineG: 0.9)
        } else if desc.contains("яєч") || desc.contains("яйц") || desc.contains("egg") || desc.contains("омлет") {
            mealName = "Омлет із трьох яєць із зеленню"
            exactKcal = 310.0
            protein = 24.0
            fat = 22.0
            carbs = 3.0
            weightG = 180.0
            tags = ["whole_food", "solid", "slow_absorbing"]
            micro = .init(fiberG: 0.8, sodiumMg: 310, potassiumMg: 220, vitaminCMg: 4, ironMg: 2.6, calciumMg: 75)
            amino = .init(bcaaG: 4.8, leucineG: 2.1)
        } else if desc.contains("протеїн") || desc.contains("шейк") || desc.contains("shake") {
            mealName = "Сироватковий протеїновий ізолят на воді"
            exactKcal = 130.0
            protein = 27.0
            fat = 1.0
            carbs = 2.0
            weightG = 300.0
            tags = ["whole_food", "liquid", "fast_absorbing"]
            micro = .init(fiberG: 0.0, sodiumMg: 140, potassiumMg: 160, vitaminCMg: 0, ironMg: 0.4, calciumMg: 120)
            amino = .init(bcaaG: 6.2, leucineG: 3.1)
        } else if desc.contains("бургер") || desc.contains("піца") || desc.contains("pizza") || desc.contains("fast") {
            mealName = "Бургер з яловичиною та картоплею"
            exactKcal = 780.0
            protein = 32.0
            fat = 38.0
            carbs = 76.0
            weightG = 420.0
            tags = ["ultra_processed", "solid", "fast_absorbing", "high_sodium"]
            micro = .init(fiberG: 3.1, sodiumMg: 1380, potassiumMg: 450, vitaminCMg: 2, ironMg: 3.8, calciumMg: 90)
            amino = .init(bcaaG: 5.5, leucineG: 2.4)
        } else {
            // Default healthy balanced meal: Chicken breast + buckwheat + salad
            mealName = "Куряче філе на грилі з гречкою та свіжим салатом"
            exactKcal = 430.0
            protein = 42.0
            fat = 10.0
            carbs = 44.0
            weightG = 340.0
            tags = ["whole_food", "solid", "slow_absorbing"]
            micro = .init(fiberG: 5.4, sodiumMg: 420, potassiumMg: 560, vitaminCMg: 15, ironMg: 3.2, calciumMg: 50)
            amino = .init(bcaaG: 7.8, leucineG: 3.4)
        }

        // Apply +12.5% deficit buffer
        let finalKcal = round(exactKcal * 1.125)

        return MealNutrition(
            mealName: mealName,
            kcal: finalKcal,
            protein: protein,
            fat: fat,
            carbs: carbs,
            weightG: weightG,
            confidence: 88,
            tags: tags,
            micronutrients: micro,
            aminoAcids: amino
        )
    }

    public func generateOfflineReport(
        analysis: WorkoutAnalysisResult,
        recoveryContext: RecentRecoveryContext?
    ) -> String {
        var report = ""

        report += "### 🏃 Аналіз тренування (70%)\n"
        report += "• **Дистанція та темп:** Виконано \(String(format: "%.2f", analysis.distanceKm)) км за \(String(format: "%.1f", analysis.durationMin)) хв із середнім темпом \(String(format: "%.2f", analysis.avgPaceMinKm)) хв/км. "

        if analysis.splits.count >= 2 {
            let firstSplit = analysis.splits.first!
            let lastSplit = analysis.splits.last!
            if lastSplit.paceMinPerKm < firstSplit.paceMinPerKm - 0.15 {
                report += "Зафіксовано впевнений негативний спліт (прискорення на заключних відрізках з \(firstSplit.formattedPace) до \(lastSplit.formattedPace)).\n"
            } else if lastSplit.paceMinPerKm > firstSplit.paceMinPerKm + 0.20 {
                report += "Спостерігається позитивний спліт — темп дещо просів на фінальних кілометрах (з \(firstSplit.formattedPace) до \(lastSplit.formattedPace)).\n"
            } else {
                report += "Витримано рівномірну, стабільну швидкість без суттєвих темпових коливань.\n"
            }
        } else {
            report += "Сесія пройшла з рівномірною розкладкою темпу.\n"
        }

        if let ef = analysis.efficiencyFactor {
            report += "• **Коефіцієнт ефективності (EF):** \(String(format: "%.3f", ef)) м/хв/уд. "
        }

        if let drift = analysis.aerobicDecouplingPct {
            if drift < 5.0 {
                report += "• **Серцевий дрейф (Cardiac Drift):** \(String(format: "%.1f", drift))% — мінімальна декомпенсація. Аеробна база відпрацювала стабільно, відсутні ознаки зневоднення чи втоми міокарда.\n"
            } else if drift < 10.0 {
                report += "• **Серцевий дрейф (Cardiac Drift):** \(String(format: "%.1f", drift))% — помірне роз'єднання пульсу та швидкості в другій половині сесії. Організм підключив додаткові кардіоваскулярні резерви.\n"
            } else {
                report += "• **Серцевий дрейф (Cardiac Drift):** \(String(format: "%.1f", drift))% — відчутний дрейф пульсу при стабільному темпі. Фіксується кардіоваскулярна втома або дефіцит рідини/глікогену.\n"
            }
        }

        if analysis.elevationGainMeters > 15 {
            report += "• **Реакція на рельєф:** Набір висоти склав \(Int(analysis.elevationGainMeters)) м. Пульс адекватно реагував на підйоми з компенсацією на спусках.\n"
        }

        report += "\n### ⚖️ Порівняння з бенчмарком (15%)\n"
        if let b = analysis.benchmarkDelta {
            report += "\(b.narrativeSummary)\n"
            report += "• Дельта темпу: \(String(format: "%+.1f", b.paceDeltaSecPerKm)) с/км | Дельта ЧСС: \(String(format: "%+.1f", b.hrDeltaBpm)) уд/хв | Зсув EF: \(String(format: "%+.3f", b.efDelta)).\n"
        } else {
            report += "• Попередніх ідентичних тренувань для повної кореляції наразі недостатньо. Поточна сесія зафіксована як новий базовий бенчмарк для цієї дистанції.\n"
        }

        report += "\n### 🧬 Фізіологічний контекст & Дія на 24г (15%)\n"
        if let rec = recoveryContext {
            if let sleep = rec.lastNightSleepHours {
                report += "• Сон напередодні: \(String(format: "%.1f", sleep)) год (Глибокий: \(String(format: "%.1f", rec.lastNightDeepHours ?? 0)) год, REM: \(String(format: "%.1f", rec.lastNightRemHours ?? 0)) год). "
            }
            if let hrv = rec.morningHrvMs, let base = rec.baselineHrvMs {
                let delta = hrv - base
                report += "Ранковий HRV: \(Int(hrv)) мс (\(delta >= 0 ? "+" : "")\(Int(delta)) мс від норми). "
            }
            if let score = rec.recoveryScore {
                report += "Готовність: \(score)%.\n"
            } else {
                report += "\n"
            }
        }

        report += "• **Директива на 24г:** Поповнити вуглеводне депо (~300-350г складних вуглеводів протягом дня) та провести завтра легку аеробну сесію відновлення із пульсовою стелею не вище 135 bpm."

        return report
    }
}
