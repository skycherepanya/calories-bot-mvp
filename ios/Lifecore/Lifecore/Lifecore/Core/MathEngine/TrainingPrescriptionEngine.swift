import Foundation

// MARK: - Enums & Core Value Types (Lifecore v3.2)

public enum PrescribedIntensityZone: Int, Codable, Sendable, Comparable, CaseIterable {
    case rest = 0
    case zone1Recovery = 1
    case zone2Easy = 2
    case zone3Tempo = 3
    case zone4Threshold = 4
    case zone5VO2Max = 5

    public static func < (lhs: PrescribedIntensityZone, rhs: PrescribedIntensityZone) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var titleUk: String {
        switch self {
        case .rest: return "Повний відпочинок"
        case .zone1Recovery: return "Зона 1 (Відновлення)"
        case .zone2Easy: return "Зона 2 (Аеробна база)"
        case .zone3Tempo: return "Зона 3 (Темповий)"
        case .zone4Threshold: return "Зона 4 (Лактатний поріг)"
        case .zone5VO2Max: return "Зона 5 (VO₂max / Прискорення)"
        }
    }

    public var shortBadgeUk: String {
        switch self {
        case .rest: return "REST"
        case .zone1Recovery: return "Z1"
        case .zone2Easy: return "Z2"
        case .zone3Tempo: return "Z3"
        case .zone4Threshold: return "Z4"
        case .zone5VO2Max: return "Z5"
        }
    }
}

public enum AdaptationReason: String, Codable, Sendable, Equatable {
    case blockedByIllnessProdrome = "blocked_illness_prodrome"
    case downgradedByVitalsOrBattery = "downgraded_vitals_or_battery"
    case modulatedByHRV = "modulated_hrv"
    case cappedByCaloricDeficit = "capped_caloric_deficit"
    case downgradedByAcuteLoadSpike = "downgraded_acwr_spike"
    case heldByCardiacDrift = "held_cardiac_drift"
    case efficiencyUnlocked = "efficiency_unlocked"
    case optimalProgression = "optimal_progression"
    case externalClubRunAdapted = "external_club_run_adapted"

    public var titleUk: String {
        switch self {
        case .blockedByIllnessProdrome: return "Блоковано: Імунна напруга"
        case .downgradedByVitalsOrBattery: return "Знижено: Вітальні / Заряд < 40%"
        case .modulatedByHRV: return "Модульовано: Знижений HRV"
        case .cappedByCaloricDeficit: return "Ліміт: Глибокий дефіцит ккал"
        case .downgradedByAcuteLoadSpike: return "Розвантаження: Високий ACWR"
        case .heldByCardiacDrift: return "Консолідація: Кардіодрейф > 5%"
        case .efficiencyUnlocked: return "Прогресія EF розблокована"
        case .optimalProgression: return "Оптимальний стимул"
        case .externalClubRunAdapted: return "Адаптовано під Клуб / Свою пробіжку"
        }
    }

    public var bevelHeadlineUk: String {
        switch self {
        case .blockedByIllnessProdrome:
            return "Сьогодні відпочинок — організм бореться з навантаженням"
        case .downgradedByVitalsOrBattery:
            return "Сьогодні краще легке відновлення, а не важке тренування"
        case .modulatedByHRV:
            return "Сьогодні помірний темп замість максимальних зусиль"
        case .cappedByCaloricDeficit:
            return "Енергетичний дефіцит — сьогодні безпечний легкий біг"
        case .downgradedByAcuteLoadSpike:
            return "Висока втома за тиждень — час розвантажитися"
        case .heldByCardiacDrift:
            return "Закріплюємо аеробну базу без збільшення дистанції"
        case .efficiencyUnlocked:
            return "Відмінна форма — серце справляється значно легше"
        case .optimalProgression:
            return "Сьогодні оптимальний день для запланованого тренування"
        case .externalClubRunAdapted:
            return "План адаптовано під твої зовнішні пробіжки"
        }
    }

    public var bevelExplanationUk: String {
        switch self {
        case .blockedByIllnessProdrome:
            return "Нічні показники пульсу та температури вказують на імунну напругу. Організму потрібен сон та спокій, щоб не захворіти."
        case .downgradedByVitalsOrBattery:
            return "Ранковий заряд і якість сну нижчі за норму. Важке тренування збережено на інший день, сьогодні лише спокійний відновлювальний рух."
        case .modulatedByHRV:
            return "Варіабельність серцевого ритму дещо знижена після попередніх навантажень. Працюємо у спокійному темпі без перевантаження ЦНС."
        case .cappedByCaloricDeficit:
            return "Останні дні організм був у помітному дефіциті калорій. Щоб не втрачати м'язову масу та не перевтомлюватися, інтенсивність обмежена."
        case .downgradedByAcuteLoadSpike:
            return "За останні дні накопичилося багато навантаження. Легка пробіжка допоможе швидше відновити свіжість у ногах."
        case .heldByCardiacDrift:
            return "Пульс під кінець пробіжок трохи зростає. Фіксуємо поточну тривалість, щоб серцево-судинна система адаптувалася."
        case .efficiencyUnlocked:
            return "Пульс залишається стабільним, а швидкість зростає. Твоє серце працює все економніше!"
        case .optimalProgression:
            return "Сон, варіабельність серця та заряд енергії у чудовому балансі. Організм повністю готовий до якісної роботи."
        case .externalClubRunAdapted:
            return "Ми врахували нещодавній біг у клубі або власну сесію і плавно підлаштували графік тренувань."
        }
    }

