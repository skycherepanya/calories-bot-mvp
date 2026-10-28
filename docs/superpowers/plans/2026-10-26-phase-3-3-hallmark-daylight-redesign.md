# Lifecore v3.3 Hallmark Daylight Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the entire Lifecore iOS application from the dark neon void theme into a warm, daylight-first Bevel & Apple Health aesthetic (`Bevel Daylight 3.3`) governed by Hallmark v2.0.0 (`scope: app`, `redesign: full`), while upgrading the 7-day workout calendar strip into an interactive day inspector and preserving 100% of deterministic Swift 6 math and Maestro E2E hooks.

**Architecture:** We replace the dark glassmorphism token system in `LifecoreDesignSystem.swift` with a 4-rung Hallmark Surface Ladder (`paperCanvas` `#F6F5F1`, `paperCard` `#FFFFFF`, `paperWell` `#EFECE6`, `ruleHairline` `#E4E1DA`) and high-contrast obsidian ink typography (`inkPrimary` `#141518`) with tabular numerals (`.monospacedDigit()`). Each of the 4 feature modules (`Today`, `Workouts`, `Nutrition`, `Trends`) is refactored independently to eliminate card-in-card nesting, tracked ALL-CAPS eyebrows, emoji status strings, and un-tokened color literals.

**Tech Stack:** Swift 6, SwiftUI, Swift Charts, HealthKit, SwiftData, Xcode (`xcodebuild`), Maestro E2E.

