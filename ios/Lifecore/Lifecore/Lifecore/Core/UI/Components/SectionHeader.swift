import SwiftUI

/// Accessible section header with optional subtitle and minimum 44pt trailing action.
public struct SectionHeader: View {
    public let title: String
    public let subtitle: String?
    public let actionTitle: String?
    public let action: (() -> Void)?

    public init(
        title: String,
        subtitle: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            horizontalLayout
            verticalLayout
        }
    }

    private var titleStack: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
                .foregroundStyle(LifecoreTheme.semanticPrimaryLabel)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(LifecoreTheme.semanticSecondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if let actionTitle, !actionTitle.isEmpty {
            Button {
                action?()
            } label: {
                Text(actionTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifecoreTheme.accentPrimary)
                    .frame(minHeight: LifecoreLayout.minTouchTarget, alignment: .center)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(actionTitle)
            .accessibilityAddTraits(.isButton)
        }
    }

    private var horizontalLayout: some View {
        HStack(alignment: .center, spacing: LifecoreLayout.spacing12) {
            titleStack
            Spacer(minLength: LifecoreLayout.spacing8)
            actionButton
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var verticalLayout: some View {
        VStack(alignment: .leading, spacing: LifecoreLayout.spacing4) {
            titleStack
            actionButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
