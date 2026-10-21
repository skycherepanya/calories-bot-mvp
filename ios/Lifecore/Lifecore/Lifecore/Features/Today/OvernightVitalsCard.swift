import SwiftUI
import Charts

// MARK: - Illness Prodrome Radar Banner

public struct IllnessRadarBanner: View {
    public let evaluation: OvernightVitalsEvaluation

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: evaluation.state.systemIcon)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(bannerColor)
                .padding(8)
                .background(
                    Circle()
                        .fill(bannerColor.opacity(0.18))
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(evaluation.headline)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    LifecoreGlowPill(
                        text: "\(evaluation.outliersCount) відхилень",
                        color: bannerColor
                    )
                }

                Text(evaluation.state.subtitleUk)
                    .font(.system(size: 12))
                    .foregroundColor(LifecoreTheme.textMuted)
                    .lineLimit(3)

                Text(evaluation.actionDirective)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(bannerColor)
                    .padding(.top, 2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(bannerColor.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(bannerColor.opacity(0.40), lineWidth: 1.0)
        )
    }

    private var bannerColor: Color {
        switch evaluation.state {
        case .optimal: return LifecoreTheme.athleticEmerald
        case .trainingFatigue: return LifecoreTheme.electricTeal
        case .immuneWatch: return LifecoreTheme.amberWarning
        case .illnessProdrome: return LifecoreTheme.coralDanger
        }
    }
}

// MARK: - Overnight Vitals Corridor Card

public struct OvernightVitalsCard: View {
    public let evaluation: OvernightVitalsEvaluation?

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LifecoreSectionHeader(
                title: "Нічні вітальні показники",
                subtitle: "Коридор норми Apple Vitals (5 біомаркерів)"
            )

            if let eval = evaluation {
                // Pre-symptomatic Illness Prodrome Radar
                IllnessRadarBanner(evaluation: eval)

                // 5-Metric Pillars Grid
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
                Text("Очікування нічних вимірювань Apple Watch...")
                    .font(.system(size: 13))
                    .foregroundColor(LifecoreTheme.textMuted)
            }
        }
        .lifecoreGlassCard()
    }
}

// MARK: - 24h Energy Bank / Body Battery Card

public struct EnergyBankCard: View {
    public let energyBank: EnergyBankEvaluation?

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Банк Енергії (Body Battery)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("Динаміка заряду та розряду протягом 24 годин")
                        .font(.system(size: 12))
                        .foregroundColor(LifecoreTheme.textMuted)
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
                // Swift Charts Timeline
                Chart(eb.timeline, id: \.hour) { point in
                    LineMark(
                        x: .value("Година", point.hour),
                        y: .value("Рівень", point.batteryLevel)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [LifecoreTheme.electricTeal, LifecoreTheme.recoveryPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    AreaMark(
                        x: .value("Година", point.hour),
                        y: .value("Рівень", point.batteryLevel)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [LifecoreTheme.electricTeal.opacity(0.35), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .chartXScale(domain: 0...23)
                .chartYScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks(values: [0, 6, 12, 18, 23]) { val in
                        AxisValueLabel {
                            if let h = val.as(Int.self) {
                                Text("\(h):00")
                                    .font(.system(size: 9))
                                    .foregroundColor(LifecoreTheme.textSubtle)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [20, 50, 80, 100]) { val in
                        AxisValueLabel {
                            if let v = val.as(Int.self) {
                                Text("\(v)%")
                                    .font(.system(size: 9))
                                    .foregroundColor(LifecoreTheme.textSubtle)
                            }
                        }
                    }
                }
                .frame(height: 120)

                // Stats Footer
                HStack {
                    metricBadge(label: "Пробудження", value: "\(eb.wakeBattery)%", icon: "sunrise.fill", color: LifecoreTheme.athleticEmerald)
                    Spacer()
                    metricBadge(label: "Мінімум", value: "\(eb.minBattery)%", icon: "arrow.down.to.line", color: LifecoreTheme.amberWarning)
                    Spacer()
                    metricBadge(label: "Борг сну", value: "\(String(format: "%.1f", eb.sleepDebtHours)) год", icon: "bed.double.fill", color: LifecoreTheme.electricTeal)
                }
                .padding(.top, 4)
            } else {
                Text("Розрахунок енергетичного балансу...")
                    .font(.system(size: 13))
                    .foregroundColor(LifecoreTheme.textMuted)
            }
        }
        .lifecoreGlassCard()
    }

    private func batteryColor(_ level: Int) -> Color {
        if level >= 70 { return LifecoreTheme.athleticEmerald }
        if level >= 40 { return LifecoreTheme.electricTeal }
        if level >= 20 { return LifecoreTheme.amberWarning }
        return LifecoreTheme.coralDanger
    }

    private func metricBadge(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(LifecoreTheme.textSubtle)
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
    }
}
