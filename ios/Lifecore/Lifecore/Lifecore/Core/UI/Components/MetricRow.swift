import SwiftUI

/// Accessible key-value metric row with Dynamic Type vertical fallback.
public struct MetricRow: View {
    public let title: String
    public let value: String
    public let detail: String?
    public let systemImage: String?
    public let statusTone: MetricStatusTone

    public init(
        title: String,
        value: String,
        detail: String? = nil,
        systemImage: String? = nil,
        statusTone: MetricStatusTone = .neutral
    ) {
        self.title = title
        self.value = value
        self.detail = detail
        self.systemImage = systemImage
        self.statusTone = statusTone
    }

    private var valueColor: Color {
        statusTone == .neutral ? LifecoreTheme.semanticPrimaryLabel : statusTone.color
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            horizontalLayout
            verticalLayout
        }
        .frame(minHeight: LifecoreLayout.minTouchTarget, alignment: .center)
        .accessibilityElement(children: .combine)
    }

    private var horizontalLayout: some View {
        HStack(alignment: .center, spacing: LifecoreLayout.spacing12) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(statusTone.color)
                    .frame(width: 22, alignment: .center)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(LifecoreTheme.semanticPrimaryLabel)
                    .lineLimit(1)

                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(LifecoreTheme.semanticSecondaryLabel)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: LifecoreLayout.spacing8)

            Text(value)
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var verticalLayout: some View {
        VStack(alignment: .leading, spacing: LifecoreLayout.spacing4) {
            HStack(alignment: .firstTextBaseline, spacing: LifecoreLayout.spacing8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(statusTone.color)
                        .accessibilityHidden(true)
                }

                Text(title)
                    .font(.body)
                    .foregroundStyle(LifecoreTheme.semanticPrimaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .fixedSize(horizontal: false, vertical: true)

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(LifecoreTheme.semanticSecondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, LifecoreLayout.spacing4)
    }
}
