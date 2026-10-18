import Foundation

public final class LifecoreAPIService: @unchecked Sendable {
    public static let shared = LifecoreAPIService()

    // Configured with production Supabase Edge Function endpoint
    public var endpointURL = URL(string: "https://khmviccwbuktnvdxhnwg.supabase.co/functions/v1/ingest-health")!
    public var secret = "3c021bc09943639b6e1abd58f90a6434208093169e70875f"
    public var userId = 472025574

    private init() {}

    public func syncTelemetry(
        dailyActivity: DailyActivity? = nil,
        sleep: SleepLog? = nil,
        workout: WorkoutLog? = nil
    ) async throws -> IngestResponse {
        let payload = HealthPayload(
            secret: secret,
            userId: userId,
            dailyActivity: dailyActivity,
            sleep: sleep,
            workout: workout
        )

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(IngestResponse.self, from: data)
    }
}

public enum APIError: Error, LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid HTTP response received from server."
        case .serverError(let statusCode, let message):
            return "Server returned error \(statusCode): \(message)"
        }
    }
}
