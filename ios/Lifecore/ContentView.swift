import SwiftUI
import HealthKit

struct ContentView: View {
    @State private var isSyncing = false
    @State private var syncStatus: String = "Ready to sync"
    @State private var syncSuccess: Bool? = nil
    
    @State private var dailyActivity: DailyActivity?
    @State private var sleepLog: SleepLog?
    @State private var workoutLog: WorkoutLog?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Status Card
                    statusCard
                    
                    // Recovery & Sleep Card
                    sleepRecoveryCard
                    
                    // Daily NEAT Card
                    dailyActivityCard
                    
                    // Workout Card
                    if let workout = workoutLog {
                        workoutCard(workout)
                    }
                    
                    // Sync Button
                    syncButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(red: 0.05, green: 0.06, blue: 0.08).ignoresSafeArea())
            .navigationTitle("Lifecore")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        Task { await loadLocalTelemetry() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.cyan)
                    }
                }
            }
            .task {
                await requestAuthAndLoad()
            }
        }
    }

    // MARK: - Components
    private var statusCard: some View {
        HStack {
            Circle()
                .fill(syncSuccess == true ? Color.green : (syncSuccess == false ? Color.red : Color.cyan))
                .frame(width: 10, height: 10)
            Text(syncStatus)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Text("Apple Watch Ultra")
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 0.1, green: 0.11, blue: 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var sleepRecoveryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Sleep & Recovery", systemImage: "moon.stars.fill")
                .font(.headline)
                .foregroundStyle(.indigo)

            if let sleep = sleepLog {
                HStack(spacing: 20) {
                    metricItem(title: "Total Sleep", value: String(format: "%.1f h", sleep.totalHours))
                    metricItem(title: "Deep", value: String(format: "%.1f h", sleep.deepHours))
                    metricItem(title: "REM", value: String(format: "%.1f h", sleep.remHours))
                }

                Divider().background(Color.white.opacity(0.1))

                HStack(spacing: 20) {
                    if let hrv = sleep.hrvAvgMs {
                        metricItem(title: "HRV (SDNN)", value: String(format: "%.0f ms", hrv), highlight: hrv >= 70 ? .green : .orange)
                    }
                    if let rhr = sleep.rhrBpm {
                        metricItem(title: "Resting HR", value: String(format: "%.0f bpm", rhr), highlight: rhr <= 55 ? .green : .primary)
                    }
                    metricItem(title: "Core Sleep", value: String(format: "%.1f h", sleep.coreHours))
                }
            } else {
                Text("No sleep data available for last night.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(Color(red: 0.1, green: 0.11, blue: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var dailyActivityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Today's NEAT Activity", systemImage: "flame.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            if let act = dailyActivity {
                HStack(spacing: 20) {
                    metricItem(title: "Steps", value: "\(act.steps)")
                    metricItem(title: "Active Kcal", value: "\(Int(act.activeKcal))")
                    metricItem(title: "Distance", value: String(format: "%.1f km", act.distanceKm))
                }
            } else {
                Text("Reading activity metrics...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(Color(red: 0.1, green: 0.11, blue: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func workoutCard(_ workout: WorkoutLog) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Latest Workout", systemImage: "figure.run")
                .font(.headline)
                .foregroundStyle(.green)

            HStack(spacing: 20) {
                metricItem(title: "Type", value: workout.type.capitalized)
                metricItem(title: "Duration", value: String(format: "%.0f min", workout.durationMin))
                if let dist = workout.distanceKm {
                    metricItem(title: "Distance", value: String(format: "%.2f km", dist))
                }
                if let kcal = workout.activeCalories {
                    metricItem(title: "Burned", value: "\(Int(kcal)) kcal")
                }
            }
        }
        .padding(18)
        .background(Color(red: 0.1, green: 0.11, blue: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var syncButton: some View {
        Button(action: {
            Task { await syncWithSupabase() }
        }) {
            HStack(spacing: 10) {
                if isSyncing {
                    ProgressView()
                        .tint(.black)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Sync to Lifecore Warehouse")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.cyan)
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.cyan.opacity(0.3), radius: 10, y: 5)
        }
        .disabled(isSyncing)
        .padding(.top, 10)
    }

    private func metricItem(title: String, value: String, highlight: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(highlight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions
    private func requestAuthAndLoad() async {
        do {
            try await HealthKitManager.shared.requestAuthorization()
            await loadLocalTelemetry()
        } catch {
            syncStatus = "HealthKit permission needed"
            syncSuccess = false
        }
    }

    private func loadLocalTelemetry() async {
        async let act = try? HealthKitManager.shared.fetchDailyActivity()
        async let sleep = try? HealthKitManager.shared.fetchLastNightSleep()
        async let workout = try? HealthKitManager.shared.fetchLatestWorkoutToday()

        self.dailyActivity = await act
        self.sleepLog = await sleep
        self.workoutLog = await workout
        self.syncStatus = "Telemetry refreshed locally"
    }

    private func syncWithSupabase() async {
        isSyncing = true
        syncStatus = "Syncing with Supabase..."
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.prepare()

        do {
            let response = try await LifecoreAPIService.shared.syncTelemetry(
                dailyActivity: dailyActivity,
                sleep: sleepLog,
                workout: workoutLog
            )

            if response.ok {
                syncStatus = "✅ Successfully synced to Lifecore"
                syncSuccess = true
                impact.impactOccurred()
            } else {
                syncStatus = "⚠️ Server warning"
                syncSuccess = false
            }
        } catch {
            syncStatus = "⚠️ Error: \(error.localizedDescription)"
            syncSuccess = false
        }
        isSyncing = false
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
