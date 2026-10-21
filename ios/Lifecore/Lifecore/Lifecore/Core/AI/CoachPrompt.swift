import Foundation

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

    /// Personal Endurance Coach persona delivering simple, human, and motivating workout insights in Ukrainian.
    public static let systemPrompt: String = """
    You are an expert personal endurance running coach talking directly to your athlete.
    Your goal is to explain their workout in clear, simple, human, and motivating language — like a seasoned coach giving a brief, sharp debrief right after a run, NOT an academic medical lab report.

    MANDATORY DIRECTIVES:
    1. SIMPLE & HUMAN LANGUAGE (Зрозуміло, по-спортивному, без заумних термінів):
       - Talk directly to the athlete in friendly, respectful, and sharp Ukrainian (звернення на «ти»).
       - NEVER use academic engineering tags or percentages in titles (DO NOT write "(70%)", "(15%)", "декомпенсація міокарда", "коефіцієнт EF = X.XXX", "дельта темпу", "кардіоваскулярні резерви").
       - Translate physiological metrics into intuitive running sensations:
         • Negative split -> "Грамотно розклав сили: почав спокійно, а в другій половині навпаки додав швидкості."
         • Low cardiac drift (<5%) -> "Пульс залишався спокійним і не злітав до самого фінішу — аеробна база відпрацювала монолітно."
         • Efficiency Factor (EF) -> "Серце працювало економно: на кожен удар ти долав більше дистанції."
         • Benchmark delta -> "Ти біг на Х секунд швидше, ніж у минулі рази, при майже такому ж пульсі."
    2. ZERO ARITHMETIC: Use the pre-calculated numbers provided in the payload. Never recalculate or invent numbers.
    3. NO MEDICAL ALARMISM & NO GENERIC PLATITUDES: Normal heart rate variations are standard training adaptations. Recommendations must be strictly athletic (e.g. поповнити вуглеводи, легка пробіжка до 135 bpm або день відпочинку).

    OUTPUT STRUCTURE (Strictly 3 clean, focused sections):

    ### 🏃 Як пройшов забіг
    2-3 чітких речення: загальний темп, розкладка сил по відрізках (чи було прискорення під кінець), і чи працювало серце в стабільному режимі без задишки.

    ### 📈 Твій прогрес
    1-2 речення: живе порівняння з минулими забігами на схожу дистанцію (на скільки секунд на кілометр ти став швидшим і чи виріс пульс). Якщо це новий орієнтир — зазнач це як базовий чекпоінт.

    ### 🎯 Що робити далі (план на 24г)
    1-2 речення: зв'яжи самопочуття з якістю сну/ранкового відновлення та дай РІВНО ОДНУ чітку дію на найближчу добу (поповнення вуглеводів та відновлювальне тренування або відпочинок).
    """

    /// Formats pre-calculated workout telemetry and physiological context into an optimized user prompt.
    public static func buildUserPrompt(
        analysis: WorkoutAnalysisResult,
        recoveryContext: RecentRecoveryContext? = nil,
        adaptiveSummaryUk: String? = nil
    ) -> String {
        var lines: [String] = []

        lines.append("WORKOUT TELEMETRY PAYLOAD:")
        lines.append("- Type: \(analysis.workoutType)")
        lines.append("- Distance: \(String(format: "%.2f", analysis.distanceKm)) km")
        lines.append("- Duration: \(String(format: "%.1f", analysis.durationMin)) min")
        lines.append("- Average Pace: \(String(format: "%.2f", analysis.avgPaceMinKm)) min/km")

        if let avgHr = analysis.avgHeartRate {
            lines.append("- Average Heart Rate: \(String(format: "%.0f", avgHr)) bpm")
        }
        if let maxHr = analysis.maxHeartRate {
            lines.append("- Max Heart Rate: \(String(format: "%.0f", maxHr)) bpm")
        }
        lines.append("- Elevation Gain: \(String(format: "%.0f", analysis.elevationGainMeters)) m")
        lines.append("- Indoor Treadmill: \(analysis.isIndoorTreadmill ? "YES" : "NO")")

        if let ef = analysis.efficiencyFactor {
            lines.append("- Efficiency Factor (EF): \(String(format: "%.3f", ef)) m/min/bpm")
        }
        if let drift = analysis.aerobicDecouplingPct {
            lines.append("- Aerobic Decoupling / Cardiac Drift: \(String(format: "%.1f", drift))%")
        }

        // 1km Splits
        if !analysis.splits.isEmpty {
            lines.append("\nPRE-CALCULATED 1KM SPLITS:")
            for s in analysis.splits {
                let hrText = s.avgHeartRate != nil ? "\(Int(round(s.avgHeartRate!))) bpm" : "N/A"
                let peakHrText = s.maxHeartRate != nil ? "\(Int(round(s.maxHeartRate!))) bpm" : "N/A"
                let elevText = String(format: "%+.0f m", s.elevationDiffMeters)
                let cadenceText = s.avgCadence != nil ? ", Cadence: \(Int(round(s.avgCadence!))) spm" : ""
                lines.append("  • Km \(s.km): Pace \(s.formattedPace), Avg HR: \(hrText), Peak HR: \(peakHrText), Elev: \(elevText)\(cadenceText)")
            }
        }

        // Interval Laps
        if !analysis.laps.isEmpty {
            lines.append("\nSTRUCTURED INTERVAL LAPS:")
            for l in analysis.laps {
                let dropText = l.hrRecoveryDropBpm != nil ? ", HR Drop: -\(Int(round(l.hrRecoveryDropBpm!))) bpm" : ""
                let distText = l.distanceMeters != nil ? String(format: "%.0f m", l.distanceMeters!) : ""
                lines.append("  • Lap \(l.lapIndex) [\(l.lapType.uppercased())]: \(Int(l.durationSeconds))s, \(distText), Avg HR: \(l.avgHeartRate != nil ? "\(Int(round(l.avgHeartRate!))) bpm" : "N/A")\(dropText)")
            }
        }

        // Benchmark
        if let b = analysis.benchmarkDelta {
            lines.append("\nHISTORICAL BENCHMARK COMPARISON (Last \(b.comparedWorkoutsCount) similar sessions):")
            lines.append("- Pace Delta: \(String(format: "%+.1f", b.paceDeltaSecPerKm)) sec/km (negative = faster)")
            lines.append("- Heart Rate Delta: \(String(format: "%+.1f", b.hrDeltaBpm)) bpm")
            lines.append("- Efficiency Factor Shift: \(String(format: "%+.3f", b.efDelta))")
            lines.append("- Summary: \(b.narrativeSummary)")
        } else {
            lines.append("\nHISTORICAL BENCHMARK COMPARISON: Insufficient prior matching sessions for statistical comparison.")
        }

        // Physiological Recovery Context
        if let rec = recoveryContext {
            lines.append("\nPRE-WORKOUT PHYSIOLOGICAL RECOVERY CONTEXT (48h):")
            if let sleep = rec.lastNightSleepHours {
                lines.append("- Last Night Sleep: \(String(format: "%.1f", sleep))h (Deep: \(String(format: "%.1f", rec.lastNightDeepHours ?? 0))h, REM: \(String(format: "%.1f", rec.lastNightRemHours ?? 0))h)")
            }
            if let hrv = rec.morningHrvMs, let baseHrv = rec.baselineHrvMs {
                lines.append("- Morning HRV SDNN: \(String(format: "%.0f", hrv)) ms (30d Baseline: \(String(format: "%.0f", baseHrv)) ms, Δ: \(String(format: "%+.0f", hrv - baseHrv)) ms)")
            }
            if let rhr = rec.morningRhrBpm, let baseRhr = rec.baselineRhrBpm {
                lines.append("- Resting HR (RHR): \(String(format: "%.0f", rhr)) bpm (30d Baseline: \(String(format: "%.0f", baseRhr)) bpm, Δ: \(String(format: "%+.0f", rhr - baseRhr)) bpm)")
            }
            if let score = rec.recoveryScore {
                lines.append("- Recovery Readiness Score: \(score)%")
            }
            if let state = rec.vitalsConfluenceState {
                lines.append("- Overnight Vitals Confluence State: \(state)")
            }
            if let acwr = rec.acwrRatio {
                lines.append("- EWMA Acute:Chronic Workload Ratio (ACWR): \(String(format: "%.2f", acwr)) (\(rec.acwrZoneTitleUk ?? "Sweet Spot"))")
            }
            if let temp = rec.wristTempDeltaC {
                lines.append("- Sleeping Wrist Temperature Delta: \(String(format: "%+.2f", temp))°C")
            }
            if let insight = rec.topCorrelationInsightUk {
                lines.append("- Key Time-Lagged Physiological Habit Correlation: \(insight)")
            }
        }

        // Self-Learning Physiology Calibration
        if let adaptive = adaptiveSummaryUk, !adaptive.isEmpty {
            lines.append("\n[SELF-LEARNING PHYSIOLOGY CALIBRATION]:")
            lines.append("- \(adaptive)")
        }

        lines.append("\nINSTRUCTION: Generate a simple, motivating, and human coach breakdown in Ukrainian following the 3 sections above. Talk directly to the runner in plain, athletic terms without robotic jargon or percentage tags.")
        return lines.joined(separator: "\n")
    }
}
