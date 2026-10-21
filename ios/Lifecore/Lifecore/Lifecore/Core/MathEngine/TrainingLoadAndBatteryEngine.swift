import Foundation

// MARK: - Models & Zones

public enum ACWRZone: String, Codable, Sendable, CaseIterable {
    case undertraining = "undertraining"
    case sweetSpot = "sweetSpot"
    case caution = "caution"
    case dangerSpike = "dangerSpike"

    public var titleUk: String {
        switch self {
        case .undertraining: return "Низьке навантаження"
        case .sweetSpot: return "Оптимальна зона (Sweet Spot)"
        case .caution: return "Зона ризику"
        case .dangerSpike: return "Небезпечний пік (Spike)"
        }
    }

    public var descriptionUk: String {
        switch self {
        case .undertraining:
            return "Співвідношення < 0.80. Навантаження нижче звичного хронічного рівня. Підходить для розвантажувального тижня (Taper)."
        case .sweetSpot:
            return "Співвідношення 0.80–1.30. Ідеальний баланс прогресивного навантаження та стимулу без ризику травм м'язів та зв'язок."
        case .caution:
            return "Співвідношення 1.31–1.49. Швидке нарощування навантаження. Необхідний посилений контроль відновлення та сну."
        case .dangerSpike:
            return "Співвідношення ≥ 1.50. Гострий сплеск навантаження! Ризик м'язових та зв'язкових ушкоджень зростає у 2–4 рази."
        }
    }

    public var directiveUk: String {
        switch self {
        case .undertraining: return "Можна безпечно додавати об'єм або інтенсивність."
        case .sweetSpot: return "Зберігайте поточний графік та прогресивне навантаження."
        case .caution: return "Не збільшуйте об'єм тренувань у наступні 48 годин."
        case .dangerSpike: return "Зменшіть інтенсивність або додайте повноцінний день відпочинку."
        }
    }
}

public struct ACWREvaluation: Codable, Sendable, Equatable {
    public let acuteLoad: Double       // 7-day EWMA
    public let chronicLoad: Double     // 28-day EWMA
    public let ratio: Double           // Acute / Chronic
    public let zone: ACWRZone
    public let titleUk: String
    public let recommendationUk: String

    public init(
        acuteLoad: Double,
        chronicLoad: Double,
        ratio: Double,
        zone: ACWRZone,
        titleUk: String,
        recommendationUk: String
    ) {
        self.acuteLoad = acuteLoad
        self.chronicLoad = chronicLoad
        self.ratio = ratio
        self.zone = zone
        self.titleUk = titleUk
        self.recommendationUk = recommendationUk
    }
}

public struct EnergyBankPoint: Codable, Sendable, Equatable {
    public let hour: Int              // 0 - 23
    public let batteryLevel: Int      // 5 - 100%

    public init(hour: Int, batteryLevel: Int) {
        self.hour = hour
        self.batteryLevel = batteryLevel
    }
}

public struct EnergyBankEvaluation: Codable, Sendable, Equatable {
    public let wakeBattery: Int
    public let currentBattery: Int
    public let minBattery: Int
    public let timeline: [EnergyBankPoint]
    public let sleepDebtHours: Double
    public let circadianConsistencyScore: Int
    public let basalDrainPct: Double
    public let neatDrainPct: Double
    public let workoutDrainPct: Double
    public let immuneDrainPct: Double

    public init(
        wakeBattery: Int,
        currentBattery: Int,
        minBattery: Int,
        timeline: [EnergyBankPoint],
        sleepDebtHours: Double,
        circadianConsistencyScore: Int = 88,
        basalDrainPct: Double = 0.0,
        neatDrainPct: Double = 0.0,
        workoutDrainPct: Double = 0.0,
        immuneDrainPct: Double = 0.0
    ) {
        self.wakeBattery = wakeBattery
        self.currentBattery = currentBattery
        self.minBattery = minBattery
        self.timeline = timeline
        self.sleepDebtHours = sleepDebtHours
        self.circadianConsistencyScore = circadianConsistencyScore
        self.basalDrainPct = basalDrainPct
        self.neatDrainPct = neatDrainPct
        self.workoutDrainPct = workoutDrainPct
        self.immuneDrainPct = immuneDrainPct
    }
}

// MARK: - Engine

public enum TrainingLoadAndBatteryEngine {

    /// Computes Banister's Training Impulse (TRIMP)
    /// TRIMP = Duration(min) * HR_ratio * 0.64 * exp(1.92 * HR_ratio)
    public static func computeBanisterTRIMP(
        durationMin: Double,
        avgHr: Double,
        restingHr: Double = 49.0,
        maxHr: Double = 192.0,
        isFemale: Bool = false
    ) -> Double {
        guard durationMin > 0 else { return 0.0 }
        let hrRange = max(10.0, maxHr - restingHr)
        let rawRatio = (avgHr - restingHr) / hrRange
        let hrRatio = min(1.0, max(0.0, rawRatio))

        let b: Double = isFemale ? 1.67 : 1.92
        let factor: Double = isFemale ? 0.86 : 0.64

        let trimp = durationMin * hrRatio * factor * exp(b * hrRatio)
        return round(trimp * 10.0) / 10.0
    }