**Spec:** [`docs/superpowers/specs/2026-10-26-lifecore-v3-3-hallmark-daylight-redesign-design.md`](file:///Users/skycherepanya/Developer/GitHub/calories-bot-mvp/docs/superpowers/specs/2026-10-26-lifecore-v3-3-hallmark-daylight-redesign-design.md)

## Global Constraints

- **Hallmark Floor 1 (Token Discipline):** Every color across `ios/Lifecore/` MUST come from `LifecoreTheme`. Zero literal `Color(red: 0.05...)`, `Color(red: 0.1...)`, or `.preferredColorScheme(.dark)`.
- **Hallmark Floor 9 & 11 (Copy & Surface Discipline):** Zero ALL-CAPS eyebrows (use sentence case), zero emojis in UI status labels (use SF Symbols), and zero card-in-card nesting (use `LifecoreHairlineDivider` or `.lifecoreWell()` inside `.lifecoreGlassCard()`).
- **Hallmark Gate F6 (Tabular Numerals):** All metrics, paces, heart rates, weights, and deltas MUST apply `.monospacedDigit()`.
- **E2E Hook Preservation:** All 17 `.accessibilityIdentifier(...)` strings required by `.maestro/01..05` MUST remain intact.
- **Verification Command:** Every task verifies compilation via:
  `xcodebuild -project ios/Lifecore/Lifecore/Lifecore.xcodeproj -scheme Lifecore -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`

---

### Task 1: Core Design System (`LifecoreDesignSystem.swift`) & App Shell (`LifecoreApp.swift`, `MainTabView.swift`)

**Files:**
- Modify: `ios/Lifecore/Lifecore/Lifecore/Core/UI/LifecoreDesignSystem.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/App/LifecoreApp.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/App/MainTabView.swift`

**Interfaces:**
- Consumes: `AdaptivePhysiologySnapshot`, `VitalsPillarMetric`
- Produces:
  - `LifecoreTheme` tokens: `paperCanvas`, `paperCard`, `paperWell`, `ruleHairline`, `inkPrimary`, `inkSecondary`, `inkTertiary`, `accentPrimary`, `accentTeal`, `accentIndigo`, `statusOptimal`, `statusWarning`, `statusDanger` (plus backward-compatible aliases `backgroundDark`, `deepVoidBackground`, `cardSurface`, `cardSurfaceSecondary`, `electricTeal`, `athleticEmerald`, `recoveryGreen`, `amberWarning`, `strainOrange`, `coralDanger`, `recoveryPurple`, `textMuted`, `textSubtle`).
  - View modifiers & components: `.lifecoreGlassCard(cornerRadius:padding:borderColor:)`, `.lifecoreWell(cornerRadius:padding:)`, `LifecoreHairlineDivider`, `LifecoreGlowPill`, `LifecoreSectionHeader`, `VitalsCorridorPill`, `AdaptiveEngineBadgeBar`, `RPEQuickCalibrationRow`, `AdaptiveEngineStatusCard`.

- [ ] **Step 1: Replace `LifecoreDesignSystem.swift` with Hallmark Bevel Daylight 3.3 tokens and Surface Ladder components**

Update `ios/Lifecore/Lifecore/Lifecore/Core/UI/LifecoreDesignSystem.swift` with the complete daylight token system, removing card-in-card borders inside `VitalsCorridorPill` and `AdaptiveEngineStatusCard`:

```swift
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
```

- [ ] **Step 2: Update `LifecoreApp.swift` and `MainTabView.swift` to Daylight color scheme & Emerald accent**

Modify `ios/Lifecore/Lifecore/Lifecore/App/LifecoreApp.swift`:
```swift
import SwiftUI
import SwiftData

@main
struct LifecoreApp: App {
    init() {
        #if DEBUG
        let results = MathEngineVerification.runAllVerifications()
        for r in results {
            print("[VERIFICATION] \(r.testName): \(r.passed ? "PASS" : "FAIL") - \(r.details)")
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.light)
        }
        .modelContainer(LifecoreDataStore.shared.container)
    }
}
```

Modify `ios/Lifecore/Lifecore/Lifecore/App/MainTabView.swift` lines 50-58:
```swift
        }
        .tint(LifecoreTheme.accentPrimary)
    }
}

#Preview {
    MainTabView()
        .preferredColorScheme(.light)
}
```

- [ ] **Step 3: Verify Task 1 compilation**

Run:
`xcodebuild -project ios/Lifecore/Lifecore/Lifecore.xcodeproj -scheme Lifecore -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
Expected: `BUILD SUCCEEDED`

---

### Task 2: Today Cockpit Redesign (`TodayView.swift`, `TacticalPrescriptionCard.swift`, `OvernightVitalsCard.swift`, `AthleteProfileSheet.swift`)

**Files:**
- Modify: `ios/Lifecore/Lifecore/Lifecore/Features/Today/TodayView.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/Features/Today/TacticalPrescriptionCard.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/Features/Today/OvernightVitalsCard.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/Features/Today/AthleteProfileSheet.swift`

**Interfaces:**
- Consumes: `LifecoreTheme`, `LifecoreHairlineDivider`, `LifecoreGlowPill`, `VitalsCorridorPill`, `AdaptiveEngineBadgeBar`, `RPEQuickCalibrationRow`
- Preserves E2E IDs: `today_scroll_view`, `btn_open_profile`, `card_tactical_prescription`, `txt_prescription_archetype`, `pill_prescription_reason`, `card_overnight_vitals`, `card_body_battery`, `sheet_athlete_profile`, `input_athlete_weight`, `btn_save_profile`, `btn_close_profile`.

- [ ] **Step 1: Refactor `TacticalPrescriptionCard.swift` to Bevel Daylight (sentence case, tabular metrics, no middle-dot clutter)**

Replace `ios/Lifecore/Lifecore/Lifecore/Features/Today/TacticalPrescriptionCard.swift` with:
```swift
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
            return LifecoreTheme.statusDanger
        case .downgradedByVitalsOrBattery, .modulatedByHRV, .cappedByCaloricDeficit, .downgradedByAcuteLoadSpike, .heldByCardiacDrift:
            return LifecoreTheme.statusWarning
        case .efficiencyUnlocked, .optimalProgression, .externalClubRunAdapted:
            return LifecoreTheme.statusOptimal
        }
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

                    LifecoreGlowPill(
                        text: prescription.adaptationReason.titleUk,
                        systemIcon: "checkmark.circle.fill",
                        color: reasonColor
                    )
                    .accessibilityIdentifier("pill_prescription_reason")
                }

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
            }
            .lifecoreGlassCard(cornerRadius: 20)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("card_tactical_prescription")
    }
}
```

- [ ] **Step 2: Refactor `OvernightVitalsCard.swift` (`IllnessRadarBanner`, `OvernightVitalsCard`, `EnergyBankCard`) for Daylight theme**

Update `ios/Lifecore/Lifecore/Lifecore/Features/Today/OvernightVitalsCard.swift` so `IllnessRadarBanner` uses a borderless tinted well and all text/chart labels use `LifecoreTheme.inkPrimary`, `inkSecondary`, and `inkTertiary`:
```swift
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
```

- [ ] **Step 3: Refactor `TodayView.swift` & `AthleteProfileSheet.swift` (Daylight rings, SF Symbol status rows, clean dividers)**

In `ios/Lifecore/Lifecore/Lifecore/Features/Today/TodayView.swift`:
- Replace all `.foregroundColor(.white)` / `.foregroundStyle(.white)` with `LifecoreTheme.inkPrimary`.
- Replace `Divider().background(Color.white.opacity(0.1))` with `LifecoreHairlineDivider()`.
- In `ringsHeaderView`, place `LifecoreHairlineDivider()` between the rings row, ACWR row, `AdaptiveEngineBadgeBar`, and `RPEQuickCalibrationRow`, and call `.lifecoreGlassCard(cornerRadius: 24)` without colored border glow.
- In `sleepArchitectureCard`, replace emoji prefixes `"✅ Оптимальний..."`, `"⚠️ Дефіцит..."`, `"✅ Борг сну відсутній"` with clean `Label` or `HStack` using `Image(systemName: "checkmark.circle.fill")` and `Image(systemName: "exclamationmark.triangle.fill")`.
- In `cloudSyncSection`, style the sync button with `LifecoreTheme.accentPrimary` background and `.white` foreground text, and replace emoji prefixes in `cloudSyncMessage`.
- In `BevelRingView`, remove `.background(Color.white.opacity(0.03))` and `.clipShape(...)` (eliminating card-in-card), use `LifecoreTheme.inkPrimary` for the center value, and `ringColor.opacity(0.14)` for the track.
- Change `#Preview` to `.preferredColorScheme(.light)`.
- In `ios/Lifecore/Lifecore/Lifecore/Features/Today/AthleteProfileSheet.swift`, replace `LifecoreTheme.electricTeal` section header colors with `LifecoreTheme.inkSecondary` and `LifecoreTheme.accentPrimary` for the save button.