    public var subtitleUk: String {
        switch self {
        case .blockedByIllnessProdrome:
            return "Мультиметричний сигнал передхвороби. Тренування скасовано для захисту міокарда та імунітету."
        case .downgradedByVitalsOrBattery:
            return "Ранковий ресурс знижений. Якісну сесію збережено в черзі на завтра, сьогодні — лише легкий Z1/Z2."
        case .modulatedByHRV:
            return "Парасимпатичний тонус нижче коридору. Інтенсивність обмежена до Зони 3."
        case .cappedByCaloricDeficit:
            return "Середній дефіцит за 3 дні перевищує 650 ккал. Заблоковано Z4/Z5 для захисту ЦНС і м'язів."
        case .downgradedByAcuteLoadSpike:
            return "Гостре навантаження перевищує хронічний поріг. Якісне тренування перенесено, сьогодні — відновлювальний біг."
        case .heldByCardiacDrift:
            return "Медіанний кардіодрейф > 5%. Тривалість зафіксована для укріплення аеробної економічності."
        case .efficiencyUnlocked:
            return "Кардіодрейф ≤ 3.5% та ріст EF > 1.5%. Дозволено підвищення швидкості при тому же пульсі."
        case .optimalProgression:
            return "Всі біомаркери у зеленому коридорі. Виконуємо черговий стимул за планом."
        case .externalClubRunAdapted:
            return "Чергу автоматично скориговано з урахуванням зовнішньої або клубної сесії."
        }
    }
}

public enum WorkoutArchetype: String, Codable, Sendable, CaseIterable, Identifiable {
    case aerobicBasePlusStrides = "aerobic_base_strides"
    case cruiseThresholdIntervals = "cruise_threshold_intervals"
    case recoveryFlush = "recovery_flush"
    case progressiveQualityLongRun = "progressive_quality_long_run"
    case restDay = "rest_day"

    public var id: String { rawValue }

    public static let rollingCycle: [WorkoutArchetype] = [
        .aerobicBasePlusStrides,
        .cruiseThresholdIntervals,
        .recoveryFlush,
        .progressiveQualityLongRun
    ]

    public var cleanHumanTitleUk: String {
        switch self {
        case .aerobicBasePlusStrides: return "Легкий біг з прискореннями"
        case .cruiseThresholdIntervals: return "Порогові інтервали"
        case .recoveryFlush: return "Відновлювальний легкий біг"
        case .progressiveQualityLongRun: return "Довгий прогресивний біг"
        case .restDay: return "День відпочинку"
        }
    }

    public var loadLevelUk: String {
        switch self {
        case .aerobicBasePlusStrides: return "Помірне"
        case .cruiseThresholdIntervals: return "Високе"
        case .recoveryFlush: return "Легке"
        case .progressiveQualityLongRun: return "Високе"
        case .restDay: return "Відновлення"
        }
    }

    public var titleUk: String {
        switch self {
        case .aerobicBasePlusStrides: return "Аеробна база Z2 + Прискорення 6×20с"
        case .cruiseThresholdIntervals: return "Порогові круїз-інтервали Z4"
        case .recoveryFlush: return "Відновлювальний крос Z1/Z2"
        case .progressiveQualityLongRun: return "Прогресивний довгий біг Z2→Z3"
        case .restDay: return "День повного відновлення"
        }
    }

    public var iconName: String {
        switch self {
        case .aerobicBasePlusStrides: return "figure.run"
        case .cruiseThresholdIntervals: return "bolt.heart.fill"
        case .recoveryFlush: return "leaf.fill"
        case .progressiveQualityLongRun: return "flame.fill"
        case .restDay: return "bed.double.fill"
        }
    }

    public var isQualitySession: Bool {
        self == .cruiseThresholdIntervals || self == .progressiveQualityLongRun
    }

    public var minimumRequiredTrimp: Double {
        switch self {
        case .aerobicBasePlusStrides: return 52.0
        case .cruiseThresholdIntervals: return 68.0
        case .recoveryFlush: return 22.0
        case .progressiveQualityLongRun: return 74.0
        case .restDay: return 0.0
        }
    }

