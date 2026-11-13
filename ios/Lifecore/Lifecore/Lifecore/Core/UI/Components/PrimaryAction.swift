import SwiftUI

/// Restrained primary action button with 44pt minimum touch target and Reduce Motion support.
public struct PrimaryAction: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public let title: String
    public let systemImage: String?
    public let isLoading: Bool
    public let isDisabled: Bool
    public let action: () -> Void

    public init(
        title: String,
        systemImage: String? = nil,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }

    private var isInteractiveDisabled: Bool {
        isLoading || isDisabled
    }

    public var body: some View {
        Button {
            guard !isInteractiveDisabled else { return }
            action()
        } label: {
            HStack(spacing: LifecoreLayout.spacing8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.body.weight(.semibold))
                        .accessibilityHidden(true)
                }

                Text(isLoading ? "Виконується..." : title)
                    .font(.body.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, minHeight: LifecoreLayout.minTouchTarget)
            .padding(.horizontal, LifecoreLayout.spacing16)
            .padding(.vertical, LifecoreLayout.spacing8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LifecoreTheme.accentPrimary.opacity(isInteractiveDisabled ? 0.45 : 1.0))
            )
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: isInteractiveDisabled)
        }
        .buttonStyle(.plain)
        .disabled(isInteractiveDisabled)
        .accessibilityLabel(isLoading ? "\(title), виконується" : title)
        .accessibilityAddTraits(.isButton)
    }
}
