import SwiftUI

// MARK: - Lifecore Design System (Liquid Glass Dark 3.0)

public enum LifecoreTheme {
    // Deep OLED Background
    public static let backgroundDark = Color(red: 0.05, green: 0.06, blue: 0.08)
    public static let cardSurface = Color(red: 0.10, green: 0.12, blue: 0.16).opacity(0.75)
    public static let cardSurfaceSecondary = Color(red: 0.13, green: 0.15, blue: 0.20).opacity(0.60)

    // Specular Gradients
    public static let specularBorderGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.22),
            Color.white.opacity(0.06),
            Color.white.opacity(0.02)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Semantic Athletic Accents
    public static let electricTeal = Color(red: 0.18, green: 0.82, blue: 0.96)
    public static let athleticEmerald = Color(red: 0.16, green: 0.85, blue: 0.54)
    public static let amberWarning = Color(red: 1.0, green: 0.68, blue: 0.15)
    public static let coralDanger = Color(red: 1.0, green: 0.32, blue: 0.35)
    public static let recoveryPurple = Color(red: 0.68, green: 0.40, blue: 0.98)
    public static let textMuted = Color(white: 0.65)
    public static let textSubtle = Color(white: 0.45)

    // Liquid Glass v3.1 Theme Aliases
    public static let deepVoidBackground = backgroundDark
    public static let recoveryGreen = athleticEmerald
    public static let strainOrange = amberWarning
}

// MARK: - View Modifiers

public struct LifecoreGlassCardModifier: ViewModifier {
    public var cornerRadius: CGFloat = 18
    public var padding: CGFloat = 16
    public var borderColor: Color? = nil

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(LifecoreTheme.cardSurface)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        borderColor != nil ? AnyShapeStyle(borderColor!) : AnyShapeStyle(LifecoreTheme.specularBorderGradient),
                        lineWidth: 1.0
                    )
            )
            .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 5)
    }
}

public extension View {
    func lifecoreGlassCard(cornerRadius: CGFloat = 18, padding: CGFloat = 16, borderColor: Color? = nil) -> some View {
        modifier(LifecoreGlassCardModifier(cornerRadius: cornerRadius, padding: padding, borderColor: borderColor))
    }
}

// MARK: - Semantic Glow Pill

public struct LifecoreGlowPill: View {
    public let text: String
    public let systemIcon: String?
    public let color: Color

    public init(text: String, systemIcon: String? = nil, color: Color = LifecoreTheme.athleticEmerald) {
        self.text = text
        self.systemIcon = systemIcon
        self.color = color
    }

    public var body: some View {
        HStack(spacing: 4) {
            if let icon = systemIcon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
            }
            Text(text)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
        .overlay(
            Capsule()
                .stroke(color.opacity(0.35), lineWidth: 0.8)
        )
    }
}

// MARK: - Section Header

public struct LifecoreSectionHeader: View {
    public let title: String
    public let subtitle: String?
    public var trailingText: String? = nil
    public var onTrailingTap: (() -> Void)? = nil

    public init(title: String, subtitle: String? = nil, trailingText: String? = nil, onTrailingTap: (() -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.trailingText = trailingText
        self.onTrailingTap = onTrailingTap
    }

    public var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 12))
                        .foregroundColor(LifecoreTheme.textMuted)
                }
            }
            Spacer()
            if let trailing = trailingText {
                Button(action: { onTrailingTap?() }) {
                    Text(trailing)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(LifecoreTheme.electricTeal)
                }
            }
        }
    }
}

// MARK: - Vitals Corridor Pill Component

