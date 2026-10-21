import Foundation
import SwiftData

// MARK: - Supabase Cloud Synchronization Service

public final class SupabaseSyncService: @unchecked Sendable {
    public static let shared = SupabaseSyncService()

    public var supabaseURL = URL(string: "https://khmviccwbuktnvdxhnwg.supabase.co")!
    public var supabaseKey = "sb_publishable_kf0wGKz9z9VpZiu_hQe0xQ_6WTvrpXy"
    public var userId: Int64 = 472025574

    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private init() {}

    // MARK: - Meals Synchronization

    /// Uploads unsynced meals to Supabase `meals` table and updates local `syncedToCloud` flag.
    @MainActor
    public func syncPendingMeals() async throws -> Int {
        let unsynced = MealStorageService.shared.fetchUnsyncedMeals()
        guard !unsynced.isEmpty else { return 0 }

        var syncedCount = 0

        for meal in unsynced {
            var payload: [String: Any] = [
                "user_id": userId,
                "meal_name": meal.name,
                "kcal": meal.kcal,
                "protein": meal.proteinG,
                "fat": meal.fatG,
                "carbs": meal.carbsG,
                "tags": meal.tags,
                "dietary_date": meal.dietaryDate,
                "created_at": isoFormatter.string(from: meal.createdAt)
            ]
            if let w = meal.weightG { payload["weight_g"] = w }
            if let c = meal.confidence { payload["confidence"] = c }

            if let microJson = meal.micronutrientsJson,
               let data = microJson.data(using: .utf8),
               let microObj = try? JSONSerialization.jsonObject(with: data) {
                payload["micronutrients"] = microObj
            }
            if let aminoJson = meal.aminoAcidsJson,
               let data = aminoJson.data(using: .utf8),
               let aminoObj = try? JSONSerialization.jsonObject(with: data) {
                payload["amino_acids"] = aminoObj
            }

            let endpoint = supabaseURL.appendingPathComponent("rest/v1/meals")
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? "Unknown"
                print("⚠️ Supabase meal upload failed: \(body)")
                continue
            }

            // Extract remote ID if returned
            if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let first = array.first,
               let remoteId = first["id"] as? Int64 {
                MealStorageService.shared.markMealSynced(id: meal.id, remoteId: remoteId)
            } else {
                meal.syncedToCloud = true
                try? LifecoreDataStore.shared.context.save()
            }
            syncedCount += 1
        }

        return syncedCount
    }

    // MARK: - Workout Analyses Synchronization

    /// Uploads unsynced workout analyses to Supabase `workout_analyses` table with upsert resolution.
    @MainActor
    public func syncPendingWorkoutAnalyses() async throws -> Int {
        let unsynced = WorkoutStorageService.fetchUnsyncedAnalyses()
        guard !unsynced.isEmpty else { return 0 }

        var syncedCount = 0

        for analysis in unsynced {
            let splitsData = analysis.splitsJson.data(using: .utf8) ?? Data("[]".utf8)
            let lapsData = analysis.lapsJson.data(using: .utf8) ?? Data("[]".utf8)
            let splitsObj = (try? JSONSerialization.jsonObject(with: splitsData)) ?? []
            let lapsObj = (try? JSONSerialization.jsonObject(with: lapsData)) ?? []

            var payload: [String: Any] = [
                "user_id": userId,
                "healthkit_workout_uuid": analysis.workoutUUID.uuidString,
                "workout_type": analysis.workoutType,
                "started_at": isoFormatter.string(from: analysis.startedAt),
                "distance_km": round((analysis.distanceMeters / 1000.0) * 100) / 100,
                "duration_min": round((analysis.durationSeconds / 60.0) * 10) / 10,
                "splits_json": splitsObj,
                "laps_json": lapsObj,
                "created_at": isoFormatter.string(from: analysis.createdAt),
                "updated_at": isoFormatter.string(from: analysis.updatedAt)
            ]

            if let pace = analysis.avgPaceSecPerKm { payload["avg_pace_min_km"] = round((pace / 60.0) * 100) / 100 }
            if let hr = analysis.avgHeartRate { payload["avg_hr"] = hr }
            if let maxHr = analysis.maxHeartRate { payload["max_hr"] = maxHr }
            if let elev = analysis.elevationGainMeters { payload["elevation_gain_m"] = elev }
            if let ef = analysis.efficiencyFactor { payload["efficiency_factor"] = round(ef * 1000) / 1000 }
            if let drift = analysis.cardiacDriftPercentage { payload["aerobic_decoupling_pct"] = round(drift * 10) / 10 }
            if let report = analysis.aiCoachReport { payload["ai_coach_report"] = report }

            var components = URLComponents(url: supabaseURL.appendingPathComponent("rest/v1/workout_analyses"), resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "on_conflict", value: "healthkit_workout_uuid")
            ]

            guard let url = components.url else { continue }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
            request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? "Unknown"
                print("⚠️ Supabase workout_analyses upload failed: \(body)")
                continue
            }

            WorkoutStorageService.markAnalysisSynced(workoutUUID: analysis.workoutUUID)
            syncedCount += 1
        }

        return syncedCount
    }

    // MARK: - Health Telemetry Synchronization (Daily Metrics & Sleep)

    /// Direct upload of daily biometrics (steps, active calories, sleep stages) to Supabase tables.
    public func syncTelemetry(
        dailyActivity: DailyActivity? = nil,
        sleep: SleepLog? = nil,
        workout: WorkoutLog? = nil
    ) async throws {
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
            if let w = workout {
                let neat = max(0.0, act.activeKcal - (w.activeCalories ?? 0.0))
                payload["neat_kcal"] = neat
            }

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
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown"
            print("⚠️ Supabase sync error on \(url.path): \(body)")
            return
        }
    }

    // MARK: - Unified Sync

    @MainActor
    public func syncAll() async -> (mealsSynced: Int, analysesSynced: Int) {
        let meals = (try? await syncPendingMeals()) ?? 0
        let analyses = (try? await syncPendingWorkoutAnalyses()) ?? 0
        return (meals, analyses)
    }
}
