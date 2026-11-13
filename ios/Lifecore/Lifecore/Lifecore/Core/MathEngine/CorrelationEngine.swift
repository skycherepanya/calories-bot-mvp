import Foundation

// MARK: - Correlation Models

public struct DailyJoinedPhysiologyRecord: Codable, Sendable {
    public let dateString: String                    // YYYY-MM-DD
    public let date: Date
    public let weightKg: Double?
    public let rollingWeight7dKg: Double?
    public let sodiumMg: Double
    public let carbsG: Double
    public let proteinG: Double
    public let fatG: Double
    public let leucineG: Double
    public let wholeFoodRatio: Double               // 0.0 - 1.0
    public let ultraProcessedRatio: Double          // 0.0 - 1.0
    public let hasLateMealAfter2130: Bool
    public let hasHighSodiumMeal: Bool
    public let overnightHrvMs: Double?
    public let overnightRhrBpm: Double?
    public let deepSleepHours: Double?
    public let remSleepHours: Double?
    public let workoutTrimp: Double
    public let runningCardiacDriftPct: Double?
    public let runningEf: Double?
    public let loggedMealsCount: Int
    public let hasConfirmedNutrition: Bool
    public let confirmedKcal: Double?
    public let isKnownRestDay: Bool

    public var hasCompleteNutrition: Bool {
        hasConfirmedNutrition && (loggedMealsCount > 0 || confirmedKcal == 0.0)
    }

    public init(
        dateString: String,
        date: Date,
        weightKg: Double? = nil,
        rollingWeight7dKg: Double? = nil,
        sodiumMg: Double = 0.0,
        carbsG: Double = 0.0,
        proteinG: Double = 0.0,
        fatG: Double = 0.0,
        leucineG: Double = 0.0,
        wholeFoodRatio: Double = 1.0,
        ultraProcessedRatio: Double = 0.0,
        hasLateMealAfter2130: Bool = false,
        hasHighSodiumMeal: Bool = false,
        overnightHrvMs: Double? = nil,
        overnightRhrBpm: Double? = nil,
        deepSleepHours: Double? = nil,
        remSleepHours: Double? = nil,
        workoutTrimp: Double = 0.0,
        runningCardiacDriftPct: Double? = nil,
        runningEf: Double? = nil,
        loggedMealsCount: Int? = nil,
        hasConfirmedNutrition: Bool? = nil,
        confirmedKcal: Double? = nil,
        isKnownRestDay: Bool = false
    ) {
        self.dateString = dateString
        self.date = date
        self.weightKg = weightKg
        self.rollingWeight7dKg = rollingWeight7dKg
        self.sodiumMg = sodiumMg
        self.carbsG = carbsG
        self.proteinG = proteinG
        self.fatG = fatG
        self.leucineG = leucineG
        self.wholeFoodRatio = wholeFoodRatio
        self.ultraProcessedRatio = ultraProcessedRatio
        self.hasLateMealAfter2130 = hasLateMealAfter2130
        self.hasHighSodiumMeal = hasHighSodiumMeal
        self.overnightHrvMs = overnightHrvMs
        self.overnightRhrBpm = overnightRhrBpm
        self.deepSleepHours = deepSleepHours
        self.remSleepHours = remSleepHours
        self.workoutTrimp = workoutTrimp
        self.runningCardiacDriftPct = runningCardiacDriftPct
        self.runningEf = runningEf

        let inferredMealsCount = (carbsG > 0 || proteinG > 0 || fatG > 0 || sodiumMg > 0 || hasLateMealAfter2130 || hasHighSodiumMeal) ? 1 : 0
        let resolvedLoggedCount = loggedMealsCount ?? inferredMealsCount
        self.loggedMealsCount = resolvedLoggedCount
        self.confirmedKcal = confirmedKcal
        self.hasConfirmedNutrition = hasConfirmedNutrition ?? (resolvedLoggedCount > 0 || confirmedKcal != nil)
        self.isKnownRestDay = isKnownRestDay
    }
}

public enum CorrelationInsightCategory: String, Codable, Sendable, CaseIterable {
    case hydrationWater = "hydration_water"
    case lateMealAutonomic = "late_meal_autonomic"
    case carbEndurance = "carb_endurance"
    case nutritionRecovery = "nutrition_recovery"

    public var titleUk: String {
        switch self {
        case .hydrationWater: return "Натрій та затримка води"
        case .lateMealAutonomic: return "Пізня вечеря та нічний пульс"
        case .carbEndurance: return "Вуглеводи та кардіодрейф"
        case .nutritionRecovery: return "Якість харчування та сон"
        }
    }