- [ ] **Step 4: Verify Task 2 compilation**

Run:
`xcodebuild -project ios/Lifecore/Lifecore/Lifecore.xcodeproj -scheme Lifecore -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
Expected: `BUILD SUCCEEDED`

---

### Task 3: Interactive 7-Day Workout Calendar Strip & Workouts Module (`RollingHorizonDeckView.swift`, `WorkoutsView.swift`, `WorkoutDetailView.swift`, `WorkoutChartsView.swift`, `WorkoutDetailComponents.swift`, `CoachReportView.swift`)

**Files:**
- Modify: `ios/Lifecore/Lifecore/Lifecore/Features/Workouts/RollingHorizonDeckView.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/Features/Workouts/WorkoutsView.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/Features/Workouts/WorkoutDetailView.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/Features/Workouts/WorkoutChartsView.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/Features/Workouts/WorkoutDetailComponents.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/Features/Workouts/CoachReportView.swift`

**Interfaces:**
- Consumes: `LifecoreTheme`, `TrainingPrescriptionEngine`, `TrainingPlanStore`, `HKWorkout`
- Preserves E2E IDs: `deck_rolling_horizon`, `btn_recalculate_club_queue`, `btn_refresh_workouts`, `filter_workout_all`, `filter_workout_running`, `filter_workout_strength`.

- [ ] **Step 1: Upgrade `RollingHorizonDeckView.swift` with Interactive 7-Day Bevel Calendar Strip**

Replace `ios/Lifecore/Lifecore/Lifecore/Features/Workouts/RollingHorizonDeckView.swift` with the upgraded interactive calendar strip (`@State private var selectedDayOffset: Int = 0`), daylight Bevel capsules, sentence-case labels (`"Завтра"`, `"Через 2 дні"`), and dynamic day inspection:

```swift
import SwiftUI
import HealthKit

public struct RollingHorizonDeckView: View {
    @ObservedObject public var planStore = TrainingPlanStore.shared
    @ObservedObject public var athleteStore = AthleteProfileStore.shared
    public var pastWorkouts: [HKWorkout] = []

    @State private var selectedDayOffset: Int = 0

    public init(pastWorkouts: [HKWorkout] = []) {
        self.pastWorkouts = pastWorkouts
    }

    private var currentPlan: TrainingPrescriptionPlan {
        TrainingPrescriptionEngine.prescribeTodayAndHorizon(
            queueState: planStore.queueState,
            config: planStore.goalConfig,
            previousAcuteLoad: 64.0,
            previousChronicLoad: 60.0,
            vitalsState: .optimal,
            restingHr: athleteStore.profile.restingHeartRateBaselineBpm,
            maxHr: athleteStore.profile.maxHeartRateBpm
        )
    }

    private var todayPrescription: DailyWorkoutPrescription {
        currentPlan.today
    }

    private var bannerColor: Color {
        switch todayPrescription.adaptationReason {
        case .blockedByIllnessProdrome:
            return LifecoreTheme.statusDanger
        case .downgradedByVitalsOrBattery, .modulatedByHRV, .cappedByCaloricDeficit, .downgradedByAcuteLoadSpike, .heldByCardiacDrift:
            return LifecoreTheme.statusWarning
        case .efficiencyUnlocked, .optimalProgression, .externalClubRunAdapted:
            return LifecoreTheme.statusOptimal
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 1. Upgraded Interactive Bevel 7-Day Calendar Strip
            bevelCalendarStrip

            // 2. AI Coach Recommendation Banner
            bevelCoachRecommendationBanner

            // 3. Selected Day Activity Inspector (Today + Past/Future Inspection)
            selectedDayActivitySection

            // 4. Upcoming Horizon Schedule
            upcomingHorizonSection
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("deck_rolling_horizon")
    }

    // MARK: - 1. Interactive Bevel 7-Day Calendar Strip

    private struct DaySlot: Identifiable {
        let id: Int
        let offset: Int
        let date: Date
        let dayLetter: String
        let dayNumber: String
        let isToday: Bool
    }

    private var calendarDays: [DaySlot] {
        let cal = Calendar.current
        let today = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk_UA")

        return (-3...3).map { offset in
            let date = cal.date(byAdding: .day, value: offset, to: today) ?? today
            formatter.dateFormat = "EE"
            let letter = formatter.string(from: date).capitalized
            formatter.dateFormat = "d"
            let num = formatter.string(from: date)
            return DaySlot(
                id: offset,
                offset: offset,
                date: date,
                dayLetter: letter,
                dayNumber: num,
                isToday: offset == 0
            )
        }
    }

    private var bevelCalendarStrip: some View {
        VStack(spacing: 10) {
            HStack {
                Text(monthHeaderTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LifecoreTheme.inkSecondary)
                Spacer()
                if selectedDayOffset != 0 {
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.18)) {
                            selectedDayOffset = 0
                        }
                    }) {
                        Text("Повернутись до сьогодні")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LifecoreTheme.accentPrimary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Тижневий цикл")
                        .font(.system(size: 12))
                        .foregroundStyle(LifecoreTheme.inkTertiary)
                }
            }

