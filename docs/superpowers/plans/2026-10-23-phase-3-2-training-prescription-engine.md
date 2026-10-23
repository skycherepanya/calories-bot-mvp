# Phase 3.2 (Lifecore v3.2): Deterministic Adaptive Training Prescription Engine Implementation Roadmap

> **For Flash Coding Models (Token Economy & Execution Protocol):**
> - Execute the **4 sequential Phases (Phase A → Phase B → Phase C → Phase D)** strictly in order.
> - **Zero Search Overhead:** The Xcode project uses `PBXFileSystemSynchronizedRootGroup` at `ios/Lifecore/Lifecore/Lifecore`. Any file created inside this tree compiles automatically without modifying `project.pbxproj`. Do NOT run `find` or `grep`; read and write only the exact paths specified in each work package.
> - **Build Checkpoints:** Run `xcodebuild` only at the end of **Phase A** and **Phase D** to conserve execution time and tokens.

---

## Phase A: Math Engine & Verification Suite 12

### Work Package A1: Implement `TrainingPrescriptionEngine.swift`
* **Exact File Path:** `ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/TrainingPrescriptionEngine.swift` (NEW)
* **Input/Output Type Signatures:**
  - `TrainingPrescriptionEngine.computeDailyTRIMPCap(previousAcuteLoad: Double, previousChronicLoad: Double, targetACWR: Double = 1.08) -> Double`
  - `TrainingPrescriptionEngine.computeRollingEF75(efSamples: [Double], fallbackEF: Double = 1.15) -> Double`
  - `TrainingPrescriptionEngine.deriveDynamicZones(ef75: Double, restingHr: Double, maxHr: Double) -> [PrescribedIntensityZone: DynamicZoneTarget]`
  - `TrainingPrescriptionEngine.evaluatePhysiologicalGates(vitalsState: ImmuneSystemState, hrvZScore: Double, morningBodyBattery: Int, rolling3dEnergyBalanceKcal: Double, recentLongRunCardiacDriftsPct: [Double], efDelta30dPct: Double) -> GateEvaluationResult`
  - `TrainingPrescriptionEngine.computePreWorkoutCarbsG(targetTrimp: Double, carbDriftSlope: Double) -> Int?`
  - `TrainingPrescriptionEngine.prescribeTodayAndHorizon(queueState: RollingQueueState, config: TrainingGoalConfig, previousAcuteLoad: Double, previousChronicLoad: Double, vitalsState: ImmuneSystemState, hrvZScore: Double, morningBodyBattery: Int, rolling3dEnergyBalanceKcal: Double, efSamples: [Double], recentLongRunDriftsPct: [Double], efDelta30dPct: Double, restingHr: Double, maxHr: Double, carbDriftSlope: Double) -> TrainingPrescriptionPlan`
  - `TrainingPrescriptionEngine.reconcileExternalWorkout(queueState: RollingQueueState, loggedWorkoutTrimp: Double, currentTargetTrimp: Double, isClubOrCustomOverride: Bool) -> RollingQueueState`
* **Edge-Case Constraints:**
  - Guard all `Double` inputs against `.isNaN` and `.isInfinite`.
  - When `efSamples` is empty or contains values outside `[0.65, 2.20]`, fallback deterministically to `EF = 1.15 m/min/bpm`.
  - When `restingHr` or `maxHr` are invalid or `maxHr - restingHr < 40.0`, fallback to `restingHr = 55.0`, `maxHr = 192.0` (`HRR = 137.0`).
  - Prevent division by zero in inverse EWMA (`denom = max(0.0001, lambdaA - clampedTarget * lambdaC)`) and speed-to-pace conversion (`60000.0 / max(80.0, speedMetersPerMin)`).
  - High Acute Load Spike Rule (for Test Case 12.2): when `previousAcuteLoad / max(20.0, previousChronicLoad) > 1.25`, cap raw budget to `min(trimpRaw, 45.0)` so quality sessions (`CruiseThresholdIntervals`) automatically defer in favor of `RecoveryFlush` while staying at the head of `RollingQueueState`.

- [ ] **Step A1.1: Create `ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/TrainingPrescriptionEngine.swift`**

```swift
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
            return "Кардіодрейф ≤ 3.5% та ріст EF > 1.5%. Дозволено підвищення швидкості при тому ж пульсі."
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
```

---

