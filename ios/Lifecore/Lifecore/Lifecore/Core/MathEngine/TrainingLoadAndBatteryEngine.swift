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
    public let coverage: WorkloadCoverage

    public init(
        acuteLoad: Double,
        chronicLoad: Double,
        ratio: Double,
        zone: ACWRZone,
        titleUk: String,
        recommendationUk: String,
        coverage: WorkloadCoverage = WorkloadCoverage.insufficient
    ) {
        self.acuteLoad = acuteLoad
        self.chronicLoad = chronicLoad
        self.ratio = ratio
        self.zone = zone
        self.titleUk = titleUk
        self.recommendationUk = recommendationUk
        self.coverage = coverage
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

public struct WorkoutBatteryEvent: Codable, Sendable, Equatable {
    public let startTime: Date
    public let endTime: Date
    public let trimp: Double

    public init(startTime: Date, endTime: Date, trimp: Double) {
        self.startTime = startTime
        self.endTime = endTime
        self.trimp = trimp
    }

    /// Convenience initializer using hour of day on reference date
    public init(hour: Int, trimp: Double, calendar: Calendar = .current, referenceDate: Date = Date()) {
        var startComps = calendar.dateComponents([.year, .month, .day], from: referenceDate)
        startComps.hour = hour
        startComps.minute = 0
        startComps.second = 0
        let start = calendar.date(from: startComps) ?? referenceDate
        let end = calendar.date(byAdding: .minute, value: 60, to: start) ?? start
        self.startTime = start
        self.endTime = end
        self.trimp = trimp
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

    /// Computes EWMA Acute (7d) vs Chronic (28d) Workload Ratio (ACWR) adhering to DietaryDay calendar rules.
    ///
    /// Requirements (Audit F02):
    /// - Known rest days have trimp = 0.0.
    /// - Unobserved days are excluded from EWMA iteration and break consecutive coverage.
    /// - Full confidence requires >= 28 observed consecutive days. Shorter history (< 28) is labeled provisional
    ///   and excluded from aggressive progression advice.
    /// - Empty observed history returns `nil` (NOT synthetic 1.0 / sweetSpot).
    public static func computeEWMAWorkload(
        series: [DailyLoadSeries],
        calendar: Calendar = .current
    ) -> ACWREvaluation? {
        guard !series.isEmpty else { return nil }

        let observedSeries = series.filter { $0.isObserved }
        guard !observedSeries.isEmpty else { return nil }

        // Group observed entries by DietaryDay key (04:00 boundary)
        var loadsByDietaryDay: [String: (day: DietaryDay, trimp: Double, isRest: Bool)] = [:]
        for entry in observedSeries {
            let dietaryDay = DietaryDay.containing(entry.date, calendar: calendar)
            let existing = loadsByDietaryDay[dietaryDay.key]
            let existingTrimp = existing?.trimp ?? 0.0
            let addedTrimp = entry.isKnownRestDay ? 0.0 : entry.trimpLoad
            let isRest = (existing?.isRest ?? true) && entry.isKnownRestDay
            loadsByDietaryDay[dietaryDay.key] = (dietaryDay, existingTrimp + addedTrimp, isRest)
        }

        // Sort chronologically by start of dietary day
        let sortedDays = loadsByDietaryDay.values.sorted { $0.day.interval.start < $1.day.interval.start }
        guard !sortedDays.isEmpty else { return nil }

        // Calculate consecutive observed days ending at latest day
        var consecutiveDays = 1
        for i in stride(from: sortedDays.count - 1, to: 0, by: -1) {
            let current = sortedDays[i].day.interval.start
            let previous = sortedDays[i - 1].day.interval.start
            let diffDays = calendar.dateComponents([.day], from: calendar.startOfDay(for: previous), to: calendar.startOfDay(for: current)).day ?? 0
            if diffDays == 1 {
                consecutiveDays += 1
            } else {
                break
            }
        }

        let totalObservedDays = sortedDays.count
        let confidence: WorkloadConfidence
        if consecutiveDays >= 28 {
            confidence = .fullConfidence
        } else {
            confidence = .provisional
        }

        // EWMA calculation:
        // Acute lambda = 2 / (7 + 1) = 0.25
        // Chronic lambda = 2 / (28 + 1) = ~0.0689655
        let lambdaAcute = 2.0 / (7.0 + 1.0)
        let lambdaChronic = 2.0 / (28.0 + 1.0)

        var acute = sortedDays.first?.trimp ?? 0.0
        var chronic = sortedDays.first?.trimp ?? 0.0

        for i in 1..<sortedDays.count {
            let load = sortedDays[i].trimp
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

        let isProgressionAllowed = (confidence == .fullConfidence) && (zone == .sweetSpot || zone == .undertraining)

        let titleUk: String
        let recommendationUk: String
        if confidence == .provisional {
            titleUk = "\(zone.titleUk) (Попередньо)"
            recommendationUk = "Попереднє оцінювання (\(consecutiveDays)/28 днів спостережень). Продовжуйте регулярний збір даних без агресивного нарощування."
        } else {
            titleUk = zone.titleUk
            recommendationUk = zone.directiveUk
        }

        let coverage = WorkloadCoverage(
            observedDaysCount: totalObservedDays,
            consecutiveDaysCount: consecutiveDays,
            totalDaysCount: totalObservedDays,
            confidence: confidence,
            isAggressiveProgressionAllowed: isProgressionAllowed
        )

        return ACWREvaluation(
            acuteLoad: roundedAcute,
            chronicLoad: roundedChronic,
            ratio: ratio,
            zone: zone,
            titleUk: titleUk,
            recommendationUk: recommendationUk,
            coverage: coverage
        )
    }

    /// Convenience wrapper for legacy/simple daily load pairs [(date, trimp)].
    /// When empty, returns an explicit insufficient-coverage evaluation (NOT synthetic 1.0 / sweetSpot).
    public static func computeEWMAWorkload(
        dailyLoads: [(date: Date, trimp: Double)],
        calendar: Calendar = .current
    ) -> ACWREvaluation {
        guard !dailyLoads.isEmpty else {
            return ACWREvaluation(
                acuteLoad: 0.0,
                chronicLoad: 0.0,
                ratio: 0.0,
                zone: .undertraining,
                titleUk: "Недостатньо даних",
                recommendationUk: "Для розрахунку ACWR потрібно щонайменше 28 днів спостережень.",
                coverage: .insufficient
            )
        }

        let series = dailyLoads.map {
            DailyLoadSeries(date: $0.date, trimpLoad: $0.trimp, isKnownRestDay: false, isObserved: true)
        }

        if let eval = computeEWMAWorkload(series: series, calendar: calendar) {
            return eval
        }

        return ACWREvaluation(
            acuteLoad: 0.0,
            chronicLoad: 0.0,
            ratio: 0.0,
            zone: .undertraining,
            titleUk: "Недостатньо даних",
            recommendationUk: "Для розрахунку ACWR потрібно щонайменше 28 днів спостережень.",
            coverage: .insufficient
        )
    }

    /// Continuous 24h Body Battery / Energy Bank trajectory with timestamped workout events (Audit F02).
    ///
    /// Workouts drain the battery during the specific hour interval in which they occur.
    /// Handles morning (06:00, 09:00), afternoon and evening (18:00, 19:00) sessions truthfully.
    public static func computeEnergyBankTimeline(
        wakeRecoveryScore: Int,
        sleepHours: Double,
        targetSleepHours: Double = 7.5,
        pureNeatKcal: Double = 450.0,
        events: [WorkoutBatteryEvent],
        immuneState: ImmuneSystemState = .optimal,
        currentHour: Int = Calendar.current.component(.hour, from: Date()),
        trimpDrainFactor: Double = 0.32,
        calendar: Calendar = .current,
        referenceDate: Date = Date()
    ) -> EnergyBankEvaluation {
        // Morning Wake Battery (25 - 100%)
        let sleepRatio = min(1.0, max(0.4, sleepHours / max(5.0, targetSleepHours)))
        let rawWake = Double(wakeRecoveryScore) * 0.78 + (sleepRatio * 22.0)
        let wakeBattery = Int(min(100.0, max(25.0, round(rawWake))))

        var currentLevel = Double(wakeBattery)
        var timeline: [EnergyBankPoint] = []

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

        let hourlyNeatRate = (pureNeatKcal / 16.0) * 0.012

        // Map events to hourly TRIMP distribution
        var trimpByHour: [Int: Double] = [:]
        for event in events {
            guard event.trimp > 0 else { continue }
            let startHour = calendar.component(.hour, from: event.startTime)
            let endHour = calendar.component(.hour, from: event.endTime)
            let durationSeconds = max(60.0, event.endTime.timeIntervalSince(event.startTime))

            if startHour == endHour {
                trimpByHour[startHour, default: 0.0] += event.trimp
            } else if endHour > startHour {
                // Distribute TRIMP across hours based on overlap
                var remainingTrimp = event.trimp
                let hoursSpan = max(1, endHour - startHour + 1)
                for h in startHour...endHour {
                    var hourStartComps = calendar.dateComponents([.year, .month, .day], from: event.startTime)
                    hourStartComps.hour = h
                    hourStartComps.minute = 0
                    hourStartComps.second = 0
                    guard let hStart = calendar.date(from: hourStartComps),
                          let hEnd = calendar.date(byAdding: .hour, value: 1, to: hStart) else {
                        trimpByHour[h, default: 0.0] += remainingTrimp / Double(hoursSpan)
                        continue
                    }
                    let segStart = max(event.startTime, hStart)
                    let segEnd = min(event.endTime, hEnd)
                    if segEnd > segStart {
                        let segDuration = segEnd.timeIntervalSince(segStart)
                        let proportion = segDuration / durationSeconds
                        trimpByHour[h, default: 0.0] += event.trimp * proportion
                    }
                }
            } else {
                trimpByHour[startHour, default: 0.0] += event.trimp
            }
        }

        // Build 24-point timeline (hours 0...23)
        for hour in 0...23 {
            let hourTrimp = trimpByHour[hour, default: 0.0]
            let workoutDrop = min(38.0, hourTrimp * trimpDrainFactor)

            if hour < 7 {
                // Pre-wake overnight baseline, but if early morning workout occurred (e.g. 06:00), drain it
                if workoutDrop > 0 {
                    currentLevel = max(5.0, currentLevel - workoutDrop)
                    totalWorkoutDrain += workoutDrop
                }
                timeline.append(EnergyBankPoint(hour: hour, batteryLevel: Int(round(currentLevel))))
                continue
            }

            // Basal hourly decline
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
            totalWorkoutDrain += workoutDrop

            let hourlyDrop = basalStep + neatStep + immuneExtraStep + workoutDrop
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

    /// Convenience wrapper for legacy workouts array [(hour: Int, trimp: Double)].
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
        let events = workouts.map {
            WorkoutBatteryEvent(hour: $0.hour, trimp: $0.trimp)
        }
        return computeEnergyBankTimeline(
            wakeRecoveryScore: wakeRecoveryScore,
            sleepHours: sleepHours,
            targetSleepHours: targetSleepHours,
            pureNeatKcal: pureNeatKcal,
            events: events,
            immuneState: immuneState,
            currentHour: currentHour,
            trimpDrainFactor: trimpDrainFactor
        )
    }
}