    public var minimumRequiredZone: PrescribedIntensityZone {
        switch self {
        case .aerobicBasePlusStrides: return .zone2Easy
        case .cruiseThresholdIntervals: return .zone4Threshold
        case .recoveryFlush: return .zone1Recovery
        case .progressiveQualityLongRun: return .zone3Tempo
        case .restDay: return .rest
        }
    }
}

public struct TrainingGoalConfig: Codable, Sendable, Equatable {
    public var weeklyRunDaysTarget: Int
    public var maxSessionDurationMin: Double
    public var targetACWRRatio: Double

    public init(
        weeklyRunDaysTarget: Int = 4,
        maxSessionDurationMin: Double = 60.0,
        targetACWRRatio: Double = 1.08
    ) {
        self.weeklyRunDaysTarget = min(7, max(2, weeklyRunDaysTarget))
        self.maxSessionDurationMin = min(110.0, max(30.0, maxSessionDurationMin))
        self.targetACWRRatio = min(1.25, max(0.85, targetACWRRatio))
    }
}

public struct RollingQueueState: Codable, Sendable, Equatable {
    public var currentIndex: Int
    public var clubOrCustomRunOverrideToday: Bool
    public var lastAdvancedDateString: String?

    public init(
        currentIndex: Int = 0,
        clubOrCustomRunOverrideToday: Bool = false,
        lastAdvancedDateString: String? = nil
    ) {
        let cycleCount = WorkoutArchetype.rollingCycle.count
        self.currentIndex = ((currentIndex % cycleCount) + cycleCount) % cycleCount
        self.clubOrCustomRunOverrideToday = clubOrCustomRunOverrideToday
        self.lastAdvancedDateString = lastAdvancedDateString
    }

    public var currentArchetype: WorkoutArchetype {
        let cycle = WorkoutArchetype.rollingCycle
        let safeIdx = ((currentIndex % cycle.count) + cycle.count) % cycle.count
        return cycle[safeIdx]
    }

    public func archetype(offset: Int) -> WorkoutArchetype {
        let cycle = WorkoutArchetype.rollingCycle
        let idx = (((currentIndex + offset) % cycle.count) + cycle.count) % cycle.count
        return cycle[idx]
    }
}

public struct DynamicZoneTarget: Codable, Sendable, Equatable {
    public let zone: PrescribedIntensityZone
    public let targetHeartRateBpm: Int
    public let maxHeartRateCapBpm: Int
    public let targetSpeedMetersPerMin: Double
    public let targetPaceSecPerKm: Int

    public init(
        zone: PrescribedIntensityZone,
        targetHeartRateBpm: Int,
        maxHeartRateCapBpm: Int,
        targetSpeedMetersPerMin: Double,
        targetPaceSecPerKm: Int
    ) {
        self.zone = zone
        self.targetHeartRateBpm = targetHeartRateBpm
        self.maxHeartRateCapBpm = maxHeartRateCapBpm
        self.targetSpeedMetersPerMin = targetSpeedMetersPerMin
        self.targetPaceSecPerKm = targetPaceSecPerKm
    }

    public var formattedPaceMinKm: String {
        guard targetPaceSecPerKm > 0 else { return "--:--" }
        let mins = targetPaceSecPerKm / 60
        let secs = targetPaceSecPerKm % 60
        return String(format: "%d:%02d /км", mins, secs)
    }
}

public struct WorkoutSegmentPrescription: Codable, Sendable, Equatable, Identifiable {
    public var id: String { "\(titleUk)_\(durationMin)" }
    public let titleUk: String
    public let durationMin: Double
    public let zone: PrescribedIntensityZone
    public let targetPaceSecPerKm: Int
    public let targetHrCapBpm: Int
    public let instructionUk: String

    public init(
        titleUk: String,
        durationMin: Double,
        zone: PrescribedIntensityZone,
        targetPaceSecPerKm: Int,
        targetHrCapBpm: Int,
        instructionUk: String
    ) {
        self.titleUk = titleUk
        self.durationMin = durationMin
        self.zone = zone
        self.targetPaceSecPerKm = targetPaceSecPerKm
        self.targetHrCapBpm = targetHrCapBpm
        self.instructionUk = instructionUk
    }

    public var formattedPace: String {
        guard targetPaceSecPerKm > 0 else { return "Відпочинок" }
        let m = targetPaceSecPerKm / 60
        let s = targetPaceSecPerKm % 60
        return String(format: "%d:%02d/км", m, s)
    }
}

