import SwiftUI
import Charts

// MARK: - Correlation Insights Hub Card

public struct CorrelationInsightsCard: View {
    public let insights: [CorrelationInsight]

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LifecoreSectionHeader(
                title: "Аналіз взаємозв'язків (Тайм-лаги)",
                subtitle: "Кореляція харчування, відновлення та кардіо (День T → T+1, T+2)"
            )

            if insights.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.dots.scatter")
                        .font(.system(size: 28))
                        .foregroundColor(LifecoreTheme.electricTeal.opacity(0.6))
                    Text("Накопичення даних для статистичного аналізу...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(LifecoreTheme.textMuted)
                    Text("Потрібно мінімум 6 днів спільних вимірювань харчування та тренувань.")
                        .font(.system(size: 11))
                        .foregroundColor(LifecoreTheme.textSubtle)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 10) {
                    ForEach(insights) { insight in
                        insightRow(insight)
                    }
                }
            }
        }
        .lifecoreGlassCard()
    }

    private func insightRow(_ insight: CorrelationInsight) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: insight.category.iconName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(rColor(insight.pearsonR))

                Text(insight.titleUk)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                LifecoreGlowPill(
                    text: insight.lagLabelUk,
                    color: LifecoreTheme.electricTeal
                )

                LifecoreGlowPill(
                    text: String(format: "r = %+.2f", insight.pearsonR),
                    color: rColor(insight.pearsonR)
                )
            }

            Text(insight.effectDescriptionUk)
                .font(.system(size: 12))
                .foregroundColor(LifecoreTheme.textMuted)
                .lineLimit(3)

            HStack(alignment: .top, spacing: 4) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 10))
                    .foregroundColor(LifecoreTheme.amberWarning)
                    .padding(.top, 2)
                Text(insight.actionDirectiveUk)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(LifecoreTheme.textMuted)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LifecoreTheme.cardSurfaceSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(rColor(insight.pearsonR).opacity(0.25), lineWidth: 0.8)
        )
    }

    private func rColor(_ r: Double) -> Color {
        let absR = abs(r)
        if absR >= 0.50 { return LifecoreTheme.athleticEmerald }
        if absR >= 0.30 { return LifecoreTheme.electricTeal }
        return LifecoreTheme.amberWarning
    }
}

// MARK: - EWMA ACWR Workload Sweet-Spot Card

public struct ACWRWorkloadTrendCard: View {
    public let acwr: ACWREvaluation?

    public init(acwr: ACWREvaluation? = nil, evaluation: ACWREvaluation? = nil, dailyLoads: [(date: Date, trimp: Double)] = []) {
        self.acwr = evaluation ?? acwr
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Навантаження (Garmin EWMA ACWR)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("Гостре (7d, λ=0.25) vs Хронічне (28d, λ=0.069)")
                        .font(.system(size: 12))
                        .foregroundColor(LifecoreTheme.textMuted)
                }
                Spacer()
                if let ratio = acwr?.ratio, let zone = acwr?.zone {
                    LifecoreGlowPill(
                        text: String(format: "%.2f", ratio),
                        systemIcon: "flame.fill",
                        color: zoneColor(zone)
                    )
                }
            }

            if let item = acwr {
                // Zone Description Box
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.titleUk)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(zoneColor(item.zone))
                        Spacer()
                        Text("Sweet Spot: 0.80 – 1.30")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(LifecoreTheme.athleticEmerald)
                    }

                    Text(item.zone.descriptionUk)
                        .font(.system(size: 12))
                        .foregroundColor(LifecoreTheme.textMuted)

                    Text(item.recommendationUk)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(zoneColor(item.zone))
                        .padding(.top, 2)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(zoneColor(item.zone).opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(zoneColor(item.zone).opacity(0.35), lineWidth: 1.0)
                )

                // Loads Comparison Bar
                HStack(spacing: 12) {
                    loadStat(label: "Гостре навантаження (7d)", value: "\(item.acuteLoad)", unit: "TRIMP/день", color: LifecoreTheme.electricTeal)
                    Spacer()
                    loadStat(label: "Хронічна база (28d)", value: "\(item.chronicLoad)", unit: "TRIMP/день", color: LifecoreTheme.recoveryPurple)
                }
                .padding(.top, 4)
            } else {
                Text("Розрахунок тренувального імпульсу Banister TRIMP...")
                    .font(.system(size: 13))
                    .foregroundColor(LifecoreTheme.textMuted)
            }
        }
        .lifecoreGlassCard()
    }

    private func zoneColor(_ zone: ACWRZone) -> Color {
        switch zone {
        case .undertraining: return LifecoreTheme.electricTeal
        case .sweetSpot: return LifecoreTheme.athleticEmerald
        case .caution: return LifecoreTheme.amberWarning
        case .dangerSpike: return LifecoreTheme.coralDanger
        }
    }

    private func loadStat(label: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(LifecoreTheme.textSubtle)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(unit)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(color)
            }
        }
    }
}
