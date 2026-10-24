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
            return LifecoreTheme.coralDanger
        case .downgradedByVitalsOrBattery, .modulatedByHRV, .cappedByCaloricDeficit, .downgradedByAcuteLoadSpike, .heldByCardiacDrift:
            return LifecoreTheme.amberWarning
        case .efficiencyUnlocked, .optimalProgression, .externalClubRunAdapted:
            return LifecoreTheme.athleticEmerald
        }
    }

    public var body: some View {
        Button(action: {
            onNavigateToWorkouts?()
        }) {
            HStack(spacing: 14) {
                // Circular Activity Glyph (Bevel-style dashed/glow ring)
                ZStack {
                    Circle()
                        .strokeBorder(LifecoreTheme.electricTeal.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [3]))
                        .frame(width: 46, height: 46)
                    Circle()
                        .fill(LifecoreTheme.electricTeal.opacity(0.12))
                        .frame(width: 46, height: 46)
                    Image(systemName: prescription.archetype.iconName)
                        .font(.system(size: 20))
                        .foregroundStyle(LifecoreTheme.electricTeal)
                }

                // Title & Metrics Details
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("СЬОГОДНІ")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(LifecoreTheme.electricTeal)

                        Text("•")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)

                        Text(prescription.cleanTitleUk)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .accessibilityIdentifier("txt_prescription_archetype")
                    }

                    if prescription.totalDurationMin > 0 {
                        HStack(spacing: 6) {
                            Text("\(Int(round(prescription.totalDurationMin))) хв")
                            Text("•")
                            Text("~\(String(format: "%.1f", prescription.estimatedDistanceKm)) км")
                            Text("•")
                            Text(prescription.maxAllowedZone.titleUk)
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    } else {
                        Text("День повного відновлення")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Reason Glow Pill (Compact) + Chevron
                HStack(spacing: 8) {
                    LifecoreGlowPill(
                        text: prescription.adaptationReason.titleUk,
                        systemIcon: "sparkles",
                        color: reasonColor
                    )
                    .accessibilityIdentifier("pill_prescription_reason")

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .lifecoreGlassCard(cornerRadius: 18, borderColor: LifecoreTheme.electricTeal.opacity(0.2))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("card_tactical_prescription")
    }
}