public struct DailyWorkoutPrescription: Codable, Sendable, Equatable, Identifiable {
    public var id: String { "\(dayOffset)_\(archetype.rawValue)" }
    public let dayOffset: Int                   // 0 = Today, 1 = Next Slot 1, etc.
    public let archetype: WorkoutArchetype
    public let adaptationReason: AdaptationReason
    public let targetTrimp: Double
    public let totalDurationMin: Double
    public let estimatedDistanceKm: Double
    public let maxAllowedZone: PrescribedIntensityZone
    public let preWorkoutCarbsG: Int?
    public let segments: [WorkoutSegmentPrescription]
    public let preservedQueuedArchetype: WorkoutArchetype?

    public init(
        dayOffset: Int,
        archetype: WorkoutArchetype,
        adaptationReason: AdaptationReason,
        targetTrimp: Double,
        totalDurationMin: Double,
        estimatedDistanceKm: Double,
        maxAllowedZone: PrescribedIntensityZone,
        preWorkoutCarbsG: Int?,
        segments: [WorkoutSegmentPrescription],
        preservedQueuedArchetype: WorkoutArchetype? = nil
    ) {
        self.dayOffset = dayOffset
        self.archetype = archetype
        self.adaptationReason = adaptationReason
        self.targetTrimp = targetTrimp
        self.totalDurationMin = totalDurationMin
        self.estimatedDistanceKm = estimatedDistanceKm
        self.maxAllowedZone = maxAllowedZone
        self.preWorkoutCarbsG = preWorkoutCarbsG
        self.segments = segments
        self.preservedQueuedArchetype = preservedQueuedArchetype
    }

    public var cleanTitleUk: String {
        archetype.cleanHumanTitleUk
    }

    public var summaryMetricsUk: String {
        guard totalDurationMin > 0 else { return "Повне відновлення" }
        let dur = Int(round(totalDurationMin))
        let dist = String(format: "%.1f", estimatedDistanceKm)
        return "\(dur) хв • ~\(dist) км • \(maxAllowedZone.shortBadgeUk)"
    }
}

public struct GateEvaluationResult: Codable, Sendable, Equatable {
    public let multiplier: Double
    public let maxZone: PrescribedIntensityZone
    public let durationScale: Double
    public let primaryReason: AdaptationReason
}

public struct TrainingPrescriptionPlan: Codable, Sendable, Equatable {
    public let today: DailyWorkoutPrescription
    public let horizonQueue: [DailyWorkoutPrescription] // Next 3 sessions
    public let ef75Used: Double
    public let dynamicZones: [PrescribedIntensityZone: DynamicZoneTarget]
    public let updatedQueueState: RollingQueueState
}

// MARK: - Deterministic Engine

public enum TrainingPrescriptionEngine {

    /// 2.1 Inverse EWMA ACWR Load Budgeting
    public static func computeDailyTRIMPCap(
        previousAcuteLoad: Double,
        previousChronicLoad: Double,
        targetACWR: Double = 1.08
    ) -> Double {
        let safeAcute = (previousAcuteLoad.isFinite && previousAcuteLoad >= 0.0) ? previousAcuteLoad : 45.0
        let rawChronic = (previousChronicLoad.isFinite && previousChronicLoad >= 0.0) ? previousChronicLoad : 45.0
        let effectiveChronic = max(35.0, rawChronic)
        let rTarget = min(1.25, max(0.85, targetACWR.isFinite ? targetACWR : 1.08))

        let lambdaA = 0.25                  // 2 / (7 + 1)
        let lambdaC = 2.0 / 29.0            // ~0.0689655

        let numerator = (rTarget * (1.0 - lambdaC) * effectiveChronic) - ((1.0 - lambdaA) * safeAcute)
        let denominator = max(0.0001, lambdaA - (rTarget * lambdaC))
        let rawTrimp = numerator / denominator

        // Acute spike safeguard: if prior ACWR > 1.25, enforce recovery ceiling (<= 45 TRIMP)
        let priorRatio = safeAcute / max(20.0, rawChronic)
        if priorRatio > 1.25 {
            return max(0.0, min(45.0, round(max(28.0, rawTrimp) * 10.0) / 10.0))
        }

        let clamped = min(160.0, max(0.0, rawTrimp))
        return round(clamped * 10.0) / 10.0
    }

    /// Computes 30-day rolling 75th percentile Efficiency Factor (EF_75) with safe fallback = 1.15
    public static func computeRollingEF75(
        efSamples: [Double],
        fallbackEF: Double = 1.15
    ) -> Double {
        let valid = efSamples.filter { $0.isFinite && $0 >= 0.65 && $0 <= 2.20 }.sorted()
        guard !valid.isEmpty else {
            return (fallbackEF.isFinite && fallbackEF >= 0.65 && fallbackEF <= 2.20) ? fallbackEF : 1.15
        }
        if valid.count == 1 { return round(valid[0] * 1000.0) / 1000.0 }

        let pos = 0.75 * Double(valid.count - 1)
        let lowerIdx = Int(floor(pos))
        let upperIdx = Int(ceil(pos))
        let fraction = pos - Double(lowerIdx)
        let interpolated = valid[lowerIdx] + fraction * (valid[upperIdx] - valid[lowerIdx])
        return round(interpolated * 1000.0) / 1000.0
    }

