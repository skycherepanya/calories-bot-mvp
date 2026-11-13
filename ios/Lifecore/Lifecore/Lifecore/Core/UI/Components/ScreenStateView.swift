import SwiftUI

/// Generic state-driven view container supporting loading, empty, unavailable,
/// non-destructive failure (retained content + retry banner), and refreshing/stale content.
public struct ScreenStateView<Value: Sendable, Content: View>: View {
    public let state: ScreenState<Value>
    public let emptyTitle: String
    public let emptyMessage: String
    public let emptySystemImage: String
    public let retryTitle: String
    public let onRetry: (() -> Void)?
    private let content: (Value) -> Content

    public init(
        state: ScreenState<Value>,
        emptyTitle: String = "Немає даних",
        emptyMessage: String = "Щойно з’являться нові вимірювання або записи, вони відобразяться тут.",
        emptySystemImage: String = "tray",
        retryTitle: String = "Спробувати ще раз",
        onRetry: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Value) -> Content
    ) {
        self.state = state
        self.emptyTitle = emptyTitle
        self.emptyMessage = emptyMessage
        self.emptySystemImage = emptySystemImage
        self.retryTitle = retryTitle
        self.onRetry = onRetry
        self.content = content
    }

    public var body: some View {
        switch state {
        case .loading:
            loadingView

        case .empty:
            emptyView

        case .unavailable(let message):
            unavailableView(message: message)

        case .failed(let message, let retained):
            if let retained {
                VStack(alignment: .leading, spacing: LifecoreLayout.spacing12) {
                    retainedFailureBanner(message: message)
                    content(retained)
                }
            } else {
                fullFailureView(message: message)
            }

        case .content(let value, let isRefreshing, let isStale):
            VStack(alignment: .leading, spacing: LifecoreLayout.spacing12) {
                if isRefreshing || isStale {
                    statusStrip(isRefreshing: isRefreshing, isStale: isStale)
                }
                content(value)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: LifecoreLayout.spacing12) {
            ProgressView()
                .tint(LifecoreTheme.accentPrimary)
            Text("Завантаження даних...")
                .font(.subheadline)
                .foregroundStyle(LifecoreTheme.semanticSecondaryLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LifecoreLayout.spacing32)
        .accessibilityElement(children: .combine)
    }

    private var emptyView: some View {
        VStack(spacing: LifecoreLayout.spacing12) {
            ContentUnavailableView {
                Label(emptyTitle, systemImage: emptySystemImage)
            } description: {
                Text(emptyMessage)
            } actions: {
                if let onRetry {
                    PrimaryAction(title: retryTitle, systemImage: "arrow.clockwise", action: onRetry)
                        .frame(maxWidth: 260)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func unavailableView(message: String) -> some View {
        VStack(spacing: LifecoreLayout.spacing12) {
            ContentUnavailableView {
                Label("Джерело недоступне", systemImage: "lock.shield")
            } description: {
                Text(message)
            } actions: {
                if let onRetry {
                    PrimaryAction(title: retryTitle, systemImage: "arrow.clockwise", action: onRetry)
                        .frame(maxWidth: 260)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func fullFailureView(message: String) -> some View {
        VStack(spacing: LifecoreLayout.spacing16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(LifecoreTheme.statusDanger)
                .accessibilityHidden(true)

            VStack(spacing: LifecoreLayout.spacing4) {
                Text("Не вдалося оновити дані")
                    .font(.headline)
                    .foregroundStyle(LifecoreTheme.semanticPrimaryLabel)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(LifecoreTheme.semanticSecondaryLabel)
                    .multilineTextAlignment(.center)
            }

            if let onRetry {
                PrimaryAction(title: retryTitle, systemImage: "arrow.clockwise", action: onRetry)
                    .frame(maxWidth: 280)
            }
        }
        .padding(LifecoreLayout.spacing16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LifecoreTheme.semanticCard)
        )
    }

    private func retainedFailureBanner(message: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: LifecoreLayout.spacing12) {
                bannerLabel(message: message)
                Spacer(minLength: LifecoreLayout.spacing8)
                bannerRetryButton
            }
            VStack(alignment: .leading, spacing: LifecoreLayout.spacing8) {
                bannerLabel(message: message)
                bannerRetryButton
            }
        }
        .padding(LifecoreLayout.spacing12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LifecoreTheme.statusWarning.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(LifecoreTheme.statusWarning.opacity(0.35), lineWidth: 1)
        )
        .accessibilityIdentifier("screen_state_retained_retry_banner")
    }

    private func bannerLabel(message: String) -> some View {
        HStack(alignment: .top, spacing: LifecoreLayout.spacing8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(LifecoreTheme.statusWarning)
                .accessibilityHidden(true)
            Text(message)
                .font(.footnote.weight(.medium))
                .foregroundStyle(LifecoreTheme.semanticPrimaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var bannerRetryButton: some View {
        if let onRetry {
            Button(action: onRetry) {
                Text(retryTitle)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(LifecoreTheme.accentPrimary)
                    .padding(.horizontal, LifecoreLayout.spacing8)
                    .frame(minHeight: LifecoreLayout.minTouchTarget)
            }
            .buttonStyle(.plain)
        }
    }

    private func statusStrip(isRefreshing: Bool, isStale: Bool) -> some View {
        HStack(spacing: LifecoreLayout.spacing8) {
            if isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .tint(LifecoreTheme.accentPrimary)
                Text("Оновлення даних...")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(LifecoreTheme.semanticSecondaryLabel)
            } else if isStale {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LifecoreTheme.statusWarning)
                    .accessibilityHidden(true)
                Text("Показано останні збережені дані")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(LifecoreTheme.semanticSecondaryLabel)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, LifecoreLayout.spacing12)
        .padding(.vertical, LifecoreLayout.spacing8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LifecoreTheme.semanticWell)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Component Gallery Fixture View

/// Fixture gallery demonstrating ready, empty, failed, and long Ukrainian text
/// across all five semantic primitives using LifecoreLayout spacing tokens.
public struct ComponentGalleryFixtureView: View {
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LifecoreLayout.spacing24) {
                // 1. Ready State + Primitives
                VStack(alignment: .leading, spacing: LifecoreLayout.spacing12) {
                    SectionHeader(
                        title: "Готовність та вітальні показники",
                        subtitle: "Приклад штатного стану та всіх базових примітивів",
                        actionTitle: "Оновити",
                        action: {}
                    )

                    ScreenStateView(
                        state: ScreenState.content("104 мс", isRefreshing: true, isStale: false),
                        onRetry: {}
                    ) { hrv in
                        VStack(spacing: LifecoreLayout.spacing8) {
                            ChartSummary(
                                title: "Варіабельність серцевого ритму (RMSSD)",
                                value: hrv,
                                coverage: "Покриття: 28 з 30 ночей",
                                deltaText: "+6% до бази"
                            )

                            MetricRow(
                                title: "Пульс спокою вночі",
                                value: "48 уд/хв",
                                detail: "У межах індивідуального коридору",
                                systemImage: "heart.fill",
                                statusTone: .optimal
                            )

                            PrimaryAction(
                                title: "Синхронізувати дані",
                                systemImage: "arrow.triangle.2.circlepath",
                                action: {}
                            )
                        }
                    }
                }
                .padding(LifecoreLayout.spacing16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LifecoreTheme.semanticCard)
                )

                // 2. Retained Failure State
                VStack(alignment: .leading, spacing: LifecoreLayout.spacing12) {
                    SectionHeader(
                        title: "Часткова помилка зі збереженням даних",
                        subtitle: "Не руйнує попередній контент"
                    )

                    ScreenStateView(
                        state: ScreenState.failed(
                            message: "Немає з’єднання з хмарним сервером синхронізації",
                            retained: "2 180 ккал"
                        ),
                        onRetry: {}
                    ) { retainedKcal in
                        MetricRow(
                            title: "Останній збережений калораж",
                            value: retainedKcal,
                            detail: "Локальний запис із SwiftData",
                            systemImage: "flame.fill",
                            statusTone: .warning
                        )
                    }
                }
                .padding(LifecoreLayout.spacing16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LifecoreTheme.semanticCard)
                )

                // 3. Long Ukrainian Text + Dynamic Type Stress Case
                VStack(alignment: .leading, spacing: LifecoreLayout.spacing12) {
                    SectionHeader(
                        title: "Дуже довгий заголовок секції українською мовою для перевірки перенесення рядків",
                        subtitle: "Перевірка адаптивного переходу з горизонтального рядка у вертикальний блок",
                        actionTitle: "Детальніше",
                        action: {}
                    )

                    VStack(spacing: LifecoreLayout.spacing4) {
                        MetricRow(
                            title: "Середньотижневе співвідношення гострого та хронічного тренувального навантаження",
                            value: "1.18 ACWR",
                            detail: "Оптимальна зона адаптації без перетренованості",
                            systemImage: "waveform.path.ecg",
                            statusTone: .teal
                        )

                        ChartSummary(
                            title: "Середня аеробна ефективність на темпових пробіжках",
                            value: "1.42 EF",
                            coverage: "Покриття: 14 тренувань за останні 42 дні",
                            deltaText: "+0.05 за місяць"
                        )
                    }
                }
                .padding(LifecoreLayout.spacing16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LifecoreTheme.semanticCard)
                )

                // 4. Empty State
                VStack(alignment: .leading, spacing: LifecoreLayout.spacing12) {
                    SectionHeader(title: "Порожній стан")

                    ScreenStateView<String, Text>(
                        state: .empty,
                        emptyTitle: "Записів ще немає",
                        emptyMessage: "Додайте перше тренування або прийом їжі для побудови аналітики.",
                        onRetry: {}
                    ) { value in
                        Text(value)
                    }
                }
                .padding(LifecoreLayout.spacing16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LifecoreTheme.semanticCard)
                )
            }
            .padding(.horizontal, LifecoreLayout.pageInset)
            .padding(.vertical, LifecoreLayout.spacing32)
        }
        .background(LifecoreTheme.semanticCanvas.ignoresSafeArea())
    }
}
