import SwiftUI

public struct CoachReportView: View {
    public let analysis: WorkoutAnalysisResult
    public let recoveryContext: RecentRecoveryContext?

    @State private var reportText: String?
    @State private var isLoading = false
    @State private var errorMessage: String?

    public init(
        analysis: WorkoutAnalysisResult,
        recoveryContext: RecentRecoveryContext? = nil
    ) {
        self.analysis = analysis
        self.recoveryContext = recoveryContext
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Label("AI Тренер", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Spacer()

                Text("Lifecore Coach")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.2))
                    .foregroundStyle(.purple)
                    .clipShape(Capsule())
            }

            if let report = reportText {
                // Formatted Report Sections
                VStack(alignment: .leading, spacing: 14) {
                    Text(LocalizedStringKey(report))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.92))
                        .lineSpacing(5)
                }
                .padding(.vertical, 4)

                // Refresh Button
                Button(action: {
                    Task { await generateReport() }
                }) {
                    HStack(spacing: 6) {
                        if isLoading {
                            ProgressView().tint(.cyan)
                        } else {
                            Image(systemName: "arrow.clockwise")
                            Text("Оновити пораду тренера")
                        }
                    }
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.cyan)
                }
                .disabled(isLoading)
                .padding(.top, 4)

            } else {
                // Initial CTA Card
                VStack(spacing: 12) {
                    Text("Персональний розбір пробіжки простою мовою: як ти розклав сили, твій прогрес до минулих тренувань та практична порада на сьогодні й завтра.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)

                    if let err = errorMessage {
                        Text(err)
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }

                    Button(action: {
                        Task { await generateReport() }
                    }) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .tint(.black)
                                Text("Аналізую телеметрію...")
                                    .fontWeight(.bold)
                            } else {
                                Image(systemName: "brain.head.profile")
                                Text("Отримати аналіз тренера")
                                    .fontWeight(.bold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [.cyan, Color(red: 0.0, green: 0.7, blue: 0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Color.cyan.opacity(0.3), radius: 8, y: 3)
                    }
                    .disabled(isLoading)
                }
            }
        }
        .padding(18)
        .background(Color(red: 0.1, green: 0.11, blue: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func generateReport() async {
        isLoading = true
        errorMessage = nil

        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.prepare()

        do {
            let result = try await GeminiService.shared.generateCoachReport(
                analysis: analysis,
                recoveryContext: recoveryContext
            )
            self.reportText = result
            impact.impactOccurred()
        } catch {
            // If API call fails, use deterministic sports analyst offline fallback
            self.reportText = GeminiService.shared.generateOfflineReport(
                analysis: analysis,
                recoveryContext: recoveryContext
            )
            impact.impactOccurred()
        }

        isLoading = false
    }
}
