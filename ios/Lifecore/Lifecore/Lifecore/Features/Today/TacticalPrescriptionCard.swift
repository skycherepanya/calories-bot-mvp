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
            VStack(alignment: .leading, spacing: 10) {
                // Top Row: Section Label + Status Glow Pill (full width, zero crowding!)
                HStack(alignment: .center) {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(LifecoreTheme.electricTeal)

                        Text("СЬОГОДНІШНЯ АКТИВНІСТЬ")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(LifecoreTheme.electricTeal)
                    }

                    Spacer()

                    LifecoreGlowPill(
                        text: prescription.adaptationReason.titleUk,
                        systemIcon: "sparkles",
                        color: reasonColor
                    )
                    .accessibilityIdentifier("pill_prescription_reason")
                }

                // Main Row: Circular Glyph + Full Title & Clear Metrics + Chevron
                HStack(spacing: 12) {
                    // Circular Activity Glyph (Bevel-style dashed/glow ring)
                    ZStack {
                        Circle()
                            .strokeBorder(LifecoreTheme.electricTeal.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [3]))
                            .frame(width: 44, height: 44)
                        Circle()
                            .fill(LifecoreTheme.electricTeal.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: prescription.archetype.iconName)
                            .font(.system(size: 20))
                            .foregroundStyle(LifecoreTheme.electricTeal)
                    }

                    // Title & Metrics Details (Ample space - no truncations!)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(prescription.cleanTitleUk)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .accessibilityIdentifier("txt_prescription_archetype")

                        if prescription.totalDurationMin > 0 {
                            HStack(spacing: 6) {
                                Text("\(Int(round(prescription.totalDurationMin))) хв")
                                Text("•")
                                Text("~\(String(format: "%.1f", prescription.estimatedDistanceKm)) км")
                                Text("•")
                                Text(prescription.maxAllowedZone.shortBadgeUk)
                            }
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(LifecoreTheme.athleticEmerald)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        } else {
                            Text("День відпочинку та відновлення сил")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .lifecoreGlassCard(cornerRadius: 18, borderColor: LifecoreTheme.electricTeal.opacity(0.25))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("card_tactical_prescription")
    }
}
