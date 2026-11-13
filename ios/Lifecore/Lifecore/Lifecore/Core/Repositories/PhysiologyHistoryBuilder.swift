import Foundation

// MARK: - Workout Input Model for Longitudinal Join

public struct PhysiologyWorkoutSample: Sendable, Equatable, Codable {
    public let startedAt: Date
    public let durationSeconds: TimeInterval
    public let trimp: Double?
    public let avgHeartRate: Double?
    public let cardiacDriftPct: Double?
    public let efficiencyFactor: Double?
    public let isRunning: Bool

    public init(
        startedAt: Date,
        durationSeconds: TimeInterval = 0.0,
        trimp: Double? = nil,
        avgHeartRate: Double? = nil,
        cardiacDriftPct: Double? = nil,
        efficiencyFactor: Double? = nil,
        isRunning: Bool = true
    ) {
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.trimp = trimp
        self.avgHeartRate = avgHeartRate
        self.cardiacDriftPct = cardiacDriftPct
        self.efficiencyFactor = efficiencyFactor
        self.isRunning = isRunning
    }

    public init(
        from entity: WorkoutAnalysisEntity,
        restingHr: Double = 49.0,
        maxHr: Double = 192.0
    ) {
        let durationMin = entity.durationSeconds / 60.0
        let computedTrimp: Double? = entity.avgHeartRate.map { hr in
            TrainingLoadAndBatteryEngine.computeBanisterTRIMP(
                durationMin: durationMin,
                avgHr: hr,
                restingHr: restingHr,
                maxHr: maxHr
            )
        }
        let normalizedType = entity.workoutType.lowercased()
        let isRun = normalizedType.contains("run") || normalizedType.contains("біг")

        self.init(
            startedAt: entity.startedAt,
            durationSeconds: entity.durationSeconds,
            trimp: computedTrimp,
            avgHeartRate: entity.avgHeartRate,
            cardiacDriftPct: entity.cardiacDriftPercentage,
            efficiencyFactor: entity.efficiencyFactor,
            isRunning: isRun
        )
    }

    public init(
        from sample: AerobicEfficiencyTrendSample,
        restingHr: Double = 49.0,
        maxHr: Double = 192.0
    ) {
        let computedTrimp = TrainingLoadAndBatteryEngine.computeBanisterTRIMP(
            durationMin: sample.durationMin,
            avgHr: sample.avgHrBpm,
            restingHr: restingHr,
            maxHr: maxHr
        )
        self.init(
            startedAt: sample.date,
            durationSeconds: sample.durationMin * 60.0,
            trimp: computedTrimp,
            avgHeartRate: sample.avgHrBpm,
            cardiacDriftPct: sample.aerobicDecouplingPct,
            efficiencyFactor: sample.efficiencyFactor,
            isRunning: true
        )
    }
}

// MARK: - Shared Longitudinal Physiology History Builder

public enum PhysiologyHistoryBuilder {

