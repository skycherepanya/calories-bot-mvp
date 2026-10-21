import AppIntents
import Foundation

public struct LifecoreSyncIntent: AppIntent {
    public static var title: LocalizedStringResource = "Sync Lifecore Health"
    public static var description = IntentDescription("Reads Apple Watch sleep stages, recovery biomarkers, and daily activity, syncing them directly to the Lifecore warehouse.")
    
    // Background execution without bringing app to foreground
    public static var openAppWhenRun: Bool = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let health = HealthKitManager.shared

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
            try await SupabaseSyncService.shared.syncTelemetry(
                dailyActivity: dailyActivity,
                sleep: sleepLog,
                workout: workout
            )
            let (meals, analyses) = await SupabaseSyncService.shared.syncAll()

            var summary = "✅ Lifecore синхронізовано:"
            if let sleep = sleepLog {
                summary += " 😴 \(sleep.totalHours)г (Deep: \(sleep.deepHours)г)"
                if let hrv = sleep.hrvAvgMs {
                    summary += " | HRV: \(Int(hrv))ms"
                }
            }
            if let act = dailyActivity {
                summary += " | 👟 \(act.steps) кроків"
            }
            if meals > 0 || analyses > 0 {
                summary += " | ☁️ +\(meals) страв, +\(analyses) тренувань"
            }

            return .result(dialog: IntentDialog(stringLiteral: summary))
        } catch {
            return .result(dialog: "⚠️ Помилка синхронізації з Lifecore: \(error.localizedDescription)")
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
                "Sync with \(.applicationName)",
                "Синхронізувати \(.applicationName)"
            ],
            shortTitle: "Sync Health",
            systemImageName: "heart.text.square.fill"
        )
        AppShortcut(
            intent: LogMealIntent(),
            phrases: [
                "Log meal in \(.applicationName)",
                "Записати їжу в \(.applicationName)",
                "Додати страву в \(.applicationName)"
            ],
            shortTitle: "Log Meal",
            systemImageName: "fork.knife"
        )
    }
}