### Work Package A2: Add Suite 12 (`verifyTrainingPrescriptionEngine()`) to `MathEngineVerification.swift`
* **Exact File Path:** `ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/MathEngineVerification.swift` (UPDATE)
* **Input/Output Type Signatures:**
  - Append `results.append(verifyTrainingPrescriptionEngine())` inside `runAllVerifications() -> [VerificationResult]`.
  - Add `private static func verifyTrainingPrescriptionEngine() -> VerificationResult`.
* **Required Test Cases:**
  - **Test Case 12.1:** `.illnessProdrome` strictly forces `.restDay` (`maxAllowedZone == .rest`) and `targetTrimp == 0.0`.
  - **Test Case 12.2:** High acute load (`previousAcuteLoad = 115.0`, `previousChronicLoad = 70.0`, `ACWR > 1.25`) downscales `targetTrimp` and swaps queued `.cruiseThresholdIntervals` for `.recoveryFlush` today while preserving `.cruiseThresholdIntervals` in `preservedQueuedArchetype` and at the head of `horizonQueue`.
  - **Test Case 12.3:** Increasing $EF_{75}$ from `1.15` to `1.28` deterministically increases prescribed Zone 2 speed (`targetSpeedMetersPerMin`) and makes `targetPaceSecPerKm` faster while maintaining the exact same `targetHeartRateBpm` ceiling.

- [ ] **Step A2.1: Update `MathEngineVerification.swift` and run `xcodebuild`**
Add `verifyTrainingPrescriptionEngine()` to `ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/MathEngineVerification.swift`:

```swift
    private static func verifyTrainingPrescriptionEngine() -> VerificationResult {
        // Test Case 12.1: .illnessProdrome strictly forces .rest and targetTRIMP == 0
        let queueAtQuality = RollingQueueState(currentIndex: 1) // .cruiseThresholdIntervals
        let illnessPlan = TrainingPrescriptionEngine.prescribeTodayAndHorizon(
            queueState: queueAtQuality,
            previousAcuteLoad: 70.0,
            previousChronicLoad: 70.0,
            vitalsState: .illnessProdrome
        )
        let case12_1 = (illnessPlan.today.archetype == .restDay) &&
                       (illnessPlan.today.maxAllowedZone == .rest) &&
                       (illnessPlan.today.targetTrimp == 0.0)

        // Test Case 12.2: High acute load (ACWR > 1.25) downscales target TRIMP and swaps CruiseThresholdIntervals for RecoveryFlush while preserving quality session in queue
        let spikePlan = TrainingPrescriptionEngine.prescribeTodayAndHorizon(
            queueState: queueAtQuality,
            previousAcuteLoad: 115.0,
            previousChronicLoad: 70.0,
            vitalsState: .optimal
        )
        let case12_2 = (spikePlan.today.archetype == .recoveryFlush) &&
                       (spikePlan.today.preservedQueuedArchetype == .cruiseThresholdIntervals) &&
                       (spikePlan.horizonQueue.first?.archetype == .cruiseThresholdIntervals) &&
                       (spikePlan.today.targetTrimp <= 45.0)

        // Test Case 12.3: Increasing EF_75 from 1.15 to 1.28 deterministically increases Z2 speed at identical HR ceiling
        let zonesLowEF = TrainingPrescriptionEngine.deriveDynamicZones(ef75: 1.15, restingHr: 49.0, maxHr: 192.0)
        let zonesHighEF = TrainingPrescriptionEngine.deriveDynamicZones(ef75: 1.28, restingHr: 49.0, maxHr: 192.0)
        let z2Low = zonesLowEF[.zone2Easy]!
        let z2High = zonesHighEF[.zone2Easy]!
        let case12_3 = (z2High.targetSpeedMetersPerMin > z2Low.targetSpeedMetersPerMin) &&
                       (z2High.targetPaceSecPerKm < z2Low.targetPaceSecPerKm) &&
                       (z2High.targetHeartRateBpm == z2Low.targetHeartRateBpm)

        let passed = case12_1 && case12_2 && case12_3
        return VerificationResult(
            testName: "Adaptive Training Prescription Engine (Suite 12)",
            passed: passed,
            details: "12.1(IllnessRest)=\(case12_1), 12.2(ACWRQueueSwap)=\(case12_2), 12.3(EF_SpeedGain:\(z2Low.formattedPaceMinKm)->\(z2High.formattedPaceMinKm)@\(z2High.targetHeartRateBpm)bpm)=\(case12_3)"
        )
    }
```

