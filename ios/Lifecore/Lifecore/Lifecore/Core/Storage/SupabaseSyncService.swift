import Foundation
import SwiftData

// MARK: - Supabase Cloud Synchronization Service

public final class SupabaseSyncService: @unchecked Sendable {
    public static let shared = SupabaseSyncService()
    public static var networkRequestAttemptCount: Int = 0

    public var supabaseURL = AppConfiguration.supabaseURL
    public var supabaseKey = AppConfiguration.supabaseAnonKey
    public var userId: Int64 = 472025574

    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private init() {}

    @MainActor
    private func configureCoordinator() {
        let effectiveUserId = AccountSessionManager.shared.verifiedLegacyUserId ?? userId
        let transport = URLSessionCloudSyncTransport(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )
        SyncCoordinator.shared.updateTransport(transport, userId: effectiveUserId)
    }

    // MARK: - Meals Synchronization

    /// Uploads unsynced meals via `SyncCoordinator` and `CloudDTOs`, respecting revisions and outbox serialization.
    @MainActor
    public func syncPendingMeals() async throws -> Int {
        guard !AppEnvironment.current.isFixtureMode else { return 0 }
        Self.networkRequestAttemptCount += 1
        configureCoordinator()

        try? SyncCoordinator.shared.enqueueMissingUnsyncedMeals()
        let result = await SyncCoordinator.shared.flushOutbox()
        return countSucceeded(entityType: .meal, from: result)
    }

    // MARK: - Workout Analyses Synchronization

    /// Uploads unsynced workout analyses via `SyncCoordinator` and `WorkoutAnalysisCloudDTO`.
    @MainActor
    public func syncPendingWorkoutAnalyses() async throws -> Int {
        guard !AppEnvironment.current.isFixtureMode else { return 0 }
        Self.networkRequestAttemptCount += 1
        configureCoordinator()

        try? SyncCoordinator.shared.enqueueMissingUnsyncedWorkouts()
        let result = await SyncCoordinator.shared.flushOutbox()
        return countSucceeded(entityType: .workout, from: result)
    }

    // MARK: - Health Telemetry Synchronization (Daily Metrics & Sleep)

    /// Direct upload of daily biometrics (steps, active calories, sleep stages) to Supabase tables.
    public func syncTelemetry(
        dailyActivity: DailyActivity? = nil,
        sleep: SleepLog? = nil,
        workout: WorkoutLog? = nil,
        pureNEATKcal: Double? = nil
    ) async throws {
        guard !AppEnvironment.current.isFixtureMode else { return }
        Self.networkRequestAttemptCount += 1

        // 1. Sync daily activity to daily_metrics
        if let act = dailyActivity {
            var payload: [String: Any] = [
                "user_id": userId,
                "metric_date": act.date,
                "steps": act.steps,
                "active_kcal": act.activeKcal,
                "distance_km": act.distanceKm,
                "created_at": isoFormatter.string(from: Date())
            ]
            if let neat = pureNEATKcal {
                payload["neat_kcal"] = neat
            } else if let w = workout {
                let neat = max(0.0, act.activeKcal - (w.activeCalories ?? 0.0))
                payload["neat_kcal"] = neat
            }
            if let t = act.trimpScore { payload["trimp_score"] = t }
            if let a = act.ewmaAcuteLoad { payload["ewma_acute_load"] = a }
            if let c = act.ewmaChronicLoad { payload["ewma_chronic_load"] = c }
            if let r = act.acwrRatio { payload["acwr_ratio"] = r }
            if let w = act.bodyBatteryWake { payload["body_battery_wake"] = w }
            if let m = act.bodyBatteryMin { payload["body_battery_min"] = m }

            var components = URLComponents(url: supabaseURL.appendingPathComponent("rest/v1/daily_metrics"), resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name: "on_conflict", value: "user_id,metric_date")]
            if let url = components.url {
                try await sendPostRequest(url: url, payload: payload)
            }
        }

