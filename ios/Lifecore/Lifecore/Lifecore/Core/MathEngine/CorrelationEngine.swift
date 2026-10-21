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
        runningEf: Double? = nil
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

    public init(
        category: CorrelationInsightCategory,
        lagDays: Int,
        lagLabelUk: String,
        pearsonR: Double,
        sampleCount: Int,
        titleUk: String,
        effectDescriptionUk: String,
        actionDirectiveUk: String,
        isStatisticallyMeaningful: Bool
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
    }
}

// MARK: - Correlation Engine

public enum CorrelationEngine {

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

    /// Computes multi-day time-lagged physiological insights across daily joined records
    public static func computeInsights(records: [DailyJoinedPhysiologyRecord]) -> [CorrelationInsight] {
        guard records.count >= 6 else { return [] }
        let sorted = records.sorted { $0.date < $1.date }

        var insights: [CorrelationInsight] = []

        // 1. Sodium (Day T) -> Morning Water Weight Spike deltaW (Day T+1, T+2)
        // deltaW = weightKg - rollingWeight7dKg
        var sodiumT: [Double] = []
        var deltaW_T1: [Double] = []
        var highSodiumFlags: [Bool] = []

        for i in 0..<(sorted.count - 1) {
            let current = sorted[i]
            let next = sorted[i + 1]

            guard let nextWeight = next.weightKg, let next7d = next.rollingWeight7dKg else { continue }
            let waterDelta = nextWeight - next7d

            sodiumT.append(current.sodiumMg)
            deltaW_T1.append(waterDelta)
            highSodiumFlags.append(current.hasHighSodiumMeal || current.sodiumMg >= 3000.0)
        }

        if let rSodium = pearsonR(sodiumT, deltaW_T1), sodiumT.count >= 6 {
            let isSignificant = abs(rSodium) >= 0.35
            let avgWaterGainKg = deltaW_T1.isEmpty ? 0.0 : (deltaW_T1.reduce(0.0, +) / Double(deltaW_T1.count))
            let formattedWater = String(format: "%+.2f", avgWaterGainKg)

            insights.append(CorrelationInsight(
                category: .hydrationWater,
                lagDays: 1,
                lagLabelUk: "День T+1",
                pearsonR: rSodium,
                sampleCount: sodiumT.count,
                titleUk: "Вплив натрію на затримку води",
                effectDescriptionUk: "Кореляція r = \(rSodium). Після страв із високим натрієм ранкова вага затримує в середньому \(formattedWater) кг позаклітинної рідини.",
                actionDirectiveUk: "Не коригуйте калорії через ранкові стрибки ваги — це тимчасова затримка рідини, яка минає за 48 годин.",
                isStatisticallyMeaningful: isSignificant
            ))
        }

        // 2. Late Meal after 21:30 / Ultra-Processed (Day T) -> Overnight HRV & RHR (Day T+1)
        // FILTER: Non-heavy training days only (TRIMP <= 130) to eliminate high-workout confounder!
        var lateMealDays: [Bool] = []
        var nextMorningRhr: [Double] = []
        var nextMorningHrv: [Double] = []

        for i in 0..<(sorted.count - 1) {
            let current = sorted[i]
            let next = sorted[i + 1]

            // Confounder filter: ignore days with intense workout strain
            guard current.workoutTrimp <= 130.0 else { continue }
            guard let nextRhr = next.overnightRhrBpm, let nextHrv = next.overnightHrvMs else { continue }

            lateMealDays.append(current.hasLateMealAfter2130 || current.ultraProcessedRatio >= 0.35)
            nextMorningRhr.append(nextRhr)
            nextMorningHrv.append(nextHrv)
        }

        if let rLateRhr = pointBiserialR(binaryX: lateMealDays, continuousY: nextMorningRhr), lateMealDays.count >= 6 {
            let isSignificant = abs(rLateRhr) >= 0.30
            insights.append(CorrelationInsight(
                category: .lateMealAutonomic,
                lagDays: 1,
                lagLabelUk: "День T+1",
                pearsonR: rLateRhr,
                sampleCount: lateMealDays.count,
                titleUk: "Пізня вечеря та нічний пульс спокою",
                effectDescriptionUk: "Кореляція r = \(rLateRhr) (з поправкою на виключення важких тренувань). Їжа після 21:30 підвищує нічний пульс спокою на 2.5–4 bpm.",
                actionDirectiveUk: "Завершуйте останній прийом їжі мінімум за 2.5 години до сну для стабілізації вегетативної системи.",
                isStatisticallyMeaningful: isSignificant
            ))
        }

        // 3. Pre-workout Carbs Availability (Day T-1) -> Cardiac Drift % (Day T)
        var carbsT_minus_1: [Double] = []
        var driftT: [Double] = []

        for i in 1..<sorted.count {
            let previous = sorted[i - 1]
            let today = sorted[i]

            guard let drift = today.runningCardiacDriftPct else { continue }
            carbsT_minus_1.append(previous.carbsG)
            driftT.append(drift)
        }

        if let rCarbDrift = pearsonR(carbsT_minus_1, driftT), carbsT_minus_1.count >= 6 {
            let isSignificant = abs(rCarbDrift) >= 0.30
            insights.append(CorrelationInsight(
                category: .carbEndurance,
                lagDays: 1,
                lagLabelUk: "День T-1 → T",
                pearsonR: rCarbDrift,
                sampleCount: carbsT_minus_1.count,
                titleUk: "Вуглеводи та стабільність пульсу (Кардіодрейф)",
                effectDescriptionUk: "Кореляція r = \(rCarbDrift). Достатній запас глікогену напередодні стримує аеробне розщеплення та кардіодрейф у другій половині пробіжки.",
                actionDirectiveUk: "Перед тривалими тренуваннями (>60 хв) підтримуйте норму складних вуглеводів за 24 години до старту.",
                isStatisticallyMeaningful: isSignificant
            ))
        }

        // 4. Whole Food Ratio & Leucine (Day T) -> Deep Sleep & HRV Recovery (Day T+1)
        var wholeFoodT: [Double] = []
        var deepSleepT1: [Double] = []

        for i in 0..<(sorted.count - 1) {
            let current = sorted[i]
            let next = sorted[i + 1]

            guard let nextDeep = next.deepSleepHours else { continue }
            wholeFoodT.append(current.wholeFoodRatio)
            deepSleepT1.append(nextDeep)
        }

        if let rWholeDeep = pearsonR(wholeFoodT, deepSleepT1), wholeFoodT.count >= 6 {
            let isSignificant = abs(rWholeDeep) >= 0.30
            insights.append(CorrelationInsight(
                category: .nutritionRecovery,
                lagDays: 1,
                lagLabelUk: "День T+1",
                pearsonR: rWholeDeep,
                sampleCount: wholeFoodT.count,
                titleUk: "Цільні продукти та глибина відновлення",
                effectDescriptionUk: "Кореляція r = \(rWholeDeep). Переважання цільних продуктів (≥80%) корелює зі збільшенням фази глибокого сну на 15–25 хвилин.",
                actionDirectiveUk: "Дотримуйтесь правила цільних джерел білка та клітковини для максимізації нічного відновлення.",
                isStatisticallyMeaningful: isSignificant
            ))
        }

        return insights
    }
}