    /// 2.3 Automatic Pace & HR Zone Derivation from EF_75 and Heart Rate Reserve
    public static func deriveDynamicZones(
        ef75: Double,
        restingHr: Double = 55.0,
        maxHr: Double = 192.0
    ) -> [PrescribedIntensityZone: DynamicZoneTarget] {
        let safeEF = (ef75.isFinite && ef75 >= 0.65 && ef75 <= 2.20) ? ef75 : 1.15
        let safeRest = (restingHr.isFinite && restingHr >= 35.0 && restingHr <= 95.0) ? restingHr : 55.0
        let safeMax = (maxHr.isFinite && maxHr >= 145.0 && maxHr <= 220.0 && maxHr - safeRest >= 40.0) ? maxHr : 192.0
        let hrr = max(40.0, safeMax - safeRest)

        func makeZone(_ zone: PrescribedIntensityZone, hrrFraction: Double, efMultiplier: Double) -> DynamicZoneTarget {
            let hrTarget = safeRest + (hrrFraction * hrr)
            let speedMetersPerMin = max(80.0, safeEF * hrTarget * efMultiplier)
            let paceSecPerKm = Int(round(60000.0 / speedMetersPerMin))
            let roundedHr = Int(round(hrTarget))
            return DynamicZoneTarget(
                zone: zone,
                targetHeartRateBpm: roundedHr,
                maxHeartRateCapBpm: roundedHr + 3,
                targetSpeedMetersPerMin: round(speedMetersPerMin * 10.0) / 10.0,
                targetPaceSecPerKm: paceSecPerKm
            )
        }

        return [
            .rest: DynamicZoneTarget(zone: .rest, targetHeartRateBpm: Int(round(safeRest)), maxHeartRateCapBpm: Int(round(safeRest + 15)), targetSpeedMetersPerMin: 0.0, targetPaceSecPerKm: 0),
            .zone1Recovery: makeZone(.zone1Recovery, hrrFraction: 0.62, efMultiplier: 0.96),
            .zone2Easy: makeZone(.zone2Easy, hrrFraction: 0.72, efMultiplier: 1.00),
            .zone3Tempo: makeZone(.zone3Tempo, hrrFraction: 0.80, efMultiplier: 1.02),
            .zone4Threshold: makeZone(.zone4Threshold, hrrFraction: 0.86, efMultiplier: 1.05),
            .zone5VO2Max: makeZone(.zone5VO2Max, hrrFraction: 0.93, efMultiplier: 1.12)
        ]
    }

    /// 2.2 Multi-Gate Physiological Override State Machine
    public static func evaluatePhysiologicalGates(
        vitalsState: ImmuneSystemState,
        hrvZScore: Double,
        morningBodyBattery: Int,
        rolling3dEnergyBalanceKcal: Double,
        recentLongRunCardiacDriftsPct: [Double],
        efDelta30dPct: Double
    ) -> GateEvaluationResult {
        let safeZ = hrvZScore.isFinite ? hrvZScore : 0.0
        let safeDeficit = rolling3dEnergyBalanceKcal.isFinite ? rolling3dEnergyBalanceKcal : -300.0
        let safeEfDelta = efDelta30dPct.isFinite ? efDelta30dPct : 0.0

        // Gate 1: Illness & Autonomic Vitals
        if vitalsState == .illnessProdrome {
            return GateEvaluationResult(
                multiplier: 0.0,
                maxZone: .rest,
                durationScale: 0.0,
                primaryReason: .blockedByIllnessProdrome
            )
        }

        var multiplier = 1.0
        var maxZone: PrescribedIntensityZone = .zone5VO2Max
        var durationScale = 1.0
        var reason: AdaptationReason = .optimalProgression

        if vitalsState == .immuneWatch || morningBodyBattery < 40 {
            multiplier = 0.55
            maxZone = .zone2Easy
            reason = .downgradedByVitalsOrBattery
        } else if vitalsState == .trainingFatigue && safeZ < -1.0 {
            multiplier = 0.80
            maxZone = .zone3Tempo
            reason = .modulatedByHRV
        }

        // Gate 2: Caloric Deficit Protection (< -650 kcal/day 3d average)
        if safeDeficit < -650.0 && maxZone > .zone3Tempo {
            maxZone = .zone3Tempo
            multiplier = min(multiplier, 0.85)
            reason = .cappedByCaloricDeficit
        }

        // Gate 3: Cardiac Drift Efficiency Gate (last 3 aerobic runs >= 45 min)
        let validDrifts = recentLongRunCardiacDriftsPct.filter { $0.isFinite && $0 >= 0.0 }.suffix(3).sorted()
        if !validDrifts.isEmpty {
            let medianDrift = validDrifts[validDrifts.count / 2]
            if medianDrift > 5.0 {
                durationScale = 1.0
                if reason == .optimalProgression {
                    reason = .heldByCardiacDrift
                }
            } else if medianDrift <= 3.5 && safeEfDelta > 1.5 && reason == .optimalProgression {
                durationScale = 1.08
                reason = .efficiencyUnlocked
            }
        }

        return GateEvaluationResult(
            multiplier: multiplier,
            maxZone: maxZone,
            durationScale: durationScale,
            primaryReason: reason
        )
    }

