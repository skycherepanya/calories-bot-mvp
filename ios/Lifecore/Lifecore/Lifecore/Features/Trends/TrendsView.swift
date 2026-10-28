import SwiftUI
import HealthKit

public enum TrendsCategory: String, CaseIterable, Identifiable {
    case adaptation = "Адаптація"
    case workload = "Навантаження"
    case body = "Тіло & Вага"
    case cardio = "Кардіо & ВНС"

    public var id: String { rawValue }

    public var systemIcon: String {
        switch self {
        case .adaptation: return "brain.head.profile"
        case .workload: return "flame.fill"
        case .body: return "scalemass.fill"
        case .cardio: return "waveform.path.ecg"
        }
    }
}

public struct TrendsView: View {
    @State private var selectedRange: TrendsTimeRange = .days30
    @State private var selectedCategory: TrendsCategory = .adaptation
    @State private var adaptiveSnapshot: AdaptivePhysiologySnapshot?
    @State private var weightPoints: [TrendWeightPoint] = []
    @State private var autonomicSamples: [DateAutonomicSample] = []
    @State private var efSamples: [AerobicEfficiencyTrendSample] = []
    @State private var correlationInsights: [CorrelationInsight] = []
    @State private var acwrEvaluation: ACWREvaluation?
    @State private var dailyTrimpLoads: [(date: Date, trimp: Double)] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 1. Time Range Selector
                    TrendsRangePickerView(selectedRange: $selectedRange)
                        .padding(.top, 4)

                    // 2. Liquid Glass Category Segmented Switcher
                    categorySwitcher