Run verification build:
`xcodebuild -project ios/Lifecore/Lifecore/Lifecore.xcodeproj -scheme Lifecore -destination 'generic/platform=iOS Simulator' build`

---

## Phase B: SwiftData Persistence & State Wiring

### Work Package B1: Create `TrainingPlanModels.swift` & Register in `LifecoreDataStore`
* **Exact File Paths:**
  - `ios/Lifecore/Lifecore/Lifecore/Core/Storage/TrainingPlanModels.swift` (NEW)
  - `ios/Lifecore/Lifecore/Lifecore/Core/Storage/SwiftDataModels.swift` (UPDATE)
* **Input/Output Type Signatures:**
  - `@Model public final class AthleteTrainingPlanState`
  - `@MainActor public final class TrainingPlanStore: ObservableObject` (`shared` singleton providing reactive `@Published public var queueState: RollingQueueState` and `@Published public var goalConfig: TrainingGoalConfig`, backed by SwiftData `AthleteTrainingPlanState` + `UserDefaults` mirror for instant startup).
* **Edge-Case Constraints:**
  - If `AthleteTrainingPlanState` does not yet exist in SwiftData on first launch, automatically insert a default row (`currentQueueIndex = 0`, `weeklyRunFrequency = 4`, `sessionDurationCapMin = 60.0`, `clubRunOverrideToday = false`).

- [ ] **Step B1.1: Create `ios/Lifecore/Lifecore/Lifecore/Core/Storage/TrainingPlanModels.swift`**

```swift
import Foundation
import SwiftData
import Combine

@Model
public final class AthleteTrainingPlanState {
    @Attribute(.unique) public var id: String
    public var currentQueueIndex: Int
    public var weeklyRunFrequency: Int
    public var targetSessionDurationCapMin: Double
    public var targetACWRRatio: Double
    public var clubRunOverrideToday: Bool
    public var lastUpdatedDateString: String
    public var updatedAt: Date

    public init(
        id: String = "primary_athlete_plan_state",
        currentQueueIndex: Int = 0,
        weeklyRunFrequency: Int = 4,
        targetSessionDurationCapMin: Double = 60.0,
        targetACWRRatio: Double = 1.08,
        clubRunOverrideToday: Bool = false,
        lastUpdatedDateString: String = "",
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.currentQueueIndex = currentQueueIndex
        self.weeklyRunFrequency = weeklyRunFrequency
        self.targetSessionDurationCapMin = targetSessionDurationCapMin
        self.targetACWRRatio = targetACWRRatio
        self.clubRunOverrideToday = clubRunOverrideToday
        self.lastUpdatedDateString = lastUpdatedDateString
        self.updatedAt = updatedAt
    }
}

@MainActor
public final class TrainingPlanStore: ObservableObject {
    public static let shared = TrainingPlanStore()

    @Published public var queueState: RollingQueueState
    @Published public var goalConfig: TrainingGoalConfig

    private init() {
        let context = LifecoreDataStore.shared.context
        let descriptor = FetchDescriptor<AthleteTrainingPlanState>()
        if let existing = (try? context.fetch(descriptor))?.first {
            self.queueState = RollingQueueState(
                currentIndex: existing.currentQueueIndex,
                clubOrCustomRunOverrideToday: existing.clubRunOverrideToday,
                lastAdvancedDateString: existing.lastUpdatedDateString
            )
            self.goalConfig = TrainingGoalConfig(
                weeklyRunDaysTarget: existing.weeklyRunFrequency,
                maxSessionDurationMin: existing.targetSessionDurationCapMin,
                targetACWRRatio: existing.targetACWRRatio
            )
        } else {
            let initial = AthleteTrainingPlanState()
            context.insert(initial)
            try? context.save()
            self.queueState = RollingQueueState()
            self.goalConfig = TrainingGoalConfig()
        }
    }

    public func toggleClubOrCustomRunToday() {
        queueState.clubOrCustomRunOverrideToday.toggle()
        if queueState.clubOrCustomRunOverrideToday {
            queueState.currentIndex = (queueState.currentIndex + 1) % WorkoutArchetype.rollingCycle.count
        }
        persist()
    }

    public func advanceQueueSlot() {
        queueState.currentIndex = (queueState.currentIndex + 1) % WorkoutArchetype.rollingCycle.count
        queueState.clubOrCustomRunOverrideToday = false
        persist()
    }

    public func persist() {
        let context = LifecoreDataStore.shared.context
        let descriptor = FetchDescriptor<AthleteTrainingPlanState>()
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.currentQueueIndex = queueState.currentIndex
            existing.clubRunOverrideToday = queueState.clubOrCustomRunOverrideToday
            existing.weeklyRunFrequency = goalConfig.weeklyRunDaysTarget
            existing.targetSessionDurationCapMin = goalConfig.maxSessionDurationMin
            existing.targetACWRRatio = goalConfig.targetACWRRatio
            existing.updatedAt = Date()
            try? context.save()
        }
    }
}
```

