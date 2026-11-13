import SwiftUI

/// Numeric chart summary header with explicit data coverage and Dynamic Type reflow.
public struct ChartSummary: View {
    public let title: String
    public let value: String
    public let coverage: String
    public let deltaText: String?

    public init(
        title: String,
        value: String,
        coverage: String,
        deltaText: String? = nil
    ) {
        self.title = title
        self.value = value
        self.coverage = coverage
        self.deltaText = deltaText
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            horizontalLayout
            verticalLayout
        }
        .padding(LifecoreLayout.spacing12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LifecoreTheme.semanticWell)
        )
        .accessibilityElement(children: .combine)
    }

    private var titleAndCoverage: some View {
        VStack(alignment: .leading, spacing: LifecoreLayout.spacing4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LifecoreTheme.semanticPrimaryLabel)
                .fixedSize(horizontal: false, vertical: true)

            Text(coverage)
                .font(.caption)
                .foregroundStyle(LifecoreTheme.semanticSecondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var valueAndDelta: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(LifecoreTheme.semanticPrimaryLabel)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            if let deltaText, !deltaText.isEmpty {
                Text(deltaText)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(LifecoreTheme.accentTeal)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private var horizontalLayout: some View {
        HStack(alignment: .center, spacing: LifecoreLayout.spacing12) {
            titleAndCoverage
            Spacer(minLength: LifecoreLayout.spacing8)
            valueAndDelta
        }
    }

    private var verticalLayout: some View {
        VStack(alignment: .leading, spacing: LifecoreLayout.spacing8) {
            titleAndCoverage

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(LifecoreTheme.semanticPrimaryLabel)
                    .fixedSize(horizontal: false, vertical: true)

                if let deltaText, !deltaText.isEmpty {
                    Text(deltaText)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(LifecoreTheme.accentTeal)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
