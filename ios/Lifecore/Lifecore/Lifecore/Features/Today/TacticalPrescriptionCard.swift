import SwiftUI

public struct TacticalPrescriptionCard: View {
    public let plan: TrainingPrescriptionPlan?
    public var onSkipOrAdvance: (() -> Void)?

    public init(plan: TrainingPrescriptionPlan?, onSkipOrAdvance: (() -> Void)? = nil) {
        self.plan = plan
        self.onSkipOrAdvance = onSkipOrAdvance
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
        VStack(alignment: .leading, spacing: 14) {
            // Header Row: Archetype & Adaptation Reason Glow Pill
            HStack(alignment: .top, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: prescription.archetype.iconName)
                        .font(.headline)
                        .foregroundStyle(LifecoreTheme.electricTeal)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Тактичний план на сьогодні")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Text(prescription.archetype.titleUk)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .accessibilityIdentifier("txt_prescription_archetype")
                    }
                }

                Spacer()

                LifecoreGlowPill(
                    text: prescription.adaptationReason.titleUk,
                    systemIcon: "sparkles",
                    color: reasonColor
                )
                .accessibilityIdentifier("pill_prescription_reason")
            }

            Text(prescription.adaptationReason.subtitleUk)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))

            // KPI Badges Row: Target TRIMP, Est Distance, Pre-Run Carbs
            HStack(spacing: 8) {
                kpiPill(label: "Ціль TRIMP", value: "\(Int(prescription.targetTrimp))", color: LifecoreTheme.electricTeal)
                if prescription.totalDurationMin > 0 {
                    kpiPill(label: "Час / Об'єм", value: "\(Int(prescription.totalDurationMin)) хв • ~\(String(format: "%.1f", prescription.estimatedDistanceKm)) км", color: LifecoreTheme.recoveryGreen)
                }
                if let carbs = prescription.preWorkoutCarbsG {
                    kpiPill(label: "Вуглеводи за 2г", value: "+\(carbs) г", color: LifecoreTheme.strainOrange)
                }
            }

            Divider().background(Color.white.opacity(0.08))

            // Segments Breakdown
            VStack(spacing: 8) {
                ForEach(prescription.segments) { seg in
                    HStack {
                        Text(seg.zone.shortBadgeUk)
                            .font(.caption2.bold())
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(LifecoreTheme.electricTeal.opacity(0.18))
                            .foregroundStyle(LifecoreTheme.electricTeal)
                            .clipShape(Capsule())

                        VStack(alignment: .leading, spacing: 1) {
                            Text(seg.titleUk)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                            Text(seg.instructionUk)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        if seg.durationMin > 0 {
                            VStack(alignment: .trailing, spacing: 1) {
                                Text("\(seg.formattedPace)")
                                    .font(.caption.monospacedDigit().bold())
                                    .foregroundStyle(LifecoreTheme.athleticEmerald)
                                Text("≤\(seg.targetHrCapBpm) bpm • \(Int(seg.durationMin)) хв")
                                    .font(.system(size: 10).monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .accessibilityIdentifier("list_prescription_segments")
        }
        .padding(16)
        .lifecoreGlassCard(cornerRadius: 22, borderColor: reasonColor.opacity(0.28))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("card_tactical_prescription")
    }

    private func kpiPill(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit().bold())
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