- [ ] **Step B1.2: Register `AthleteTrainingPlanState.self` in `SwiftDataModels.swift`**
In `ios/Lifecore/Lifecore/Lifecore/Core/Storage/SwiftDataModels.swift` inside `LifecoreDataStore.init()`:
Update `let schema = Schema([MealEntity.self, WorkoutAnalysisEntity.self, AthleteTrainingPlanState.self])`.

---

## Phase C: Liquid Glass UI 3.2 Components & Tab Integration

### Work Package C1: Create `TacticalPrescriptionCard.swift` & Wire into `TodayView.swift`
* **Exact File Paths:**
  - `ios/Lifecore/Lifecore/Lifecore/Features/Today/TacticalPrescriptionCard.swift` (NEW)
  - `ios/Lifecore/Lifecore/Lifecore/Features/Today/TodayView.swift` (UPDATE)
* **Accessibility Identifiers (Mandatory for Maestro E2E):**
  - Card container: `"card_tactical_prescription"`
  - Archetype headline: `"txt_prescription_archetype"`
  - Adaptation reason pill: `"pill_prescription_reason"`
  - Segments list container: `"list_prescription_segments"`

- [ ] **Step C1.1: Create `ios/Lifecore/Lifecore/Lifecore/Features/Today/TacticalPrescriptionCard.swift`**

```swift
import SwiftUI

public struct TacticalPrescriptionCard: View {
    public let plan: TrainingPrescriptionPlan?
    public var onSkipOrAdvance: (() -> Void)?

    public init(plan: TrainingPrescriptionPlan?, onSkipOrAdvance: (() -> Void)? = nil) {
        self.plan = plan
        self.onSkipOrAdvance = onSkipOrAdvance
    }

    private var prescription: DailyWorkoutPrescription {
        if let p = plan?.today { return p }
        return TrainingPrescriptionEngine.prescribeTodayAndHorizon(
            queueState: RollingQueueState(),
            previousAcuteLoad: 62.0,
            previousChronicLoad: 60.0,
            vitalsState: .optimal
        ).today
    }

    private var reasonColor: Color {
        switch prescription.adaptationReason {
        case .blockedByIllnessProdrome:
            return LifecoreTheme.coralDanger
        case .downgradedByVitalsOrBattery, .modulatedByHRV, .cappedByCaloricDeficit, .downgradedByAcuteLoadSpike, .heldByCardiacDrift:
            return LifecoreTheme.amberWarning
        case .efficiencyUnlocked, .optimalProgression, .externalClubRunAdapted:
            return LifecoreTheme.athleticEmerald
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Row: Archetype & Adaptation Reason Glow Pill
            HStack(alignment: .top, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: prescription.archetype.iconName)
                        .font(.headline)
                        .foregroundStyle(LifecoreTheme.electricTeal)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Тактичний план на сьогодні")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Text(prescription.archetype.titleUk)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .accessibilityIdentifier("txt_prescription_archetype")
                    }
                }

                Spacer()

                LifecoreGlowPill(
                    text: prescription.adaptationReason.titleUk,
                    color: reasonColor,
                    icon: "sparkles"
                )
                .accessibilityIdentifier("pill_prescription_reason")
            }

            Text(prescription.adaptationReason.subtitleUk)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))

            // KPI Badges Row: Target TRIMP, Est Distance, Pre-Run Carbs
            HStack(spacing: 8) {
                kpiPill(label: "Ціль TRIMP", value: "\(Int(prescription.targetTrimp))", color: LifecoreTheme.electricTeal)
                if prescription.totalDurationMin > 0 {
                    kpiPill(label: "Час / Об'єм", value: "\(Int(prescription.totalDurationMin)) хв • ~\(String(format: "%.1f", prescription.estimatedDistanceKm)) км", color: LifecoreTheme.recoveryGreen)
                }
                if let carbs = prescription.preWorkoutCarbsG {
                    kpiPill(label: "Вуглеводи за 2г", value: "+\(carbs) г", color: LifecoreTheme.strainOrange)
                }
            }

            Divider().background(Color.white.opacity(0.08))

            // Segments Breakdown
            VStack(spacing: 8) {
                ForEach(prescription.segments) { seg in
                    HStack {
                        Text(seg.zone.shortBadgeUk)
                            .font(.caption2.bold())
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(LifecoreTheme.electricTeal.opacity(0.18))
                            .foregroundStyle(LifecoreTheme.electricTeal)
                            .clipShape(Capsule())

                        VStack(alignment: .leading, spacing: 1) {
                            Text(seg.titleUk)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                            Text(seg.instructionUk)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        if seg.durationMin > 0 {
                            VStack(alignment: .trailing, spacing: 1) {
                                Text("\(seg.formattedPace)")
                                    .font(.caption.monospacedDigit().bold())
                                    .foregroundStyle(LifecoreTheme.athleticEmerald)
                                Text("≤\(seg.targetHrCapBpm) bpm • \(Int(seg.durationMin)) хв")
                                    .font(.system(size: 10).monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .accessibilityIdentifier("list_prescription_segments")
        }
        .padding(16)
        .lifecoreGlassCard(cornerRadius: 22, borderColor: reasonColor.opacity(0.28))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("card_tactical_prescription")
    }

    private func kpiPill(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit().bold())
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
```

