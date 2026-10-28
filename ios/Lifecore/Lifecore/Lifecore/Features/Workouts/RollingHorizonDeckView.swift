import SwiftUI
import HealthKit

public struct RollingHorizonDeckView: View {
    @ObservedObject public var planStore = TrainingPlanStore.shared
    @ObservedObject public var athleteStore = AthleteProfileStore.shared
    public var pastWorkouts: [HKWorkout] = []

    @State private var selectedDayOffset: Int = 0

    public init(pastWorkouts: [HKWorkout] = []) {
        self.pastWorkouts = pastWorkouts
    }

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

    private var todayPrescription: DailyWorkoutPrescription {
        currentPlan.today
    }

    private var bannerColor: Color {
        switch todayPrescription.adaptationReason {
        case .blockedByIllnessProdrome:
            return LifecoreTheme.statusDanger
        case .downgradedByVitalsOrBattery, .modulatedByHRV, .cappedByCaloricDeficit, .downgradedByAcuteLoadSpike, .heldByCardiacDrift:
            return LifecoreTheme.statusWarning
        case .efficiencyUnlocked, .optimalProgression, .externalClubRunAdapted:
            return LifecoreTheme.statusOptimal
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 1. Upgraded Interactive Bevel 7-Day Calendar Strip
            bevelCalendarStrip

            // 2. AI Coach Recommendation Banner
            bevelCoachRecommendationBanner

            // 3. Selected Day Activity Inspector (Today + Past/Future Inspection)
            selectedDayActivitySection

            // 4. Upcoming Horizon Schedule
            upcomingHorizonSection
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("deck_rolling_horizon")
    }

    // MARK: - 1. Interactive Bevel 7-Day Calendar Strip

    private struct DaySlot: Identifiable {
        let id: Int
        let offset: Int
        let date: Date
        let dayLetter: String
        let dayNumber: String
        let isToday: Bool
    }

    private var calendarDays: [DaySlot] {
        let cal = Calendar.current
        let today = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk_UA")

        return (-3...3).map { offset in
            let date = cal.date(byAdding: .day, value: offset, to: today) ?? today
            formatter.dateFormat = "EE"
            let letter = formatter.string(from: date).capitalized
            formatter.dateFormat = "d"
            let num = formatter.string(from: date)
            return DaySlot(
                id: offset,
                offset: offset,
                date: date,
                dayLetter: letter,
                dayNumber: num,
                isToday: offset == 0
            )
        }
    }

    private var bevelCalendarStrip: some View {
        VStack(spacing: 10) {
            HStack {
                Text(monthHeaderTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LifecoreTheme.inkSecondary)
                Spacer()
                if selectedDayOffset != 0 {
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.18)) {
                            selectedDayOffset = 0
                        }
                    }) {
                        Text("Повернутись до сьогодні")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LifecoreTheme.accentPrimary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Тижневий цикл")
                        .font(.system(size: 12))
                        .foregroundStyle(LifecoreTheme.inkTertiary)
                }
            }

