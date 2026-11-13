import Foundation

// MARK: - Enums & Models

public enum ImmuneSystemState: String, Codable, Sendable, CaseIterable {
    case optimal = "optimal"
    case trainingFatigue = "trainingFatigue"
    case immuneWatch = "immuneWatch"
    case illnessProdrome = "illnessProdrome"

    public var titleUk: String {
        switch self {
        case .optimal: return "Оптимальний стан"
        case .trainingFatigue: return "Тренувальна втома"
        case .immuneWatch: return "Підвищене навантаження"
        case .illnessProdrome: return "Імунна напруга (Передхвороба)"
        }
    }

    public var subtitleUk: String {
        switch self {
        case .optimal:
            return "Усі нічні біомаркери у коридорі норми. Організм відновлений до навантажень."
        case .trainingFatigue:
            return "Ізольоване відхилення без зміни температури. Нормальна реакція на тренування або пізній прийом їжі."
        case .immuneWatch:
            return "Відхилення 2 показників або термальний зсув. Рекомендовано знизити навантаження до Зони 1–2 (пульс ≤ 135 bpm)."
        case .illnessProdrome:
            return "Мультиметричний сигнал інкубаційного періоду або запалення. Скасуйте важкі тренування: пріоритет — сон і гідратація."
        }
    }

    public var actionDirectiveUk: String {
        switch self {
        case .optimal:
            return "Готовий до планових і високоінтенсивних тренувань."
        case .trainingFatigue:
            return "Звичайне відновлення. Дотримуйтесь графіка тренувань без перевантажень."
        case .immuneWatch:
            return "Обмежте інтенсивність. Тільки легке відновлювальне тренування або прогулянка."
        case .illnessProdrome:
            return "Повний день відпочинку. Контролюйте температуру та збільшіть споживання рідини."
        }
    }

    public var systemIcon: String {
        switch self {
        case .optimal: return "checkmark.shield.fill"
        case .trainingFatigue: return "figure.walk.motion"
        case .immuneWatch: return "exclamationmark.triangle.fill"
        case .illnessProdrome: return "cross.case.fill"
        }
    }
}

public enum VitalsPillarStatus: String, Codable, Sendable {
    case inside = "inside"
    case warning = "warning"
    case outlier = "outlier"
    case unmeasured = "unmeasured"
}

public struct VitalsPillarMetric: Codable, Sendable, Equatable {
    public let name: String
    public let currentValue: Double
    public let baselineValue: Double
    public let delta: Double
    public let unit: String
    public let status: VitalsPillarStatus
    public let zScore: Double?

    public init(
        name: String,
        currentValue: Double,
        baselineValue: Double,
        delta: Double,
        unit: String,
        status: VitalsPillarStatus,
        zScore: Double? = nil
    ) {
        self.name = name
        self.currentValue = currentValue
        self.baselineValue = baselineValue
        self.delta = delta
        self.unit = unit
        self.status = status
        self.zScore = zScore
    }
}

public struct NocturnalVitalsInput: Codable, Sendable {
    public let hrvMs: Double?
    public let hrvMethod: HRVMethod?
    public let rhrBpm: Double?
    public let wristTempCelsius: Double?
    public let wristTempDeltaCelsius: Double?
    public let respiratoryRateBpm: Double?
    public let spo2Pct: Double?

    public init(
        hrvMs: Double? = nil,
        hrvMethod: HRVMethod? = nil,
        rhrBpm: Double? = nil,
        wristTempCelsius: Double? = nil,
        wristTempDeltaCelsius: Double? = nil,
        respiratoryRateBpm: Double? = nil,
        spo2Pct: Double? = nil
    ) {
        self.hrvMs = hrvMs
        self.hrvMethod = hrvMethod
        self.rhrBpm = rhrBpm
        self.wristTempCelsius = wristTempCelsius
        self.wristTempDeltaCelsius = wristTempDeltaCelsius
        self.respiratoryRateBpm = respiratoryRateBpm
        self.spo2Pct = spo2Pct
    }

    /// Convenience backward-compatible initializer
    public init(
        hrvMs: Double,
        rhrBpm: Double,
        wristTempCelsius: Double? = nil,
        wristTempDeltaCelsius: Double? = nil,
        respiratoryRateBpm: Double? = nil,
        spo2Pct: Double? = nil
    ) {
        self.hrvMs = hrvMs
        self.hrvMethod = nil
        self.rhrBpm = rhrBpm
        self.wristTempCelsius = wristTempCelsius
        self.wristTempDeltaCelsius = wristTempDeltaCelsius
        self.respiratoryRateBpm = respiratoryRateBpm
        self.spo2Pct = spo2Pct
    }
}