public struct VitalsCorridorPill: View {
    public let metric: VitalsPillarMetric

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(metric.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(LifecoreTheme.textMuted)
                    .lineLimit(1)
                Spacer()
                statusBadge
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formatValue(metric.currentValue))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(metric.unit)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(LifecoreTheme.textSubtle)
                Spacer()
                Text(formatDelta(metric.delta))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(statusColor)
            }

            // Corridor Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 4)

                    // Target corridor highlight in middle
                    Capsule()
                        .fill(LifecoreTheme.athleticEmerald.opacity(0.35))
                        .frame(width: geo.size.width * 0.5, height: 4)
                        .offset(x: geo.size.width * 0.25)

                    // Current point dot
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                        .offset(x: calculateDotOffset(width: geo.size.width))
                        .shadow(color: statusColor.opacity(0.6), radius: 3)
                }
            }
            .frame(height: 8)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LifecoreTheme.cardSurfaceSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(statusColor.opacity(metric.status == .inside ? 0.15 : 0.40), lineWidth: 1.0)
        )
    }

    private var statusColor: Color {
        switch metric.status {
        case .inside: return LifecoreTheme.athleticEmerald
        case .warning: return LifecoreTheme.amberWarning
        case .outlier: return LifecoreTheme.coralDanger
        }
    }

    private var statusBadge: some View {
        switch metric.status {
        case .inside:
            return LifecoreGlowPill(text: "Норма", color: LifecoreTheme.athleticEmerald)
        case .warning:
            return LifecoreGlowPill(text: "Увага", color: LifecoreTheme.amberWarning)
        case .outlier:
            return LifecoreGlowPill(text: "Відхилення", color: LifecoreTheme.coralDanger)
        }
    }

    private func formatValue(_ val: Double) -> String {
        if val >= 100 {
            return String(format: "%.0f", val)
        } else if val >= 10 {
            return String(format: "%.1f", val)
        } else {
            return String(format: "%.2f", val)
        }
    }

    private func formatDelta(_ d: Double) -> String {
        let sign = d >= 0 ? "+" : ""
        if abs(d) >= 10 {
            return "\(sign)\(String(format: "%.0f", d))"
        } else {
            return "\(sign)\(String(format: "%.1f", d))"
        }
    }

    private func calculateDotOffset(width: CGFloat) -> CGFloat {
        // Map baseline to center (0.5), delta to offset
        let ratio: CGFloat
        if metric.baselineValue > 0 {
            let rel = metric.delta / (metric.baselineValue * 0.15)
            ratio = 0.5 + CGFloat(rel * 0.25)
        } else {
            ratio = 0.5
        }
        let clamped = max(0.05, min(0.95, ratio))
        return clamped * (width - 8)
    }
}

// MARK: - Phase 3.1 Adaptive Engine UI Components

public struct AdaptiveEngineBadgeBar: View {
    public let snapshot: AdaptivePhysiologySnapshot

    public init(snapshot: AdaptivePhysiologySnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(LifecoreTheme.electricTeal)
            Text("Адаптивне ядро • \(snapshot.confidencePct)% точності")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            Text("BMR \(Int(snapshot.dynamicTDEE.learnedBmrKcal)) ккал (\(String(format: "%+.0f", snapshot.dynamicTDEE.metabolicAdaptationKcal)))")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(LifecoreTheme.textMuted)
            Text("•")
                .font(.system(size: 10))
                .foregroundColor(LifecoreTheme.textSubtle)
            Text("Na→H₂O +\(String(format: "%.2f", snapshot.sensitivities.sodiumWaterKgPerGram)) кг")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(LifecoreTheme.athleticEmerald)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(LifecoreTheme.cardSurfaceSecondary)
        )
        .overlay(
            Capsule()
                .stroke(LifecoreTheme.electricTeal.opacity(0.3), lineWidth: 0.8)
        )
    }
}

public struct RPEQuickCalibrationRow: View {
    public let isCalibratedToday: Bool
    public let onSelect: (Int) -> Void

    public init(isCalibratedToday: Bool, onSelect: @escaping (Int) -> Void) {
        self.isCalibratedToday = isCalibratedToday
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Як ти реально почуваєшся сьогодні?")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(LifecoreTheme.textMuted)
                Spacer()
                if isCalibratedToday {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                        Text("Враховано у вагах ядра ✓")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(LifecoreTheme.athleticEmerald)
                }
            }

            if !isCalibratedToday {
                HStack(spacing: 8) {
                    Button(action: { onSelect(-1) }) {
                        Text("Нижче прогнозу")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(LifecoreTheme.coralDanger)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(
                                Capsule()
                                    .fill(LifecoreTheme.coralDanger.opacity(0.12))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(LifecoreTheme.coralDanger.opacity(0.3), lineWidth: 0.8)
                            )
                    }

                    Button(action: { onSelect(0) }) {
                        Text("Точно")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(LifecoreTheme.athleticEmerald)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(
                                Capsule()
                                    .fill(LifecoreTheme.athleticEmerald.opacity(0.12))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(LifecoreTheme.athleticEmerald.opacity(0.3), lineWidth: 0.8)
                            )
                    }

                    Button(action: { onSelect(1) }) {
                        Text("Краще прогнозу")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(LifecoreTheme.electricTeal)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(
                                Capsule()
                                    .fill(LifecoreTheme.electricTeal.opacity(0.12))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(LifecoreTheme.electricTeal.opacity(0.3), lineWidth: 0.8)
                            )
                    }
                }
            }
        }
    }
}

