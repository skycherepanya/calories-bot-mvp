import AppIntents
import Foundation

public struct LifecoreSyncIntent: AppIntent {
    public static var title: LocalizedStringResource = "Sync Lifecore Health"
    public static var description = IntentDescription("Reads Apple Watch sleep stages, recovery biomarkers, and daily activity, syncing them directly to the Lifecore warehouse.")
    
    // Background execution without bringing app to foreground
    public static var openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let health = HealthKitManager.shared
        let api = LifecoreAPIService.shared

        // 1. Ensure permissions
        do {
            try await health.requestAuthorization()
        } catch {
            return .result(dialog: "⚠️ HealthKit authorization failed: \(error.localizedDescription)")
        }

        // 2. Query HealthKit asynchronously
        async let dailyActivityTask = try? health.fetchDailyActivity()
        async let sleepLogTask = try? health.fetchLastNightSleep()
        async let workoutTask = try? health.fetchLatestWorkoutToday()

        let dailyActivity = await dailyActivityTask
        let sleepLog = await sleepLogTask
        let workout = await workoutTask

        // 3. Send payload to Supabase
        do {
            let response = try await api.syncTelemetry(
                dailyActivity: dailyActivity,
                sleep: sleepLog,
                workout: workout
            )

            guard response.ok else {
                return .result(dialog: "⚠️ Lifecore sync completed with server warnings.")
            }

            var summary = "✅ Lifecore Synced:"
            if let sleep = sleepLog {
                summary += " 😴 \(sleep.totalHours)h (Deep: \(sleep.deepHours)h)"
                if let hrv = sleep.hrvAvgMs {
                    summary += " | HRV: \(hrv)ms"
                }
            }
            if let act = dailyActivity {
                summary += " | 👟 \(act.steps) steps (\(act.activeKcal) kcal)"
            }
            if let w = workout {
                summary += " | 🏃 \(w.type) (\(w.durationMin) min)"
            }

            return .result(dialog: IntentDialog(stringLiteral: summary))
        } catch {
            return .result(dialog: "⚠️ Failed to sync with Lifecore: \(error.localizedDescription)")
        }
    }
}

// Extension to register Shortcuts provider in iOS 16+ / 17 / 18 / 27
public struct LifecoreShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LifecoreSyncIntent(),
            phrases: [
                "Sync \(.applicationName)",
                "Sync Lifecore",
                "Log my health in \(.applicationName)"
            ],
            shortTitle: "Sync Health",
            systemImageName: "heart.text.square.fill"
        )
    }
}
