import SwiftUI

/* Hallmark · scope: app · genre: modern-minimal · theme: Bevel Daylight · redesign: full · v2.0.0 */

// MARK: - Lifecore Design System (Bevel & Apple Health Daylight 3.3)

public enum LifecoreTheme {
    // 4-Rung Surface Ladder (Warm Alabaster Paper -> Pure White Card -> Warm Stone Well -> Hairline Rule)
    public static let paperCanvas = Color(red: 0.965, green: 0.961, blue: 0.945)   // #F6F5F1
    public static let paperCard = Color(red: 1.000, green: 1.000, blue: 1.000)     // #FFFFFF
    public static let paperWell = Color(red: 0.937, green: 0.929, blue: 0.902)     // #EFECE6
    public static let ruleHairline = Color(red: 0.894, green: 0.882, blue: 0.855)  // #E4E1DA

    // Typography Ink Hierarchy (Obsidian Ink)
    public static let inkPrimary = Color(red: 0.078, green: 0.082, blue: 0.094)    // #141518
    public static let inkSecondary = Color(red: 0.345, green: 0.357, blue: 0.388)  // #585B63
    public static let inkTertiary = Color(red: 0.545, green: 0.557, blue: 0.588)   // #8B8E96

    // Semantic Athletic & Biometric Signals
    public static let accentPrimary = Color(red: 0.067, green: 0.600, blue: 0.365) // #11995D Bevel Emerald
    public static let accentTeal = Color(red: 0.055, green: 0.545, blue: 0.659)    // #0E8BA8 Precision Teal
    public static let accentIndigo = Color(red: 0.310, green: 0.275, blue: 0.898)  // #4F46E5 Sleep/VNS Indigo
    public static let statusOptimal = accentPrimary
    public static let statusWarning = Color(red: 0.851, green: 0.467, blue: 0.024) // #D97706 Strain/Watch Amber
    public static let statusDanger = Color(red: 0.863, green: 0.149, blue: 0.149)  // #DC2626 Alert Coral

    // Backward-Compatible Semantic Aliases
    public static let backgroundDark = paperCanvas
    public static let deepVoidBackground = paperCanvas
    public static let cardSurface = paperCard
    public static let cardSurfaceSecondary = paperWell
    public static let electricTeal = accentTeal
    public static let athleticEmerald = statusOptimal
    public static let recoveryGreen = statusOptimal
    public static let amberWarning = statusWarning
    public static let strainOrange = statusWarning
    public static let coralDanger = statusDanger
    public static let recoveryPurple = accentIndigo
    public static let textMuted = inkSecondary
    public static let textSubtle = inkTertiary

    public static let specularBorderGradient = LinearGradient(
        colors: [ruleHairline, ruleHairline],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Surface Ladder View Modifiers (Hallmark §3)

public struct LifecoreGlassCardModifier: ViewModifier {
    public var cornerRadius: CGFloat = 20
    public var padding: CGFloat = 16
    public var borderColor: Color? = nil

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(LifecoreTheme.paperCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor ?? LifecoreTheme.ruleHairline, lineWidth: 1.0)
            )
    }
}

public struct LifecoreWellModifier: ViewModifier {
    public var cornerRadius: CGFloat = 12
    public var padding: CGFloat = 12

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(LifecoreTheme.paperWell)
            )
    }
}

public extension View {
    func lifecoreGlassCard(cornerRadius: CGFloat = 20, padding: CGFloat = 16, borderColor: Color? = nil) -> some View {
        modifier(LifecoreGlassCardModifier(cornerRadius: cornerRadius, padding: padding, borderColor: borderColor))
    }

    func lifecoreWell(cornerRadius: CGFloat = 12, padding: CGFloat = 12) -> some View {
        modifier(LifecoreWellModifier(cornerRadius: cornerRadius, padding: padding))
    }
}

public struct LifecoreHairlineDivider: View {
    public init() {}
    public var body: some View {
        Rectangle()
            .fill(LifecoreTheme.ruleHairline)
            .frame(height: 1)
    }
}

// MARK: - Semantic Status Pill (Sentence case, no glow halo)

public struct LifecoreGlowPill: View {
    public let text: String
    public let systemIcon: String?
    public let color: Color

    public init(text: String, systemIcon: String? = nil, color: Color = LifecoreTheme.statusOptimal) {
        self.text = text
        self.systemIcon = systemIcon
        self.color = color
    }

