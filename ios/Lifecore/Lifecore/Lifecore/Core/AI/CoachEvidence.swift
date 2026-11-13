import Foundation

// MARK: - Scoped Nutrition Window

/// Represents an explicit time-bounded nutrition window anchored to a reference date (e.g., workout start or current time).
public struct CoachNutritionWindow: Codable, Sendable, Equatable {
    public let start: Date
    public let end: Date
    public let windowHours: Int
    public let labelUk: String

    public var interval: DateInterval {
        DateInterval(start: min(start, end), end: max(start, end))
    }

    public init(
        start: Date,
        end: Date,
        windowHours: Int,
        labelUk: String
    ) {
        self.start = start
        self.end = end
        self.windowHours = windowHours
        self.labelUk = labelUk
    }

    public init(
        endingAt end: Date = Date(),
        windowHours: Int = 24,
        labelUk: String? = nil
    ) {
        let clampedHours = max(1, windowHours)
        self.end = end
        self.start = end.addingTimeInterval(-Double(clampedHours) * 3600.0)
        self.windowHours = clampedHours
        self.labelUk = labelUk ?? "Останні \(clampedHours) год"
    }
}

// MARK: - Coach Evidence Builder & Citation Validator

/// Deterministic builder and validator for AI Coach dossier evidence.
public enum CoachEvidenceBuilder {

    /// Filters meals strictly to confirmed records (`!isOptimisticPending`) created within `[window.start, window.end]`.
    public static func filterMeals(_ meals: [MealRecord], in window: CoachNutritionWindow) -> [MealRecord] {
        meals.filter { meal in
            !meal.isOptimisticPending &&
            meal.createdAt >= window.start &&
            meal.createdAt <= window.end
        }
    }

    /// Detects late-evening and post-midnight meals (`21:30...23:59` and `00:00..<04:00` local time).
    public static func isLateMeal(_ date: Date, calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return hour > 21 || (hour == 21 && minute >= 30) || hour < 4
    }

    /// Aggregates confirmed meals inside `window` into an `AcuteNutritionSlice` with zero fabricated defaults.
    public static func buildNutritionSlice(
        meals: [MealRecord],
        window: CoachNutritionWindow,
        calendar: Calendar = .current
    ) -> AcuteNutritionSlice {
        let scopedMeals = filterMeals(meals, in: window)
            .sorted { $0.createdAt > $1.createdAt }

        var totalKcal: Double = 0
        var totalCarbs: Double = 0
        var totalProtein: Double = 0
        var totalFat: Double = 0
        var totalSodium: Double = 0
        var wholeFoodCount = 0
        var hadLateMeal = false
        var mealNames: [String] = []

        for meal in scopedMeals {
            totalKcal += meal.kcal
            totalCarbs += meal.carbsG
            totalProtein += meal.proteinG
            totalFat += meal.fatG
            if let sodium = meal.micronutrients?.sodiumMg {
                totalSodium += sodium
            }
            if meal.isWholeFood {
                wholeFoodCount += 1
            }
            mealNames.append(meal.name)
            if isLateMeal(meal.createdAt, calendar: calendar) {
                hadLateMeal = true
            }
        }

        let loggedCount = scopedMeals.count
        let wholeFoodRatioPct = loggedCount > 0
            ? Int(round((Double(wholeFoodCount) / Double(loggedCount)) * 100.0))
            : 0

        return AcuteNutritionSlice(
            loggedMealsCount: loggedCount,
            last24hKcal: round(totalKcal),
            last24hCarbsG: round(totalCarbs),
            last24hProteinG: round(totalProtein),
            last24hFatG: round(totalFat),
            last24hSodiumMg: round(totalSodium),
            wholeFoodRatioPct: wholeFoodRatioPct,
            hadLateMealAfter2130: hadLateMeal,
            recentMealNames: Array(mealNames.prefix(5)),
            windowHours: window.windowHours,
            windowLabelUk: window.labelUk
        )
    }