    public var iconName: String {
        switch self {
        case .hydrationWater: return "drop.triangle.fill"
        case .lateMealAutonomic: return "moon.stars.fill"
        case .carbEndurance: return "bolt.heart.fill"
        case .nutritionRecovery: return "leaf.fill"
        }
    }
}

public struct CorrelationInsight: Codable, Sendable, Identifiable, Equatable {
    public var id: String { "\(category.rawValue)_\(lagDays)" }
    public let category: CorrelationInsightCategory
    public let lagDays: Int
    public let lagLabelUk: String
    public let pearsonR: Double
    public let sampleCount: Int
    public let titleUk: String
    public let effectDescriptionUk: String
    public let actionDirectiveUk: String
    public let isStatisticallyMeaningful: Bool
    public let dateRangeLabel: String
    public let associationLabelUk: String

    public init(
        category: CorrelationInsightCategory,
        lagDays: Int,
        lagLabelUk: String,
        pearsonR: Double,
        sampleCount: Int,
        titleUk: String,
        effectDescriptionUk: String,
        actionDirectiveUk: String,
        isStatisticallyMeaningful: Bool,
        dateRangeLabel: String = "",
        associationLabelUk: String = "Спостережуваний зв'язок"
    ) {
        self.category = category
        self.lagDays = lagDays
        self.lagLabelUk = lagLabelUk
        self.pearsonR = pearsonR
        self.sampleCount = sampleCount
        self.titleUk = titleUk
        self.effectDescriptionUk = effectDescriptionUk
        self.actionDirectiveUk = actionDirectiveUk
        self.isStatisticallyMeaningful = isStatisticallyMeaningful
        self.dateRangeLabel = dateRangeLabel
        self.associationLabelUk = associationLabelUk
    }
}

// MARK: - Correlation Engine

public enum CorrelationEngine {