public struct NocturnalVitalsBaseline: Codable, Sendable {
    public let hrvMeanMs: Double
    public let hrvStdDevMs: Double
    public let hrvMethod: HRVMethod?
    public let rhrMeanBpm: Double
    public let rhrStdDevBpm: Double
    public let wristTempMeanCelsius: Double
    public let respiratoryRateMeanBpm: Double
    public let spo2MeanPct: Double

    public init(
        hrvMeanMs: Double = 102.0,
        hrvStdDevMs: Double = 15.0,
        hrvMethod: HRVMethod? = nil,
        rhrMeanBpm: Double = 49.0,
        rhrStdDevBpm: Double = 2.5,
        wristTempMeanCelsius: Double = 36.40,
        respiratoryRateMeanBpm: Double = 14.2,
        spo2MeanPct: Double = 97.8
    ) {
        self.hrvMeanMs = hrvMeanMs
        self.hrvStdDevMs = hrvStdDevMs
        self.hrvMethod = hrvMethod
        self.rhrMeanBpm = rhrMeanBpm
        self.rhrStdDevBpm = rhrStdDevBpm
        self.wristTempMeanCelsius = wristTempMeanCelsius
        self.respiratoryRateMeanBpm = respiratoryRateMeanBpm
        self.spo2MeanPct = spo2MeanPct
    }
}

public struct OvernightVitalsEvaluation: Codable, Sendable, Equatable {
    public let state: ImmuneSystemState
    public let hrvPillar: VitalsPillarMetric
    public let rhrPillar: VitalsPillarMetric
    public let tempPillar: VitalsPillarMetric?
    public let respPillar: VitalsPillarMetric?
    public let spo2Pillar: VitalsPillarMetric?
    public let outliersCount: Int
    public let warningsCount: Int
    public let headline: String
    public let actionDirective: String

    public init(
        state: ImmuneSystemState,
        hrvPillar: VitalsPillarMetric,
        rhrPillar: VitalsPillarMetric,
        tempPillar: VitalsPillarMetric? = nil,
        respPillar: VitalsPillarMetric? = nil,
        spo2Pillar: VitalsPillarMetric? = nil,
        outliersCount: Int,
        warningsCount: Int,
        headline: String,
        actionDirective: String
    ) {
        self.state = state
        self.hrvPillar = hrvPillar
        self.rhrPillar = rhrPillar
        self.tempPillar = tempPillar
        self.respPillar = respPillar
        self.spo2Pillar = spo2Pillar
        self.outliersCount = outliersCount
        self.warningsCount = warningsCount
        self.headline = headline
        self.actionDirective = actionDirective
    }

    public var allPillars: [VitalsPillarMetric] {
        var list: [VitalsPillarMetric] = []
        if hrvPillar.status != .unmeasured { list.append(hrvPillar) }
        if rhrPillar.status != .unmeasured { list.append(rhrPillar) }
        if let temp = tempPillar { list.append(temp) }
        if let resp = respPillar { list.append(resp) }
        if let spo2 = spo2Pillar { list.append(spo2) }
        return list
    }
}

// MARK: - Engine

public enum VitalsAndIllnessEngine {

    /// Artifact-filtered beat-to-beat RMSSD calculation from raw series timestamps (Kubios / Bevel 20% filter)
    public static func computeCleanRMSSD(beats: [(timeSinceStart: TimeInterval, precededByGap: Bool)]) -> Double? {
        guard beats.count >= 10 else { return nil }

        // Extract successive RR intervals (in ms) where not preceded by gap
        var rrIntervals: [Double] = []
        for i in 0..<(beats.count - 1) {
            let current = beats[i]
            let next = beats[i + 1]
            if next.precededByGap { continue }

            let intervalSec = next.timeSinceStart - current.timeSinceStart
            let intervalMs = intervalSec * 1000.0

            // Physiological range: 330ms (180 bpm) - 2000ms (30 bpm)
            if intervalMs >= 330.0 && intervalMs <= 2000.0 {
                rrIntervals.append(intervalMs)
            }
        }

        guard rrIntervals.count >= 10 else { return nil }

        // Successive differences with 20% ectopic beat rejection
        var squaredDiffs: [Double] = []
        for i in 0..<(rrIntervals.count - 1) {
            let rr1 = rrIntervals[i]
            let rr2 = rrIntervals[i + 1]
            let diff = abs(rr2 - rr1)
            let relativeDiff = diff / rr1

            // 20% ectopic filter
            if relativeDiff <= 0.20 {
                squaredDiffs.append(diff * diff)
            }
        }

        guard squaredDiffs.count >= 8 else { return nil }

        let meanSquaredDiff = squaredDiffs.reduce(0.0, +) / Double(squaredDiffs.count)
        let rmssd = sqrt(meanSquaredDiff)
        return rmssd.isFinite && rmssd > 0 ? rmssd : nil
    }

