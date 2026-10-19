import SwiftUI
import HealthKit

public struct TodayView: View {
    @State private var snapshot: TodaySnapshot?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isSyncingWithCloud = false
    @State private var cloudSyncMessage: String?

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Top Readiness & Strain Rings
                    ringsHeaderView

                    // 2. Recovery & Autonomic Biomarkers Card
                    autonomicCard

                    // 3. Sleep Architecture Breakdown Card
                    sleepArchitectureCard

                    // 4. Daily Movement & Pure NEAT Isolation Card
                    activityAndNeatCard

                    // 5. Today's Workouts Card
                    todayWorkoutsCard

                    // 6. Cloud Sync Action
                    cloudSyncSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(red: 0.05, green: 0.06, blue: 0.08).ignoresSafeArea())
            .navigationTitle("Today")
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
            .task {
                await loadData(forceRefresh: false)
            }
        }
    }

    // MARK: - 1. Top Rings Area (Bevel Aesthetic)

    private var ringsHeaderView: some View {
        HStack(spacing: 14) {
            // Readiness Ring
            let recoveryScore = snapshot?.recovery.score ?? 85
            let recoveryColor: Color = recoveryScore >= 80 ? Color(red: 0.0, green: 0.9, blue: 0.45) :
                                       (recoveryScore >= 60 ? Color.orange : Color(red: 1.0, green: 0.3, blue: 0.3))
            BevelRingView(
                title: "Readiness",
                value: "\(recoveryScore)%",
                subtitle: snapshot?.recovery.state.rawValue.replacingOccurrences(of: "_", with: " ").capitalized ?? "Optimal",
                progress: Double(recoveryScore) / 100.0,
                ringColor: recoveryColor
            )

            // Strain Ring
            let strain21 = snapshot?.strain.whoopScale21 ?? 11.2
            let strainPercent = (snapshot?.strain.score100 ?? 53.0) / 100.0
            BevelRingView(
                title: "Day Strain",
                value: String(format: "%.1f", strain21),
                subtitle: "Scale 0-21",
                progress: strainPercent,
                ringColor: Color(red: 0.0, green: 0.85, blue: 1.0)
            )

            // Nutrition / Energy Balance Ring
            let burnedKcal = (snapshot?.dailyActivity.activeKcal ?? 850.0) + 1750.0 // BMR ~1750
            let targetKcal = 2400.0 // Example target
            let balanceRatio = min(1.2, burnedKcal / targetKcal)
            BevelRingView(
                title: "Burned",
                value: "\(Int(burnedKcal))",
                subtitle: "Target: \(Int(targetKcal))",
                progress: balanceRatio,
                ringColor: Color(red: 1.0, green: 0.65, blue: 0.0)
            )
        }
        .padding(.vertical, 8)
    }

    // MARK: - 2. Autonomic Biomarkers Card

    private var autonomicCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Autonomic Recovery", systemImage: "waveform.path.ecg")
                    .font(.headline)
                    .foregroundStyle(.cyan)
                Spacer()
                if let z = snapshot?.recovery.hrvZScore {
                    Text(String(format: "Z: %+.1f", z))
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                // HRV SDNN
                let hrv = snapshot?.sleepLog.hrvAvgMs ?? snapshot?.baseline.avgHrvSDNN ?? 102.0
                let baselineHrv = snapshot?.baseline.avgHrvSDNN ?? 102.0
                let hrvDelta = hrv - baselineHrv
                biomarkerItem(
                    title: "Morning HRV",
                    value: String(format: "%.0f ms", hrv),
                    delta: String(format: "%+.0f vs 30d", hrvDelta),
                    isPositive: hrvDelta >= -5.0
                )

                // Resting HR
                let rhr = snapshot?.sleepLog.rhrBpm ?? snapshot?.baseline.avgRHR ?? 49.0
                let baselineRhr = snapshot?.baseline.avgRHR ?? 49.0
                let rhrDelta = rhr - baselineRhr
                biomarkerItem(
                    title: "Resting HR",
                    value: String(format: "%.0f bpm", rhr),
                    delta: String(format: "%+.0f vs 30d", rhrDelta),
                    isPositive: rhrDelta <= 3.0 // <= +3 bpm is normal adaptation
                )
            }

            if let narrative = snapshot?.recovery.narrative {
                Divider().background(Color.white.opacity(0.1))
                Text(narrative)
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.8))
                    .lineSpacing(3)
            }
        }
        .padding(18)
        .background(Color(red: 0.09, green: 0.10, blue: 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - 3. Sleep Architecture Breakdown Card

    private var sleepArchitectureCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Sleep Architecture", systemImage: "moon.fill")
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.6, green: 0.45, blue: 1.0))
                Spacer()
                let total = snapshot?.sleepLog.totalHours ?? 7.5
                Text(String(format: "%.1f hours", total))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }

            // Sleep phase segments
            let deep = snapshot?.sleepLog.deepHours ?? 1.3
            let rem = snapshot?.sleepLog.remHours ?? 1.6
            let core = snapshot?.sleepLog.coreHours ?? 4.2
            let awake = snapshot?.sleepLog.awakeHours ?? 0.4

            HStack(spacing: 8) {
                sleepBar(label: "Deep", hours: deep, targetHours: 1.2, color: Color(red: 0.35, green: 0.35, blue: 0.95))
                sleepBar(label: "REM", hours: rem, targetHours: 1.5, color: Color(red: 0.7, green: 0.35, blue: 0.95))
                sleepBar(label: "Core", hours: core, targetHours: 4.0, color: Color(red: 0.3, green: 0.7, blue: 0.95))
                sleepBar(label: "Awake", hours: awake, targetHours: nil, color: Color.gray.opacity(0.6))
            }

            HStack {
                Text(deep >= 1.2 ? "✅ Optimal Deep Sleep (cellular repair)" : "⚠️ Low Deep Sleep (<1.2h)")
                    .font(.caption2)
                    .foregroundStyle(deep >= 1.2 ? .green : .orange)
                Spacer()
                Text(rem >= 1.5 ? "✅ High REM (neural recovery)" : "⚡ REM: \(String(format: "%.1f", rem))h")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(Color(red: 0.09, green: 0.10, blue: 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - 4. Activity & Pure NEAT Card

    private var activityAndNeatCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Movement & Pure NEAT", systemImage: "flame.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            let act = snapshot?.dailyActivity
            let neat = snapshot?.pureNEATKcal ?? 450.0
            let workoutKcal = snapshot?.strain.workoutKcal ?? 0.0

            HStack(spacing: 16) {
                metricCell(title: "Steps", value: "\(act?.steps ?? 8450)")
                metricCell(title: "Active Kcal", value: "\(Int(act?.activeKcal ?? 850))")
                metricCell(title: "Distance", value: String(format: "%.1f km", act?.distanceKm ?? 6.2))
            }

            Divider().background(Color.white.opacity(0.1))

            // NEAT Isolation Breakdown
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Pure NEAT (Lifestyle)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(neat)) kcal")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                }

                HStack {
                    Text("Structured Workouts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(workoutKcal)) kcal")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                }

                Text("Apple Health total energy includes workouts. Pure NEAT is isolated to prevent double-counting.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(18)
        .background(Color(red: 0.09, green: 0.10, blue: 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - 5. Today's Workouts Section

    private var todayWorkoutsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Today's Sessions", systemImage: "figure.run")
                .font(.headline)
                .foregroundStyle(.green)

            let workouts = snapshot?.workouts ?? []
            if workouts.isEmpty {
                HStack {
                    Text("No structured workouts logged today.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 4)
            } else {
                ForEach(workouts, id: \.startedAt) { w in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(w.type.capitalized)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            Text("\(Int(w.durationMin)) min\(w.distanceKm != nil ? String(format: " • %.2f km", w.distanceKm!) : "")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let kcal = w.activeCalories {
                            Text("\(Int(kcal)) kcal")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(18)
        .background(Color(red: 0.09, green: 0.10, blue: 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - 6. Cloud Sync Action

    private var cloudSyncSection: some View {
        VStack(spacing: 8) {
            Button(action: {
                Task { await syncWithCloud() }
            }) {
                HStack(spacing: 8) {
                    if isSyncingWithCloud {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Sync Snapshot to Warehouse")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.cyan)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isSyncingWithCloud)

            if let message = cloudSyncMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Reusable UI Helper Builders

    private func biomarkerItem(title: String, value: String, delta: String, isPositive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Text(delta)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(isPositive ? .green : .orange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricCell(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sleepBar(label: String, hours: Double, targetHours: Double?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(String(format: "%.1fh", hours))
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 5)
                Capsule()
                    .fill(color)
                    .frame(width: max(4, min(60, CGFloat(hours / 4.0) * 60)), height: 5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Logic & Live Data Fetching

    private func loadData(forceRefresh: Bool) async {
        isLoading = true
        errorMessage = nil

        let manager = HealthKitManager.shared
        if manager.isAvailable {
            do {
                try await manager.requestAuthorization()
                let liveSnapshot = try await manager.fetchTodaySnapshot()
                self.snapshot = liveSnapshot
            } catch {
                self.errorMessage = error.localizedDescription
                // Fallback to Sasha's physiological baseline snapshot if HealthKit throws
                loadFallbackSnapshot()
            }
        } else {
            loadFallbackSnapshot()
        }

        isLoading = false
    }

    private func loadFallbackSnapshot() {
        let baseline = ReadinessCalculator.Baseline.sasha
        let sleep = SleepLog(
            sleepDate: "2026-10-19",
            totalHours: 7.8,
            deepHours: 1.4,
            remHours: 1.6,
            coreHours: 4.3,
            awakeHours: 0.5,
            hrvAvgMs: 104.0,
            rhrBpm: 48.0
        )
        let activity = DailyActivity(
            date: "2026-10-19",
            steps: 9240,
            activeKcal: 865.0,
            distanceKm: 6.8
        )
        let recovery = ReadinessCalculator.computeRecovery(
            morningHrv: 104.0,
            morningRhr: 48.0,
            totalSleepHours: 7.8,
            deepSleepHours: 1.4,
            remSleepHours: 1.6,
            baseline: baseline
        )
        let strain = ReadinessCalculator.computeStrain(
            dailyActiveKcal: 865.0,
            workouts: []
        )
        let neat = ReadinessCalculator.isolatePureNEAT(dailyActiveKcal: 865.0, workoutActiveKcals: [])

        self.snapshot = TodaySnapshot(
            dailyActivity: activity,
            sleepLog: sleep,
            workouts: [],
            baseline: baseline,
            recovery: recovery,
            strain: strain,
            pureNEATKcal: neat
        )
    }

    private func syncWithCloud() async {
        guard let snap = snapshot else { return }
        isSyncingWithCloud = true
        cloudSyncMessage = "Syncing..."

        do {
            let response = try await LifecoreAPIService.shared.syncTelemetry(
                dailyActivity: snap.dailyActivity,
                sleep: snap.sleepLog,
                workout: snap.workouts.first
            )
            if response.ok {
                cloudSyncMessage = "✅ Successfully saved to Lifecore cloud"
            } else {
                cloudSyncMessage = "⚠️ Completed with warnings"
            }
        } catch {
            cloudSyncMessage = "⚠️ Sync error: \(error.localizedDescription)"
        }

        isSyncingWithCloud = false
    }
}

// MARK: - Bevel Ring Component

public struct BevelRingView: View {
    public let title: String
    public let value: String
    public let subtitle: String
    public let progress: Double
    public let ringColor: Color

    public init(
        title: String,
        value: String,
        subtitle: String,
        progress: Double,
        ringColor: Color
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.progress = progress
        self.ringColor = ringColor
    }

    public var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background Track
                Circle()
                    .stroke(ringColor.opacity(0.18), lineWidth: 8)

                // Animated Progress Ring
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(1.0, max(0.02, progress))))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [ringColor.opacity(0.7), ringColor]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                // Center Value
                VStack(spacing: 2) {
                    Text(value)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(title)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 88, height: 88)

            Text(subtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(red: 0.09, green: 0.10, blue: 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

#Preview {
    TodayView()
        .preferredColorScheme(.dark)
}
