import SwiftUI

public struct TacticalPrescriptionCard: View {
    public let plan: TrainingPrescriptionPlan?
    public let unavailabilityReasons: [PrescriptionUnavailabilityReason]
    public var onSkipOrAdvance: (() -> Void)?
    public var onNavigateToWorkouts: (() -> Void)?

    public init(
        plan: TrainingPrescriptionPlan?,
        unavailabilityReasons: [PrescriptionUnavailabilityReason] = [],
        onSkipOrAdvance: (() -> Void)? = nil,
        onNavigateToWorkouts: (() -> Void)? = nil
    ) {
        self.plan = plan
        self.unavailabilityReasons = unavailabilityReasons
        self.onSkipOrAdvance = onSkipOrAdvance
        self.onNavigateToWorkouts = onNavigateToWorkouts
    }

    public init(
        snapshot: DailyDashboardSnapshot?,
        onSkipOrAdvance: (() -> Void)? = nil,
        onNavigateToWorkouts: (() -> Void)? = nil
    ) {
        self.init(
            plan: snapshot?.prescriptionPlan,
            unavailabilityReasons: snapshot?.unavailabilityReasons ?? [],
            onSkipOrAdvance: onSkipOrAdvance,
            onNavigateToWorkouts: onNavigateToWorkouts
        )
    }

    private func reasonColor(for reason: AdaptationReason) -> Color {
        switch reason {
        case .blockedByIllnessProdrome:
            return LifecoreTheme.statusDanger
        case .downgradedByVitalsOrBattery, .modulatedByHRV, .cappedByCaloricDeficit, .downgradedByAcuteLoadSpike, .heldByCardiacDrift:
            return LifecoreTheme.statusWarning
        case .efficiencyUnlocked, .optimalProgression, .externalClubRunAdapted:
            return LifecoreTheme.statusOptimal
        }
    }

    private var unavailabilityBadgeText: String {
        if unavailabilityReasons.contains(.noObservationsAvailable) {
            return "Немає спостережень"
        }
        if unavailabilityReasons.contains(.missingOvernightVitals) {
            return "Очікує сну"
        }
        if unavailabilityReasons.contains(.missingWorkloadHistory) {
            return "Очікує ACWR"
        }
        if unavailabilityReasons.contains(.missingHeartRateBaselines) {
            return "Межі пульсу"
        }
        return "План на паузі"
    }

    private var unavailabilityHeadline: String {
        if unavailabilityReasons.contains(.noObservationsAvailable) {
            return "Сесія очікує біомаркерів"
        }
        if unavailabilityReasons.contains(.missingOvernightVitals) {
            return "Очікування нічних показників"
        }
        if unavailabilityReasons.contains(.missingWorkloadHistory) {
            return "Формування навантаження"
        }
        return "План відновлення сил"
    }

    private var unavailabilityExplanation: String {
        if let first = unavailabilityReasons.first {
            return first.titleUk
        }
        return "Синхронізуйте вимірювання Apple Watch для персональної рекомендації."
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

                    if let prescription = plan?.today {
                        LifecoreGlowPill(
                            text: prescription.adaptationReason.titleUk,
                            systemIcon: "checkmark.circle.fill",
                            color: reasonColor(for: prescription.adaptationReason)
                        )
                        .accessibilityIdentifier("pill_prescription_reason")
                    } else {
                        LifecoreGlowPill(
                            text: unavailabilityBadgeText,
                            systemIcon: "info.circle",
                            color: LifecoreTheme.inkSecondary
                        )
                        .accessibilityIdentifier("pill_prescription_reason")
                    }
                }

                if let prescription = plan?.today {
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
                } else {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(LifecoreTheme.inkTertiary.opacity(0.12))
                                .frame(width: 44, height: 44)
                            Image(systemName: "figure.walk")
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(LifecoreTheme.inkSecondary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(unavailabilityHeadline)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(LifecoreTheme.inkPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .accessibilityIdentifier("txt_prescription_archetype")

                            Text(unavailabilityExplanation)
                                .font(.system(size: 12))
                                .foregroundStyle(LifecoreTheme.inkSecondary)
                                .lineLimit(2)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LifecoreTheme.inkTertiary)
                    }
                }
            }
            .lifecoreGlassCard(cornerRadius: 20)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("card_tactical_prescription")
    }
}