public struct AdaptiveEngineStatusCard: View {
    public let snapshot: AdaptivePhysiologySnapshot

    public init(snapshot: AdaptivePhysiologySnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(LifecoreTheme.electricTeal)
                        Text("Адаптивне самонавчання ядра")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Text(snapshot.statusTitleUk)
                        .font(.system(size: 12))
                        .foregroundColor(LifecoreTheme.textMuted)
                }
                Spacer()
                LifecoreGlowPill(
                    text: "\(snapshot.confidencePct)% точності",
                    systemIcon: "sparkles",
                    color: snapshot.confidencePct >= 70 ? LifecoreTheme.athleticEmerald : LifecoreTheme.electricTeal
                )
            }

            // Loop 1: Confidence progress bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Калібрування профілю (N = \(snapshot.sampleDaysCount) днів)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(LifecoreTheme.textMuted)
                    Spacer()
                    Text("\(snapshot.confidencePct)%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 6)
                        Capsule()
                            .fill(LinearGradient(
                                colors: [LifecoreTheme.electricTeal, LifecoreTheme.athleticEmerald],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: max(8, geo.size.width * CGFloat(snapshot.confidencePct) / 100.0), height: 6)
                    }
                }
                .frame(height: 6)
            }

            Divider().background(Color.white.opacity(0.1))

            // Loop 2: MacroFactor Dynamic TDEE
            VStack(alignment: .leading, spacing: 4) {
                Text("Динамічний TDEE & BMR (MacroFactor Loop)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(LifecoreTheme.amberWarning)
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Реальний TDEE")
                            .font(.system(size: 10))
                            .foregroundColor(LifecoreTheme.textSubtle)
                        Text("\(Int(snapshot.dynamicTDEE.learnedDailyTdeeKcal)) ккал")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Адаптивний BMR")
                            .font(.system(size: 10))
                            .foregroundColor(LifecoreTheme.textSubtle)
                        Text("\(Int(snapshot.dynamicTDEE.learnedBmrKcal)) ккал")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Метаболічна дельта")
                            .font(.system(size: 10))
                            .foregroundColor(LifecoreTheme.textSubtle)
                        Text(String(format: "%+.0f ккал", snapshot.dynamicTDEE.metabolicAdaptationKcal))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(snapshot.dynamicTDEE.metabolicAdaptationKcal >= 0 ? LifecoreTheme.athleticEmerald : LifecoreTheme.coralDanger)
                    }
                }
            }

            Divider().background(Color.white.opacity(0.1))

            // Loop 3: Sensitivities Grid
            VStack(alignment: .leading, spacing: 6) {
                Text("Індивідуальні β-чутливості (Ridge OLS)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(LifecoreTheme.electricTeal)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    sensitivityCell(
                        title: "Na→H₂O затримка",
                        value: String(format: "+%.2f кг/1г", snapshot.sensitivities.sodiumWaterKgPerGram),
                        desc: "натрієвий водяний пік"
                    )
                    sensitivityCell(
                        title: "TRIMP розрядка",
                        value: String(format: "%.2f%%/1 TRIMP", snapshot.sensitivities.trimpBatteryDrainFactor),
                        desc: "витрата батареї тіла"
                    )
                    sensitivityCell(
                        title: "Пізня вечеря RHR",
                        value: String(format: "+%.1f уд/хв", snapshot.sensitivities.lateMealRhrPenaltyBpm),
                        desc: "штраф пульсу сну"
                    )
                    sensitivityCell(
                        title: "Вуглеводи → Дрифт",
                        value: String(format: "%.1f%%/100г", snapshot.sensitivities.carbCardiacDriftSlopePctPer100g),
                        desc: "стабільність темпу"
                    )
                }
            }

            Divider().background(Color.white.opacity(0.1))

            // Loop 4: Readiness Weight Allocation
            VStack(alignment: .leading, spacing: 4) {
                let w = snapshot.readinessWeights
                Text("Персональні ваги готовності (1-Tap RPE Feedback)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                Text("HRV \(Int(w.hrvWeight * 100))% • RHR \(Int(w.rhrWeight * 100))% • Сон \(Int((w.sleepDurationWeight + w.sleepArchitectureWeight) * 100))%")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(LifecoreTheme.athleticEmerald)
            }
        }
        .lifecoreGlassCard(cornerRadius: 20)
    }

    private func sensitivityCell(title: String, value: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(LifecoreTheme.textSubtle)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(desc)
                .font(.system(size: 9))
                .foregroundColor(LifecoreTheme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LifecoreTheme.cardSurfaceSecondary)
        )
    }
}
