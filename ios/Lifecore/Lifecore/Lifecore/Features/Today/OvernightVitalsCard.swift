import SwiftUI
import Charts

// MARK: - Illness Prodrome Radar Banner (Tinted Well, No Nested Card Border)

public struct IllnessRadarBanner: View {
    public let evaluation: OvernightVitalsEvaluation

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: evaluation.state.systemIcon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(bannerColor)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(bannerColor.opacity(0.14))
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(evaluation.headline)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(LifecoreTheme.inkPrimary)
                    Spacer()
                    LifecoreGlowPill(
                        text: "\(evaluation.outliersCount) відхилень",
                        color: bannerColor
                    )
                }

                Text(evaluation.state.subtitleUk)
                    .font(.system(size: 12))
                    .foregroundStyle(LifecoreTheme.inkSecondary)
                    .lineLimit(3)

                Text(evaluation.actionDirective)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(bannerColor)
                    .padding(.top, 2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(bannerColor.opacity(0.08))
        )
    }

    private var bannerColor: Color {
        switch evaluation.state {
        case .optimal: return LifecoreTheme.statusOptimal
        case .trainingFatigue: return LifecoreTheme.accentTeal
        case .immuneWatch: return LifecoreTheme.statusWarning
        case .illnessProdrome: return LifecoreTheme.statusDanger
        }
    }
}

// MARK: - Overnight Vitals Corridor Card

public struct OvernightVitalsCard: View {
    public let evaluation: OvernightVitalsEvaluation?

    public init(evaluation: OvernightVitalsEvaluation?) {
        self.evaluation = evaluation
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LifecoreSectionHeader(
                title: "Нічні вітальні показники",
                subtitle: "Коридор норми Apple Vitals (5 біомаркерів)"
            )

            if let eval = evaluation {
                IllnessRadarBanner(evaluation: eval)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    VitalsCorridorPill(metric: eval.hrvPillar)
                    VitalsCorridorPill(metric: eval.rhrPillar)
                    if let temp = eval.tempPillar {
                        VitalsCorridorPill(metric: temp)
                    }
                    if let resp = eval.respPillar {
                        VitalsCorridorPill(metric: resp)
                    }
                    if let spo2 = eval.spo2Pillar {
                        VitalsCorridorPill(metric: spo2)
                    }
                }
            } else {
                Text("Очікування нічних вимірювань Apple Watch…")
                    .font(.system(size: 13))
                    .foregroundStyle(LifecoreTheme.inkSecondary)
            }
        }
        .lifecoreGlassCard()
        .accessibilityIdentifier("card_overnight_vitals")
    }
}

// MARK: - 24h Energy Bank / Body Battery Card

public struct EnergyBankCard: View {
    public let energyBank: EnergyBankEvaluation?

    public init(energyBank: EnergyBankEvaluation?) {
        self.energyBank = energyBank
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Банк енергії (Body Battery)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(LifecoreTheme.inkPrimary)
                    Text("Динаміка заряду та розряду протягом 24 годин")
                        .font(.system(size: 12))
                        .foregroundStyle(LifecoreTheme.inkSecondary)
                }
                Spacer()
                if let current = energyBank?.currentBattery {
                    LifecoreGlowPill(
                        text: "\(current)%",
                        systemIcon: "bolt.fill",
                        color: batteryColor(current)
                    )
                }
            }

            if let eb = energyBank {
                Chart(eb.timeline, id: \.hour) { point in
                    LineMark(
                        x: .value("Година", point.hour),
                        y: .value("Рівень", point.batteryLevel)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LifecoreTheme.accentTeal)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    AreaMark(
                        x: .value("Година", point.hour),
                        y: .value("Рівень", point.batteryLevel)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [LifecoreTheme.accentTeal.opacity(0.22), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .chartXScale(domain: 0...23)
                .chartYScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks(values: [0, 6, 12, 18, 23]) { val in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(LifecoreTheme.ruleHairline)
                        AxisValueLabel {
                            if let h = val.as(Int.self) {
                                Text("\(h):00")
                                    .font(.system(size: 10))
                                    .monospacedDigit()
                                    .foregroundStyle(LifecoreTheme.inkTertiary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [20, 50, 80, 100]) { val in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(LifecoreTheme.ruleHairline)
                        AxisValueLabel {
                            if let v = val.as(Int.self) {
                                Text("\(v)%")
                                    .font(.system(size: 10))
                                    .monospacedDigit()
                                    .foregroundStyle(LifecoreTheme.inkTertiary)
                            }
                        }
                    }
                }
                .frame(height: 120)

                LifecoreHairlineDivider()

                HStack {
                    metricBadge(label: "Пробудження", value: "\(eb.wakeBattery)%", icon: "sunrise.fill", color: LifecoreTheme.statusOptimal)
                    Spacer()
                    metricBadge(label: "Мінімум", value: "\(eb.minBattery)%", icon: "arrow.down.to.line", color: LifecoreTheme.statusWarning)
                    Spacer()
                    metricBadge(label: "Борг сну", value: "\(String(format: "%.1f", eb.sleepDebtHours)) год", icon: "bed.double.fill", color: LifecoreTheme.accentIndigo)
                }
            } else {
                Text("Розрахунок енергетичного балансу…")
                    .font(.system(size: 13))
                    .foregroundStyle(LifecoreTheme.inkSecondary)
            }
        }
        .lifecoreGlassCard()
        .accessibilityIdentifier("card_body_battery")
    }

    private func batteryColor(_ level: Int) -> Color {
        if level >= 70 { return LifecoreTheme.statusOptimal }
        if level >= 40 { return LifecoreTheme.accentTeal }
        if level >= 20 { return LifecoreTheme.statusWarning }
        return LifecoreTheme.statusDanger
    }

    private func metricBadge(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(LifecoreTheme.inkTertiary)
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(LifecoreTheme.inkPrimary)
            }
        }
    }
}
