import AppIntents
import Foundation

// MARK: - LifecoreSyncOutcome

public struct LifecoreSyncOutcome: Equatable, Sendable {
    public let dialog: String
    public let isCleanSync: Bool
    public let isQueuedOffline: Bool
    public let isAuthError: Bool
    public let isHealthKitError: Bool

    public init(
        dialog: String,
        isCleanSync: Bool = false,
        isQueuedOffline: Bool = false,
        isAuthError: Bool = false,
        isHealthKitError: Bool = false
    ) {
        self.dialog = dialog
        self.isCleanSync = isCleanSync
        self.isQueuedOffline = isQueuedOffline
        self.isAuthError = isAuthError
        self.isHealthKitError = isHealthKitError
    }
}

// MARK: - LifecoreSyncIntentHandler (Injectable Coordinator)

@MainActor
public enum LifecoreSyncIntentHandler {
    public static func handle(
        healthProvider: (any HealthDataProvider)? = nil,
        syncService: SupabaseSyncService = .shared,
        syncRunner: (@MainActor () async -> SyncResult)? = nil
    ) async -> LifecoreSyncOutcome {
        let health = healthProvider ?? AppEnvironment.current.healthProvider

        // 1. Ensure HealthKit permissions
        do {
            try await health.requestAuthorization()
        } catch {
            return LifecoreSyncOutcome(
                dialog: "⚠️ Помилка доступу до Apple Health: \(error.localizedDescription)",
                isCleanSync: false,
                isQueuedOffline: false,
                isAuthError: false,
                isHealthKitError: true
            )
        }

        // 2. Query HealthKit asynchronously if live
        let dailyActivity: DailyActivity?
        let sleepLog: SleepLog?
        let workout: WorkoutLog?

        if !health.isMock {
            let hk = HealthKitManager.shared
            async let dailyActivityTask = try? hk.fetchDailyActivity()
            async let sleepLogTask = try? hk.fetchLastNightSleep()
            async let workoutTask = try? hk.fetchLatestWorkoutToday()

            dailyActivity = await dailyActivityTask
            sleepLog = await sleepLogTask
            workout = await workoutTask
        } else {
            dailyActivity = nil
            sleepLog = nil
            workout = nil
        }

        // 3. Best-effort push of daily telemetry
        if syncRunner == nil {
            try? await syncService.syncTelemetry(
                dailyActivity: dailyActivity,
                sleep: sleepLog,
                workout: workout
            )
        }

        // 4. Sync outbox queue and evaluate result
        let syncResult = if let syncRunner {
            await syncRunner()
        } else {
            await syncService.syncAllWithResult()
        }

        if syncResult.errorClassification == .unauthorized {
            return LifecoreSyncOutcome(
                dialog: "⚠️ Необхідно увійти в обліковий запис Lifecore для синхронізації.",
                isCleanSync: false,
                isQueuedOffline: false,
                isAuthError: true,
                isHealthKitError: false
            )
        }

        if syncResult.errorClassification == .networkUnavailable || !syncResult.pendingOperationIDs.isEmpty {
            return LifecoreSyncOutcome(
                dialog: "⏳ Зміни збережено в черзі Lifecore (очікують мережі)...",
                isCleanSync: false,
                isQueuedOffline: true,
                isAuthError: false,
                isHealthKitError: false
            )
        }

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
        let succeededCount = syncResult.succeededOperationIDs.count
        if succeededCount > 0 {
            summary += " | ☁️ +\(succeededCount) операцій"
        } else if sleepLog == nil && dailyActivity == nil {
            summary += " усі дані актуальні."
        }

        return LifecoreSyncOutcome(
            dialog: summary,
            isCleanSync: true,
            isQueuedOffline: false,
            isAuthError: false,
            isHealthKitError: false
        )
    }
}

// MARK: - LifecoreSyncIntent

public struct LifecoreSyncIntent: AppIntent {
    public static var title: LocalizedStringResource = "Sync Lifecore Health"
    public static var description = IntentDescription("Reads Apple Watch sleep stages, recovery biomarkers, and daily activity, syncing them directly to the Lifecore warehouse.")

    public static var openAppWhenRun: Bool = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let outcome = await LifecoreSyncIntentHandler.handle()
        return .result(dialog: IntentDialog(stringLiteral: outcome.dialog))
    }
}

// MARK: - Shortcuts Provider

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
