import SwiftUI

public struct CoachEvidenceView: View {
    @Environment(\.dismiss) private var dismiss

    public let items: [CoachEvidenceItem]

    public init(items: [CoachEvidenceItem]) {
        self.items = items
    }

    public init(viewModel: CoachViewModel) {
        self.items = viewModel.evidenceItems
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LifecoreLayout.spacing16) {
                // Header Banner
                headerCard

                // Scoped Evidence Cards
                ForEach(items) { item in
                    evidenceCard(for: item)
                }

                // Data Integrity Disclosure
                integrityNoticeCard
            }
            .padding(.horizontal, LifecoreLayout.pageInset)
            .padding(.vertical, LifecoreLayout.spacing16)
        }
        .background(LifecoreTheme.semanticCanvas.ignoresSafeArea())
        .navigationTitle("Доказова база тренера")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Готово") {
                    dismiss()
                }
                .fontWeight(.semibold)
                .foregroundStyle(LifecoreTheme.accentPrimary)
                .accessibilityIdentifier("btn_close_evidence")
            }
        }
        .accessibilityIdentifier("screen_coach_evidence")
    }

    // MARK: - Subviews

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: LifecoreLayout.spacing8) {
            HStack(spacing: LifecoreLayout.spacing8) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(LifecoreTheme.accentPrimary)
                Text("Обґрунтування аналізу")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(LifecoreTheme.inkPrimary)
            }

            Text("Тренер Lifecore спирається виключно на підтверджені дані ваших датчиків, журналу харчування та особистого контексту. Жодних усереднених припущень.")
                .font(.system(size: 13))
                .foregroundStyle(LifecoreTheme.inkSecondary)
                .lineSpacing(3)
        }
        .padding(LifecoreLayout.spacing16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LifecoreTheme.paperCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(LifecoreTheme.ruleHairline, lineWidth: 1)
        )
    }

    private func evidenceCard(for item: CoachEvidenceItem) -> some View {
        VStack(alignment: .leading, spacing: LifecoreLayout.spacing12) {
            // Header Row: Domain + Status
            HStack(alignment: .center) {
                HStack(spacing: LifecoreLayout.spacing8) {
                    Image(systemName: iconForDomain(item.id))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(item.isAvailable ? LifecoreTheme.accentPrimary : LifecoreTheme.inkTertiary)
                    Text(item.domainUk)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(LifecoreTheme.inkPrimary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(item.isAvailable ? LifecoreTheme.statusOptimal : LifecoreTheme.inkTertiary.opacity(0.5))
                        .frame(width: 6, height: 6)
                    Text(item.isAvailable ? "Виміряно" : "Немає записів")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(item.isAvailable ? LifecoreTheme.statusOptimal : LifecoreTheme.inkTertiary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(item.isAvailable ? LifecoreTheme.statusOptimal.opacity(0.10) : LifecoreTheme.paperWell)
                .clipShape(Capsule())
            }

            LifecoreHairlineDivider()

            // Source, Window, Coverage Breakdown
            VStack(alignment: .leading, spacing: LifecoreLayout.spacing8) {
                detailRow(title: "Джерело", value: item.sourceUk)
                detailRow(title: "Вікно спостереження", value: item.windowUk)
                detailRow(title: "Охоплення", value: item.coverageUk)
            }

            // Validated Metric Pills (if present)
            if !item.pills.isEmpty {
                LifecoreHairlineDivider()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: LifecoreLayout.spacing8) {
                        ForEach(item.pills) { pill in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pill.labelUk)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(LifecoreTheme.inkTertiary)
                                Text(pill.valueUk)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(colorForTone(pill.tone))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(LifecoreTheme.paperWell)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
            }
        }
        .padding(LifecoreLayout.spacing16)
        .background(LifecoreTheme.paperCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(LifecoreTheme.ruleHairline, lineWidth: 1)
        )
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: LifecoreLayout.spacing8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(LifecoreTheme.inkSecondary)
                .frame(width: 130, alignment: .leading)

            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(LifecoreTheme.inkPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var integrityNoticeCard: some View {
        HStack(alignment: .top, spacing: LifecoreLayout.spacing8) {
            Image(systemName: "lock.shield")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(LifecoreTheme.accentTeal)
                .padding(.top, 2)

            Text("Принцип нульових галюцинацій: якщо дані сну чи харчування не записані, тренер чесно зазначає про це та не будує на їх основі висновків.")
                .font(.system(size: 12))
                .foregroundStyle(LifecoreTheme.inkSecondary)
                .lineSpacing(2)
        }
        .padding(LifecoreLayout.spacing12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LifecoreTheme.paperWell)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Helpers

    private func iconForDomain(_ id: String) -> String {
        switch id {
        case "workout_telemetry": return "figure.run"
        case "scoped_nutrition": return "fork.knife"
        case "overnight_vitals": return "heart.text.square"
        case "athlete_memory": return "brain.head.profile"
        default: return "chart.bar.doc.horizontal"
        }
    }

    private func colorForTone(_ tone: String) -> Color {
        switch tone {
        case "optimal": return LifecoreTheme.statusOptimal
        case "teal": return LifecoreTheme.accentTeal
        case "warning": return LifecoreTheme.statusWarning
        case "danger": return LifecoreTheme.statusDanger
        default: return LifecoreTheme.inkPrimary
        }
    }
}
