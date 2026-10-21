import Foundation

// MARK: - Readiness & Recovery Models

public struct RecoveryEvaluation: Sendable, Codable {
    public let score: Int // 0 - 100%
    public let state: RecoveryState
    public let hrvZScore: Double?
    public let rhrDeltaBpm: Double?
    public let sleepDurationHours: Double
    public let deepSleepHours: Double
    public let remSleepHours: Double
    public let narrative: String

    public enum RecoveryState: String, Sendable, Codable {
        case prime = "optimal"        // 80 - 100%
        case moderate = "adequate"    // 60 - 79%
        case low = "recovery_needed"  // 0 - 59%
    }

    public init(
        score: Int,
        state: RecoveryState,
        hrvZScore: Double?,
        rhrDeltaBpm: Double?,
        sleepDurationHours: Double,
        deepSleepHours: Double,
        remSleepHours: Double,
        narrative: String
    ) {
        self.score = score
        self.state = state
        self.hrvZScore = hrvZScore
        self.rhrDeltaBpm = rhrDeltaBpm
        self.sleepDurationHours = sleepDurationHours
        self.deepSleepHours = deepSleepHours
        self.remSleepHours = remSleepHours
        self.narrative = narrative
    }
}

public struct StrainEvaluation: Sendable, Codable {
    public let score100: Double // 0 - 100%
    public let whoopScale21: Double // 0.0 - 21.0
    public let neatKcal: Double
    public let workoutKcal: Double
    public let totalActiveKcal: Double

    public init(
        score100: Double,
        whoopScale21: Double,
        neatKcal: Double,
        workoutKcal: Double,
        totalActiveKcal: Double
    ) {
        self.score100 = score100
        self.whoopScale21 = whoopScale21
        self.neatKcal = neatKcal
        self.workoutKcal = workoutKcal
        self.totalActiveKcal = totalActiveKcal
    }
}

public struct RollingWeightTrend: Sendable, Codable {
    public let latestWeightKg: Double
    public let rollingAvg7d: Double?
    public let rollingAvg14d: Double?
    public let net7dChangeKg: Double?
    public let isWaterRetentionSuspected: Bool

    public init(
        latestWeightKg: Double,
        rollingAvg7d: Double?,
        rollingAvg14d: Double?,
        net7dChangeKg: Double?,
        isWaterRetentionSuspected: Bool
    ) {
        self.latestWeightKg = latestWeightKg
        self.rollingAvg7d = rollingAvg7d
        self.rollingAvg14d = rollingAvg14d
        self.net7dChangeKg = net7dChangeKg
        self.isWaterRetentionSuspected = isWaterRetentionSuspected
    }
}

public struct DateWeightSample: Sendable, Codable, Identifiable {
    public var id: Date { date }
    public let date: Date
    public let weightKg: Double

    public init(date: Date, weightKg: Double) {
        self.date = date
        self.weightKg = weightKg
    }
}

public struct TrendWeightPoint: Sendable, Codable, Identifiable {
    public var id: Date { date }
    public let date: Date
    public let rawWeightKg: Double
    public let rolling7dKg: Double?
    public let rolling14dKg: Double?
    public let isWaterSpike: Bool

    public init(
        date: Date,
        rawWeightKg: Double,
        rolling7dKg: Double?,
        rolling14dKg: Double?,
        isWaterSpike: Bool
    ) {
        self.date = date
        self.rawWeightKg = rawWeightKg
        self.rolling7dKg = rolling7dKg
        self.rolling14dKg = rolling14dKg
        self.isWaterSpike = isWaterSpike
    }
}

public struct DateAutonomicSample: Sendable, Codable, Identifiable {
    public var id: Date { date }
    public let date: Date
    public let hrvMs: Double?
    public let rhrBpm: Double?
    public let hrvBaselineMean: Double?
    public let hrvBaselineLower: Double?
    public let hrvBaselineUpper: Double?

    public init(
        date: Date,
        hrvMs: Double?,
        rhrBpm: Double?,
        hrvBaselineMean: Double? = nil,
        hrvBaselineLower: Double? = nil,
        hrvBaselineUpper: Double? = nil
    ) {
        self.date = date
        self.hrvMs = hrvMs
        self.rhrBpm = rhrBpm
        self.hrvBaselineMean = hrvBaselineMean
        self.hrvBaselineLower = hrvBaselineLower
        self.hrvBaselineUpper = hrvBaselineUpper
    }
}