                    if isLoading && weightPoints.isEmpty && adaptiveSnapshot == nil {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(LifecoreTheme.accentPrimary)
                            Text("Завантаження фізіологічних трендів...")
                                .font(.caption)
                                .foregroundStyle(LifecoreTheme.inkSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        // 3. Category Content View
                        switch selectedCategory {
                        case .adaptation:
                            if let snapshot = adaptiveSnapshot {
                                AdaptiveEngineStatusCard(snapshot: snapshot)
                            }
                            CorrelationInsightsCard(insights: correlationInsights)

                        case .workload:
                            ACWRWorkloadTrendCard(evaluation: acwrEvaluation, dailyLoads: dailyTrimpLoads)

                        case .body:
                            WeightTrendCard(points: weightPoints)

                        case .cardio:
                            AutonomicTrendCard(samples: autonomicSamples)
                            AerobicEfficiencyTrendCard(samples: efSamples)
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(LifecoreTheme.statusDanger)
                            .padding(.horizontal)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .accessibilityIdentifier("trends_scroll_view")
            .background(LifecoreTheme.paperCanvas.ignoresSafeArea())
            .navigationTitle("Тренди та Аналітика")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        Task { await loadData(forceRefresh: true) }
                    }) {
                        if isLoading {
                            ProgressView()
                                .tint(LifecoreTheme.accentPrimary)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(LifecoreTheme.accentPrimary)
                        }
                    }
                }
            }
            .refreshable {
                await loadData(forceRefresh: true)
            }
            .task(id: selectedRange) {
                await loadData(forceRefresh: false)
            }
        }
    }

    // MARK: - Category Switcher

    private var categorySwitcher: some View {
        HStack(spacing: 6) {
            ForEach(TrendsCategory.allCases) { cat in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = cat
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: cat.systemIcon)
                            .font(.system(size: 10, weight: .bold))
                        Text(cat.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(selectedCategory == cat ? LifecoreTheme.inkPrimary : LifecoreTheme.inkSecondary)
                    .background(
                        selectedCategory == cat ?
                            LifecoreTheme.paperCard : Color.clear
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(selectedCategory == cat ? LifecoreTheme.ruleHairline : Color.clear, lineWidth: 1.0)
                    )
                }
                .accessibilityIdentifier({
                    switch cat {
                    case .adaptation: return "tab_trend_adaptation"
                    case .workload: return "tab_trend_workload"
                    case .body: return "tab_trend_body"
                    case .cardio: return "tab_trend_cardio"
                    }
                }())
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(LifecoreTheme.paperWell)
        )
    }

    // MARK: - Data Pipeline

    private func loadData(forceRefresh: Bool) async {
        if isLoading { return }
        isLoading = true
        errorMessage = nil

        let days = selectedRange.rawValue

        async let weightSamplesTask = HealthKitManager.shared.fetchBodyWeightHistory(days: days)
        async let autonomicTask = HealthKitManager.shared.fetchAutonomicLongitudinalHistory(days: days)
        async let efTask = HealthKitManager.shared.fetchAerobicEfficiencyHistory(limit: max(10, days / 4))

        let (rawWeightSamples, fetchedAutonomic, fetchedEf) = await (weightSamplesTask, autonomicTask, efTask)

        // Compute 7d and 14d rolling averages and water retention spike flags in Swift Math Engine
        let computedPoints = ReadinessCalculator.computeLongitudinalWeightTrend(samples: rawWeightSamples)

        // Build joined daily physiology records to feed the Correlation Engine
        let calendar = Calendar.current
        let today = Date()
        var dailyJoined: [DailyJoinedPhysiologyRecord] = []

        // Extract logged meals by dietary date
        let allMeals = MealStorageService.shared.fetchAllMeals()

        for d in 0..<min(30, days) {
            guard let recordDate = calendar.date(byAdding: .day, value: -d, to: today) else { continue }
            let dateKey = formatDietaryDate(from: recordDate)

            let dayMeals = allMeals.filter { $0.dietaryDate == dateKey }
            var daySodium = 0.0
            var dayCarbs = 0.0
            var dayProtein = 0.0
            var dayFat = 0.0
            var dayLeucine = 0.0
            var wholeCount = 0
            var ultraCount = 0

            for m in dayMeals {
                if let s = m.micronutrients?.sodiumMg { daySodium += s }
                dayCarbs += m.carbsG
                dayProtein += m.proteinG
                dayFat += m.fatG
                if let l = m.aminoAcids?.leucineG { dayLeucine += l }
                if m.isWholeFood { wholeCount += 1 }
                if m.isUltraProcessed { ultraCount += 1 }
            }

            let wholeRatio = dayMeals.isEmpty ? 0.85 : Double(wholeCount) / Double(dayMeals.count)
            let ultraRatio = dayMeals.isEmpty ? 0.10 : Double(ultraCount) / Double(dayMeals.count)

            let hasLateMeal = dayMeals.contains { meal in
                let hour = calendar.component(.hour, from: meal.createdAt)
                let minute = calendar.component(.minute, from: meal.createdAt)
                return (hour > 21 || (hour == 21 && minute >= 30))
            }
            let hasHighSodium = daySodium >= 2800.0 || dayMeals.contains { $0.tags.contains("high_sodium") }

            let weightPoint = computedPoints.first { calendar.isDate($0.date, inSameDayAs: recordDate) }
            let autoSample = fetchedAutonomic.first { calendar.isDate($0.date, inSameDayAs: recordDate) }
            let efSample = fetchedEf.first { calendar.isDate($0.date, inSameDayAs: recordDate) }

            dailyJoined.append(DailyJoinedPhysiologyRecord(
                dateString: dateKey,
                date: recordDate,
                weightKg: weightPoint?.rawWeightKg,
                rollingWeight7dKg: weightPoint?.rolling7dKg,
                sodiumMg: daySodium > 0 ? daySodium : (hasHighSodium ? 3800.0 : 1900.0),
                carbsG: dayCarbs > 0 ? dayCarbs : 210.0,
                proteinG: dayProtein > 0 ? dayProtein : 160.0,
                fatG: dayFat > 0 ? dayFat : 68.0,
                leucineG: dayLeucine > 0 ? dayLeucine : 3.2,
                wholeFoodRatio: wholeRatio,
                ultraProcessedRatio: ultraRatio,
                hasLateMealAfter2130: hasLateMeal,
                hasHighSodiumMeal: hasHighSodium,
                overnightHrvMs: autoSample?.hrvMs,
                overnightRhrBpm: autoSample?.rhrBpm,
                deepSleepHours: 1.3,
                remSleepHours: 1.5,
                workoutTrimp: efSample != nil ? 95.0 : 35.0,
                runningCardiacDriftPct: efSample?.aerobicDecouplingPct,
                runningEf: efSample?.efficiencyFactor
            ))
        }

        let computedInsights = CorrelationEngine.computeInsights(records: dailyJoined)

        // Compute EWMA ACWR across daily loads
        var dailyLoads: [(date: Date, trimp: Double)] = []
        for point in dailyJoined {
            dailyLoads.append((date: point.date, trimp: point.workoutTrimp))
        }
        let computedAcwr = TrainingLoadAndBatteryEngine.computeEWMAWorkload(dailyLoads: dailyLoads)

        let profile = AthleteProfileStore.shared.profile
        let evaluatedAdaptive = AdaptivePhysiologyEngine.evaluateAdaptiveSnapshot(
            records: dailyJoined,
            priorBmrKcal: profile.bmrKcalPerDay,
            priorTargetKcal: profile.targetCaloriesKcal,
            priorBaseline: NocturnalVitalsBaseline(
                hrvMeanMs: profile.hrvBaselineMs,
                rhrMeanBpm: profile.restingHeartRateBaselineBpm,
                wristTempMeanCelsius: profile.wristTempBaselineCelsius,
                respiratoryRateMeanBpm: profile.respiratoryRateBaselineBpm,
                spo2MeanPct: profile.spo2BaselinePct
            ),
            currentWeights: profile.readinessWeights,
            rpeCheckinsCount: profile.rpeCalibrationCount,
            todayNeatKcal: 450.0,
            todayWorkoutKcal: 200.0
        )

        withAnimation(.easeInOut(duration: 0.25)) {
            self.adaptiveSnapshot = evaluatedAdaptive
            self.weightPoints = computedPoints
            self.autonomicSamples = fetchedAutonomic
            self.efSamples = fetchedEf
            self.correlationInsights = computedInsights
            self.acwrEvaluation = computedAcwr
            self.dailyTrimpLoads = dailyLoads
            self.isLoading = false
        }
    }

    private func formatDietaryDate(from date: Date) -> String {
        let calendar = Calendar.current
        let shifted = calendar.date(byAdding: .hour, value: -4, to: date) ?? date
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: shifted)
    }
}

#Preview {
    TrendsView()
        .preferredColorScheme(.light)
}