    /// 2.5 Pre-Workout Carbohydrate Prescription (for targetTrimp >= 75)
    public static func computePreWorkoutCarbsG(
        targetTrimp: Double,
        carbDriftSlope: Double
    ) -> Int? {
        guard targetTrimp.isFinite && targetTrimp >= 75.0 else { return nil }
        let absSlope = carbDriftSlope.isFinite ? abs(carbDriftSlope) : 1.8
        // Normalize slope: if stored as percentage points per 100g (e.g. 1.8), scale by 0.01 so *10 -> 0.18
        let normalizedSlope = absSlope > 0.25 ? (absSlope / 100.0) : absSlope
        let rawCarbs = (targetTrimp / 1.8) * (1.0 + (normalizedSlope * 10.0))
        let clamped = min(110.0, max(25.0, rawCarbs))
        let rounded5 = Int(round(clamped / 5.0) * 5.0)
        return rounded5
    }

    /// 2.4 Master Prescription & 3-Session Horizon Builder
    public static func prescribeTodayAndHorizon(
        queueState: RollingQueueState,
        config: TrainingGoalConfig = TrainingGoalConfig(),
        previousAcuteLoad: Double,
        previousChronicLoad: Double,
        vitalsState: ImmuneSystemState,
        hrvZScore: Double = 0.0,
        morningBodyBattery: Int = 82,
        rolling3dEnergyBalanceKcal: Double = -350.0,
        efSamples: [Double] = [],
        recentLongRunDriftsPct: [Double] = [],
        efDelta30dPct: Double = 0.0,
        restingHr: Double = 55.0,
        maxHr: Double = 192.0,
        carbDriftSlope: Double = -1.8
    ) -> TrainingPrescriptionPlan {
        let ef75 = computeRollingEF75(efSamples: efSamples)
        let zones = deriveDynamicZones(ef75: ef75, restingHr: restingHr, maxHr: maxHr)
        let trimpBudget = computeDailyTRIMPCap(
            previousAcuteLoad: previousAcuteLoad,
            previousChronicLoad: previousChronicLoad,
            targetACWR: config.targetACWRRatio
        )
        let gate = evaluatePhysiologicalGates(
            vitalsState: vitalsState,
            hrvZScore: hrvZScore,
            morningBodyBattery: morningBodyBattery,
            rolling3dEnergyBalanceKcal: rolling3dEnergyBalanceKcal,
            recentLongRunCardiacDriftsPct: recentLongRunDriftsPct,
            efDelta30dPct: efDelta30dPct
        )

        let effectiveTrimp = round((trimpBudget * gate.multiplier) * 10.0) / 10.0
        let queuedArchetype = queueState.currentArchetype
        let priorRatio = previousAcuteLoad / max(20.0, previousChronicLoad)

        // Resolve Today's Archetype (Non-destructive deferral of Quality sessions)
        let todayArchetype: WorkoutArchetype
        let todayReason: AdaptationReason
        var preservedQuality: WorkoutArchetype? = nil

        if gate.maxZone == .rest || effectiveTrimp < 15.0 {
            todayArchetype = .restDay
            todayReason = gate.primaryReason
            preservedQuality = queuedArchetype
        } else if queueState.clubOrCustomRunOverrideToday {
            todayArchetype = .aerobicBasePlusStrides
            todayReason = .externalClubRunAdapted
        } else if queuedArchetype.isQualitySession &&
                  (effectiveTrimp < queuedArchetype.minimumRequiredTrimp || gate.maxZone < queuedArchetype.minimumRequiredZone) {
            // Defer quality session in queue, inject RecoveryFlush today
            todayArchetype = .recoveryFlush
            todayReason = (priorRatio > 1.25 && gate.primaryReason == .optimalProgression)
                ? .downgradedByAcuteLoadSpike
                : gate.primaryReason
            preservedQuality = queuedArchetype
        } else {
            todayArchetype = queuedArchetype
            todayReason = gate.primaryReason
        }

        let todayPrescription = buildWorkoutPrescription(
            dayOffset: 0,
            archetype: todayArchetype,
            reason: todayReason,
            targetTrimp: todayArchetype == .restDay ? 0.0 : max(28.0, effectiveTrimp),
            maxSessionDurationMin: config.maxSessionDurationMin * (gate.durationScale > 0 ? gate.durationScale : 1.0),
            maxAllowedZone: gate.maxZone,
            zones: zones,
            carbDriftSlope: carbDriftSlope,
            preservedQueuedArchetype: preservedQuality
        )

        // Build 3-Session Rolling Horizon
        // If today deferred a quality session, horizon starts at offset 0 (the preserved quality session)
        let startOffset = (preservedQuality != nil) ? 0 : 1
        var horizon: [DailyWorkoutPrescription] = []
        for step in 0..<3 {
            let arch = queueState.archetype(offset: startOffset + step)
            let nominalTrimp: Double = {
                switch arch {
                case .aerobicBasePlusStrides: return 68.0
                case .cruiseThresholdIntervals: return 88.0
                case .recoveryFlush: return 42.0
                case .progressiveQualityLongRun: return 96.0
                case .restDay: return 0.0
                }
            }()
            horizon.append(
                buildWorkoutPrescription(
                    dayOffset: step + 1,
                    archetype: arch,
                    reason: .optimalProgression,
                    targetTrimp: nominalTrimp,
                    maxSessionDurationMin: config.maxSessionDurationMin,
                    maxAllowedZone: .zone5VO2Max,
                    zones: zones,
                    carbDriftSlope: carbDriftSlope,
                    preservedQueuedArchetype: nil
                )
            )
        }

        return TrainingPrescriptionPlan(
            today: todayPrescription,
            horizonQueue: horizon,
            ef75Used: ef75,
            dynamicZones: zones,
            updatedQueueState: queueState
        )
    }

