import SwiftUI
import HealthKit

public struct TrendsView: View {
    @State private var selectedRange: TrendsTimeRange = .days30
    @State private var weightPoints: [TrendWeightPoint] = []
    @State private var autonomicSamples: [DateAutonomicSample] = []
    @State private var efSamples: [AerobicEfficiencyTrendSample] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Time Range Selector
                    TrendsRangePickerView(selectedRange: $selectedRange)
                        .padding(.top, 4)

                    if isLoading && weightPoints.isEmpty {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.cyan)
                            Text("Завантаження фізіологічних трендів...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        // 2. Card 1: Body Weight Trend & Water Noise Filter
                        WeightTrendCard(points: weightPoints)

                        // 3. Card 2: Autonomic Stability & Baselines Corridor
                        AutonomicTrendCard(samples: autonomicSamples)

                        // 4. Card 3: Aerobic Efficiency & Cardiac Drift
                        AerobicEfficiencyTrendCard(samples: efSamples)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(red: 0.05, green: 0.06, blue: 0.08).ignoresSafeArea())
            .navigationTitle("Trends")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        Task { await loadData(forceRefresh: true) }
                    }) {
                        if isLoading {
                            ProgressView()
                                .tint(.cyan)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(.cyan)
                        }
                    }
                }
            }
            .refreshable {
                await loadData(forceRefresh: true)
            }
            .task(id: selectedRange) {
                await loadData(forceRefresh: false)
            }
        }
    }

    // MARK: - Data Pipeline

    private func loadData(forceRefresh: Bool) async {
        if isLoading { return }
        isLoading = true
        errorMessage = nil

        let days = selectedRange.rawValue

        async let weightSamplesTask = HealthKitManager.shared.fetchBodyWeightHistory(days: days)
        async let autonomicTask = HealthKitManager.shared.fetchAutonomicLongitudinalHistory(days: days)
        async let efTask = HealthKitManager.shared.fetchAerobicEfficiencyHistory(limit: max(10, days / 4))

        let (rawWeightSamples, fetchedAutonomic, fetchedEf) = await (weightSamplesTask, autonomicTask, efTask)

        // Compute 7d and 14d rolling averages and water retention spike flags in Swift Math Engine
        let computedPoints = ReadinessCalculator.computeLongitudinalWeightTrend(samples: rawWeightSamples)

        withAnimation(.easeInOut(duration: 0.25)) {
            self.weightPoints = computedPoints
            self.autonomicSamples = fetchedAutonomic
            self.efSamples = fetchedEf
            self.isLoading = false
        }
    }
}

#Preview {
    TrendsView()
        .preferredColorScheme(.dark)
}