    public var body: some View {
        HStack(spacing: 4) {
            if let icon = systemIcon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
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
                    .foregroundStyle(LifecoreTheme.inkPrimary)
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 12))
                        .foregroundStyle(LifecoreTheme.inkSecondary)
                }
            }
            Spacer()
            if let trailing = trailingText {
                Button(action: { onTrailingTap?() }) {
                    Text(trailing)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LifecoreTheme.accentPrimary)
                }
            }
        }
    }
}

// MARK: - Vitals Corridor Row / Well Component (No Card-in-Card Border)

public struct VitalsCorridorPill: View {
    public let metric: VitalsPillarMetric

    public init(metric: VitalsPillarMetric) {
        self.metric = metric
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(metric.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(LifecoreTheme.inkSecondary)
                    .lineLimit(1)
                Spacer()
                statusBadge
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formatValue(metric.currentValue))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(LifecoreTheme.inkPrimary)
                Text(metric.unit)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(LifecoreTheme.inkTertiary)
                Spacer()
                Text(formatDelta(metric.delta))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(statusColor)
            }

            // Corridor Track
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LifecoreTheme.ruleHairline)
                        .frame(height: 4)

                    Capsule()
                        .fill(LifecoreTheme.statusOptimal.opacity(0.35))
                        .frame(width: geo.size.width * 0.5, height: 4)
                        .offset(x: geo.size.width * 0.25)

                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                        .offset(x: calculateDotOffset(width: geo.size.width))
                }
            }
            .frame(height: 8)
        }
        .lifecoreWell(cornerRadius: 12, padding: 10)
    }

    private var statusColor: Color {
        switch metric.status {
        case .inside: return LifecoreTheme.statusOptimal
        case .warning: return LifecoreTheme.statusWarning
        case .outlier: return LifecoreTheme.statusDanger
        }
    }

    private var statusBadge: some View {
        switch metric.status {
        case .inside:
            return LifecoreGlowPill(text: "Норма", color: LifecoreTheme.statusOptimal)
        case .warning:
            return LifecoreGlowPill(text: "Увага", color: LifecoreTheme.statusWarning)
        case .outlier:
            return LifecoreGlowPill(text: "Відхилення", color: LifecoreTheme.statusDanger)
        }
    }

    private func formatValue(_ val: Double) -> String {
        if val >= 100 { return String(format: "%.0f", val) }
        else if val >= 10 { return String(format: "%.1f", val) }
        else { return String(format: "%.2f", val) }
    }

    private func formatDelta(_ d: Double) -> String {
        let sign = d >= 0 ? "+" : ""
        if abs(d) >= 10 { return "\(sign)\(String(format: "%.0f", d))" }
        else { return "\(sign)\(String(format: "%.1f", d))" }
    }

    private func calculateDotOffset(width: CGFloat) -> CGFloat {
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

// MARK: - Phase 3.1 Adaptive Engine UI Components (Daylight Clean)

public struct AdaptiveEngineBadgeBar: View {
    public let snapshot: AdaptivePhysiologySnapshot

    public init(snapshot: AdaptivePhysiologySnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(LifecoreTheme.accentTeal)
            Text("Адаптивне ядро \(snapshot.confidencePct)%")
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(LifecoreTheme.inkPrimary)
            Spacer()
            Text("BMR \(Int(snapshot.dynamicTDEE.learnedBmrKcal)) ккал (\(String(format: "%+.0f", snapshot.dynamicTDEE.metabolicAdaptationKcal)))")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(LifecoreTheme.inkSecondary)
            Text("Na→H₂O +\(String(format: "%.2f", snapshot.sensitivities.sodiumWaterKgPerGram)) кг")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(LifecoreTheme.statusOptimal)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LifecoreTheme.paperWell)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Як ти реально почуваєшся сьогодні?")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(LifecoreTheme.inkSecondary)
                Spacer()
                if isCalibratedToday {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                        Text("Враховано у вагах ядра")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(LifecoreTheme.statusOptimal)
                }
            }

            if !isCalibratedToday {
                HStack(spacing: 8) {
                    rpeButton(title: "Нижче прогнозу", delta: -1, color: LifecoreTheme.statusDanger)
                    rpeButton(title: "Точно", delta: 0, color: LifecoreTheme.statusOptimal)
                    rpeButton(title: "Краще прогнозу", delta: 1, color: LifecoreTheme.accentTeal)
                }
            }
        }
    }

    private func rpeButton(title: String, delta: Int, color: Color) -> some View {
        Button(action: { onSelect(delta) }) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.opacity(0.10))
                )
        }
        .buttonStyle(.plain)
    }
}