    /// Builds chronological `DailyJoinedPhysiologyRecord` rows across `interval`,
    /// strictly keyed by `DietaryDay` (04:00 local rollover) without fabricating missing nutrition, weight, or sleep stages.
    public static func buildRecords(
        in interval: DateInterval,
        meals: [MealRecord],
        weightObservations: [Observation<Double>],
        sleepEpisodes: [SleepEpisode],
        workouts: [PhysiologyWorkoutSample] = [],
        confirmedZeroNutritionDates: Set<String> = [],
        knownRestDates: Set<String> = [],
        calendar: Calendar = .current
    ) -> [DailyJoinedPhysiologyRecord] {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone

        let days = enumerateDietaryDays(in: interval, calendar: gregorian)
        guard !days.isEmpty else { return [] }

        // 1. Group confirmed meals by DietaryDay key
        var mealsByDay: [String: [MealRecord]] = [:]
        for meal in meals where !meal.isOptimisticPending {
            let key = dietaryDayKey(for: meal, calendar: gregorian)
            mealsByDay[key, default: []].append(meal)
        }

        // 2. Group valid weight observations by DietaryDay key (keep latest observedAt per day)
        var weightByDay: [String: (observedAt: Date, kg: Double)] = [:]
        for obs in weightObservations {
            guard obs.quality != .unavailable,
                  let value = obs.value,
                  let observedAt = obs.observedAt else {
                continue
            }
            let day = DietaryDay.containing(observedAt, calendar: gregorian)
            if let existing = weightByDay[day.key] {
                if observedAt >= existing.observedAt {
                    weightByDay[day.key] = (observedAt, value)
                }
            } else {
                weightByDay[day.key] = (observedAt, value)
            }
        }

        // 3. Group sleep episodes by wake DietaryDay key (keep primary/longest episode per day)
        var sleepByDay: [String: SleepEpisode] = [:]
        for episode in sleepEpisodes {
            let day = DietaryDay.containing(episode.interval.end, calendar: gregorian)
            if let existing = sleepByDay[day.key] {
                if episode.totalSleepDurationSeconds > existing.totalSleepDurationSeconds ||
                    (episode.totalSleepDurationSeconds == existing.totalSleepDurationSeconds &&
                     episode.interval.end >= existing.interval.end) {
                    sleepByDay[day.key] = episode
                }
            } else {
                sleepByDay[day.key] = episode
            }
        }

        // 4. Group workouts by DietaryDay key
        var workoutsByDay: [String: [PhysiologyWorkoutSample]] = [:]
        for workout in workouts {
            let day = DietaryDay.containing(workout.startedAt, calendar: gregorian)
            workoutsByDay[day.key, default: []].append(workout)
        }

        // 5. Join each DietaryDay in chronological order
        var records: [DailyJoinedPhysiologyRecord] = []
        records.reserveCapacity(days.count)

        for day in days {
            let dayKey = day.key

            // Nutrition aggregation
            let dayMeals = mealsByDay[dayKey] ?? []
            var daySodium = 0.0
            var dayCarbs = 0.0
            var dayProtein = 0.0
            var dayFat = 0.0
            var dayLeucine = 0.0
            var dayKcal = 0.0
            var wholeCount = 0
            var ultraCount = 0

            for meal in dayMeals {
                dayKcal += meal.kcal
                dayCarbs += meal.carbsG
                dayProtein += meal.proteinG
                dayFat += meal.fatG
                if let sodium = meal.micronutrients?.sodiumMg { daySodium += sodium }
                if let leucine = meal.aminoAcids?.leucineG { dayLeucine += leucine }
                if meal.isWholeFood { wholeCount += 1 }
                if meal.isUltraProcessed { ultraCount += 1 }
            }

            let loggedMealsCount = dayMeals.count
            let isConfirmedZero = loggedMealsCount == 0 && confirmedZeroNutritionDates.contains(dayKey)
            let hasConfirmedNutrition = loggedMealsCount > 0 || isConfirmedZero
            let confirmedKcal: Double? = loggedMealsCount > 0 ? dayKcal : (isConfirmedZero ? 0.0 : nil)

            let wholeFoodRatio = loggedMealsCount > 0 ? Double(wholeCount) / Double(loggedMealsCount) : 0.0
            let ultraProcessedRatio = loggedMealsCount > 0 ? Double(ultraCount) / Double(loggedMealsCount) : 0.0

            let hasLateMealAfter2130 = dayMeals.contains { meal in
                let comps = gregorian.dateComponents([.hour, .minute], from: meal.createdAt)
                let hour = comps.hour ?? 0
                let minute = comps.minute ?? 0
                return hour > 21 || (hour == 21 && minute >= 30) || hour < 4
            }
            let hasHighSodiumMeal = daySodium >= 2800.0 || dayMeals.contains { $0.isHighSodium }

            // Weight + 7-day rolling weight (computed ONLY when an observed weight exists on this day)
            let observedWeightKg = weightByDay[dayKey]?.kg
            let rolling7dKg: Double?
            if observedWeightKg != nil {
                rolling7dKg = computeRolling7dWeight(
                    upToDayKey: dayKey,
                    weightByDay: weightByDay
                )
            } else {
                rolling7dKg = nil
            }

            // Sleep & nocturnal vitals (preserve nil stages without fabricating 0.22/0.23)
            let sleep = sleepByDay[dayKey]
            let overnightHrvMs: Double? = (sleep?.hrv?.quality != .unavailable) ? sleep?.hrv?.value : nil
            let overnightRhrBpm: Double? = (sleep?.restingHeartRate?.quality != .unavailable) ? sleep?.restingHeartRate?.value : nil

            let deepSleepHours: Double?
            let remSleepHours: Double?
            if let episode = sleep {
                let hasStagedSleep = episode.stages.contains {
                    $0.stage == .deep || $0.stage == .rem || $0.stage == .core
                }
                if hasStagedSleep {
                    deepSleepHours = episode.deepDurationSeconds / 3600.0
                    remSleepHours = episode.remDurationSeconds / 3600.0
                } else {
                    deepSleepHours = nil
                    remSleepHours = nil
                }
            } else {
                deepSleepHours = nil
                remSleepHours = nil
            }

            // Workouts & rest day flag
            let dayWorkouts = workoutsByDay[dayKey] ?? []
            let isKnownRestDay = knownRestDates.contains(dayKey)
            let workoutTrimp: Double
            if dayWorkouts.isEmpty {
                workoutTrimp = 0.0
            } else {
                workoutTrimp = dayWorkouts.reduce(0.0) { partial, workout in
                    if let explicitTrimp = workout.trimp {
                        return partial + max(0.0, explicitTrimp)
                    }
                    if workout.durationSeconds > 0, let avgHr = workout.avgHeartRate {
                        return partial + TrainingLoadAndBatteryEngine.computeBanisterTRIMP(
                            durationMin: workout.durationSeconds / 60.0,
                            avgHr: avgHr
                        )
                    }
                    return partial
                }
            }

            let runningWorkouts = dayWorkouts.filter(\.isRunning)
            let runningDrift = runningWorkouts.compactMap(\.cardiacDriftPct).last
            let runningEf = runningWorkouts.compactMap(\.efficiencyFactor).last

            records.append(DailyJoinedPhysiologyRecord(
                dateString: dayKey,
                date: day.interval.start,
                weightKg: observedWeightKg,
                rollingWeight7dKg: rolling7dKg,
                sodiumMg: daySodium,
                carbsG: dayCarbs,
                proteinG: dayProtein,
                fatG: dayFat,
                leucineG: dayLeucine,
                wholeFoodRatio: wholeFoodRatio,
                ultraProcessedRatio: ultraProcessedRatio,
                hasLateMealAfter2130: hasLateMealAfter2130,
                hasHighSodiumMeal: hasHighSodiumMeal,
                overnightHrvMs: overnightHrvMs,
                overnightRhrBpm: overnightRhrBpm,
                deepSleepHours: deepSleepHours,
                remSleepHours: remSleepHours,
                workoutTrimp: workoutTrimp,
                runningCardiacDriftPct: runningDrift,
                runningEf: runningEf,
                loggedMealsCount: loggedMealsCount,
                hasConfirmedNutrition: hasConfirmedNutrition,
                confirmedKcal: confirmedKcal,
                isKnownRestDay: isKnownRestDay
            ))
        }

        return records
    }

