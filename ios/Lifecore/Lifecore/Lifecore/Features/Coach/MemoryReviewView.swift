import SwiftUI
import SwiftData

public struct MemoryReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject public var viewModel: CoachViewModel

    public init(viewModel: CoachViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LifecoreLayout.spacing16) {
                // Privacy & Data Disclosure Header
                disclosureCard

                // Candidates Section (Requires Manual Approval)
                candidateSection

                // Confirmed Section (Active Context)
                confirmedSection

                // Settings & Credentials Setup Hint
                settingsHintCard
            }
            .padding(.horizontal, LifecoreLayout.pageInset)
            .padding(.vertical, LifecoreLayout.spacing16)
        }
        .background(LifecoreTheme.semanticCanvas.ignoresSafeArea())
        .navigationTitle("Пам’ять тренера")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Готово") {
                    dismiss()
                }
                .fontWeight(.semibold)
                .foregroundStyle(LifecoreTheme.accentPrimary)
                .accessibilityIdentifier("btn_close_memory_review")
            }
        }
        .onAppear {
            viewModel.refreshMemories()
        }
        .accessibilityIdentifier("screen_memory_review")
    }

    // MARK: - Disclosure Card

    private var disclosureCard: some View {
        VStack(alignment: .leading, spacing: LifecoreLayout.spacing8) {
            HStack(spacing: LifecoreLayout.spacing8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(LifecoreTheme.accentIndigo)
                Text("Контекст атлета")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(LifecoreTheme.inkPrimary)
            }

            Text("Lifecore зберігає тільки ті факти, якими ви ділитеся в діалозі (цілі, особливості бігу, старі травми). Жодні медичні діагнози не додаються автоматично без вашого явного підтвердження.")
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

    // MARK: - Candidate Section

    private var candidateSection: some View {
        VStack(alignment: .leading, spacing: LifecoreLayout.spacing12) {
            HStack {
                Text("Очікують підтвердження")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(LifecoreTheme.inkPrimary)

                Spacer()

                Text("\(viewModel.candidateMemories.count)")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(viewModel.candidateMemories.isEmpty ? LifecoreTheme.paperWell : LifecoreTheme.statusWarning.opacity(0.15))
                    .foregroundStyle(viewModel.candidateMemories.isEmpty ? LifecoreTheme.inkTertiary : LifecoreTheme.statusWarning)
                    .clipShape(Capsule())
            }

            if viewModel.candidateMemories.isEmpty {
                HStack(spacing: LifecoreLayout.spacing8) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(LifecoreTheme.inkTertiary)
                    Text("Немає нових фактів для перевірки. Коли тренер виділить інсайт у діалозі, він з'явиться тут.")
                        .font(.system(size: 12))
                        .foregroundStyle(LifecoreTheme.inkSecondary)
                }
                .padding(LifecoreLayout.spacing12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LifecoreTheme.paperWell)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                ForEach(viewModel.candidateMemories) { memory in
                    candidateRow(memory)
                }
            }
        }
    }

    private func candidateRow(_ memory: AthleteMemoryEntity) -> some View {
        VStack(alignment: .leading, spacing: LifecoreLayout.spacing8) {
            HStack {
                Text(categoryTitle(memory.category))
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(LifecoreTheme.statusWarning.opacity(0.12))
                    .foregroundStyle(LifecoreTheme.statusWarning)
                    .clipShape(Capsule())

                Spacer()

                Text("Кандидат")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(LifecoreTheme.inkTertiary)
            }

            Text(memory.factTextUk)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LifecoreTheme.inkPrimary)
                .lineSpacing(2)

            HStack(spacing: 10) {
                Button(action: {
                    withAnimation {
                        viewModel.confirmMemory(id: memory.id)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                        Text("Підтвердити")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(LifecoreTheme.statusOptimal)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("btn_confirm_memory_\(memory.id.uuidString)")

                Button(action: {
                    withAnimation {
                        viewModel.deleteMemory(id: memory.id)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                        Text("Відхилити")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(LifecoreTheme.paperWell)
                    .foregroundStyle(LifecoreTheme.inkSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("btn_delete_memory_\(memory.id.uuidString)")
            }
            .padding(.top, 2)
        }
        .padding(LifecoreLayout.spacing12)
        .background(LifecoreTheme.paperCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(LifecoreTheme.statusWarning.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Confirmed Section

    private var confirmedSection: some View {
        VStack(alignment: .leading, spacing: LifecoreLayout.spacing12) {
            HStack {
                Text("Підтверджена пам'ять")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(LifecoreTheme.inkPrimary)

                Spacer()

                Text("\(viewModel.confirmedMemories.count)")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(LifecoreTheme.paperWell)
                    .foregroundStyle(LifecoreTheme.inkTertiary)
                    .clipShape(Capsule())
            }

            if viewModel.confirmedMemories.isEmpty {
                HStack(spacing: LifecoreLayout.spacing8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(LifecoreTheme.inkTertiary)
                    Text("Підтверджених фактів ще немає. Поділіться з тренером своїми цілями чи історією травм у чаті.")
                        .font(.system(size: 12))
                        .foregroundStyle(LifecoreTheme.inkSecondary)
                }
                .padding(LifecoreLayout.spacing12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LifecoreTheme.paperWell)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                ForEach(viewModel.confirmedMemories) { memory in
                    confirmedRow(memory)
                }
            }
        }
    }

    private func confirmedRow(_ memory: AthleteMemoryEntity) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: memory.isPinnedGoal ? "star.fill" : "circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(memory.isPinnedGoal ? LifecoreTheme.statusWarning : LifecoreTheme.accentPrimary)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(memory.factTextUk)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(LifecoreTheme.inkPrimary)
                    .lineSpacing(2)

                HStack(spacing: 6) {
                    Text(categoryTitle(memory.category))
                        .font(.system(size: 10))
                        .foregroundStyle(LifecoreTheme.inkTertiary)
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundStyle(LifecoreTheme.inkTertiary)
                    Text(formatDate(memory.createdAt))
                        .font(.system(size: 10))
                        .foregroundStyle(LifecoreTheme.inkTertiary)
                }
            }

            Spacer()

            Button(action: {
                withAnimation {
                    viewModel.deleteMemory(id: memory.id)
                }
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(LifecoreTheme.inkTertiary)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("btn_remove_memory_\(memory.id.uuidString)")
        }
        .padding(LifecoreLayout.spacing12)
        .background(LifecoreTheme.paperCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(LifecoreTheme.ruleHairline, lineWidth: 1)
        )
    }

    // MARK: - Settings Hint Card

    private var settingsHintCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "gearshape")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(LifecoreTheme.accentIndigo)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text("Керування в Налаштуваннях")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(LifecoreTheme.inkPrimary)
                Text("Повне налаштування ключів API, очищення контексту та конфіденційності доступні у вкладці Налаштування → Пам’ять тренера.")
                    .font(.system(size: 11))
                    .foregroundStyle(LifecoreTheme.inkSecondary)
                    .lineSpacing(2)
            }
        }
        .padding(LifecoreLayout.spacing12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LifecoreTheme.paperWell)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Helpers

    private func categoryTitle(_ category: String) -> String {
        switch category {
        case "goal": return "Ціль"
        case "injury_note": return "Травма / Біль"
        case "nutrition_habit": return "Харчова звичка"
        case "workout_feel": return "Відчуття"
        case "coach_insight": return "Інсайт тренера"
        default: return "Нотатка"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk_UA")
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}
