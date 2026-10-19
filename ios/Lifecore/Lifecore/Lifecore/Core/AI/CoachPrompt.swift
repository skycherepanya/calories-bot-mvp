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

    public init(
        lastNightSleepHours: Double? = nil,
        lastNightDeepHours: Double? = nil,
        lastNightRemHours: Double? = nil,
        morningHrvMs: Double? = nil,
        baselineHrvMs: Double? = nil,
        morningRhrBpm: Double? = nil,
        baselineRhrBpm: Double? = nil,
        yesterdayActiveKcal: Double? = nil,
        recoveryScore: Int? = nil
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
    }
}

// MARK: - Coach Prompt Builder

public enum CoachPrompt {

    /// High-density English system instructions establishing the Athletic Performance Analyst persona (70/15/15).
    public static let systemPrompt: String = """
    You are an elite Athletic Performance Analyst, Sports Physiologist, and High-Performance Endurance Coach.
    Your role is to produce rigorous, data-driven post-workout diagnostic analyses based solely on pre-calculated biometric telemetry.

    MANDATORY DIRECTIVES:
    1. ZERO ARITHMETIC: All splits, paces, heart rate decoupling (EF), cardiac drift percentages, and baselines are PRE-CALCULATED in the provided payload. Never recalculate or alter numbers.
    2. ANTI-ALARMISM POLICY: Eliminate all "anxious therapist" tone. Day-to-day Resting Heart Rate (RHR) variations (±2 to 4 bpm) and transient HRV drops are normal training adaptations, NOT medical emergencies. Never issue panic-induced "STOP / CANCEL TRAINING" alarms.
    3. ZERO GENERIC WELLNESS PLATITUDES: Do not recommend warm baths, general meditation, mindfulness apps, or non-specific rest. Recommendations must be strictly athletic and physiological (e.g. glycogen replenishment grams, aerobic ceiling BPM, cadence drills).
    4. LANGUAGE & VOICE:
       - System prompt is in English.
       - The output report MUST BE GENERATED ENTIRELY IN UKRAINIAN.
       - Tone: Authoritative, objective, sharp, and athletic.

    OUTPUT STRUCTURE (Strictly enforce the 70 / 15 / 15 proportion):

    ### 🏃 Аналіз тренування (70%)
    - Break down the 1km splits and/or interval laps chronologically.
    - Analyze pacing strategy (even, negative, or positive split).
    - Identify exact kilometer where cardiac drift occurred (Efficiency Factor drop or HR rise at steady pace).
    - Evaluate cardiovascular response to terrain changes (elevation gain Δh vs heart rate surge; downhill recovery efficiency).

    ### ⚖️ Порівняння з бенчмарком (15%)
    - Compare this workout against previous similar sessions from the payload (Pace Δ, HR Δ, EF shift).
    - Diagnose whether current aerobic efficiency is improving, stable, or transiently suppressed.

    ### 🧬 Фізіологічний контекст & Дія на 24г (15%)
    - Causally link workout performance to pre-workout recovery telemetry (sleep stages, deep/REM duration, morning HRV, RHR baseline delta).
    - Conclude with EXACTLY ONE concise, actionable athletic directive for the next 24 hours (e.g. target carbohydrate intake, specific active recovery HR zone).
    """

    /// Formats pre-calculated workout telemetry and physiological context into an optimized user prompt.
    public static func buildUserPrompt(
        analysis: WorkoutAnalysisResult,
        recoveryContext: RecentRecoveryContext? = nil
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
        }

        lines.append("\nINSTRUCTION: Generate the 70/15/15 athletic performance report in Ukrainian strictly following the system guidelines.")
        return lines.joined(separator: "\n")
    }
}
