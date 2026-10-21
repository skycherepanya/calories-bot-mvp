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
        workout: WorkoutLog? = nil,
        pureNEATKcal: Double? = nil
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

    // MARK: - Two-Way Cloud Hydration

    /// Pulls historical meals and workout analyses from Supabase if local SwiftData store is empty
    @MainActor
    public func pullHistoricalDataIfNeeded() async {
        let existingMeals = MealStorageService.shared.fetchAllMeals()
        if existingMeals.isEmpty {
            await pullHistoricalMeals()
        }

        let existingAnalyses = WorkoutStorageService.fetchAllAnalyses()
        if existingAnalyses.isEmpty {
            await pullHistoricalWorkoutAnalyses()
        }
    }

    @MainActor
    private func pullHistoricalMeals() async {
        guard var components = URLComponents(url: supabaseURL.appendingPathComponent("rest/v1/meals"), resolvingAgainstBaseURL: false) else { return }
        components.queryItems = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "order", value: "created_at.desc"),
            URLQueryItem(name: "limit", value: "60")
        ]
        guard let url = components.url else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode),
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return
        }

        for item in jsonArray {
            guard let name = item["meal_name"] as? String,
                  let kcal = item["kcal"] as? Double,
                  let protein = item["protein"] as? Double,
                  let fat = item["fat"] as? Double,
                  let carbs = item["carbs"] as? Double,
                  let dietaryDate = item["dietary_date"] as? String else { continue }

            let tags = (item["tags"] as? [String]) ?? []
            let weight = item["weight_g"] as? Double
            let remoteId = item["id"] as? Int64

            let createdAt: Date
            if let dateStr = item["created_at"] as? String, let parsed = isoFormatter.date(from: dateStr) {
                createdAt = parsed
            } else {
                createdAt = Date()
            }

            let record = MealRecord(
                name: name,
                kcal: kcal,
                proteinG: protein,
                fatG: fat,
                carbsG: carbs,
                weightG: weight,
                tags: tags,
                dietaryDate: dietaryDate,
                createdAt: createdAt,
                isOptimisticPending: false
            )
            MealStorageService.shared.insertHydratedMeal(record, syncedToCloud: true, remoteId: remoteId)
        }
    }

    @MainActor
    private func pullHistoricalWorkoutAnalyses() async {
        guard var components = URLComponents(url: supabaseURL.appendingPathComponent("rest/v1/workout_analyses"), resolvingAgainstBaseURL: false) else { return }
        components.queryItems = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "order", value: "started_at.desc"),
            URLQueryItem(name: "limit", value: "30")
        ]
        guard let url = components.url else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode),
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return
        }

        for item in jsonArray {
            guard let uuidStr = item["workout_uuid"] as? String,
                  let workoutUUID = UUID(uuidString: uuidStr),
                  let workoutType = item["workout_type"] as? String,
                  let duration = item["duration_seconds"] as? Double else { continue }

            let distance = item["distance_meters"] as? Double
            let avgHr = item["avg_heart_rate"] as? Double
            let maxHr = item["max_heart_rate"] as? Double
            let ef = item["efficiency_factor"] as? Double
            let drift = item["cardiac_drift_pct"] as? Double
            let coachReport = item["ai_coach_report"] as? String

            let splitsJson: String = {
                if let splitsObj = item["splits"], let data = try? JSONSerialization.data(withJSONObject: splitsObj) {
                    return String(data: data, encoding: .utf8) ?? "[]"
                }
                return "[]"
            }()

            let lapsJson: String = {
                if let lapsObj = item["laps"], let data = try? JSONSerialization.data(withJSONObject: lapsObj) {
                    return String(data: data, encoding: .utf8) ?? "[]"
                }
                return "[]"
            }()

            let startedAt: Date
            if let dateStr = item["started_at"] as? String, let parsed = isoFormatter.date(from: dateStr) {
                startedAt = parsed
            } else {
                startedAt = Date()
            }

            WorkoutStorageService.insertHydratedAnalysis(
                workoutUUID: workoutUUID,
                workoutType: workoutType,
                startedAt: startedAt,
                distanceMeters: distance,
                durationSeconds: duration,
                avgHeartRate: avgHr,
                maxHeartRate: maxHr,
                efficiencyFactor: ef,
                cardiacDriftPct: drift,
                splitsJson: splitsJson,
                lapsJson: lapsJson,
                aiCoachReport: coachReport,
                syncedToCloud: true
            )
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