- [ ] **Step C1.2: Wire `TacticalPrescriptionCard` into `TodayView.swift`**
In `ios/Lifecore/Lifecore/Lifecore/Features/Today/TodayView.swift`:
1. Add `@ObservedObject private var planStore = TrainingPlanStore.shared` and `@State private var prescriptionPlan: TrainingPrescriptionPlan?`.
2. Inside `body` (`VStack(spacing: 18)`), insert `TacticalPrescriptionCard(plan: prescriptionPlan)` right after `ringsHeaderView` (before `OvernightVitalsCard`).
3. Inside `loadData(forceRefresh:)`, compute `prescriptionPlan = TrainingPrescriptionEngine.prescribeTodayAndHorizon(...)` using `planStore.queueState`, `planStore.goalConfig`, `snapshot.acwrEvaluation`, `snapshot.vitalsEvaluation.state`, `snapshot.energyBank.wakeBattery`, and `athleteStore.profile`.

---

### Work Package C2: Create `RollingHorizonDeckView.swift` & Wire into `WorkoutsView.swift`
* **Exact File Paths:**
  - `ios/Lifecore/Lifecore/Lifecore/Features/Workouts/RollingHorizonDeckView.swift` (NEW)
  - `ios/Lifecore/Lifecore/Lifecore/Features/Workouts/WorkoutsView.swift` (UPDATE)
* **Accessibility Identifiers (Mandatory for Maestro E2E):**
  - Deck container: `"deck_rolling_horizon"`
  - Club/Custom Run button: `"btn_recalculate_club_queue"`

- [ ] **Step C2.1: Create `ios/Lifecore/Lifecore/Lifecore/Features/Workouts/RollingHorizonDeckView.swift`**