public struct AerobicEfficiencyTrendSample: Sendable, Codable, Identifiable {
    public let id: UUID
    public let date: Date
    public let workoutName: String
    public let distanceKm: Double
    public let durationMin: Double
    public let avgPaceMinKm: Double
    public let avgHrBpm: Double
    public let efficiencyFactor: Double // m/min/bpm
    public let aerobicDecouplingPct: Double? // % drift

    public init(
        id: UUID = UUID(),
        date: Date,
        workoutName: String,
        distanceKm: Double,
        durationMin: Double,
        avgPaceMinKm: Double,
        avgHrBpm: Double,
        efficiencyFactor: Double,
        aerobicDecouplingPct: Double? = nil
    ) {
        self.id = id
        self.date = date
        self.workoutName = workoutName
        self.distanceKm = distanceKm
        self.durationMin = durationMin
        self.avgPaceMinKm = avgPaceMinKm
        self.avgHrBpm = avgHrBpm
        self.efficiencyFactor = efficiencyFactor
        self.aerobicDecouplingPct = aerobicDecouplingPct
    }
}

// MARK: - Readiness Calculator

public enum ReadinessCalculator {

    /// Default baseline for Sasha (HRV ~102ms, RHR ~49bpm, Target Sleep 7.5h)
    public struct Baseline: Sendable {
        public let avgHrvSDNN: Double
        public let stdDevHrv: Double
        public let avgRHR: Double
        public let targetSleepHours: Double
        public let targetDeepHours: Double
        public let targetRemHours: Double

        public static let sasha = Baseline(
            avgHrvSDNN: 102.0,
            stdDevHrv: 15.0,
            avgRHR: 49.0,
            targetSleepHours: 7.5,
            targetDeepHours: 1.2,
            targetRemHours: 1.5
        )

        public init(
            avgHrvSDNN: Double = 102.0,
            stdDevHrv: Double = 15.0,
            avgRHR: Double = 49.0,
            targetSleepHours: Double = 7.5,
            targetDeepHours: Double = 1.2,
            targetRemHours: Double = 1.5
        ) {
            self.avgHrvSDNN = avgHrvSDNN
            self.stdDevHrv = stdDevHrv
            self.avgRHR = avgRHR
            self.targetSleepHours = targetSleepHours
            self.targetDeepHours = targetDeepHours
            self.targetRemHours = targetRemHours
        }
    }

