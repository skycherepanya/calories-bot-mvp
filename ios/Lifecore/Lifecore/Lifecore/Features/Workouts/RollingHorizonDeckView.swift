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