        // 2. Sync sleep log
        if let s = sleep {
            var payload: [String: Any] = [
                "user_id": userId,
                "sleep_date": s.sleepDate,
                "total_hours": s.totalHours,
                "deep_hours": s.deepHours,
                "rem_hours": s.remHours,
                "core_hours": s.coreHours,
                "awake_hours": s.awakeHours,
                "source": "apple_health",
                "created_at": isoFormatter.string(from: Date())
            ]
            if let hrv = s.hrvAvgMs { payload["hrv_avg_ms"] = hrv }
            if let rhr = s.rhrBpm { payload["rhr_bpm"] = rhr }
            if let rmssd = s.hrvRmssdMs { payload["hrv_rmssd_ms"] = rmssd }
            if let temp = s.wristTempDeltaC { payload["wrist_temp_delta_c"] = temp }
            if let spo2 = s.spo2Pct { payload["spo2_pct"] = spo2 }
            if let rr = s.respiratoryRate { payload["respiratory_rate"] = rr }
            if let eff = s.sleepEfficiencyPct { payload["sleep_efficiency_pct"] = eff }
            if let im = s.immuneState { payload["immune_state"] = im }

            var components = URLComponents(url: supabaseURL.appendingPathComponent("rest/v1/sleep_logs"), resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name: "on_conflict", value: "user_id,sleep_date")]
            if let url = components.url {
                try await sendPostRequest(url: url, payload: payload)
            }
        }
    }

    private func sendPostRequest(url: URL, payload: [String: Any]) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")

        if let userToken = try AccountSessionManager.currentAccessTokenIfValid() {
            request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudSyncTransportError.serverError(statusCode: 500, message: "Non-HTTP response on \(url.path)")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown"
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
            throw CloudSyncTransportError.fromHTTPStatus(
                httpResponse.statusCode,
                message: body,
                retryAfterSeconds: retryAfter
            )
        }
    }

    // MARK: - Two-Way Paginated Cloud Hydration

    /// Pulls all paginated meals and workout analyses from Supabase via `SyncCoordinator`,
    /// preserving unsynced local edits and working on both empty and non-empty local stores.
    @MainActor
    public func pullHistoricalDataIfNeeded() async {
        guard !AppEnvironment.current.isFixtureMode else { return }
        Self.networkRequestAttemptCount += 1
        configureCoordinator()

        _ = await SyncCoordinator.shared.pullIncrementalAll(since: nil, pageSize: 50)
    }

    // MARK: - Unified Sync

    @MainActor
    public func syncAllWithResult() async -> SyncResult {
        if AccountSessionManager.shared.isTokenExpired {
            return SyncResult(
                errorClassification: .unauthorized,
                isCleanSuccess: false
            )
        }
        guard !AppEnvironment.current.isFixtureMode else { return SyncResult() }
        Self.networkRequestAttemptCount += 1
        configureCoordinator()

        try? SyncCoordinator.shared.enqueueMissingUnsyncedMeals()
        try? SyncCoordinator.shared.enqueueMissingUnsyncedWorkouts()
        return await SyncCoordinator.shared.flushOutbox()
    }

    @MainActor
    public func syncAll() async -> (mealsSynced: Int, analysesSynced: Int) {
        let result = await syncAllWithResult()
        return (
            mealsSynced: countSucceeded(entityType: .meal, from: result),
            analysesSynced: countSucceeded(entityType: .workout, from: result)
        )
    }

    @MainActor
    private func countSucceeded(entityType: SyncEntityType, from result: SyncResult) -> Int {
        guard !result.succeededOperationIDs.isEmpty else { return 0 }
        let succeededSet = Set(result.succeededOperationIDs)
        let ops = (try? SyncOutbox.shared.fetchAllOperations()) ?? []
        return ops.filter { succeededSet.contains($0.operationID) && $0.parsedEntityType == entityType }.count
    }
}
