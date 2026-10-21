import SwiftUI
import HealthKit

public struct TodayView: View {
    @State private var snapshot: TodaySnapshot?
    @State private var adaptiveSnapshot: AdaptivePhysiologySnapshot?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isSyncingWithCloud = false
    @State private var cloudSyncMessage: String?
    @State private var isShowingProfileSheet = false
    @ObservedObject private var athleteStore = AthleteProfileStore.shared

    public init() {}

    private var todayDateKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        // Lifecore 04:00 AM day cutoff
        let calendar = Calendar.current
        let shifted = calendar.date(byAdding: .hour, value: -4, to: Date()) ?? Date()
        return formatter.string(from: shifted)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // 1. Hero Cockpit Bento Card (Rings + Adaptive Engine Badge + 1-Tap RPE)
                    ringsHeaderView

                    // 2. Overnight Vitals Corridor & Pre-Symptomatic Illness Radar
                    OvernightVitalsCard(evaluation: snapshot?.vitalsEvaluation)
                        .accessibilityIdentifier("card_overnight_vitals")

                    // 3. 24h Energy Bank (Body Battery & Sleep Debt)
                    EnergyBankCard(energyBank: snapshot?.energyBank)
                        .accessibilityIdentifier("card_body_battery")

                    // 4. Bento Section: Sleep Architecture & Metabolism (Pure NEAT + Adaptive TDEE)
                    sleepAndMetabolismBentoSection

                    // 5. Today's Workouts Card
                    todayWorkoutsCard

