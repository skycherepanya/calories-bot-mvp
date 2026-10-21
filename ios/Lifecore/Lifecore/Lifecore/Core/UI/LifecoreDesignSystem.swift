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
}

// MARK: - View Modifiers

public struct LifecoreGlassCardModifier: ViewModifier {
    public var cornerRadius: CGFloat = 18
    public var padding: CGFloat = 16

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
                    .stroke(LifecoreTheme.specularBorderGradient, lineWidth: 1.0)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 5)
    }
}

public extension View {
    func lifecoreGlassCard(cornerRadius: CGFloat = 18, padding: CGFloat = 16) -> some View {
        modifier(LifecoreGlassCardModifier(cornerRadius: cornerRadius, padding: padding))
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