    /// Strips any evidence pill whose underlying metric is missing or unlogged in `dossier`.
    public static func validateCitations(
        _ pills: [MetricEvidencePill],
        against dossier: AssembledHealthDossier
    ) -> [MetricEvidencePill] {
        pills.filter { isPillSupported($0, against: dossier) }
    }

    private static func isPillSupported(
        _ pill: MetricEvidencePill,
        against dossier: AssembledHealthDossier
    ) -> Bool {
        let label = pill.labelUk.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let value = pill.valueUk.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !label.isEmpty, !value.isEmpty, value != "n/a", value != "--" else {
            return false
        }

        // 1. Nutrition citations require at least one logged meal in the scoped window.
        let nutritionKeywords = [
            "вуглевод", "carb",
            "ккал", "калор", "kcal", "енерг",
            "білок", "білк", "protein",
            "жир", "fat",
            "натрі", "sodium",
            "якість їж", "цільн", "whole"
        ]
        if nutritionKeywords.contains(where: { label.contains($0) }) {
            if dossier.acuteNutrition.loggedMealsCount == 0 {
                return false
            }
        }

        // 2. Overnight RHR citations require morningRhrBpm.
        let rhrKeywords = ["rhr", "пульс спокою", "нічний пульс", "resting hr", "resting heart"]
        let isOvernightRHR = rhrKeywords.contains(where: { label.contains($0) })
        if isOvernightRHR {
            if dossier.recoveryContext?.morningRhrBpm == nil {
                return false
            }
            return true
        }

        // 3. HRV citations require morningHrvMs; workout HR citations require workoutAnalysis?.avgHeartRate.
        let isHRV = label.contains("hrv") || label.contains("варіабельн")
        if isHRV {
            if dossier.recoveryContext?.morningHrvMs == nil {
                return false
            }
            return true
        } else {
            let workoutHRKeywords = ["пульс", "чсс", "heart rate", "avg hr", "max hr"]
            if workoutHRKeywords.contains(where: { label.contains($0) }) {
                if dossier.workoutAnalysis?.avgHeartRate == nil {
                    return false
                }
            }
        }

        // 4. Sleep stage & duration citations require their respective non-nil fields.
        if label.contains("глибок") || label.contains("deep") {
            if dossier.recoveryContext?.lastNightDeepHours == nil {
                return false
            }
        } else if label.contains("rem") || label.contains("швидк") {
            if dossier.recoveryContext?.lastNightRemHours == nil {
                return false
            }
        } else {
            let sleepKeywords = ["сон", "сну", "sleep"]
            if sleepKeywords.contains(where: { label.contains($0) }) {
                if dossier.recoveryContext?.lastNightSleepHours == nil {
                    return false
                }
            }
        }

        // 5. Workout telemetry citations require corresponding measured workout fields.
        if label.contains("ef") || label.contains("ефективн") {
            if dossier.workoutAnalysis?.efficiencyFactor == nil {
                return false
            }
        }
        if label.contains("дрейф") || label.contains("drift") || label.contains("декаплінг") {
            if dossier.workoutAnalysis?.aerobicDecouplingPct == nil {
                return false
            }
        }
        let generalWorkoutKeywords = ["темп", "pace", "дистанц", "distance"]
        if generalWorkoutKeywords.contains(where: { label.contains($0) }) {
            if dossier.workoutAnalysis == nil {
                return false
            }
        }

        // 5. ACWR citations require acwrRatio.
        if label.contains("acwr") {
            if dossier.recoveryContext?.acwrRatio == nil {
                return false
            }
        }

        // 6. Readiness citations require recoveryScore.
        let readinessKeywords = ["готовн", "readiness", "recovery score"]
        if readinessKeywords.contains(where: { label.contains($0) }) {
            if dossier.recoveryContext?.recoveryScore == nil {
                return false
            }
        }

        return true
    }
}
