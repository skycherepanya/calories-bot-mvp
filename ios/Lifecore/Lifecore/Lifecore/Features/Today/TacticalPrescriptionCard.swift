import SwiftUI

public struct TacticalPrescriptionCard: View {
    public let plan: TrainingPrescriptionPlan?
    public var onSkipOrAdvance: (() -> Void)?
    public var onNavigateToWorkouts: (() -> Void)?

    public init(
        plan: TrainingPrescriptionPlan?,
        onSkipOrAdvance: (() -> Void)? = nil,
        onNavigateToWorkouts: (() -> Void)? = nil
    ) {
        self.plan = plan
        self.onSkipOrAdvance = onSkipOrAdvance
        self.onNavigateToWorkouts = onNavigateToWorkouts
    }

    private var prescription: DailyWorkoutPrescription {
        if let p = plan?.today { return p }
        return TrainingPrescriptionEngine.prescribeTodayAndHorizon(
            queueState: RollingQueueState(),
            previousAcuteLoad: 62.0,
            previousChronicLoad: 60.0,
            vitalsState: .optimal
        ).today
    }

    private var reasonColor: Color {
        switch prescription.adaptationReason {
        case .blockedByIllnessProdrome:
            return LifecoreTheme.statusDanger
        case .downgradedByVitalsOrBattery, .modulatedByHRV, .cappedByCaloricDeficit, .downgradedByAcuteLoadSpike, .heldByCardiacDrift:
            return LifecoreTheme.statusWarning
        case .efficiencyUnlocked, .optimalProgression, .externalClubRunAdapted:
            return LifecoreTheme.statusOptimal
        }
    }

    public var body: some View {
        Button(action: {
            onNavigateToWorkouts?()
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LifecoreTheme.accentPrimary)

                        Text("Сьогоднішня активність")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LifecoreTheme.inkSecondary)
                    }

                    Spacer()

                    LifecoreGlowPill(
                        text: prescription.adaptationReason.titleUk,
                        systemIcon: "checkmark.circle.fill",
                        color: reasonColor
                    )
                    .accessibilityIdentifier("pill_prescription_reason")
                }

                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LifecoreTheme.accentPrimary.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: prescription.archetype.iconName)
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(LifecoreTheme.accentPrimary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(prescription.cleanTitleUk)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(LifecoreTheme.inkPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .accessibilityIdentifier("txt_prescription_archetype")

                        if prescription.totalDurationMin > 0 {
                            HStack(spacing: 10) {
                                Label("\(Int(round(prescription.totalDurationMin))) хв", systemImage: "clock")
                                Label("~\(String(format: "%.1f", prescription.estimatedDistanceKm)) км", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                                Text(prescription.maxAllowedZone.shortBadgeUk)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(LifecoreTheme.accentTeal)
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

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LifecoreTheme.inkTertiary)
                }
            }
            .lifecoreGlassCard(cornerRadius: 20)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("card_tactical_prescription")
    }
}