            HStack(spacing: 4) {
                ForEach(calendarDays) { slot in
                    let isSelected = (slot.offset == selectedDayOffset)
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.18)) {
                            selectedDayOffset = slot.offset
                        }
                    }) {
                        VStack(spacing: 6) {
                            Text(slot.dayLetter)
                                .font(.system(size: 11, weight: isSelected || slot.isToday ? .semibold : .regular))
                                .foregroundStyle(
                                    isSelected ? LifecoreTheme.inkPrimary :
                                    (slot.isToday ? LifecoreTheme.accentPrimary : LifecoreTheme.inkTertiary)
                                )

                            Text(slot.dayNumber)
                                .font(.system(size: 15, weight: isSelected || slot.isToday ? .bold : .medium, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(
                                    isSelected ? LifecoreTheme.inkPrimary :
                                    (slot.isToday ? LifecoreTheme.accentPrimary : LifecoreTheme.inkSecondary)
                                )

                            glyphForSlot(slot, isSelected: isSelected)

                            Circle()
                                .fill(slot.isToday ? LifecoreTheme.accentPrimary : Color.clear)
                                .frame(width: 4, height: 4)
                        }
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isSelected ? LifecoreTheme.paperWell : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .lifecoreGlassCard(cornerRadius: 20, padding: 14)
    }

    private var monthHeaderTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk_UA")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: Date()).capitalized
    }

    @ViewBuilder
    private func glyphForSlot(_ slot: DaySlot, isSelected: Bool) -> some View {
        if slot.isToday {
            ZStack {
                Circle()
                    .strokeBorder(
                        LifecoreTheme.accentPrimary,
                        style: StrokeStyle(lineWidth: 1.5, dash: [3])
                    )
                    .frame(width: 34, height: 34)
                Circle()
                    .fill(LifecoreTheme.accentPrimary.opacity(isSelected ? 0.18 : 0.10))
                    .frame(width: 34, height: 34)
                Image(systemName: todayPrescription.archetype.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LifecoreTheme.accentPrimary)
            }
        } else if slot.offset < 0 {
            if let w = workoutFor(date: slot.date) {
                let info = glyphInfoForWorkout(w)
                ZStack {
                    Circle()
                        .fill(info.color.opacity(0.15))
                        .frame(width: 34, height: 34)
                    Image(systemName: info.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(info.color)
                }
            } else {
                ZStack {
                    Circle()
                        .fill(LifecoreTheme.paperWell)
                        .frame(width: 34, height: 34)
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(LifecoreTheme.inkTertiary)
                }
            }
        } else {
            let queueIdx = slot.offset - 1
            if queueIdx < currentPlan.horizonQueue.count {
                let upcoming = currentPlan.horizonQueue[queueIdx]
                if upcoming.archetype == .restDay {
                    ZStack {
                        Circle()
                            .fill(LifecoreTheme.paperWell)
                            .frame(width: 34, height: 34)
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(LifecoreTheme.inkTertiary)
                    }
                } else {
                    ZStack {
                        Circle()
                            .strokeBorder(LifecoreTheme.accentTeal.opacity(0.45), style: StrokeStyle(lineWidth: 1.2, dash: [3]))
                            .frame(width: 34, height: 34)
                        Image(systemName: upcoming.archetype.iconName)
                            .font(.system(size: 13))
                            .foregroundStyle(LifecoreTheme.accentTeal)
                    }
                }
            }
        }
    }

    private func workoutFor(date: Date) -> HKWorkout? {
        let cal = Calendar.current
        return pastWorkouts.first { cal.isDate($0.startDate, inSameDayAs: date) }
    }

    private func glyphInfoForWorkout(_ w: HKWorkout) -> (icon: String, color: Color) {
        switch w.workoutActivityType {
        case .running:
            return ("figure.run", LifecoreTheme.statusOptimal)
        case .cycling:
            return ("figure.outdoor.cycle", LifecoreTheme.accentTeal)
        case .traditionalStrengthTraining, .functionalStrengthTraining:
            return ("figure.strengthtraining.traditional", LifecoreTheme.statusWarning)
        case .walking:
            return ("figure.walk", LifecoreTheme.accentIndigo)
        default:
            return ("bolt.heart.fill", LifecoreTheme.accentPrimary)
        }
    }

    // MARK: - 2. AI Coach Recommendation Banner

    private var bevelCoachRecommendationBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: todayPrescription.adaptationReason == .blockedByIllnessProdrome ? "cross.case.fill" : "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(bannerColor)

                Text(todayPrescription.adaptationReason.bevelHeadlineUk)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(LifecoreTheme.inkPrimary)
                    .lineLimit(2)

                Spacer()
            }

            Text(todayPrescription.adaptationReason.bevelExplanationUk)
                .font(.system(size: 13))
                .foregroundStyle(LifecoreTheme.inkSecondary)
                .lineSpacing(2)

            if planStore.queueState.clubOrCustomRunOverrideToday {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(LifecoreTheme.statusOptimal)
                    Text("Сьогодні враховано клубну сесію. Черга тренувань збережена.")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(LifecoreTheme.statusOptimal)
                }
                .padding(.top, 2)
            }
        }
        .lifecoreGlassCard(cornerRadius: 20)
    }

    // MARK: - 3. Selected Day Activity Section

    private var selectedDayActivitySection: some View {
        let activePrescription: DailyWorkoutPrescription = {
            if selectedDayOffset > 0 {
                let idx = selectedDayOffset - 1
                if idx < currentPlan.horizonQueue.count {
                    return currentPlan.horizonQueue[idx]
                }
            }
            return todayPrescription
        }()

        let sectionHeaderTitle: String = {
            if selectedDayOffset == 0 { return "Сьогоднішня активність" }
            if selectedDayOffset < 0 { return "Архів за обраний день" }
            return "Запланована сесія (\(slotLabel(offset: selectedDayOffset)))"
        }()

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(sectionHeaderTitle)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(LifecoreTheme.inkPrimary)

                Spacer()

                LifecoreGlowPill(
                    text: activePrescription.archetype.loadLevelUk,
                    systemIcon: "flame.fill",
                    color: LifecoreTheme.accentTeal
                )
            }

            if selectedDayOffset < 0 {
                if let slot = calendarDays.first(where: { $0.offset == selectedDayOffset }),
                   let pastW = workoutFor(date: slot.date) {
                    let distKm = (pastW.totalDistance?.doubleValue(for: .meter()) ?? 0) / 1000.0
                    let durMin = pastW.duration / 60.0
                    HStack(spacing: 12) {
                        let info = glyphInfoForWorkout(pastW)
                        ZStack {
                            Circle()
                                .fill(info.color.opacity(0.14))
                                .frame(width: 44, height: 44)
                            Image(systemName: info.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(info.color)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Виконане тренування")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(LifecoreTheme.inkSecondary)
                            Text(String(format: "%.0f хв  ·  %.2f км", durMin, distKm))
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(LifecoreTheme.inkPrimary)
                        }
                        Spacer()
                    }
                    .lifecoreWell(cornerRadius: 14, padding: 12)
                } else {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(LifecoreTheme.paperWell)
                                .frame(width: 44, height: 44)
                            Image(systemName: "moon.zzz.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(LifecoreTheme.inkTertiary)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("День відпочинку")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(LifecoreTheme.inkSecondary)
                            Text("Тренувань не зафіксовано")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(LifecoreTheme.inkPrimary)
                        }
                        Spacer()
                    }
                    .lifecoreWell(cornerRadius: 14, padding: 12)
                }
            } else {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(LifecoreTheme.accentPrimary.opacity(0.12))
                            .frame(width: 48, height: 48)
                        Image(systemName: activePrescription.archetype.iconName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(LifecoreTheme.accentPrimary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(activePrescription.maxAllowedZone.titleUk)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(LifecoreTheme.inkSecondary)

                        Text(activePrescription.cleanTitleUk)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(LifecoreTheme.inkPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        if activePrescription.totalDurationMin > 0 {
                            HStack(spacing: 10) {
                                Label("\(Int(round(activePrescription.totalDurationMin))) хв", systemImage: "clock")
                                Label("~\(String(format: "%.1f", activePrescription.estimatedDistanceKm)) км", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                                if let targetPace = activePrescription.segments.first(where: { $0.targetPaceSecPerKm > 0 })?.formattedPace {
                                    Text(targetPace)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(LifecoreTheme.statusOptimal)
                                }
                            }
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(LifecoreTheme.inkSecondary)
                            .lineLimit(1)
                        } else {
                            Text("День відпочинку та відновлення сил")
                                .font(.system(size: 12))
                                .foregroundStyle(LifecoreTheme.inkSecondary)
                        }
                    }

                    Spacer()
                }

                if !activePrescription.segments.isEmpty && activePrescription.totalDurationMin > 0 {
                    HStack(spacing: 6) {
                        ForEach(activePrescription.segments) { seg in
                            HStack(spacing: 4) {
                                Text(seg.zone.shortBadgeUk)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(LifecoreTheme.accentTeal)
                                Text("\(Int(seg.durationMin)) хв")
                                    .font(.system(size: 10))
                                    .monospacedDigit()
                                    .foregroundStyle(LifecoreTheme.inkSecondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(LifecoreTheme.paperWell)
                            .clipShape(Capsule())
                        }
                        Spacer()
                    }
                }
            }

            LifecoreHairlineDivider()

            if selectedDayOffset == 0 {
                // 1-Tap Club / Custom Run Recalculation Button (Always accessible for E2E Flow 05)
                Button(action: {
                    withAnimation(.easeOut(duration: 0.2)) {
                        planStore.toggleClubOrCustomRunToday()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: planStore.queueState.clubOrCustomRunOverrideToday ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                        Text(planStore.queueState.clubOrCustomRunOverrideToday
                             ? "Сьогодні біжу в клубі / за своїм планом (увімкнено)"
                             : "Біжу в клубі або за своїм планом (адаптувати чергу)")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        planStore.queueState.clubOrCustomRunOverrideToday
                            ? LifecoreTheme.statusOptimal.opacity(0.14)
                            : LifecoreTheme.paperWell
                    )
                    .foregroundStyle(
                        planStore.queueState.clubOrCustomRunOverrideToday
                            ? LifecoreTheme.statusOptimal
                            : LifecoreTheme.inkPrimary
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("btn_recalculate_club_queue")
            } else {
                Button(action: {
                    withAnimation(.easeOut(duration: 0.18)) {
                        selectedDayOffset = 0
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Повернутись до сьогодні")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(LifecoreTheme.paperWell)
                    .foregroundStyle(LifecoreTheme.accentPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .lifecoreGlassCard(cornerRadius: 20)
    }

    // MARK: - 4. Upcoming Horizon Schedule

    private var upcomingHorizonSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Найближчі тренування")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(LifecoreTheme.inkPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(currentPlan.horizonQueue) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(slotLabel(offset: item.dayOffset))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(LifecoreTheme.accentPrimary)
                                Spacer()
                                Text(item.archetype.loadLevelUk)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(LifecoreTheme.inkTertiary)
                            }

                            Text(item.cleanTitleUk)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(LifecoreTheme.inkPrimary)
                                .lineLimit(2)

                            if item.totalDurationMin > 0 {
                                Text("\(Int(item.totalDurationMin)) хв  ·  ~\(String(format: "%.1f", item.estimatedDistanceKm)) км")
                                    .font(.system(size: 11, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(LifecoreTheme.inkSecondary)
                            } else {
                                Text("Відпочинок")
                                    .font(.system(size: 11))
                                    .foregroundStyle(LifecoreTheme.inkSecondary)
                            }
                        }
                        .frame(width: 172, alignment: .leading)
                        .lifecoreGlassCard(cornerRadius: 16, padding: 12)
                    }
                }
            }
        }
    }

    private func slotLabel(offset: Int) -> String {
        switch offset {
        case 1: return "Завтра"
        case 2: return "Через 2 дні"
        case 3: return "Через 3 дні"
        default: return "Слот +\(offset)"
        }
    }
}
