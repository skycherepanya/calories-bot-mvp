import SwiftUI
import HealthKit

public struct RollingHorizonDeckView: View {
    @ObservedObject public var planStore = TrainingPlanStore.shared
    @ObservedObject public var athleteStore = AthleteProfileStore.shared
    public var pastWorkouts: [HKWorkout] = []

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
            return LifecoreTheme.coralDanger
        case .downgradedByVitalsOrBattery, .modulatedByHRV, .cappedByCaloricDeficit, .downgradedByAcuteLoadSpike, .heldByCardiacDrift:
            return LifecoreTheme.amberWarning
        case .efficiencyUnlocked, .optimalProgression, .externalClubRunAdapted:
            return LifecoreTheme.athleticEmerald
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 1. Bevel 7-Day Calendar Strip
            bevelCalendarStrip

            // 2. AI Coach Recommendation Banner
            bevelCoachRecommendationBanner

            // 3. Today's Activity Section
            todayActivitySection

            // 4. Upcoming Horizon Schedule
            upcomingHorizonSection
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("deck_rolling_horizon")
    }

    // MARK: - 1. Bevel 7-Day Calendar Strip

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
        HStack(spacing: 0) {
            ForEach(calendarDays) { slot in
                VStack(spacing: 6) {
                    // Triangle pointer for today
                    if slot.isToday {
                        Image(systemName: "arrowtriangle.down.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(LifecoreTheme.electricTeal)
                    } else {
                        Color.clear.frame(height: 8)
                    }

                    // Day of week
                    Text(slot.dayLetter)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(slot.isToday ? LifecoreTheme.electricTeal : .secondary)

                    // Day number
                    Text(slot.dayNumber)
                        .font(.system(size: 15, weight: slot.isToday ? .bold : .medium))
                        .foregroundStyle(slot.isToday ? LifecoreTheme.electricTeal : .white)

                    // Activity glyph
                    glyphForSlot(slot)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
        .lifecoreGlassCard(cornerRadius: 18, borderColor: Color.white.opacity(0.08))
    }

    @ViewBuilder
    private func glyphForSlot(_ slot: DaySlot) -> some View {
        if slot.isToday {
            // Today active glyph
            ZStack {
                Circle()
                    .strokeBorder(LifecoreTheme.electricTeal, style: StrokeStyle(lineWidth: 1.5, dash: [3]))
                    .frame(width: 34, height: 34)
                Circle()
                    .fill(LifecoreTheme.electricTeal.opacity(0.18))
                    .frame(width: 34, height: 34)
                Image(systemName: todayPrescription.archetype.iconName)
                    .font(.system(size: 14))
                    .foregroundStyle(LifecoreTheme.electricTeal)
            }
        } else if slot.offset < 0 {
            // Past days: match workout or rest
            if let w = workoutFor(date: slot.date) {
                let info = glyphInfoForWorkout(w)
                ZStack {
                    Circle()
                        .fill(info.color.opacity(0.18))
                        .frame(width: 34, height: 34)
                    Image(systemName: info.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(info.color)
                }
            } else {
                // Rest day
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 34, height: 34)
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            // Future days: show upcoming queued session or rest
            let queueIdx = slot.offset - 1
            if queueIdx < currentPlan.horizonQueue.count {
                let upcoming = currentPlan.horizonQueue[queueIdx]
                if upcoming.archetype == .restDay {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 34, height: 34)
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ZStack {
                        Circle()
                            .strokeBorder(LifecoreTheme.electricTeal.opacity(0.4), style: StrokeStyle(lineWidth: 1.2, dash: [3]))
                            .frame(width: 34, height: 34)
                        Image(systemName: upcoming.archetype.iconName)
                            .font(.system(size: 13))
                            .foregroundStyle(LifecoreTheme.electricTeal.opacity(0.8))
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
            return ("figure.run", LifecoreTheme.athleticEmerald)
        case .cycling:
            return ("figure.outdoor.cycle", Color.purple)
        case .traditionalStrengthTraining, .functionalStrengthTraining:
            return ("figure.strengthtraining.traditional", LifecoreTheme.strainOrange)
        case .walking:
            return ("figure.walk", Color.cyan)
        default:
            return ("bolt.heart.fill", LifecoreTheme.electricTeal)
        }
    }

    // MARK: - 2. AI Coach Recommendation Banner

    private var bevelCoachRecommendationBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: todayPrescription.adaptationReason == .blockedByIllnessProdrome ? "cross.case.fill" : "figure.run")
                    .font(.headline)
                    .foregroundStyle(bannerColor)

                Text(todayPrescription.adaptationReason.bevelHeadlineUk)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Spacer()

                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(todayPrescription.adaptationReason.bevelExplanationUk)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.85))
                .lineSpacing(3)

            if planStore.queueState.clubOrCustomRunOverrideToday {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(LifecoreTheme.athleticEmerald)
                    Text("Сьогодні враховано клубну сесію. Черга тренувань збережена.")
                        .font(.caption2)
                        .foregroundStyle(LifecoreTheme.athleticEmerald)
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .lifecoreGlassCard(cornerRadius: 20, borderColor: bannerColor.opacity(0.35))
    }

    // MARK: - 3. Today's Activity Section

    private var todayActivitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Сьогоднішня активність")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)

                Spacer()

                LifecoreGlowPill(
                    text: todayPrescription.archetype.loadLevelUk,
                    systemIcon: "flame.fill",
                    color: LifecoreTheme.electricTeal
                )
            }

            // Clean Activity Card
            VStack(spacing: 12) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .strokeBorder(LifecoreTheme.electricTeal, style: StrokeStyle(lineWidth: 1.5, dash: [3]))
                            .frame(width: 48, height: 48)
                        Circle()
                            .fill(LifecoreTheme.electricTeal.opacity(0.15))
                            .frame(width: 48, height: 48)
                        Image(systemName: todayPrescription.archetype.iconName)
                            .font(.system(size: 22))
                            .foregroundStyle(LifecoreTheme.electricTeal)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("СЬОГОДНІ • \(todayPrescription.maxAllowedZone.titleUk)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Text(todayPrescription.cleanTitleUk)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)

                        if todayPrescription.totalDurationMin > 0 {
                            HStack(spacing: 8) {
                                Label("\(Int(round(todayPrescription.totalDurationMin))) хв", systemImage: "clock")
                                Text("•")
                                Label("~\(String(format: "%.1f", todayPrescription.estimatedDistanceKm)) км", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                                if let targetPace = todayPrescription.segments.first(where: { $0.targetPaceSecPerKm > 0 })?.formattedPace {
                                    Text("•")
                                    Text(targetPace)
                                }
                            }
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(LifecoreTheme.athleticEmerald)
                        } else {
                            Text("День відпочинку та відновлення сил")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }

                // Segments overview (compact pills)
                if !todayPrescription.segments.isEmpty && todayPrescription.totalDurationMin > 0 {
                    HStack(spacing: 6) {
                        ForEach(todayPrescription.segments) { seg in
                            HStack(spacing: 4) {
                                Text(seg.zone.shortBadgeUk)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(LifecoreTheme.electricTeal)
                                Text("\(Int(seg.durationMin))хв")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Capsule())
                        }
                        Spacer()
                    }
                }

                Divider().background(Color.white.opacity(0.08))

                // 1-Tap Club / Custom Run Recalculation Button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        planStore.toggleClubOrCustomRunToday()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: planStore.queueState.clubOrCustomRunOverrideToday ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                        Text(planStore.queueState.clubOrCustomRunOverrideToday
                             ? "Сьогодні біжу в клубі / за своїм планом (Увімкнено)"
                             : "Біжу в клубі або за своїм планом (Адаптувати чергу)")
                            .font(.caption.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        planStore.queueState.clubOrCustomRunOverrideToday
                            ? LifecoreTheme.athleticEmerald.opacity(0.22)
                            : Color.white.opacity(0.08)
                    )
                    .foregroundStyle(
                        planStore.queueState.clubOrCustomRunOverrideToday
                            ? LifecoreTheme.athleticEmerald
                            : LifecoreTheme.electricTeal
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("btn_recalculate_club_queue")
            }
            .padding(14)
            .lifecoreGlassCard(cornerRadius: 18, borderColor: LifecoreTheme.electricTeal.opacity(0.2))
        }
    }

    // MARK: - 4. Upcoming Horizon Schedule

    private var upcomingHorizonSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Найближчі тренування")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(currentPlan.horizonQueue) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(slotLabel(offset: item.dayOffset))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(LifecoreTheme.electricTeal)
                                Spacer()
                                Text(item.archetype.loadLevelUk)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }

                            Text(item.cleanTitleUk)
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .lineLimit(2)

                            if item.totalDurationMin > 0 {
                                Text("\(Int(item.totalDurationMin)) хв • ~\(String(format: "%.1f", item.estimatedDistanceKm)) км")
                                    .font(.system(size: 10).monospacedDigit())
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Відпочинок")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 170, alignment: .leading)
                        .padding(12)
                        .lifecoreGlassCard(cornerRadius: 14, borderColor: Color.white.opacity(0.08))
                    }
                }
            }
        }
    }

    private func slotLabel(offset: Int) -> String {
        switch offset {
        case 1: return "ЗАВТРА"
        case 2: return "ЧЕРЕЗ 2 ДНІ"
        case 3: return "ЧЕРЕЗ 3 ДНІ"
        default: return "СЛОТ +\(offset)"
        }
    }
}