    /// Reconciles an external or club workout and advances the queue pointer if stimulus matches within +/- 20%
    public static func reconcileExternalWorkout(
        queueState: RollingQueueState,
        loggedWorkoutTrimp: Double,
        currentTargetTrimp: Double,
        isClubOrCustomOverride: Bool = false
    ) -> RollingQueueState {
        var nextState = queueState
        let target = max(30.0, currentTargetTrimp)
        let ratio = loggedWorkoutTrimp / target
        if isClubOrCustomOverride || (ratio >= 0.80 && ratio <= 1.35) {
            nextState.currentIndex = (queueState.currentIndex + 1) % WorkoutArchetype.rollingCycle.count
            nextState.clubOrCustomRunOverrideToday = false
        }
        return nextState
    }

    // MARK: - Internal Segment Builder

    private static func buildWorkoutPrescription(
        dayOffset: Int,
        archetype: WorkoutArchetype,
        reason: AdaptationReason,
        targetTrimp: Double,
        maxSessionDurationMin: Double,
        maxAllowedZone: PrescribedIntensityZone,
        zones: [PrescribedIntensityZone: DynamicZoneTarget],
        carbDriftSlope: Double,
        preservedQueuedArchetype: WorkoutArchetype?
    ) -> DailyWorkoutPrescription {
        let z1 = zones[.zone1Recovery]!
        let z2 = zones[.zone2Easy]!
        let z3 = zones[.zone3Tempo]!
        let z4 = zones[.zone4Threshold]!
        let z5 = zones[.zone5VO2Max]!

        var segments: [WorkoutSegmentPrescription] = []
        var totalMin: Double = 0.0
        var totalMeters: Double = 0.0

        switch archetype {
        case .restDay:
            segments = [
                WorkoutSegmentPrescription(
                    titleUk: "Повний відпочинок та гідратація",
                    durationMin: 0.0,
                    zone: .rest,
                    targetPaceSecPerKm: 0,
                    targetHrCapBpm: z1.targetHeartRateBpm,
                    instructionUk: "День без бігового навантаження. Фокус на сні та відновленні ВНС."
                )
            ]
        case .recoveryFlush:
            let dur = min(40.0, max(30.0, round(maxSessionDurationMin * 0.60)))
            segments = [
                WorkoutSegmentPrescription(
                    titleUk: "Легкий відновлювальний біг Z1",
                    durationMin: dur,
                    zone: .zone1Recovery,
                    targetPaceSecPerKm: z1.targetPaceSecPerKm,
                    targetHrCapBpm: z1.maxHeartRateCapBpm,
                    instructionUk: "Суворий контроль пульсу до \(z1.maxHeartRateCapBpm) bpm для парасимпатичного відгуку."
                )
            ]
            totalMin = dur
            totalMeters = dur * z1.targetSpeedMetersPerMin

        case .aerobicBasePlusStrides:
            let baseMin = min(50.0, max(40.0, round(maxSessionDurationMin * 0.80)))
            let stridesMin = 6.0
            segments = [
                WorkoutSegmentPrescription(
                    titleUk: "Аеробна база Z2",
                    durationMin: baseMin,
                    zone: .zone2Easy,
                    targetPaceSecPerKm: z2.targetPaceSecPerKm,
                    targetHrCapBpm: z2.maxHeartRateCapBpm,
                    instructionUk: "Монолітний біг у Зоні 2 без кардіодрейфу."
                ),
                WorkoutSegmentPrescription(
                    titleUk: "Нейром'язові прискорення 6×20с",
                    durationMin: stridesMin,
                    zone: min(maxAllowedZone, .zone5VO2Max),
                    targetPaceSecPerKm: z5.targetPaceSecPerKm,
                    targetHrCapBpm: z5.maxHeartRateCapBpm,
                    instructionUk: "6 легких вільних прискорень по 20с (60с підтюпцем між ними) для бігової економічності."
                )
            ]
            totalMin = baseMin + stridesMin
            totalMeters = (baseMin * z2.targetSpeedMetersPerMin) + (2.0 * z5.targetSpeedMetersPerMin) + (4.0 * z1.targetSpeedMetersPerMin)

        case .cruiseThresholdIntervals:
            let reps = maxSessionDurationMin >= 55.0 ? 4 : 3
            let workMin = Double(reps) * 6.0
            let restMin = Double(reps) * 1.5
            segments = [
                WorkoutSegmentPrescription(
                    titleUk: "Розминка Z2",
                    durationMin: 10.0,
                    zone: .zone2Easy,
                    targetPaceSecPerKm: z2.targetPaceSecPerKm,
                    targetHrCapBpm: z2.maxHeartRateCapBpm,
                    instructionUk: "Плавний вхід у робочий пульсовий коридор."
                ),
                WorkoutSegmentPrescription(
                    titleUk: "Круїз-інтервали \(reps)×6 хв у Z4",
                    durationMin: workMin + restMin,
                    zone: .zone4Threshold,
                    targetPaceSecPerKm: z4.targetPaceSecPerKm,
                    targetHrCapBpm: z4.maxHeartRateCapBpm,
                    instructionUk: "\(reps) відрізки по 6 хв на лактатному порозі через 90с легкого бігу."
                ),
                WorkoutSegmentPrescription(
                    titleUk: "Заминка Z1",
                    durationMin: 10.0,
                    zone: .zone1Recovery,
                    targetPaceSecPerKm: z1.targetPaceSecPerKm,
                    targetHrCapBpm: z1.maxHeartRateCapBpm,
                    instructionUk: "Зниження ЧСС та утилізація лактату."
                )
            ]
            totalMin = 20.0 + workMin + restMin
            totalMeters = (10.0 * z2.targetSpeedMetersPerMin) + (workMin * z4.targetSpeedMetersPerMin) + ((restMin + 10.0) * z1.targetSpeedMetersPerMin)

        case .progressiveQualityLongRun:
            let totalDur = min(75.0, max(60.0, round(maxSessionDurationMin * 1.15)))
            let z2Dur = round(totalDur * 0.75)
            let z3Dur = totalDur - z2Dur
            segments = [
                WorkoutSegmentPrescription(
                    titleUk: "Перші 75%: Стійка Зона 2",
                    durationMin: z2Dur,
                    zone: .zone2Easy,
                    targetPaceSecPerKm: z2.targetPaceSecPerKm,
                    targetHrCapBpm: z2.maxHeartRateCapBpm,
                    instructionUk: "Контроль аеробної бази без перевищення \(z2.maxHeartRateCapBpm) bpm."
                ),
                WorkoutSegmentPrescription(
                    titleUk: "Фінальні 25%: Прогресія у Z3",
                    durationMin: z3Dur,
                    zone: .zone3Tempo,
                    targetPaceSecPerKm: z3.targetPaceSecPerKm,
                    targetHrCapBpm: z3.maxHeartRateCapBpm,
                    instructionUk: "Плавний накат лише за умови утримання пульсу в коридорі."
                )
            ]
            totalMin = totalDur
            totalMeters = (z2Dur * z2.targetSpeedMetersPerMin) + (z3Dur * z3.targetSpeedMetersPerMin)
        }

        let distKm = round((totalMeters / 1000.0) * 10.0) / 10.0
        let carbs = computePreWorkoutCarbsG(targetTrimp: targetTrimp, carbDriftSlope: carbDriftSlope)

        return DailyWorkoutPrescription(
            dayOffset: dayOffset,
            archetype: archetype,
            adaptationReason: reason,
            targetTrimp: round(targetTrimp),
            totalDurationMin: totalMin,
            estimatedDistanceKm: distKm,
            maxAllowedZone: maxAllowedZone,
            preWorkoutCarbsG: carbs,
            segments: segments,
            preservedQueuedArchetype: preservedQueuedArchetype
        )
    }
}
