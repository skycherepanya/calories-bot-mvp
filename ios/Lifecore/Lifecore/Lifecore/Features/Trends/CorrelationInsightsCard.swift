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
                        .foregroundStyle(LifecoreTheme.accentTeal.opacity(0.6))
                    Text("Накопичення даних для статистичного аналізу...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(LifecoreTheme.inkSecondary)
                    Text("Потрібно мінімум 6 днів спільних вимірювань харчування та тренувань.")
                        .font(.system(size: 11))
                        .foregroundStyle(LifecoreTheme.inkTertiary)
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
                    .foregroundStyle(rColor(insight.pearsonR))

                Text(insight.titleUk)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LifecoreTheme.inkPrimary)

                Spacer()

                LifecoreGlowPill(
                    text: insight.lagLabelUk,
                    color: LifecoreTheme.accentTeal
                )

                LifecoreGlowPill(
                    text: String(format: "r = %+.2f", insight.pearsonR),
                    color: rColor(insight.pearsonR)
                )
            }

            Text(insight.effectDescriptionUk)
                .font(.system(size: 12))
                .foregroundStyle(LifecoreTheme.inkSecondary)
                .lineLimit(3)

            HStack(alignment: .top, spacing: 4) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(LifecoreTheme.statusWarning)
                    .padding(.top, 2)
                Text(insight.actionDirectiveUk)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(LifecoreTheme.inkSecondary)
            }
        }
        .lifecoreWell(cornerRadius: 12, padding: 12)
    }

    private func rColor(_ r: Double) -> Color {
        let absR = abs(r)
        if absR >= 0.50 { return LifecoreTheme.statusOptimal }
        if absR >= 0.30 { return LifecoreTheme.accentTeal }
        return LifecoreTheme.statusWarning
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
                        .foregroundStyle(LifecoreTheme.inkPrimary)
                    Text("Гостре (7d, λ=0.25) vs Хронічне (28d, λ=0.069)")
                        .font(.system(size: 12))
                        .foregroundStyle(LifecoreTheme.inkSecondary)
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
                            .foregroundStyle(zoneColor(item.zone))
                        Spacer()
                        Text("Sweet Spot: 0.80 – 1.30")
                            .font(.system(size: 11, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(LifecoreTheme.statusOptimal)
                    }

                    Text(item.zone.descriptionUk)
                        .font(.system(size: 12))
                        .foregroundStyle(LifecoreTheme.inkSecondary)

                    Text(item.recommendationUk)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(zoneColor(item.zone))
                        .padding(.top, 2)
                }
                .lifecoreWell(cornerRadius: 12, padding: 12)

                // Loads Comparison Bar
                HStack(spacing: 12) {
                    loadStat(label: "Гостре навантаження (7d)", value: "\(item.acuteLoad)", unit: "TRIMP/день", color: LifecoreTheme.accentTeal)
                    Spacer()
                    loadStat(label: "Хронічна база (28d)", value: "\(item.chronicLoad)", unit: "TRIMP/день", color: LifecoreTheme.accentIndigo)
                }
                .padding(.top, 4)
            } else {
                Text("Розрахунок тренувального імпульсу Banister TRIMP...")
                    .font(.system(size: 13))
                    .foregroundStyle(LifecoreTheme.inkSecondary)
            }
        }
        .lifecoreGlassCard()
    }

    private func zoneColor(_ zone: ACWRZone) -> Color {
        switch zone {
        case .undertraining: return LifecoreTheme.accentTeal
        case .sweetSpot: return LifecoreTheme.statusOptimal
        case .caution: return LifecoreTheme.statusWarning
        case .dangerSpike: return LifecoreTheme.statusDanger
        }
    }

    private func loadStat(label: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(LifecoreTheme.inkTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(LifecoreTheme.inkPrimary)
                Text(unit)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(color)
            }
        }
    }
}