                    // 6. Cloud Sync Action
                    cloudSyncSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .accessibilityIdentifier("today_scroll_view")
            .background(LifecoreTheme.deepVoidBackground.ignoresSafeArea())
            .navigationTitle("Lifecore")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { isShowingProfileSheet = true }) {
                        Image(systemName: "person.crop.circle")
                            .foregroundStyle(LifecoreTheme.electricTeal)
                    }
                    .accessibilityIdentifier("btn_open_profile")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        Task { await loadData(forceRefresh: true) }
                    }) {
                        if isLoading {
                            ProgressView()
                                .tint(LifecoreTheme.electricTeal)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(LifecoreTheme.electricTeal)
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingProfileSheet) {
                AthleteProfileSheet()
            }
            .refreshable {
                await loadData(forceRefresh: true)
            }
            .task {
                await loadData(forceRefresh: false)
            }
        }
    }

    // MARK: - 1. Hero Cockpit Bento Card

    private var ringsHeaderView: some View {
        VStack(spacing: 14) {
            // Rings Row
            HStack(spacing: 10) {
                // Readiness Ring
                let recoveryScore = snapshot?.recovery.score ?? 85
                let recoveryColor: Color = recoveryScore >= 80 ? LifecoreTheme.athleticEmerald :
                                           (recoveryScore >= 60 ? LifecoreTheme.amberWarning : LifecoreTheme.coralDanger)
                let recoverySubtitle: String = {
                    switch snapshot?.recovery.state {
                    case .prime: return "Оптимально"
                    case .moderate: return "Адаптивно"
                    case .low: return "Відпочинок"
                    case .none: return "Оптимально"
                    }
                }()

                BevelRingView(
                    title: "Відновлення",
                    value: "\(recoveryScore)%",
                    subtitle: recoverySubtitle,
                    progress: Double(recoveryScore) / 100.0,
                    ringColor: recoveryColor
                )

                // Strain Ring
                let strain21 = snapshot?.strain.whoopScale21 ?? 11.2
                let strainPercent = (snapshot?.strain.score100 ?? 53.0) / 100.0
                BevelRingView(
                    title: "Навантаження",
                    value: String(format: "%.1f", strain21),
                    subtitle: "Шкала 0-21",
                    progress: strainPercent,
                    ringColor: LifecoreTheme.electricTeal
                )

                // Active Move Ring
                let activeKcal = snapshot?.dailyActivity.activeKcal ?? 0.0
                let targetMoveKcal = athleteStore.profile.activeMoveGoalKcal
                let moveRatio = min(1.2, activeKcal / max(100.0, targetMoveKcal))
                BevelRingView(
                    title: "Калорії",
                    value: "\(Int(activeKcal))",
                    subtitle: "Ціль: \(Int(targetMoveKcal)) ккал",
                    progress: moveRatio,
                    ringColor: LifecoreTheme.amberWarning
                )
            }

            // ACWR Status Pill
            if let acwr = snapshot?.acwr {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(acwrColor(acwr.zone))
                    Text("ACWR \(String(format: "%.2f", acwr.ratio)):")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                    Text(acwr.titleUk)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(acwrColor(acwr.zone))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(acwrColor(acwr.zone).opacity(0.14))
                )
                .overlay(
                    Capsule()
                        .stroke(acwrColor(acwr.zone).opacity(0.35), lineWidth: 0.8)
                )
            }

            // Adaptive Engine Live Badge Bar
            if let adaptive = adaptiveSnapshot {
                AdaptiveEngineBadgeBar(snapshot: adaptive)
            }

            // 1-Tap Subjective RPE Calibration
            let isCalibrated = athleteStore.profile.lastRpeCalibrationDate == todayDateKey
            RPEQuickCalibrationRow(isCalibratedToday: isCalibrated) { feedback in
                athleteStore.recordRPEFeedback(
                    feedback,
                    hrvWasLow: (snapshot?.recovery.hrvZScore ?? 0) < -0.8,
                    sleepWasLow: (snapshot?.sleepLog.totalHours ?? 7.5) < 6.8,
                    dietaryDate: todayDateKey
                )
                Task {
                    await loadData(forceRefresh: false)
                }
            }
        }
        .lifecoreGlassCard(cornerRadius: 24, borderColor: LifecoreTheme.recoveryGreen.opacity(0.25))
    }

    private func acwrColor(_ zone: ACWRZone) -> Color {
        switch zone {
        case .undertraining: return LifecoreTheme.electricTeal
        case .sweetSpot: return LifecoreTheme.athleticEmerald
        case .caution: return LifecoreTheme.amberWarning
        case .dangerSpike: return LifecoreTheme.coralDanger
        }
    }

    // MARK: - 4. Bento Section: Sleep Architecture & Metabolism

    private var sleepAndMetabolismBentoSection: some View {
        VStack(spacing: 16) {
            sleepArchitectureCard
            activityAndNeatCard
        }
    }

    private var sleepArchitectureCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Архітектура сну", systemImage: "moon.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(LifecoreTheme.recoveryPurple)
                Spacer()
                let total = snapshot?.sleepLog.totalHours ?? 7.5
                Text(String(format: "%.1f год", total))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            let deep = snapshot?.sleepLog.deepHours ?? 1.3
            let rem = snapshot?.sleepLog.remHours ?? 1.6
            let core = snapshot?.sleepLog.coreHours ?? 4.2
            let awake = snapshot?.sleepLog.awakeHours ?? 0.4
            let sleepDebt = max(0.0, athleteStore.profile.targetSleepHours - (snapshot?.sleepLog.totalHours ?? 7.5))

            HStack(spacing: 8) {
                sleepBar(label: "Глибокий", hours: deep, color: Color(red: 0.35, green: 0.35, blue: 0.95))
                sleepBar(label: "REM", hours: rem, color: Color(red: 0.7, green: 0.35, blue: 0.95))
                sleepBar(label: "Легкий", hours: core, color: Color(red: 0.3, green: 0.7, blue: 0.95))
                sleepBar(label: "Не спав", hours: awake, color: Color.gray.opacity(0.6))
            }

            HStack {
                Text(deep >= 1.2 ? "✅ Оптимальний глибокий сон (клітинне відновлення)" : "⚠️ Дефіцит глибокого сну (<1.2 год)")
                    .font(.caption2)
                    .foregroundStyle(deep >= 1.2 ? LifecoreTheme.athleticEmerald : LifecoreTheme.amberWarning)
                Spacer()
                if sleepDebt > 0.2 {
                    Text("Борг сну: \(String(format: "%.1f", sleepDebt)) год")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(LifecoreTheme.coralDanger)
                } else {
                    Text("✅ Борг сну відсутній")
                        .font(.caption2)
                        .foregroundStyle(LifecoreTheme.athleticEmerald)
                }
            }
        }
        .lifecoreGlassCard()
    }

    private var activityAndNeatCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Чистий NEAT та Адаптивний TDEE", systemImage: "flame.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(LifecoreTheme.amberWarning)
                Spacer()
                if let adapt = adaptiveSnapshot {
                    Text("BMR: \(Int(adapt.dynamicTDEE.learnedBmrKcal)) ккал")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(LifecoreTheme.athleticEmerald)
                }
            }

            let act = snapshot?.dailyActivity
            let neat = snapshot?.pureNEATKcal ?? 450.0
            let workoutKcal = snapshot?.strain.workoutKcal ?? 0.0

            HStack(spacing: 12) {
                metricCell(title: "Кроки", value: "\(act?.steps ?? 8450)")
                metricCell(title: "Активні ккал", value: "\(Int(act?.activeKcal ?? 850))")
                metricCell(title: "Дистанція", value: String(format: "%.1f км", act?.distanceKm ?? 6.2))
            }

            Divider().background(Color.white.opacity(0.1))

            // NEAT Isolation & Dynamic TDEE Breakdown
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("Чистий NEAT (побутовий рух)")
                        .font(.caption)
                        .foregroundStyle(LifecoreTheme.textMuted)
                    Spacer()
                    Text("\(Int(neat)) ккал")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(LifecoreTheme.amberWarning)
                }

                HStack {
                    Text("Тренування (структуровані)")
                        .font(.caption)
                        .foregroundStyle(LifecoreTheme.textMuted)
                    Spacer()
                    Text("\(Int(workoutKcal)) ккал")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(LifecoreTheme.athleticEmerald)
                }

                let learnedBmr = adaptiveSnapshot?.dynamicTDEE.learnedBmrKcal ?? athleteStore.profile.bmrKcalPerDay
                let elapsedMinutes = max(1.0, Date().timeIntervalSince(Calendar.current.startOfDay(for: Date())) / 60.0)
                let accruedBMR = learnedBmr * min(1.0, elapsedMinutes / 1440.0)
                let currentTDEE = (act?.activeKcal ?? 0.0) + accruedBMR

                HStack {
                    Text("Адаптивний BMR (на цей час)")
                        .font(.caption)
                        .foregroundStyle(LifecoreTheme.textMuted)
                    Spacer()
                    Text("\(Int(accruedBMR)) ккал")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(LifecoreTheme.electricTeal)
                }

                HStack {
                    Text("Реальний TDEE (активність + BMR)")
                        .font(.caption)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(Int(currentTDEE)) ккал")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(LifecoreTheme.athleticEmerald)
                }

                Text("Apple Health активна енергія фіксує лише рух. Базальний метаболізм (BMR ~\(Int(learnedBmr)) ккал/добу) нараховується рівномірно протягом 24 годин.")
                    .font(.caption2)
                    .foregroundStyle(LifecoreTheme.textSubtle)
                    .padding(.top, 2)
            }
        }
        .lifecoreGlassCard()
    }

    // MARK: - 5. Today's Workouts Card

    private var todayWorkoutsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Сьогоднішні сесії", systemImage: "figure.run")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(LifecoreTheme.athleticEmerald)

            let workouts = snapshot?.workouts ?? []
            if workouts.isEmpty {
                HStack {
                    Text("Сьогодні ще немає зафіксованих тренувань.")
                        .font(.subheadline)
                        .foregroundStyle(LifecoreTheme.textMuted)
                    Spacer()
                }
                .padding(.vertical, 4)
            } else {
                ForEach(workouts, id: \.startedAt) { w in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(w.type.capitalized)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            Text("\(Int(w.durationMin)) хв\(w.distanceKm != nil ? String(format: " • %.2f км", w.distanceKm!) : "")")
                                .font(.caption)
                                .foregroundStyle(LifecoreTheme.textMuted)
                        }
                        Spacer()
                        if let kcal = w.activeCalories {
                            Text("\(Int(kcal)) ккал")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(LifecoreTheme.athleticEmerald)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .lifecoreGlassCard()
    }

    // MARK: - 6. Cloud Sync Action

    private var cloudSyncSection: some View {
        VStack(spacing: 8) {
            Button(action: {
                Task { await syncWithCloud() }
            }) {
                HStack(spacing: 8) {
                    if isSyncingWithCloud {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Синхронізувати з хмарою")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(LifecoreTheme.electricTeal)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isSyncingWithCloud)

            if let message = cloudSyncMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(LifecoreTheme.textMuted)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Reusable UI Helper Builders

    private func metricCell(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(LifecoreTheme.textSubtle)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sleepBar(label: String, hours: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(LifecoreTheme.textSubtle)
            Text(String(format: "%.1fг", hours))
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 5)
                Capsule()
                    .fill(color)
                    .frame(width: max(4, min(60, CGFloat(hours / 4.0) * 60)), height: 5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Logic & Live Data Fetching

    private func loadData(forceRefresh: Bool) async {
        isLoading = true
        errorMessage = nil

        // 1. Build longitudinal records to evaluate on-device AdaptivePhysiologyEngine
        let joinedRecords = await buildJoinedPhysiologyHistory(days: 28)
        let evaluatedAdaptive = AdaptivePhysiologyEngine.evaluateAdaptiveSnapshot(
            records: joinedRecords,
            priorBmrKcal: athleteStore.profile.bmrKcalPerDay,
            priorTargetKcal: athleteStore.profile.targetCaloriesKcal,
            priorBaseline: NocturnalVitalsBaseline(
                hrvMeanMs: athleteStore.profile.hrvBaselineMs,
                rhrMeanBpm: athleteStore.profile.restingHeartRateBaselineBpm,
                wristTempMeanCelsius: athleteStore.profile.wristTempBaselineCelsius,
                respiratoryRateMeanBpm: athleteStore.profile.respiratoryRateBaselineBpm,
                spo2MeanPct: athleteStore.profile.spo2BaselinePct
            ),
            currentWeights: athleteStore.profile.readinessWeights,
            rpeCheckinsCount: athleteStore.profile.rpeCalibrationCount,
            todayNeatKcal: 450.0,
            todayWorkoutKcal: 200.0
        )
        self.adaptiveSnapshot = evaluatedAdaptive

        let manager = HealthKitManager.shared
        if manager.isAvailable {
            do {
                try await manager.requestAuthorization()
                let liveSnapshot = try await manager.fetchTodaySnapshot(
                    readinessWeights: athleteStore.profile.readinessWeights,
                    vitalsBaseline: evaluatedAdaptive.dynamicVitalsBaseline,
                    trimpDrainFactor: evaluatedAdaptive.sensitivities.trimpBatteryDrainFactor
                )
                self.snapshot = liveSnapshot
            } catch {
                self.errorMessage = error.localizedDescription
                loadFallbackSnapshot(adaptive: evaluatedAdaptive)
            }
        } else {
            loadFallbackSnapshot(adaptive: evaluatedAdaptive)
        }

        isLoading = false
    }

    private func buildJoinedPhysiologyHistory(days: Int = 28) async -> [DailyJoinedPhysiologyRecord] {
        let rawWeightSamples = await HealthKitManager.shared.fetchBodyWeightHistory(days: days)
        let fetchedAutonomic = await HealthKitManager.shared.fetchAutonomicLongitudinalHistory(days: days)
        let fetchedEf = await HealthKitManager.shared.fetchAerobicEfficiencyHistory(limit: max(10, days / 4))
        let computedPoints = ReadinessCalculator.computeLongitudinalWeightTrend(samples: rawWeightSamples)

        let calendar = Calendar.current
        let today = Date()
        var dailyJoined: [DailyJoinedPhysiologyRecord] = []
        let allMeals = MealStorageService.shared.fetchAllMeals()

        for d in 0..<days {
            guard let recordDate = calendar.date(byAdding: .day, value: -d, to: today) else { continue }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let dateKey = formatter.string(from: recordDate)

            let dayMeals = allMeals.filter { $0.dietaryDate == dateKey }
            var daySodium = 0.0
            var dayCarbs = 0.0
            var dayProtein = 0.0
            var dayFat = 0.0
            var wholeCount = 0
            var ultraCount = 0

            for m in dayMeals {
                if let s = m.micronutrients?.sodiumMg { daySodium += s }
                dayCarbs += m.carbsG
                dayProtein += m.proteinG
                dayFat += m.fatG
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
                weightKg: weightPoint?.rawWeightKg ?? (d == 0 ? athleteStore.profile.weightKg : nil),
                rollingWeight7dKg: weightPoint?.rolling7dKg,
                sodiumMg: daySodium > 0 ? daySodium : (hasHighSodium ? 3800.0 : 1900.0),
                carbsG: dayCarbs > 0 ? dayCarbs : 215.0,
                proteinG: dayProtein > 0 ? dayProtein : 165.0,
                fatG: dayFat > 0 ? dayFat : 70.0,
                wholeFoodRatio: wholeRatio,
                ultraProcessedRatio: ultraRatio,
                hasLateMealAfter2130: hasLateMeal,
                hasHighSodiumMeal: hasHighSodium,
                overnightHrvMs: autoSample?.hrvMs ?? (d == 0 ? athleteStore.profile.hrvBaselineMs : nil),
                overnightRhrBpm: autoSample?.rhrBpm ?? (d == 0 ? athleteStore.profile.restingHeartRateBaselineBpm : nil),
                deepSleepHours: 1.3,
                remSleepHours: 1.5,
                workoutTrimp: efSample != nil ? 95.0 : 35.0,
                runningCardiacDriftPct: efSample?.aerobicDecouplingPct,
                runningEf: efSample?.efficiencyFactor
            ))
        }

        return dailyJoined
    }

    private func loadFallbackSnapshot(adaptive: AdaptivePhysiologySnapshot) {
        let baseline = ReadinessCalculator.Baseline(
            avgHrvSDNN: adaptive.dynamicVitalsBaseline.hrvMeanMs,
            stdDevHrv: adaptive.dynamicVitalsBaseline.hrvStdDevMs,
            avgRHR: adaptive.dynamicVitalsBaseline.rhrMeanBpm,
            targetSleepHours: athleteStore.profile.targetSleepHours,
            targetDeepHours: 1.2,
            targetRemHours: 1.5
        )
        let sleep = SleepLog(
            sleepDate: todayDateKey,
            totalHours: 7.8,
            deepHours: 1.4,
            remHours: 1.6,
            coreHours: 4.3,
            awakeHours: 0.5,
            hrvAvgMs: adaptive.dynamicVitalsBaseline.hrvMeanMs + 2.0,
            rhrBpm: adaptive.dynamicVitalsBaseline.rhrMeanBpm - 1.0
        )
        let activity = DailyActivity(
            date: todayDateKey,
            steps: 9240,
            activeKcal: 865.0,
            distanceKm: 6.8
        )
        let recovery = ReadinessCalculator.computeRecovery(
            morningHrv: sleep.hrvAvgMs,
            morningRhr: sleep.rhrBpm,
            totalSleepHours: 7.8,
            deepSleepHours: 1.4,
            remSleepHours: 1.6,
            baseline: baseline,
            weights: athleteStore.profile.readinessWeights
        )
        let strain = ReadinessCalculator.computeStrain(
            dailyActiveKcal: 865.0,
            workouts: []
        )
        let neat = ReadinessCalculator.isolatePureNEAT(dailyActiveKcal: 865.0, workoutActiveKcals: [])

        let vitalsEval = VitalsAndIllnessEngine.evaluateOvernightVitals(
            input: NocturnalVitalsInput(
                hrvMs: sleep.hrvAvgMs ?? adaptive.dynamicVitalsBaseline.hrvMeanMs,
                rhrBpm: sleep.rhrBpm ?? adaptive.dynamicVitalsBaseline.rhrMeanBpm,
                wristTempCelsius: athleteStore.profile.wristTempBaselineCelsius,
                respiratoryRateBpm: athleteStore.profile.respiratoryRateBaselineBpm,
                spo2Pct: athleteStore.profile.spo2BaselinePct
            ),
            baseline: adaptive.dynamicVitalsBaseline
        )

        let energyBank = TrainingLoadAndBatteryEngine.computeEnergyBankTimeline(
            wakeRecoveryScore: recovery.score,
            sleepHours: sleep.totalHours,
            targetSleepHours: athleteStore.profile.targetSleepHours,
            pureNeatKcal: neat,
            workouts: [],
            immuneState: vitalsEval.state,
            currentHour: Calendar.current.component(.hour, from: Date()),
            trimpDrainFactor: adaptive.sensitivities.trimpBatteryDrainFactor
        )

        let acwr = TrainingLoadAndBatteryEngine.computeEWMAWorkload(
            dailyLoads: [(date: Date(), trimp: 45.0)]
        )

        self.snapshot = TodaySnapshot(
            dailyActivity: activity,
            sleepLog: sleep,
            workouts: [],
            baseline: baseline,
            recovery: recovery,
            strain: strain,
            pureNEATKcal: neat,
            vitalsEvaluation: vitalsEval,
            energyBank: energyBank,
            acwr: acwr
        )
    }

    private func syncWithCloud() async {
        guard let snap = snapshot else { return }
        isSyncingWithCloud = true
        cloudSyncMessage = "Синхронізація..."

        do {
            try await SupabaseSyncService.shared.syncTelemetry(
                dailyActivity: snap.dailyActivity,
                sleep: snap.sleepLog,
                workout: snap.workouts.first,
                pureNEATKcal: snap.pureNEATKcal
            )
            let result = await SupabaseSyncService.shared.syncAll()
            cloudSyncMessage = "✅ Хмара оновлена (страв: \(result.mealsSynced), тренувань: \(result.analysesSynced))"
        } catch {
            cloudSyncMessage = "⚠️ Помилка: \(error.localizedDescription)"
        }

        isSyncingWithCloud = false
    }
}

// MARK: - Bevel Ring Component (Liquid Glass Bento styled)

public struct BevelRingView: View {
    public let title: String
    public let value: String
    public let subtitle: String
    public let progress: Double
    public let ringColor: Color

    public init(
        title: String,
        value: String,
        subtitle: String,
        progress: Double,
        ringColor: Color
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.progress = progress
        self.ringColor = ringColor
    }

    public var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Background Track
                Circle()
                    .stroke(ringColor.opacity(0.18), lineWidth: 7)

                // Animated Progress Ring
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(1.0, max(0.02, progress))))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [ringColor.opacity(0.7), ringColor]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                // Center Value
                VStack(spacing: 1) {
                    Text(value)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(title)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(LifecoreTheme.textSubtle)
                }
            }
            .frame(width: 80, height: 80)

            Text(subtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(LifecoreTheme.textMuted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    TodayView()
        .preferredColorScheme(.dark)
}