public struct AdaptiveEngineStatusCard: View {
    public let snapshot: AdaptivePhysiologySnapshot

    public init(snapshot: AdaptivePhysiologySnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(LifecoreTheme.accentTeal)
                        Text("Адаптивне самонавчання ядра")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(LifecoreTheme.inkPrimary)
                    }
                    Text(snapshot.statusTitleUk)
                        .font(.system(size: 12))
                        .foregroundStyle(LifecoreTheme.inkSecondary)
                }
                Spacer()
                LifecoreGlowPill(
                    text: "\(snapshot.confidencePct)% точності",
                    systemIcon: "checkmark.seal.fill",
                    color: snapshot.confidencePct >= 70 ? LifecoreTheme.statusOptimal : LifecoreTheme.accentTeal
                )
            }

            // Confidence progress bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Калібрування профілю (N = \(snapshot.sampleDaysCount) днів)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(LifecoreTheme.inkSecondary)
                    Spacer()
                    Text("\(snapshot.confidencePct)%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(LifecoreTheme.inkPrimary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(LifecoreTheme.paperWell)
                            .frame(height: 6)
                        Capsule()
                            .fill(LifecoreTheme.accentPrimary)
                            .frame(width: max(8, geo.size.width * CGFloat(snapshot.confidencePct) / 100.0), height: 6)
                    }
                }
                .frame(height: 6)
            }

            LifecoreHairlineDivider()

            // Dynamic TDEE & BMR
            VStack(alignment: .leading, spacing: 6) {
                Text("Динамічний TDEE та BMR")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LifecoreTheme.inkSecondary)
                HStack(spacing: 16) {
                    tdeeStat(title: "Реальний TDEE", value: "\(Int(snapshot.dynamicTDEE.learnedDailyTdeeKcal)) ккал", color: LifecoreTheme.inkPrimary)
                    tdeeStat(title: "Адаптивний BMR", value: "\(Int(snapshot.dynamicTDEE.learnedBmrKcal)) ккал", color: LifecoreTheme.inkPrimary)
                    tdeeStat(
                        title: "Метаболічна дельта",
                        value: String(format: "%+.0f ккал", snapshot.dynamicTDEE.metabolicAdaptationKcal),
                        color: snapshot.dynamicTDEE.metabolicAdaptationKcal >= 0 ? LifecoreTheme.statusOptimal : LifecoreTheme.statusDanger
                    )
                }
            }

            LifecoreHairlineDivider()

            // Sensitivities Grid (Tinted wells, no card-in-card borders)
            VStack(alignment: .leading, spacing: 8) {
                Text("Індивідуальні β-чутливості (Ridge OLS)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LifecoreTheme.inkSecondary)
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

            LifecoreHairlineDivider()

            // Readiness Weight Allocation
            VStack(alignment: .leading, spacing: 4) {
                let w = snapshot.readinessWeights
                Text("Персональні ваги готовності")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LifecoreTheme.inkSecondary)
                HStack(spacing: 12) {
                    Text("HRV \(Int(w.hrvWeight * 100))%")
                    Text("RHR \(Int(w.rhrWeight * 100))%")
                    Text("Сон \(Int((w.sleepDurationWeight + w.sleepArchitectureWeight) * 100))%")
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(LifecoreTheme.statusOptimal)
            }
        }
        .lifecoreGlassCard(cornerRadius: 20)
    }

    private func tdeeStat(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(LifecoreTheme.inkTertiary)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sensitivityCell(title: String, value: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(LifecoreTheme.inkTertiary)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(LifecoreTheme.inkPrimary)
            Text(desc)
                .font(.system(size: 10))
                .foregroundStyle(LifecoreTheme.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifecoreWell(cornerRadius: 10, padding: 10)
    }
}

// MARK: - Universal Keyboard Management (Lifecore Daylight)

public extension View {
    /// Programmatically resigns the first responder to dismiss the software keyboard.
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// Standard Lifecore keyboard dismissal toolbar accessory.
    /// Attaches an accessible "Сховати клавіатуру" button directly to the keyboard accessory bar.
    func lifecoreKeyboardDismissToolbar() -> some View {
        self.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    hideKeyboard()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Сховати клавіатуру")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(LifecoreTheme.paperWell)
                    .foregroundStyle(LifecoreTheme.inkPrimary)
                    .clipShape(Capsule())
                }
                .accessibilityIdentifier("btn_hide_keyboard_toolbar")
            }
        }
    }
}