    private static let gregorianUTC: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return cal
    }()

    /// Parses a strict Gregorian `yyyy-MM-dd` key into a UTC noon `Date` (DST-safe).
    internal static func parseDateKey(_ dateString: String) -> Date? {
        let parts = dateString.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]),
              (1...12).contains(month),
              (1...31).contains(day) else {
            return nil
        }

        var comps = DateComponents()
        comps.calendar = gregorianUTC
        comps.timeZone = gregorianUTC.timeZone
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = 12
        comps.minute = 0
        comps.second = 0

        guard let date = gregorianUTC.date(from: comps) else { return nil }
        let roundTrip = gregorianUTC.dateComponents([.year, .month, .day], from: date)
        guard roundTrip.year == year, roundTrip.month == month, roundTrip.day == day else {
            return nil
        }
        return date
    }

    /// Formats a UTC date into a Gregorian `yyyy-MM-dd` key.
    internal static func formatDateKey(_ date: Date) -> String {
        let comps = gregorianUTC.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }

    /// Returns the exact next Gregorian calendar day key (`T+1`) for a `yyyy-MM-dd` key.
    public static func nextDayKey(from dateString: String) -> String? {
        guard let date = parseDateKey(dateString),
              let nextDate = gregorianUTC.date(byAdding: .day, value: 1, to: date) else {
            return nil
        }
        return formatDateKey(nextDate)
    }

    /// Indexes records by `yyyy-MM-dd` `dateString` (keeping the latest record per key) and returns sorted keys.
    internal static func indexRecordsByDay(_ records: [DailyJoinedPhysiologyRecord]) -> (byKey: [String: DailyJoinedPhysiologyRecord], sortedKeys: [String]) {
        var byKey: [String: DailyJoinedPhysiologyRecord] = [:]
        for record in records {
            if let existing = byKey[record.dateString] {
                if record.date >= existing.date {
                    byKey[record.dateString] = record
                }
            } else {
                byKey[record.dateString] = record
            }
        }
        let sortedKeys = byKey.keys.sorted()
        return (byKey, sortedKeys)
    }

    private static func formatDateRangeLabel(_ matchedDates: [String]) -> String {
        guard let first = matchedDates.first, let last = matchedDates.last else { return "" }
        return "\(first)…\(last)"
    }

    private static func groupDifference(flags: [Bool], values: [Double]) -> Double? {
        guard flags.count == values.count else { return nil }
        var trueValues: [Double] = []
        var falseValues: [Double] = []
        for i in 0..<flags.count {
            if flags[i] {
                trueValues.append(values[i])
            } else {
                falseValues.append(values[i])
            }
        }
        guard !trueValues.isEmpty && !falseValues.isEmpty else { return nil }
        let trueMean = trueValues.reduce(0.0, +) / Double(trueValues.count)
        let falseMean = falseValues.reduce(0.0, +) / Double(falseValues.count)
        return trueMean - falseMean
    }

    /// Computes Pearson correlation coefficient between two arrays of equal length
    public static func pearsonR(_ x: [Double], _ y: [Double]) -> Double? {
        guard x.count == y.count && x.count >= 6 else { return nil }
        let n = Double(x.count)

        let sumX = x.reduce(0.0, +)
        let sumY = y.reduce(0.0, +)
        let meanX = sumX / n
        let meanY = sumY / n

        var numerator = 0.0
        var denomX = 0.0
        var denomY = 0.0

        for i in 0..<x.count {
            let dx = x[i] - meanX
            let dy = y[i] - meanY
            numerator += dx * dy
            denomX += dx * dx
            denomY += dy * dy
        }

        let denominator = sqrt(denomX * denomY)
        guard denominator > 0.000001 else { return nil }

        let r = numerator / denominator
        return max(-1.0, min(1.0, round(r * 100.0) / 100.0))
    }

    /// Computes Point-Biserial correlation between a boolean feature (0 or 1) and continuous Y
    public static func pointBiserialR(binaryX: [Bool], continuousY: [Double]) -> Double? {
        guard binaryX.count == continuousY.count && binaryX.count >= 6 else { return nil }
        let numX = binaryX.map { $0 ? 1.0 : 0.0 }
        return pearsonR(numX, continuousY)
    }

    /// Computes multi-day time-lagged physiological insights across daily joined records using exact Gregorian T -> T+1 joins.
    public static func computeInsights(records: [DailyJoinedPhysiologyRecord]) -> [CorrelationInsight] {
        let (byKey, sortedKeys) = indexRecordsByDay(records)
        guard sortedKeys.count >= 6 else { return [] }

        var insights: [CorrelationInsight] = []
        let associationLabel = "Спостережуваний зв'язок"

        // 1. Sodium (Day T) -> Morning Water Weight Spike deltaW (Day T+1)
        // deltaW = weightKg - rollingWeight7dKg
        var sodiumT: [Double] = []
        var deltaW_T1: [Double] = []
        var highSodiumFlags: [Bool] = []
        var sodiumMatchedDates: [String] = []

        for key in sortedKeys {
            guard let current = byKey[key],
                  current.hasCompleteNutrition,
                  let nextKey = nextDayKey(from: key),
                  let next = byKey[nextKey],
                  let nextWeight = next.weightKg,
                  let next7d = next.rollingWeight7dKg else {
                continue
            }

            sodiumT.append(current.sodiumMg)
            deltaW_T1.append(nextWeight - next7d)
            highSodiumFlags.append(current.hasHighSodiumMeal || current.sodiumMg >= 3000.0)
            sodiumMatchedDates.append(current.dateString)
        }

        if let rSodium = pearsonR(sodiumT, deltaW_T1), sodiumT.count >= 6 {
            let isSignificant = abs(rSodium) >= 0.35
            let dateRangeLabel = formatDateRangeLabel(sodiumMatchedDates)
            let rFormatted = String(format: "%+.2f", rSodium)

            let directionPhrase: String
            if rSodium > 0 {
                directionPhrase = "вище споживання натрію супроводжувалося вищим ранковим відхиленням ваги від 7-денного тренду"
            } else if rSodium < 0 {
                directionPhrase = "вище споживання натрію у цих даних супроводжувалося нижчим ранковим відхиленням ваги від 7-денного тренду"
            } else {
                directionPhrase = "лінійного зв'язку між натрієм та ранковим відхиленням ваги у цих даних не виявлено"
            }

            let groupPhrase: String
            if let diffKg = groupDifference(flags: highSodiumFlags, values: deltaW_T1) {
                groupPhrase = String(format: " Різниця після днів із високим натрієм: %+.2f кг.", diffKg)
            } else {
                groupPhrase = ""
            }

            insights.append(CorrelationInsight(
                category: .hydrationWater,
                lagDays: 1,
                lagLabelUk: "День T+1",
                pearsonR: rSodium,
                sampleCount: sodiumT.count,
                titleUk: "Вплив натрію на затримку води",
                effectDescriptionUk: "\(associationLabel) (r = \(rFormatted), n = \(sodiumT.count), \(dateRangeLabel)): \(directionPhrase).\(groupPhrase)",
                actionDirectiveUk: "Не коригуйте калорії через разові ранкові стрибки ваги — оцінюйте 7-денний тренд і водний баланс.",
                isStatisticallyMeaningful: isSignificant,
                dateRangeLabel: dateRangeLabel,
                associationLabelUk: associationLabel
            ))
        }

        // 2. Late Meal after 21:30 / Ultra-Processed (Day T) -> Overnight RHR (Day T+1)
        // FILTER: Non-heavy training days only (TRIMP <= 130) to eliminate high-workout confounder.
        var lateMealDays: [Bool] = []
        var nextMorningRhr: [Double] = []
        var lateMealMatchedDates: [String] = []

        for key in sortedKeys {
            guard let current = byKey[key],
                  current.hasCompleteNutrition,
                  current.workoutTrimp <= 130.0,
                  let nextKey = nextDayKey(from: key),
                  let next = byKey[nextKey],
                  let nextRhr = next.overnightRhrBpm,
                  next.overnightHrvMs != nil else {
                continue
            }

            lateMealDays.append(current.hasLateMealAfter2130 || current.ultraProcessedRatio >= 0.35)
            nextMorningRhr.append(nextRhr)
            lateMealMatchedDates.append(current.dateString)
        }

        if let rLateRhr = pointBiserialR(binaryX: lateMealDays, continuousY: nextMorningRhr), lateMealDays.count >= 6 {
            let isSignificant = abs(rLateRhr) >= 0.30
            let dateRangeLabel = formatDateRangeLabel(lateMealMatchedDates)
            let rFormatted = String(format: "%+.2f", rLateRhr)
            let diffSuffix = groupDifference(flags: lateMealDays, values: nextMorningRhr)
                .map { String(format: " (різниця %+.1f уд/хв)", $0) } ?? ""

            let directionPhrase: String
            if rLateRhr > 0 {
                directionPhrase = "пізній прийом їжі або висока частка ультраоброблених продуктів супроводжувалися вищим нічним пульсом спокою\(diffSuffix)"
            } else if rLateRhr < 0 {
                directionPhrase = "пізній прийом їжі або висока частка ультраоброблених продуктів у цих даних супроводжувалися нижчим нічним пульсом спокою\(diffSuffix)"
            } else {
                directionPhrase = "різниці нічного пульсу спокою між днями з пізньою вечерею та без неї не виявлено\(diffSuffix)"
            }

            let directive = rLateRhr > 0
                ? "Завершуйте останній прийом їжі за 2.5–3 години до сну та відстежуйте реакцію нічного пульсу."
                : "У поточній вибірці пізня вечеря не супроводжувалася вищим нічним пульсом — продовжуйте фіксувати час прийомів їжі."

            insights.append(CorrelationInsight(
                category: .lateMealAutonomic,
                lagDays: 1,
                lagLabelUk: "День T+1",
                pearsonR: rLateRhr,
                sampleCount: lateMealDays.count,
                titleUk: "Пізня вечеря та нічний пульс спокою",
                effectDescriptionUk: "\(associationLabel) (r = \(rFormatted), n = \(lateMealDays.count), \(dateRangeLabel), TRIMP ≤ 130): \(directionPhrase).",
                actionDirectiveUk: directive,
                isStatisticallyMeaningful: isSignificant,
                dateRangeLabel: dateRangeLabel,
                associationLabelUk: associationLabel
            ))
        }

        // 3. Pre-workout Carbs Availability (Day T-1) -> Cardiac Drift % (Day T)
        var carbsT_minus_1: [Double] = []
        var driftT: [Double] = []
        var carbMatchedDates: [String] = []

        for key in sortedKeys {
            guard let previous = byKey[key],
                  previous.hasCompleteNutrition,
                  let nextKey = nextDayKey(from: key),
                  let today = byKey[nextKey],
                  let drift = today.runningCardiacDriftPct else {
                continue
            }

            carbsT_minus_1.append(previous.carbsG)
            driftT.append(drift)
            carbMatchedDates.append(previous.dateString)
        }

        if let rCarbDrift = pearsonR(carbsT_minus_1, driftT), carbsT_minus_1.count >= 6 {
            let isSignificant = abs(rCarbDrift) >= 0.30
            let dateRangeLabel = formatDateRangeLabel(carbMatchedDates)
            let rFormatted = String(format: "%+.2f", rCarbDrift)

            let directionPhrase: String
            if rCarbDrift < 0 {
                directionPhrase = "вище споживання вуглеводів напередодні асоціювалося з нижчим кардіодрейфом під час пробіжки"
            } else if rCarbDrift > 0 {
                directionPhrase = "вище споживання вуглеводів напередодні у цих даних асоціювалося з вищим кардіодрейфом під час пробіжки"
            } else {
                directionPhrase = "лінійного зв'язку між вуглеводами напередодні та кардіодрейфом не виявлено"
            }

            let highCarbFlags = carbsT_minus_1.map { $0 >= 200.0 }
            let groupPhrase: String
            if let diffDrift = groupDifference(flags: highCarbFlags, values: driftT) {
                groupPhrase = String(format: " Різниця кардіодрейфу (≥200 г vs <200 г): %+.1f%%.", diffDrift)
            } else {
                groupPhrase = ""
            }

            insights.append(CorrelationInsight(
                category: .carbEndurance,
                lagDays: 1,
                lagLabelUk: "День T-1 → T",
                pearsonR: rCarbDrift,
                sampleCount: carbsT_minus_1.count,
                titleUk: "Вуглеводи та стабільність пульсу (Кардіодрейф)",
                effectDescriptionUk: "\(associationLabel) (r = \(rFormatted), n = \(carbsT_minus_1.count), \(dateRangeLabel)): \(directionPhrase).\(groupPhrase)",
                actionDirectiveUk: "Перед тривалими тренуваннями (>60 хв) фіксуйте споживання вуглеводів напередодні та оцінюйте кардіодрейф за подібного темпу.",
                isStatisticallyMeaningful: isSignificant,
                dateRangeLabel: dateRangeLabel,
                associationLabelUk: associationLabel
            ))
        }

        // 4. Whole Food Ratio (Day T) -> Deep Sleep Hours (Day T+1)
        var wholeFoodT: [Double] = []
        var deepSleepT1: [Double] = []
        var wholeFoodMatchedDates: [String] = []

        for key in sortedKeys {
            guard let current = byKey[key],
                  current.hasCompleteNutrition,
                  let nextKey = nextDayKey(from: key),
                  let next = byKey[nextKey],
                  let nextDeep = next.deepSleepHours else {
                continue
            }

            wholeFoodT.append(current.wholeFoodRatio)
            deepSleepT1.append(nextDeep)
            wholeFoodMatchedDates.append(current.dateString)
        }

        if let rWholeDeep = pearsonR(wholeFoodT, deepSleepT1), wholeFoodT.count >= 6 {
            let isSignificant = abs(rWholeDeep) >= 0.30
            let dateRangeLabel = formatDateRangeLabel(wholeFoodMatchedDates)
            let rFormatted = String(format: "%+.2f", rWholeDeep)

            let directionPhrase: String
            if rWholeDeep > 0 {
                directionPhrase = "вища частка цільних продуктів асоціювалася з більшою тривалістю глибокого сну"
            } else if rWholeDeep < 0 {
                directionPhrase = "вища частка цільних продуктів у цих даних асоціювалася з меншою тривалістю глибокого сну"
            } else {
                directionPhrase = "лінійного зв'язку між часткою цільних продуктів і глибоким сном не виявлено"
            }

            let highWholeFlags = wholeFoodT.map { $0 >= 0.80 }
            let groupPhrase: String
            if let diffHours = groupDifference(flags: highWholeFlags, values: deepSleepT1) {
                let diffMinutes = diffHours * 60.0
                groupPhrase = String(format: " Спостережувана різниця (≥80%% vs <80%%): %+.0f хв.", diffMinutes)
            } else {
                groupPhrase = ""
            }

            let directive = rWholeDeep >= 0
                ? "Надавайте перевагу цільним джерелам білка та клітковини й відстежуйте якість нічного відновлення."
                : "У поточній вибірці зв'язок зворотний — оцініть можливі супутні чинники (час вечері, об'єм їжі, вечірнє навантаження)."

            insights.append(CorrelationInsight(
                category: .nutritionRecovery,
                lagDays: 1,
                lagLabelUk: "День T+1",
                pearsonR: rWholeDeep,
                sampleCount: wholeFoodT.count,
                titleUk: "Цільні продукти та глибина відновлення",
                effectDescriptionUk: "\(associationLabel) (r = \(rFormatted), n = \(wholeFoodT.count), \(dateRangeLabel)): \(directionPhrase).\(groupPhrase)",
                actionDirectiveUk: directive,
                isStatisticallyMeaningful: isSignificant,
                dateRangeLabel: dateRangeLabel,
                associationLabelUk: associationLabel
            ))
        }

        return insights
    }
}
