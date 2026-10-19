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
        public struct Part: Codable, Sendable {
            public let text: String
            public init(text: String) { self.text = text }
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

        public init(temperature: Double = 0.4, maxOutputTokens: Int = 1500) {
            self.temperature = temperature
            self.maxOutputTokens = maxOutputTokens
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
        }
    }
}

// MARK: - Gemini Service

public final class GeminiService: @unchecked Sendable {
    public static let shared = GeminiService()

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
        return UserDefaults.standard.string(forKey: "GEMINI_API_KEY")
    }

    /// Generates the Athletic Performance Analyst narrative for a workout analysis.
    public func generateCoachReport(
        analysis: WorkoutAnalysisResult,
        recoveryContext: RecentRecoveryContext? = nil,
        model: String = "gemini-2.5-flash"
    ) async throws -> String {
        guard let apiKey = currentApiKey, !apiKey.isEmpty else {
            // Provide high-fidelity local athletic analyst fallback when API key is unconfigured
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

    /// Deterministic athletic analyst narrative generator for offline mode or missing API key.
    public func generateOfflineReport(
        analysis: WorkoutAnalysisResult,
        recoveryContext: RecentRecoveryContext?
    ) -> String {
        var report = ""

        // Section 1: 70% Workout Telemetry Analysis
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

        // Section 2: 15% Benchmark Comparison
        report += "\n### ⚖️ Порівняння з бенчмарком (15%)\n"
        if let b = analysis.benchmarkDelta {
            report += "\(b.narrativeSummary)\n"
            report += "• Дельта темпу: \(String(format: "%+.1f", b.paceDeltaSecPerKm)) с/км | Дельта ЧСС: \(String(format: "%+.1f", b.hrDeltaBpm)) уд/хв | Зсув EF: \(String(format: "%+.3f", b.efDelta)).\n"
        } else {
            report += "• Попередніх ідентичних тренувань для повної кореляції наразі недостатньо. Поточна сесія зафіксована як новий базовий бенчмарк для цієї дистанції.\n"
        }

        // Section 3: 15% Physiological Root Causes & 24h Directive
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