    /// Asynchronously fetches weight and sleep history from `healthRepository` over `interval`
    /// and joins them with meals and workouts by `DietaryDay`.
    public static func build(
        in interval: DateInterval,
        healthRepository: any HealthRepository,
        meals: [MealRecord],
        workouts: [PhysiologyWorkoutSample] = [],
        confirmedZeroNutritionDates: Set<String> = [],
        knownRestDates: Set<String> = [],
        calendar: Calendar = .current
    ) async throws -> [DailyJoinedPhysiologyRecord] {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone

        let days = enumerateDietaryDays(in: interval, calendar: gregorian)
        guard let firstDay = days.first else { return [] }

        // Include 6-day lookback so rolling 7-day weight can be computed for early days in `interval`.
        let lookbackStart = gregorian.date(byAdding: .day, value: -6, to: firstDay.interval.start) ?? firstDay.interval.start
        let weightInterval = DateInterval(start: lookbackStart, end: max(lookbackStart, interval.end))
        let weightObservations = try await healthRepository.weightHistory(in: weightInterval)

        var sleepEpisodes: [SleepEpisode] = []
        var seenIntervals = Set<DateInterval>()

        for day in days {
            if let episode = try await healthRepository.sleepEpisode(endingBefore: day.interval.end),
               day.contains(episode.interval.end),
               !seenIntervals.contains(episode.interval) {
                seenIntervals.insert(episode.interval)
                sleepEpisodes.append(episode)
            }
        }

        return buildRecords(
            in: interval,
            meals: meals,
            weightObservations: weightObservations,
            sleepEpisodes: sleepEpisodes,
            workouts: workouts,
            confirmedZeroNutritionDates: confirmedZeroNutritionDates,
            knownRestDates: knownRestDates,
            calendar: gregorian
        )
    }

    // MARK: - Internal Helpers

    private static func enumerateDietaryDays(in interval: DateInterval, calendar: Calendar) -> [DietaryDay] {
        let startDay = DietaryDay.containing(interval.start, calendar: calendar)
        if interval.duration <= 0 {
            return [startDay]
        }

        var days: [DietaryDay] = []
        var currentDay = startDay
        while currentDay.interval.start < interval.end {
            days.append(currentDay)
            currentDay = DietaryDay.containing(currentDay.interval.end, calendar: calendar)
        }
        return days
    }

    private static func dietaryDayKey(for meal: MealRecord, calendar: Calendar) -> String {
        let createdAtDay = DietaryDay.containing(meal.createdAt, calendar: calendar)
        if meal.dietaryDate.isEmpty {
            return createdAtDay.key
        }

        let comps = calendar.dateComponents([.year, .month, .day, .hour], from: meal.createdAt)
        let rawCreatedKey = String(
            format: "%04d-%02d-%02d",
            comps.year ?? 0,
            comps.month ?? 0,
            comps.day ?? 0
        )
        if (comps.hour ?? 0) < 4 && meal.dietaryDate == rawCreatedKey {
            return createdAtDay.key
        }
        return meal.dietaryDate
    }

    private static func computeRolling7dWeight(
        upToDayKey dayKey: String,
        weightByDay: [String: (observedAt: Date, kg: Double)]
    ) -> Double? {
        guard let anchorDate = CorrelationEngine.parseDateKey(dayKey) else { return nil }
        var gregorianUTC = Calendar(identifier: .gregorian)
        gregorianUTC.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt

        var values: [Double] = []
        for offset in (-6)...0 {
            guard let targetDate = gregorianUTC.date(byAdding: .day, value: offset, to: anchorDate) else {
                continue
            }
            let targetKey = CorrelationEngine.formatDateKey(targetDate)
            if let sample = weightByDay[targetKey] {
                values.append(sample.kg)
            }
        }

        guard values.count >= 2 else { return nil }
        let mean = values.reduce(0.0, +) / Double(values.count)
        return round(mean * 100.0) / 100.0
    }
}