```swift
import SwiftUI

public struct RollingHorizonDeckView: View {
    @ObservedObject public var planStore = TrainingPlanStore.shared
    @ObservedObject public var athleteStore = AthleteProfileStore.shared

    public init() {}

    private var currentPlan: TrainingPrescriptionPlan {
        TrainingPrescriptionEngine.prescribeTodayAndHorizon(
            queueState: planStore.queueState,
            config: planStore.goalConfig,
            previousAcuteLoad: 64.0,
            previousChronicLoad: 60.0,
            vitalsState: .optimal,
            restingHr: athleteStore.profile.restingHeartRateBaselineBpm,
            maxHr: athleteStore.profile.maxHeartRateBpm
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Гнучка черга стимулів (EF-Фокус)", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.subheadline.bold())
                    .foregroundStyle(LifecoreTheme.electricTeal)
                Spacer()
                Text("EF₇₅: \(String(format: "%.2f", currentPlan.ef75Used))")
                    .font(.caption2.monospacedDigit())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(LifecoreTheme.electricTeal.opacity(0.15))
                    .foregroundStyle(LifecoreTheme.electricTeal)
                    .clipShape(Capsule())
            }

            // 3 Upcoming Horizon Slots
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(currentPlan.horizonQueue) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Слот +\(item.dayOffset)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(LifecoreTheme.electricTeal)
                                Spacer()
                                Text("TRIMP \(Int(item.targetTrimp))")
                                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Text(item.archetype.titleUk)
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .lineLimit(2)
                            Text("\(Int(item.totalDurationMin)) хв • ~\(String(format: "%.1f", item.estimatedDistanceKm)) км")
                                .font(.system(size: 10).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 175, alignment: .leading)
                        .padding(10)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }

            // 1-Tap Club / Custom Run Recalculation Button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    planStore.toggleClubOrCustomRunToday()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: planStore.queueState.clubOrCustomRunOverrideToday ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                    Text("Сьогодні своя пробіжка / Клуб (Recalculate Queue)")
                        .font(.caption.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    planStore.queueState.clubOrCustomRunOverrideToday
                        ? LifecoreTheme.athleticEmerald.opacity(0.25)
                        : LifecoreTheme.electricTeal.opacity(0.16)
                )
                .foregroundStyle(planStore.queueState.clubOrCustomRunOverrideToday ? LifecoreTheme.athleticEmerald : LifecoreTheme.electricTeal)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("btn_recalculate_club_queue")
        }
        .padding(14)
        .lifecoreGlassCard(cornerRadius: 20, borderColor: LifecoreTheme.electricTeal.opacity(0.25))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("deck_rolling_horizon")
    }
}
```

- [ ] **Step C2.2: Insert `RollingHorizonDeckView()` at top of `WorkoutsView.swift`**
In `ios/Lifecore/Lifecore/Lifecore/Features/Workouts/WorkoutsView.swift` inside `ScrollView { VStack(spacing: 16) { ... } }`, place `RollingHorizonDeckView()` as the first item right above `filterScrollView`.

---

## Phase D: Gemini Tactical Briefing Prompt & Maestro E2E

### Work Package D1: Add Pre-Computed Prescription Context to `CoachPrompt.swift`
* **Exact File Path:** `ios/Lifecore/Lifecore/Lifecore/Core/AI/CoachPrompt.swift` (UPDATE)
* **Input/Output Type Signatures:**
  - Add optional parameter `nextPrescriptionSummaryUk: String? = nil` to `CoachPrompt.buildUserPrompt(...)`.
  - Append `[NEXT 24H DETERMINISTIC TRAINING PRESCRIPTION]` section so Gemini verbalizes the exact pre-computed archetype, target pace, and HR cap without inventing numbers.

### Work Package D2: Create Maestro E2E Flow `.maestro/05_training_prescription_flow.yaml` & Update `.maestro/suite.yaml`
* **Exact File Paths:**
  - `.maestro/05_training_prescription_flow.yaml` (NEW)
  - `.maestro/suite.yaml` (UPDATE)

- [ ] **Step D2.1: Create `.maestro/05_training_prescription_flow.yaml`**

```yaml
appId: com.skycherepanya.Lifecore
---
# Flow 05: Deterministic Adaptive Training Prescription & Rolling Queue E2E
- launchApp:
    clearState: false

# 1. Verify Tactical Prescription Card on Today Tab
- tapOn:
    id: "tab_today"

- assertVisible:
    id: "card_tactical_prescription"

- assertVisible:
    id: "txt_prescription_archetype"

- assertVisible:
    id: "pill_prescription_reason"

# 2. Switch to Workouts Tab & Verify Rolling Horizon Deck
- tapOn:
    id: "tab_workouts"

- assertVisible:
    id: "deck_rolling_horizon"

- assertVisible:
    id: "btn_recalculate_club_queue"

# 3. Trigger Club/Custom Run Queue Recalculation & Return to Today
- tapOn:
    id: "btn_recalculate_club_queue"

- tapOn:
    id: "tab_today"

- assertVisible:
    id: "card_tactical_prescription"
```

- [ ] **Step D2.2: Append `- runFlow: 05_training_prescription_flow.yaml` to `.maestro/suite.yaml` and run final `xcodebuild`**
Run:
`xcodebuild -project ios/Lifecore/Lifecore/Lifecore.xcodeproj -scheme Lifecore -destination 'generic/platform=iOS Simulator' build`