    /// Computes EWMA Acute (7d) vs Chronic (28d) Workload Ratio (ACWR)
    /// Acute lambda = 2 / (7 + 1) = 0.25
    /// Chronic lambda = 2 / (28 + 1) = 0.0689655
    public static func computeEWMAWorkload(
        dailyLoads: [(date: Date, trimp: Double)]
    ) -> ACWREvaluation {
        guard !dailyLoads.isEmpty else {
            return ACWREvaluation(
                acuteLoad: 0.0,
                chronicLoad: 0.0,
                ratio: 1.0,
                zone: .sweetSpot,
                titleUk: ACWRZone.sweetSpot.titleUk,
                recommendationUk: ACWRZone.sweetSpot.directiveUk
            )
        }

        let sorted = dailyLoads.sorted { $0.date < $1.date }
        let lambdaAcute = 2.0 / (7.0 + 1.0)      // 0.25
        let lambdaChronic = 2.0 / (28.0 + 1.0)   // ~0.06897

        var acute = sorted.first?.trimp ?? 0.0
        var chronic = sorted.first?.trimp ?? 0.0

        for i in 1..<sorted.count {
            let load = sorted[i].trimp
            acute = (load * lambdaAcute) + (acute * (1.0 - lambdaAcute))
            chronic = (load * lambdaChronic) + (chronic * (1.0 - lambdaChronic))
        }

        let roundedAcute = round(acute * 10.0) / 10.0
        let roundedChronic = round(chronic * 10.0) / 10.0
        let effectiveChronic = max(15.0, roundedChronic)
        let ratio = round((roundedAcute / effectiveChronic) * 100.0) / 100.0

        let zone: ACWRZone
        if ratio < 0.80 {
            zone = .undertraining
        } else if ratio <= 1.30 {
            zone = .sweetSpot
        } else if ratio <= 1.49 {
            zone = .caution
        } else {
            zone = .dangerSpike
        }

        return ACWREvaluation(
            acuteLoad: roundedAcute,
            chronicLoad: roundedChronic,
            ratio: ratio,
            zone: zone,
            titleUk: zone.titleUk,
            recommendationUk: zone.directiveUk
        )
    }

    /// Continuous 24h Body Battery / Energy Bank trajectory
    public static func computeEnergyBankTimeline(
        wakeRecoveryScore: Int,
        sleepHours: Double,
        targetSleepHours: Double = 7.5,
        pureNeatKcal: Double = 450.0,
        workouts: [(hour: Int, trimp: Double)] = [],
        immuneState: ImmuneSystemState = .optimal,
        currentHour: Int = Calendar.current.component(.hour, from: Date()),
        trimpDrainFactor: Double = 0.32
    ) -> EnergyBankEvaluation {
        // Morning Wake Battery (25 - 100%)
        let sleepRatio = min(1.0, max(0.4, sleepHours / max(5.0, targetSleepHours)))
        let rawWake = Double(wakeRecoveryScore) * 0.78 + (sleepRatio * 22.0)
        let wakeBattery = Int(min(100.0, max(25.0, round(rawWake))))

        var currentLevel = Double(wakeBattery)
        var timeline: [EnergyBankPoint] = []

        // Hourly simulation from 07:00 to 23:00
        var totalBasalDrain = 0.0
        var totalNeatDrain = 0.0
        var totalWorkoutDrain = 0.0
        var totalImmuneDrain = 0.0

        let immuneMultiplier: Double
        switch immuneState {
        case .optimal: immuneMultiplier = 1.0
        case .trainingFatigue: immuneMultiplier = 1.1
        case .immuneWatch: immuneMultiplier = 1.3
        case .illnessProdrome: immuneMultiplier = 1.65
        }

        // Active daytime simulation
        let hourlyNeatRate = (pureNeatKcal / 16.0) * 0.012

        // Build 24-point timeline
        for hour in 0...23 {
            if hour < 7 {
                // Pre-wake overnight baseline
                timeline.append(EnergyBankPoint(hour: hour, batteryLevel: wakeBattery))
                continue
            }

            // Basal hourly circadian decline
            let basalRate: Double
            if hour >= 7 && hour <= 12 {
                basalRate = 2.4
            } else if hour > 12 && hour <= 18 {
                basalRate = 3.2
            } else {
                basalRate = 3.8
            }

            let basalStep = basalRate
            let neatStep = hourlyNeatRate
            let immuneExtraStep = (basalStep + neatStep) * (immuneMultiplier - 1.0)

            totalBasalDrain += basalStep
            totalNeatDrain += neatStep
            totalImmuneDrain += immuneExtraStep

            var hourlyDrop = (basalStep + neatStep + immuneExtraStep)

            // Workouts occurring at this hour
            let hourWorkouts = workouts.filter { $0.hour == hour }
            for w in hourWorkouts {
                let workoutDrop = min(38.0, w.trimp * trimpDrainFactor)
                hourlyDrop += workoutDrop
                totalWorkoutDrain += workoutDrop
            }

            currentLevel = max(5.0, currentLevel - hourlyDrop)
            timeline.append(EnergyBankPoint(hour: hour, batteryLevel: Int(round(currentLevel))))
        }

        let clampedCurrentHour = max(0, min(23, currentHour))
        let batteryAtNow = timeline.first(where: { $0.hour == clampedCurrentHour })?.batteryLevel ?? Int(round(currentLevel))
        let minBattery = timeline.map { $0.batteryLevel }.min() ?? 5

        let sleepDebt = max(0.0, round((targetSleepHours - sleepHours) * 10.0) / 10.0)

        return EnergyBankEvaluation(
            wakeBattery: wakeBattery,
            currentBattery: batteryAtNow,
            minBattery: minBattery,
            timeline: timeline,
            sleepDebtHours: sleepDebt,
            circadianConsistencyScore: 88,
            basalDrainPct: round(totalBasalDrain * 10.0) / 10.0,
            neatDrainPct: round(totalNeatDrain * 10.0) / 10.0,
            workoutDrainPct: round(totalWorkoutDrain * 10.0) / 10.0,
            immuneDrainPct: round(totalImmuneDrain * 10.0) / 10.0
        )
    }
}