    /// Computes deterministic autonomic Recovery Score (0 - 100%).
    public static func computeRecovery(
        morningHrv: Double?,
        morningRhr: Double?,
        totalSleepHours: Double,
        deepSleepHours: Double,
        remSleepHours: Double,
        baseline: Baseline = .sasha,
        weights: ReadinessWeightVector = ReadinessWeightVector()
    ) -> RecoveryEvaluation {
        // 1. HRV Score (Weight: weights.hrvWeight)
        let hrvZ: Double?
        let hrvScore: Double
        if let hrv = morningHrv {
            let z = (hrv - baseline.avgHrvSDNN) / max(1.0, baseline.stdDevHrv)
            hrvZ = round(z * 100) / 100
            // Map z in [-2.5, +2.0] to [20, 100]
            let normalized = 80.0 + (z * 12.0)
            hrvScore = min(100.0, max(15.0, normalized))
        } else {
            hrvZ = nil
            hrvScore = 75.0 // Neutral fallback
        }

        // 2. RHR Score (Weight: weights.rhrWeight)
        let rhrDelta: Double?
        let rhrScore: Double
        if let rhr = morningRhr {
            let delta = rhr - baseline.avgRHR
            rhrDelta = round(delta * 10) / 10
            if delta <= 0 {
                rhrScore = 100.0
            } else if delta <= 3.0 {
                // Normal athletic fluctuation (no alarmism)
                rhrScore = 95.0 - (delta * 3.0)
            } else if delta <= 6.0 {
                // Moderate elevation
                rhrScore = 85.0 - ((delta - 3.0) * 5.0)
            } else {
                // High autonomic strain
                rhrScore = max(20.0, 70.0 - ((delta - 6.0) * 8.0))
            }
        } else {
            rhrDelta = nil
            rhrScore = 75.0
        }

        // 3. Sleep Duration Score (Weight: weights.sleepDurationWeight)
        let durationRatio = min(1.2, totalSleepHours / max(1.0, baseline.targetSleepHours))
        let sleepDurationScore = min(100.0, durationRatio * 85.0)

        // 4. Sleep Architecture Score (Weight: weights.sleepArchitectureWeight)
        let deepRatio = min(1.5, deepSleepHours / max(0.1, baseline.targetDeepHours))
        let remRatio = min(1.5, remSleepHours / max(0.1, baseline.targetRemHours))
        let architectureScore = min(100.0, ((deepRatio + remRatio) / 2.0) * 100.0)

        // Composite Weighted Score
        let rawComposite = (hrvScore * weights.hrvWeight) + (rhrScore * weights.rhrWeight) + (sleepDurationScore * weights.sleepDurationWeight) + (architectureScore * weights.sleepArchitectureWeight)
        let finalScore = Int(min(100, max(0, round(rawComposite))))

        let state: RecoveryEvaluation.RecoveryState
        if finalScore >= 80 {
            state = .prime
        } else if finalScore >= 60 {
            state = .moderate
        } else {
            state = .low
        }

        let narrative: String
        switch state {
        case .prime:
            narrative = "Готовність висока. Вегетативна система стабільна (HRV: \(morningHrv != nil ? "\(Int(morningHrv!)) ms" : "OK"), RHR: \(morningRhr != nil ? "\(Int(morningRhr!)) bpm" : "OK")). Можна виконувати планове тренування."
        case .moderate:
            narrative = "Адаптивна готовність. Невеликі коливання пульсу спокою або сну. Зберігайте планову інтенсивність, контролюючи пульсові зони."
        case .low:
            narrative = "Знижене відновлення. Спостерігається дефіцит глибокого сну або просадка варіабельності. Рекомендовано акцент на активне відновлення (Zone 1/2)."
        }

        return RecoveryEvaluation(
            score: finalScore,
            state: state,
            hrvZScore: hrvZ,
            rhrDeltaBpm: rhrDelta,
            sleepDurationHours: round(totalSleepHours * 10) / 10,
            deepSleepHours: round(deepSleepHours * 10) / 10,
            remSleepHours: round(remSleepHours * 10) / 10,
            narrative: narrative
        )
    }

    /// Alias for computeRecovery
    public static func evaluateRecovery(
        morningHrv: Double?,
        morningRhr: Double?,
        totalSleepHours: Double,
        deepSleepHours: Double,
        remSleepHours: Double,
        baseline: Baseline = .sasha,
        weights: ReadinessWeightVector = ReadinessWeightVector()
    ) -> RecoveryEvaluation {
        return computeRecovery(
            morningHrv: morningHrv,
            morningRhr: morningRhr,
            totalSleepHours: totalSleepHours,
            deepSleepHours: deepSleepHours,
            remSleepHours: remSleepHours,
            baseline: baseline,
            weights: weights
        )
    }

    /// Pure NEAT Isolation: NEAT = max(0, daily_active_kcal - sum(workout_kcal))
    public static func isolatePureNEAT(dailyActiveKcal: Double, workoutActiveKcals: [Double]) -> Double {
        let totalWorkoutKcal = workoutActiveKcals.reduce(0.0, +)
        let neat = max(0.0, dailyActiveKcal - totalWorkoutKcal)
        return round(neat * 10) / 10
    }

    /// Computes Cardiovascular Strain Score combining workouts load and NEAT lifestyle movement.
    public static func computeStrain(
        dailyActiveKcal: Double,
        workouts: [(durationMin: Double, avgHr: Double?, activeKcal: Double)]
    ) -> StrainEvaluation {
        let workoutKcals = workouts.map { $0.activeKcal }
        let totalWorkoutKcal = workoutKcals.reduce(0.0, +)
        let neatKcal = isolatePureNEAT(dailyActiveKcal: dailyActiveKcal, workoutActiveKcals: workoutKcals)

        // Workout cardiovascular strain points
        var workoutPoints: Double = 0.0
        for w in workouts {
            let hrWeight: Double
            if let hr = w.avgHr, hr > 100 {
                // Exponential cardiovascular load based on HR intensity
                hrWeight = pow(hr / 130.0, 2.5)
            } else {
                hrWeight = 1.0
            }
            workoutPoints += (w.durationMin * hrWeight) * 0.5
        }

        // NEAT activity points (100 kcal ~ 2.5 strain points)
        let neatPoints = (neatKcal / 100.0) * 2.5

        let totalRawPoints = workoutPoints + neatPoints

        // Map to 0 - 100% and Whoop-scale 0.0 - 21.0
        let score100 = min(100.0, round((totalRawPoints / 1.5) * 10) / 10)
        let scale21 = min(21.0, round((21.0 * (1.0 - exp(-totalRawPoints / 75.0))) * 10) / 10)

        return StrainEvaluation(
            score100: score100,
            whoopScale21: scale21,
            neatKcal: neatKcal,
            workoutKcal: round(totalWorkoutKcal * 10) / 10,
            totalActiveKcal: round(dailyActiveKcal * 10) / 10
        )
    }