            HStack(spacing: 4) {
                ForEach(calendarDays) { slot in
                    let isSelected = (slot.offset == selectedDayOffset)
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.18)) {
                            selectedDayOffset = slot.offset
                        }
                    }) {
                        VStack(spacing: 6) {
                            Text(slot.dayLetter)
                                .font(.system(size: 11, weight: isSelected || slot.isToday ? .semibold : .regular))
                                .foregroundStyle(
                                    isSelected ? LifecoreTheme.inkPrimary :
                                    (slot.isToday ? LifecoreTheme.accentPrimary : LifecoreTheme.inkTertiary)
                                )

                            Text(slot.dayNumber)
                                .font(.system(size: 15, weight: isSelected || slot.isToday ? .bold : .medium, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(
                                    isSelected ? LifecoreTheme.inkPrimary :
                                    (slot.isToday ? LifecoreTheme.accentPrimary : LifecoreTheme.inkSecondary)
                                )

                            glyphForSlot(slot, isSelected: isSelected)

                            Circle()
                                .fill(slot.isToday ? LifecoreTheme.accentPrimary : Color.clear)
                                .frame(width: 4, height: 4)
                        }
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isSelected ? LifecoreTheme.paperWell : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .lifecoreGlassCard(cornerRadius: 20, padding: 14)
    }

    private var monthHeaderTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk_UA")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: Date()).capitalized
    }

    @ViewBuilder
    private func glyphForSlot(_ slot: DaySlot, isSelected: Bool) -> some View {
        if slot.isToday {
            ZStack {
                Circle()
                    .strokeBorder(
                        LifecoreTheme.accentPrimary,
                        style: StrokeStyle(lineWidth: 1.5, dash: [3])
                    )
                    .frame(width: 34, height: 34)
                Circle()
                    .fill(LifecoreTheme.accentPrimary.opacity(isSelected ? 0.18 : 0.10))
                    .frame(width: 34, height: 34)
                Image(systemName: todayPrescription.archetype.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LifecoreTheme.accentPrimary)
            }
        } else if slot.offset < 0 {
            if let w = workoutFor(date: slot.date) {
                let info = glyphInfoForWorkout(w)
                ZStack {
                    Circle()
                        .fill(info.color.opacity(0.15))
                        .frame(width: 34, height: 34)
                    Image(systemName: info.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(info.color)
                }
            } else {
                ZStack {
                    Circle()
                        .fill(LifecoreTheme.paperWell)
                        .frame(width: 34, height: 34)
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(LifecoreTheme.inkTertiary)
                }
            }
        } else {
            let queueIdx = slot.offset - 1
            if queueIdx < currentPlan.horizonQueue.count {
                let upcoming = currentPlan.horizonQueue[queueIdx]
                if upcoming.archetype == .restDay {
                    ZStack {
                        Circle()
                            .fill(LifecoreTheme.paperWell)
                            .frame(width: 34, height: 34)
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(LifecoreTheme.inkTertiary)
                    }
                } else {
                    ZStack {
                        Circle()
                            .strokeBorder(LifecoreTheme.accentTeal.opacity(0.45), style: StrokeStyle(lineWidth: 1.2, dash: [3]))
                            .frame(width: 34, height: 34)
                        Image(systemName: upcoming.archetype.iconName)
                            .font(.system(size: 13))
                            .foregroundStyle(LifecoreTheme.accentTeal)
                    }
                }
            }
        }
    }

    private func workoutFor(date: Date) -> HKWorkout? {
        let cal = Calendar.current
        return pastWorkouts.first { cal.isDate($0.startDate, inSameDayAs: date) }
    }

    private func glyphInfoForWorkout(_ w: HKWorkout) -> (icon: String, color: Color) {
        switch w.workoutActivityType {
        case .running:
            return ("figure.run", LifecoreTheme.statusOptimal)
        case .cycling:
            return ("figure.outdoor.cycle", LifecoreTheme.accentTeal)
        case .traditionalStrengthTraining, .functionalStrengthTraining:
            return ("figure.strengthtraining.traditional", LifecoreTheme.statusWarning)
        case .walking:
            return ("figure.walk", LifecoreTheme.accentIndigo)
        default:
            return ("bolt.heart.fill", LifecoreTheme.accentPrimary)
        }
    }

    // MARK: - 2. AI Coach Recommendation Banner

    private var bevelCoachRecommendationBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: todayPrescription.adaptationReason == .blockedByIllnessProdrome ? "cross.case.fill" : "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(bannerColor)

                Text(todayPrescription.adaptationReason.bevelHeadlineUk)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(LifecoreTheme.inkPrimary)
                    .lineLimit(2)

                Spacer()
            }

            Text(todayPrescription.adaptationReason.bevelExplanationUk)
                .font(.system(size: 13))
                .foregroundStyle(LifecoreTheme.inkSecondary)
                .lineSpacing(2)

            if planStore.queueState.clubOrCustomRunOverrideToday {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(LifecoreTheme.statusOptimal)
                    Text("Сьогодні враховано клубну сесію. Черга тренувань збережена.")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(LifecoreTheme.statusOptimal)
                }
                .padding(.top, 2)
            }
        }
        .lifecoreGlassCard(cornerRadius: 20)
    }

    // MARK: - 3. Selected Day Activity Section

    private var selectedDayActivitySection: some View {
        let activePrescription: DailyWorkoutPrescription = {
            if selectedDayOffset > 0 {
                let idx = selectedDayOffset - 1
                if idx < currentPlan.horizonQueue.count {
                    return currentPlan.horizonQueue[idx]
                }
            }
            return todayPrescription
        }()

        let sectionHeaderTitle: String = {
            if selectedDayOffset == 0 { return "Сьогоднішня активність" }
            if selectedDayOffset < 0 { return "Архів за обраний день" }
            return "Запланована сесія (\(slotLabel(offset: selectedDayOffset)))"
        }()

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(sectionHeaderTitle)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(LifecoreTheme.inkPrimary)

                Spacer()

                LifecoreGlowPill(
                    text: activePrescription.archetype.loadLevelUk,
                    systemIcon: "flame.fill",
                    color: LifecoreTheme.accentTeal
                )
            }

            if selectedDayOffset < 0,
               let slot = calendarDays.first(where: { $0.offset == selectedDayOffset }),
               let pastW = workoutFor(date: slot.date) {
                let distKm = (pastW.totalDistance?.doubleValue(for: .meter()) ?? 0) / 1000.0
                let durMin = pastW.duration / 60.0
                HStack(spacing: 12) {
                    let info = glyphInfoForWorkout(pastW)
                    ZStack {
                        Circle()
                            .fill(info.color.opacity(0.14))
                            .frame(width: 44, height: 44)
                        Image(systemName: info.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(info.color)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Виконане тренування")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(LifecoreTheme.inkSecondary)
                        Text(String(format: "%.0f хв  ·  %.2f км", durMin, distKm))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(LifecoreTheme.inkPrimary)
                    }
                    Spacer()
                }
                .lifecoreWell(cornerRadius: 14, padding: 12)
            } else {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(LifecoreTheme.accentPrimary.opacity(0.12))
                            .frame(width: 48, height: 48)
                        Image(systemName: activePrescription.archetype.iconName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(LifecoreTheme.accentPrimary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(activePrescription.maxAllowedZone.titleUk)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(LifecoreTheme.inkSecondary)

                        Text(activePrescription.cleanTitleUk)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(LifecoreTheme.inkPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        if activePrescription.totalDurationMin > 0 {
                            HStack(spacing: 10) {
                                Label("\(Int(round(activePrescription.totalDurationMin))) хв", systemImage: "clock")
                                Label("~\(String(format: "%.1f", activePrescription.estimatedDistanceKm)) км", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                                if let targetPace = activePrescription.segments.first(where: { $0.targetPaceSecPerKm > 0 })?.formattedPace {
                                    Text(targetPace)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(LifecoreTheme.statusOptimal)
                                }
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
                }

                if !activePrescription.segments.isEmpty && activePrescription.totalDurationMin > 0 {
                    HStack(spacing: 6) {
                        ForEach(activePrescription.segments) { seg in
                            HStack(spacing: 4) {
                                Text(seg.zone.shortBadgeUk)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(LifecoreTheme.accentTeal)
                                Text("\(Int(seg.durationMin)) хв")
                                    .font(.system(size: 10))
                                    .monospacedDigit()
                                    .foregroundStyle(LifecoreTheme.inkSecondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(LifecoreTheme.paperWell)
                            .clipShape(Capsule())
                        }
                        Spacer()
                    }
                }
            }

            LifecoreHairlineDivider()

            // 1-Tap Club / Custom Run Recalculation Button (Always accessible for E2E Flow 05)
            Button(action: {
                withAnimation(.easeOut(duration: 0.2)) {
                    planStore.toggleClubOrCustomRunToday()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: planStore.queueState.clubOrCustomRunOverrideToday ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                    Text(planStore.queueState.clubOrCustomRunOverrideToday
                         ? "Сьогодні біжу в клубі / за своїм планом (увімкнено)"
                         : "Біжу в клубі або за своїм планом (адаптувати чергу)")
                        .font(.system(size: 12, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    planStore.queueState.clubOrCustomRunOverrideToday
                        ? LifecoreTheme.statusOptimal.opacity(0.14)
                        : LifecoreTheme.paperWell
                )
                .foregroundStyle(
                    planStore.queueState.clubOrCustomRunOverrideToday
                        ? LifecoreTheme.statusOptimal
                        : LifecoreTheme.inkPrimary
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("btn_recalculate_club_queue")
        }
        .lifecoreGlassCard(cornerRadius: 20)
    }

    // MARK: - 4. Upcoming Horizon Schedule

    private var upcomingHorizonSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Найближчі тренування")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(LifecoreTheme.inkPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(currentPlan.horizonQueue) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(slotLabel(offset: item.dayOffset))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(LifecoreTheme.accentPrimary)
                                Spacer()
                                Text(item.archetype.loadLevelUk)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(LifecoreTheme.inkTertiary)
                            }

                            Text(item.cleanTitleUk)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(LifecoreTheme.inkPrimary)
                                .lineLimit(2)

                            if item.totalDurationMin > 0 {
                                Text("\(Int(item.totalDurationMin)) хв  ·  ~\(String(format: "%.1f", item.estimatedDistanceKm)) км")
                                    .font(.system(size: 11, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(LifecoreTheme.inkSecondary)
                            } else {
                                Text("Відпочинок")
                                    .font(.system(size: 11))
                                    .foregroundStyle(LifecoreTheme.inkSecondary)
                            }
                        }
                        .frame(width: 172, alignment: .leading)
                        .lifecoreGlassCard(cornerRadius: 16, padding: 12)
                    }
                }
            }
        }
    }

    private func slotLabel(offset: Int) -> String {
        switch offset {
        case 1: return "Завтра"
        case 2: return "Через 2 дні"
        case 3: return "Через 3 дні"
        default: return "Слот +\(offset)"
        }
    }
}
```

- [ ] **Step 2: Refactor `WorkoutsView.swift`, `WorkoutDetailView.swift`, `WorkoutChartsView.swift`, `WorkoutDetailComponents.swift`, and `CoachReportView.swift` to Bevel Daylight**

Apply the following changes across the Workouts files:
- **`WorkoutsView.swift`**:
  - Replace `.tint(.cyan)` and `.foregroundStyle(.cyan)` in toolbar with `LifecoreTheme.accentPrimary`.
  - In `filterScrollView`, active chip uses `LifecoreTheme.inkPrimary` background with `.white` text; inactive chip uses `LifecoreTheme.paperCard` with `1px` `LifecoreTheme.ruleHairline` border and `LifecoreTheme.inkSecondary` text.
  - Replace `Color(red: 0.1, green: 0.11, blue: 0.15)` in `casualWalksToggle` and `emptyStateView` with `.lifecoreGlassCard()`.
  - Replace `.foregroundStyle(.white)` with `LifecoreTheme.inkPrimary` and `Divider().background(...)` with `LifecoreHairlineDivider()`.
  - Apply `.monospacedDigit()` to `metricColumn` values.
  - Change `#Preview` to `.preferredColorScheme(.light)`.
- **`WorkoutDetailView.swift`, `WorkoutChartsView.swift`, `WorkoutDetailComponents.swift`, `CoachReportView.swift`**:
  - Replace all `Color(red: 0.05, green: 0.06, blue: 0.08)` with `LifecoreTheme.paperCanvas`.
  - Replace all `.background(Color(red: 0.1, green: 0.11, blue: 0.15))` + `.clipShape(...)` with `.lifecoreGlassCard()`.
  - Replace all `.foregroundStyle(.white)` with `LifecoreTheme.inkPrimary`.
  - In `WorkoutChartsView.swift`, replace `Color.white.opacity(0.08)` grid lines with `LifecoreTheme.ruleHairline`, and style `interactiveTooltip` with `LifecoreTheme.paperWell` background and `LifecoreTheme.inkPrimary` text.
  - In `SplitsTableView` and `IntervalLapsTableView`, apply `.monospacedDigit()` to all numeric columns and use `LifecoreHairlineDivider()`.
  - In `CoachReportView.swift`, replace neon `.cyan`/`.purple` gradients with `LifecoreTheme.accentPrimary` button fill (`.white` label) and `LifecoreTheme.inkPrimary` report text.

- [ ] **Step 3: Verify Task 3 compilation**

Run:
`xcodebuild -project ios/Lifecore/Lifecore/Lifecore.xcodeproj -scheme Lifecore -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
Expected: `BUILD SUCCEEDED`

---

### Task 4: Nutrition Module Redesign (`NutritionView.swift`, `NutritionComponents.swift`, `FoodInputSheet.swift`)

**Files:**
- Modify: `ios/Lifecore/Lifecore/Lifecore/Features/Nutrition/NutritionView.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/Features/Nutrition/NutritionComponents.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/Features/Nutrition/FoodInputSheet.swift`

**Interfaces:**
- Consumes: `LifecoreTheme`, `MealStorageService`, `FoodPrompt`
- Preserves E2E IDs: `card_nutrition_summary`, `btn_add_meal`, `sheet_food_input`, `btn_close_food_input`, `preset_oatmeal`, `input_food_text`, `btn_submit_food`.

- [ ] **Step 1: Refactor `NutritionView.swift` for Daylight theme**

In `ios/Lifecore/Lifecore/Lifecore/Features/Nutrition/NutritionView.swift`:
- Replace `.foregroundStyle(.white)` with `LifecoreTheme.inkPrimary`.
- In `dateNavigationHeader`, style the left/right circular chevron buttons with `LifecoreTheme.paperCard` fill, `1px` `LifecoreTheme.ruleHairline` stroke, and `LifecoreTheme.inkPrimary` icon.
- In `fastActionBar`, style the yesterday toggle button with `LifecoreTheme.statusWarning` when active (`.white` text) and `LifecoreTheme.paperCard` when inactive (`LifecoreTheme.inkPrimary` text).
- In `emptyDayView` and `undoBanner`, replace literal dark RGB backgrounds (`Color(red: 0.1...)` and `Color(red: 0.14...)`) with `.lifecoreGlassCard()`.
- Change `#Preview` to `.preferredColorScheme(.light)`.

- [ ] **Step 2: Refactor `NutritionComponents.swift` & `FoodInputSheet.swift` for Daylight theme**

In `ios/Lifecore/Lifecore/Lifecore/Features/Nutrition/NutritionComponents.swift`:
- Replace all `.foregroundStyle(.white)` with `LifecoreTheme.inkPrimary`.
- Replace all `Color.white.opacity(0.08)` progress bar tracks with `LifecoreTheme.paperWell`.
- Replace `Divider().background(Color.white.opacity(0.08))` with `LifecoreHairlineDivider()`.
- Apply `.monospacedDigit()` to all calorie, gram, sodium, and leucine numbers.
- In `OptimisticAnalyzingCard`, replace `Color(red: 0.1, green: 0.11, blue: 0.15)` with `.lifecoreGlassCard()`.

In `ios/Lifecore/Lifecore/Lifecore/Features/Nutrition/FoodInputSheet.swift`:
- Replace `.background(Color(red: 0.05, green: 0.06, blue: 0.08).ignoresSafeArea())` with `.background(LifecoreTheme.paperCanvas.ignoresSafeArea())`.
- Replace `Color(red: 0.1, green: 0.11, blue: 0.15)` on the gallery button and `TextEditor` container with `LifecoreTheme.paperCard` and `1px` `LifecoreTheme.ruleHairline` border.
- Change `TextEditor` `.foregroundStyle(.white)` to `.foregroundStyle(LifecoreTheme.inkPrimary)`.
- Style `presetChip` with `LifecoreTheme.paperWell` background and `LifecoreTheme.inkPrimary` text (preserving `id: "preset_oatmeal"`).
- Style `submitButton` with `LifecoreTheme.accentPrimary` when `canSubmit` is true (`.white` text) and `LifecoreTheme.paperWell` when disabled (`LifecoreTheme.inkTertiary` text), preserving `id: "btn_submit_food"`.

- [ ] **Step 3: Verify Task 4 compilation**

Run:
`xcodebuild -project ios/Lifecore/Lifecore/Lifecore.xcodeproj -scheme Lifecore -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
Expected: `BUILD SUCCEEDED`

---

### Task 5: Trends & Analytics Redesign (`TrendsView.swift`, `TrendsComponents.swift`, `CorrelationInsightsCard.swift`)

**Files:**
- Modify: `ios/Lifecore/Lifecore/Lifecore/Features/Trends/TrendsView.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/Features/Trends/TrendsComponents.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/Features/Trends/CorrelationInsightsCard.swift`

**Interfaces:**
- Consumes: `LifecoreTheme`, `LifecoreHairlineDivider`, `AdaptiveEngineStatusCard`
- Preserves E2E IDs: `trends_scroll_view`, `tab_trend_adaptation`, `tab_trend_workload`, `tab_trend_body`, `tab_trend_cardio`.

- [ ] **Step 1: Refactor `TrendsView.swift` & `CorrelationInsightsCard.swift` to Bevel Daylight**

In `ios/Lifecore/Lifecore/Lifecore/Features/Trends/TrendsView.swift`:
- In `categorySwitcher`, style the outer container with `LifecoreTheme.paperWell` and the selected category pill with `LifecoreTheme.paperCard` + `1px` `LifecoreTheme.ruleHairline` border and `LifecoreTheme.inkPrimary` text (inactive text: `LifecoreTheme.inkSecondary`).
- Change `#Preview` to `.preferredColorScheme(.light)`.

In `ios/Lifecore/Lifecore/Lifecore/Features/Trends/CorrelationInsightsCard.swift`:
- Replace all `.foregroundColor(.white)` with `LifecoreTheme.inkPrimary`.
- In `insightRow`, remove the nested `.stroke(...)` border (Gate 4 card-in-card fix) and use `.lifecoreWell(cornerRadius: 12, padding: 12)` instead.
- In `ACWRWorkloadTrendCard`, replace the nested bordered box with `.lifecoreWell(cornerRadius: 12, padding: 12)` and apply `.monospacedDigit()` to `loadStat`.

- [ ] **Step 2: Refactor `TrendsComponents.swift` (Daylight Charts, Tabular Stats, No Emoji Badges)**

In `ios/Lifecore/Lifecore/Lifecore/Features/Trends/TrendsComponents.swift`:
- In `TrendsRangePickerView`, replace `Color(red: 0.08, green: 0.09, blue: 0.12)` track with `LifecoreTheme.paperWell`; selected range uses `LifecoreTheme.paperCard` with `LifecoreTheme.inkPrimary` text; unselected uses `LifecoreTheme.inkSecondary`.
- In `TrendStatItem`, replace `.foregroundStyle(.white)` with `LifecoreTheme.inkPrimary` and add `.monospacedDigit()`.
- In `WeightTrendCard`, `AutonomicTrendCard`, and `AerobicEfficiencyTrendCard`:
  - Replace all `.foregroundStyle(.white)` with `LifecoreTheme.inkPrimary`.
  - Replace `"💧 Водний сплеск"` emoji with `Label("Водний сплеск", systemImage: "drop.fill")`.
  - Replace `Color.white.opacity(0.08)` scrub tooltips with `LifecoreTheme.paperWell`.
  - Replace `Color.white.opacity(0.08)` chart grid lines with `LifecoreTheme.ruleHairline`.
  - Replace raw weight scatter point color `Color.white.opacity(0.35)` with `LifecoreTheme.inkTertiary.opacity(0.45)`.

- [ ] **Step 3: Verify Task 5 compilation**

Run:
`xcodebuild -project ios/Lifecore/Lifecore/Lifecore.xcodeproj -scheme Lifecore -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
Expected: `BUILD SUCCEEDED`

---

### Task 6: Hallmark Sweep, E2E Verification & Documentation Synchronization (`AGENTS.md` Rule 3)

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `PROJECT_KNOWLEDGE.md`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `README.md`

- [ ] **Step 1: Run Hallmark Token & Anti-Slop Audit across `ios/Lifecore/`**

Run:
```bash
grep -rn "Color(red: 0.05" ios/Lifecore/Lifecore/Lifecore/ || true
grep -rn "Color(red: 0.1," ios/Lifecore/Lifecore/Lifecore/ || true
grep -rn "preferredColorScheme(.dark)" ios/Lifecore/Lifecore/Lifecore/ || true
```
Expected: Zero matches across the entire iOS source tree.

- [ ] **Step 2: Verify all 17 Maestro E2E `.accessibilityIdentifier` hooks exist**

Run:
```bash
grep -rn "accessibilityIdentifier" ios/Lifecore/Lifecore/Lifecore/
```
Expected: All 17 identifiers (`tab_today`, `tab_workouts`, `tab_nutrition`, `tab_trends`, `today_scroll_view`, `card_overnight_vitals`, `card_body_battery`, `btn_open_profile`, `sheet_athlete_profile`, `input_athlete_weight`, `btn_save_profile`, `card_tactical_prescription`, `txt_prescription_archetype`, `pill_prescription_reason`, `deck_rolling_horizon`, `btn_recalculate_club_queue`, `card_nutrition_summary`, `btn_add_meal`, `sheet_food_input`, `btn_close_food_input`, `preset_oatmeal`, `btn_submit_food`, `btn_refresh_workouts`, `filter_workout_*`, `trends_scroll_view`, `tab_trend_*`) present.

- [ ] **Step 3: Synchronize Project Documentation (`CHANGELOG.md`, `PROJECT_KNOWLEDGE.md`, `docs/ROADMAP.md`, `docs/ARCHITECTURE.md`, `README.md`)**

Update all 5 documentation files in concise English (`AGENTS.md` Rule 1.1 & Rule 3) to reflect **Lifecore v3.3 (Hallmark v2.0.0 Bevel & Apple Health Daylight UI Redesign & Interactive 7-Day Workout Calendar Strip)**.