    /// Computes log-transformed Z-score: Z = (ln(HRV) - mean_ln) / max(0.06, std_ln)
    public static func computeLogHRVZScore(
        currentHrvMs: Double,
        historicalHrvMs: [Double] = [],
        fallbackMeanMs: Double = 102.0
    ) -> Double {
        guard currentHrvMs > 0 else { return -3.0 }

        let validHistory = historicalHrvMs.filter { $0 > 0 }
        let logCurrent = log(currentHrvMs)

        if validHistory.count >= 7 {
            let logHistory = validHistory.map { log($0) }
            let meanLog = logHistory.reduce(0.0, +) / Double(logHistory.count)
            let variance = logHistory.reduce(0.0) { $0 + pow($1 - meanLog, 2) } / Double(logHistory.count)
            let stdLog = max(0.06, sqrt(variance))
            return (logCurrent - meanLog) / stdLog
        } else {
            // High-fidelity fallback using athlete's mean and conservative default dispersion
            let meanLog = log(max(10.0, fallbackMeanMs))
            let defaultStdLog = 0.15 // Empirical log-SD for active endurance athletes
            return (logCurrent - meanLog) / defaultStdLog
        }
    }

    /// Evaluates the 5-metric nocturnal corridor & classifies immune/fatigue state (Audit F04).
    ///
    /// Rules:
    /// - Matching HRV method required: never compare RMSSD to SDNN baseline.
    /// - Missing pillars remain `nil` and are never substituted with normal baselines.
    /// - Pre-symptomatic illness prodrome strictly requires >= 3 of 5 nocturnal vitals deviating
    ///   OR wrist temp delta >= +0.40°C with autonomic shift (HRV or RHR outlier).
    /// - Single-metric normal variance without thermal shift is classified as training fatigue.
    public static func evaluateOvernightVitals(
        input: NocturnalVitalsInput,
        baseline: NocturnalVitalsBaseline = NocturnalVitalsBaseline()
    ) -> OvernightVitalsEvaluation {
        var outliersCount = 0
        var warningsCount = 0

        // 1. HRV Pillar (Log-transformed Z-Score with method consistency)
        let hrvPillar: VitalsPillarMetric
        let hrvStatus: VitalsPillarStatus
        if let hrv = input.hrvMs, hrv > 0 {
            let methodsMismatch = (input.hrvMethod != nil && baseline.hrvMethod != nil && input.hrvMethod != baseline.hrvMethod)
            if methodsMismatch {
                // Incompatible method: do not compare RMSSD to SDNN baseline
                hrvStatus = .unmeasured
                hrvPillar = VitalsPillarMetric(
                    name: "HRV (Варіабельність)",
                    currentValue: hrv,
                    baselineValue: baseline.hrvMeanMs,
                    delta: 0.0,
                    unit: "ms",
                    status: .unmeasured,
                    zScore: nil
                )
            } else {
                let zHrv = computeLogHRVZScore(currentHrvMs: hrv, fallbackMeanMs: baseline.hrvMeanMs)
                if zHrv <= -1.35 {
                    hrvStatus = .outlier
                    outliersCount += 1
                } else if zHrv <= -0.85 {
                    hrvStatus = .warning
                    warningsCount += 1
                } else {
                    hrvStatus = .inside
                }
                hrvPillar = VitalsPillarMetric(
                    name: "HRV (Варіабельність)",
                    currentValue: hrv,
                    baselineValue: baseline.hrvMeanMs,
                    delta: hrv - baseline.hrvMeanMs,
                    unit: "ms",
                    status: hrvStatus,
                    zScore: zHrv
                )
            }
        } else {
            hrvStatus = .unmeasured
            hrvPillar = VitalsPillarMetric(
                name: "HRV (Варіабельність)",
                currentValue: 0.0,
                baselineValue: baseline.hrvMeanMs,
                delta: 0.0,
                unit: "ms",
                status: .unmeasured,
                zScore: nil
            )
        }

        // 2. Sleeping RHR Pillar
        let rhrPillar: VitalsPillarMetric
        let rhrStatus: VitalsPillarStatus
        if let rhr = input.rhrBpm, rhr > 0 {
            let rhrDelta = rhr - baseline.rhrMeanBpm
            let zRhr = baseline.rhrStdDevBpm > 0 ? (rhrDelta / baseline.rhrStdDevBpm) : (rhrDelta / 2.5)
            if rhrDelta >= 4.5 || zRhr >= 1.6 {
                rhrStatus = .outlier
                outliersCount += 1
            } else if rhrDelta >= 2.8 {
                rhrStatus = .warning
                warningsCount += 1
            } else {
                rhrStatus = .inside
            }
            rhrPillar = VitalsPillarMetric(
                name: "Пульс уві сні (RHR)",
                currentValue: rhr,
                baselineValue: baseline.rhrMeanBpm,
                delta: rhrDelta,
                unit: "bpm",
                status: rhrStatus,
                zScore: zRhr
            )
        } else {
            rhrStatus = .unmeasured
            rhrPillar = VitalsPillarMetric(
                name: "Пульс уві сні (RHR)",
                currentValue: 0.0,
                baselineValue: baseline.rhrMeanBpm,
                delta: 0.0,
                unit: "bpm",
                status: .unmeasured,
                zScore: nil
            )
        }

        // 3. Wrist Temperature Pillar (Delta in Celsius) - Remains nil if unmeasured
        var tempPillar: VitalsPillarMetric? = nil
        let tempDelta: Double? = input.wristTempDeltaCelsius ?? (input.wristTempCelsius.map { $0 - baseline.wristTempMeanCelsius })
        if let deltaT = tempDelta {
            let tempStatus: VitalsPillarStatus
            if deltaT >= 0.40 {
                tempStatus = .outlier
                outliersCount += 1
            } else if deltaT >= 0.25 {
                tempStatus = .warning
                warningsCount += 1
            } else {
                tempStatus = .inside
            }
            tempPillar = VitalsPillarMetric(
                name: "Температура зап'ястя",
                currentValue: input.wristTempCelsius ?? (baseline.wristTempMeanCelsius + deltaT),
                baselineValue: baseline.wristTempMeanCelsius,
                delta: deltaT,
                unit: "°C",
                status: tempStatus
            )
        }

        // 4. Respiratory Rate Pillar - Remains nil if unmeasured
        var respPillar: VitalsPillarMetric? = nil
        if let rr = input.respiratoryRateBpm {
            let rrDelta = rr - baseline.respiratoryRateMeanBpm
            let respStatus: VitalsPillarStatus
            if rrDelta >= 1.8 {
                respStatus = .outlier
                outliersCount += 1
            } else if rrDelta >= 1.0 {
                respStatus = .warning
                warningsCount += 1
            } else {
                respStatus = .inside
            }
            respPillar = VitalsPillarMetric(
                name: "Частота дихання",
                currentValue: rr,
                baselineValue: baseline.respiratoryRateMeanBpm,
                delta: rrDelta,
                unit: "дих/хв",
                status: respStatus
            )
        }

        // 5. Blood Oxygen (SpO2) Pillar - Remains nil if unmeasured
        var spo2Pillar: VitalsPillarMetric? = nil
        if let spo2 = input.spo2Pct {
            let spo2Delta = spo2 - baseline.spo2MeanPct
            let spo2Status: VitalsPillarStatus
            if spo2 < 95.0 || spo2Delta <= -2.0 {
                spo2Status = .outlier
                outliersCount += 1
            } else if spo2 < 96.0 {
                spo2Status = .warning
                warningsCount += 1
            } else {
                spo2Status = .inside
            }
            spo2Pillar = VitalsPillarMetric(
                name: "Кисень у крові (SpO₂)",
                currentValue: spo2,
                baselineValue: baseline.spo2MeanPct,
                delta: spo2Delta,
                unit: "%",
                status: spo2Status
            )
        }

        // Confluence State Machine Evaluation
        let isWristTempOutlier = (tempPillar?.status == .outlier) || ((tempDelta ?? 0.0) >= 0.40 && tempPillar != nil)
        let isWristTempElevated = (tempPillar?.status == .warning) || ((tempDelta ?? 0.0) >= 0.25 && tempPillar != nil)
        let hasAutonomicShift = (hrvStatus == .outlier) || (rhrStatus == .outlier)

        let state: ImmuneSystemState
        if outliersCount >= 3 || (isWristTempOutlier && hasAutonomicShift) {
            state = .illnessProdrome
        } else if outliersCount == 2 || (isWristTempElevated && (warningsCount >= 1 || outliersCount >= 1)) {
            state = .immuneWatch
        } else if outliersCount == 1 && (tempDelta ?? 0.0) < 0.25 {
            state = .trainingFatigue
        } else {
            state = .optimal
        }

        return OvernightVitalsEvaluation(
            state: state,
            hrvPillar: hrvPillar,
            rhrPillar: rhrPillar,
            tempPillar: tempPillar,
            respPillar: respPillar,
            spo2Pillar: spo2Pillar,
            outliersCount: outliersCount,
            warningsCount: warningsCount,
            headline: state.titleUk,
            actionDirective: state.actionDirectiveUk
        )
    }
}