    /// Computes 7-day and 14-day rolling body weight averages to filter water & glycogen noise.
    public static func computeRollingWeight(weights: [Double]) -> RollingWeightTrend? {
        guard let latest = weights.last else { return nil }

        let n = weights.count
        let avg7d: Double?
        if n >= 3 {
            let window7 = weights.suffix(min(7, n))
            avg7d = round((window7.reduce(0.0, +) / Double(window7.count)) * 100) / 100
        } else {
            avg7d = nil
        }

        let avg14d: Double?
        if n >= 7 {
            let window14 = weights.suffix(min(14, n))
            avg14d = round((window14.reduce(0.0, +) / Double(window14.count)) * 100) / 100
        } else {
            avg14d = nil
        }

        let net7dChange: Double?
        if let avg7 = avg7d, n >= 7 {
            let previousAvg7 = weights.prefix(max(1, n - 7)).suffix(min(7, n - 7))
            if !previousAvg7.isEmpty {
                let prev = previousAvg7.reduce(0.0, +) / Double(previousAvg7.count)
                net7dChange = round((avg7 - prev) * 100) / 100
            } else {
                net7dChange = nil
            }
        } else {
            net7dChange = nil
        }

        // Acute water spike suspicion: day-to-day jump > 1.2 kg while 7d average is stable
        let isWaterSpike: Bool
        if let avg7 = avg7d {
            isWaterSpike = abs(latest - avg7) >= 1.2
        } else {
            isWaterSpike = false
        }

        return RollingWeightTrend(
            latestWeightKg: latest,
            rollingAvg7d: avg7d,
            rollingAvg14d: avg14d,
            net7dChangeKg: net7dChange,
            isWaterRetentionSuspected: isWaterSpike
        )
    }

    /// Computes full longitudinal weight points with 7d and 14d rolling averages and water retention spike flags.
    public static func computeLongitudinalWeightTrend(samples: [DateWeightSample]) -> [TrendWeightPoint] {
        guard !samples.isEmpty else { return [] }
        let sorted = samples.sorted(by: { $0.date < $1.date })
        var points: [TrendWeightPoint] = []

        for i in 0..<sorted.count {
            let current = sorted[i]
            let raw = current.weightKg

            // 7-day rolling window: samples within [date - 6 days ... date]
            let calendar = Calendar.current
            let start7 = calendar.date(byAdding: .day, value: -6, to: current.date) ?? current.date
            let window7 = sorted[0...i].filter { $0.date >= start7 }
            let avg7d: Double?
            if window7.count >= 2 {
                avg7d = round((window7.map(\.weightKg).reduce(0.0, +) / Double(window7.count)) * 100) / 100
            } else {
                avg7d = nil
            }

            // 14-day rolling window: samples within [date - 13 days ... date]
            let start14 = calendar.date(byAdding: .day, value: -13, to: current.date) ?? current.date
            let window14 = sorted[0...i].filter { $0.date >= start14 }
            let avg14d: Double?
            if window14.count >= 4 {
                avg14d = round((window14.map(\.weightKg).reduce(0.0, +) / Double(window14.count)) * 100) / 100
            } else {
                avg14d = nil
            }

            // Acute water retention spike detection: single-day raw weight >= 1.2 kg above 7d rolling average
            let isWaterSpike: Bool
            if let avg7 = avg7d {
                isWaterSpike = (raw - avg7) >= 1.2
            } else {
                isWaterSpike = false
            }

            points.append(
                TrendWeightPoint(
                    date: current.date,
                    rawWeightKg: raw,
                    rolling7dKg: avg7d,
                    rolling14dKg: avg14d,
                    isWaterSpike: isWaterSpike
                )
            )
        }

        return points
    }
}
