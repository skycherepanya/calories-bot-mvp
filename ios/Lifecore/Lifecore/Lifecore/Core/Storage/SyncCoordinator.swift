import Foundation
import SwiftData

// MARK: - Transport Protocols & Errors

public enum CloudSyncTransportError: Error, Sendable, Equatable {
    case networkUnavailable(String)
    case unauthorized(statusCode: Int, message: String)
    case conflict(remoteRevision: Int?, remotePayloadJson: String?)
    case rateLimited(retryAfterSeconds: Int?, message: String)
    case serverError(statusCode: Int, message: String)
    case badRequest(statusCode: Int, message: String)

    public var classification: SyncErrorClassification {
        switch self {
        case .networkUnavailable: return .networkUnavailable
        case .unauthorized: return .unauthorized
        case .conflict: return .conflict
        case .rateLimited: return .rateLimited
        case .serverError: return .serverError
        case .badRequest: return .badRequest
        }
    }

    public static func classify(_ error: Error) -> CloudSyncTransportError {
        if let transportError = error as? CloudSyncTransportError {
            return transportError
        }
        if let urlError = error as? URLError {
            return .networkUnavailable(urlError.localizedDescription)
        }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return .networkUnavailable(nsError.localizedDescription)
        }
        return .serverError(statusCode: 500, message: error.localizedDescription)
    }

    public static func fromHTTPStatus(
        _ statusCode: Int,
        message: String = "",
        retryAfterSeconds: Int? = nil
    ) -> CloudSyncTransportError {
        switch statusCode {
        case 401, 403:
            return .unauthorized(statusCode: statusCode, message: message)
        case 409:
            return .conflict(remoteRevision: nil, remotePayloadJson: message.isEmpty ? nil : message)
        case 429:
            return .rateLimited(retryAfterSeconds: retryAfterSeconds, message: message)
        case 400, 404, 422:
            return .badRequest(statusCode: statusCode, message: message)
        default:
            return .serverError(statusCode: statusCode, message: message)
        }
    }
}

public protocol CloudSyncTransport: Sendable {
    func pushMeal(_ dto: MealCloudDTO, expectedServerRevision: Int?) async throws -> MealCloudDTO
    func pushWorkoutAnalysis(_ dto: WorkoutAnalysisCloudDTO, expectedServerRevision: Int?) async throws -> WorkoutAnalysisCloudDTO
    func fetchMealsPage(userId: Int64, since: Date?, cursor: String?, limit: Int) async throws -> CloudPage<MealCloudDTO>
    func fetchWorkoutAnalysesPage(userId: Int64, since: Date?, cursor: String?, limit: Int) async throws -> CloudPage<WorkoutAnalysisCloudDTO>
}

public protocol HealthKitMealExportTransport: Sendable {
    func exportMeal(
        clientUUID: UUID,
        name: String,
        kcal: Double,
        proteinG: Double,
        fatG: Double,
        carbsG: Double,
        sodiumMg: Double?,
        fiberG: Double?,
        date: Date
    ) async throws

    func deleteMeal(clientUUID: UUID) async throws
}

// MARK: - Live HealthKit Export Transport

public struct LiveHealthKitMealExportTransport: HealthKitMealExportTransport {
    public init() {}

    public func exportMeal(
        clientUUID: UUID,
        name: String,
        kcal: Double,
        proteinG: Double,
        fatG: Double,
        carbsG: Double,
        sodiumMg: Double?,
        fiberG: Double?,
        date: Date
    ) async throws {
        guard !AppEnvironment.current.isFixtureMode else { return }
        try await HealthKitManager.shared.saveMealToHealthKit(
            name: name,
            kcal: kcal,
            proteinG: proteinG,
            fatG: fatG,
            carbsG: carbsG,
            sodiumMg: sodiumMg,
            fiberG: fiberG,
            date: date,
            mealId: clientUUID
        )
    }

    public func deleteMeal(clientUUID: UUID) async throws {
        guard !AppEnvironment.current.isFixtureMode else { return }
        try await HealthKitManager.shared.deleteMealFromHealthKit(mealId: clientUUID)
    }
}

// MARK: - URLSession Supabase REST Transport

public final class URLSessionCloudSyncTransport: CloudSyncTransport, @unchecked Sendable {
    public let supabaseURL: URL
    public let supabaseKey: String
    private let session: URLSession

    public init(
        supabaseURL: URL,
        supabaseKey: String,
        session: URLSession = .shared
    ) {
        self.supabaseURL = supabaseURL
        self.supabaseKey = supabaseKey
        self.session = session
    }

    public func pushMeal(_ dto: MealCloudDTO, expectedServerRevision: Int?) async throws -> MealCloudDTO {
        let writePayload = dto.strippingServerIDForWrite()
        let bodyData = try CloudJSONCoding.makeEncoder().encode(writePayload)

        if let expectedRevision = expectedServerRevision {
            var components = URLComponents(
                url: supabaseURL.appendingPathComponent("rest/v1/meals"),
                resolvingAgainstBaseURL: false
            )!
            var queryItems = [URLQueryItem(name: "user_id", value: "eq.\(dto.userId)")]
            if let clientUUID = dto.clientUUID {
                queryItems.append(URLQueryItem(name: "client_uuid", value: "eq.\(clientUUID.uuidString)"))
            } else if let remoteId = dto.id {
                queryItems.append(URLQueryItem(name: "id", value: "eq.\(remoteId)"))
            }
            queryItems.append(URLQueryItem(name: "revision", value: "eq.\(expectedRevision)"))
            components.queryItems = queryItems

            guard let url = components.url else {
                throw CloudSyncTransportError.badRequest(statusCode: 400, message: "Invalid meals PATCH URL")
            }

            var request = makeAuthorizedRequest(url: url, method: "PATCH")
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
            request.httpBody = bodyData

            let (data, httpResponse) = try await performDataRequest(request)
            if httpResponse.statusCode == 409 {
                if let existingRemote = await fetchRemoteMealDTO(
                    userId: dto.userId,
                    clientUUID: dto.clientUUID,
                    remoteId: dto.id
                ) {
                    // Idempotent recovery: if an initial POST succeeded remotely before we received its response
                    // and the server row is still at our sent revision, adopt the remote row instead of flagging a conflict.
                    if existingRemote.clientUUID == dto.clientUUID && existingRemote.revision == dto.revision {
                        return existingRemote
                    }
                    throw CloudSyncTransportError.conflict(
                        remoteRevision: existingRemote.revision,
                        remotePayloadJson: CloudJSONCoding.encodeToString(existingRemote)
                    )
                }
                throw CloudSyncTransportError.conflict(remoteRevision: nil, remotePayloadJson: nil)
            }
            try validateStatusCode(httpResponse, data: data)

            let decoded = try CloudJSONCoding.makeDecoder().decode([MealCloudDTO].self, from: data)
            if let updated = decoded.first {
                return updated
            }
            // Empty representation on PATCH with revision=eq.<expected> indicates CAS revision mismatch.
            let remote = await fetchRemoteMealSnapshot(userId: dto.userId, clientUUID: dto.clientUUID, remoteId: dto.id)
            throw CloudSyncTransportError.conflict(remoteRevision: remote.revision, remotePayloadJson: remote.payloadJson)
        } else {
            let url = supabaseURL.appendingPathComponent("rest/v1/meals")
            var request = makeAuthorizedRequest(url: url, method: "POST")
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
            request.httpBody = bodyData

            let (data, httpResponse) = try await performDataRequest(request)
            if httpResponse.statusCode == 409 {
                if let existingRemote = await fetchRemoteMealDTO(
                    userId: dto.userId,
                    clientUUID: dto.clientUUID,
                    remoteId: dto.id
                ) {
                    // Idempotent recovery: if an initial POST succeeded remotely before we received its response
                    // and the server row is still at our sent revision, adopt the remote row instead of flagging a conflict.
                    if existingRemote.clientUUID == dto.clientUUID && existingRemote.revision == dto.revision {
                        return existingRemote
                    }
                    throw CloudSyncTransportError.conflict(
                        remoteRevision: existingRemote.revision,
                        remotePayloadJson: CloudJSONCoding.encodeToString(existingRemote)
                    )
                }
                throw CloudSyncTransportError.conflict(remoteRevision: nil, remotePayloadJson: nil)
            }
            try validateStatusCode(httpResponse, data: data)

            let decoded = try CloudJSONCoding.makeDecoder().decode([MealCloudDTO].self, from: data)
            return decoded.first ?? dto
        }
    }

    public func pushWorkoutAnalysis(_ dto: WorkoutAnalysisCloudDTO, expectedServerRevision: Int?) async throws -> WorkoutAnalysisCloudDTO {
        let bodyData = try CloudJSONCoding.makeEncoder().encode(dto)

        if let expectedRevision = expectedServerRevision {
            var components = URLComponents(
                url: supabaseURL.appendingPathComponent("rest/v1/workout_analyses"),
                resolvingAgainstBaseURL: false
            )!
            components.queryItems = [
                URLQueryItem(name: "healthkit_workout_uuid", value: "eq.\(dto.healthkitWorkoutUUID.uuidString)"),
                URLQueryItem(name: "revision", value: "eq.\(expectedRevision)")
            ]
            guard let url = components.url else {
                throw CloudSyncTransportError.badRequest(statusCode: 400, message: "Invalid workout_analyses PATCH URL")
            }

            var request = makeAuthorizedRequest(url: url, method: "PATCH")
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
            request.httpBody = bodyData

            let (data, httpResponse) = try await performDataRequest(request)
            if httpResponse.statusCode == 409 {
                let remote = await fetchRemoteWorkoutSnapshot(healthkitWorkoutUUID: dto.healthkitWorkoutUUID)
                throw CloudSyncTransportError.conflict(remoteRevision: remote.revision, remotePayloadJson: remote.payloadJson)
            }
            try validateStatusCode(httpResponse, data: data)

            let decoded = try CloudJSONCoding.makeDecoder().decode([WorkoutAnalysisCloudDTO].self, from: data)
            if let updated = decoded.first {
                return updated
            }
            let remote = await fetchRemoteWorkoutSnapshot(healthkitWorkoutUUID: dto.healthkitWorkoutUUID)
            throw CloudSyncTransportError.conflict(remoteRevision: remote.revision, remotePayloadJson: remote.payloadJson)
        } else {
            var components = URLComponents(
                url: supabaseURL.appendingPathComponent("rest/v1/workout_analyses"),
                resolvingAgainstBaseURL: false
            )!
            components.queryItems = [
                URLQueryItem(name: "on_conflict", value: "healthkit_workout_uuid")
            ]
            guard let url = components.url else {
                throw CloudSyncTransportError.badRequest(statusCode: 400, message: "Invalid workout_analyses POST URL")
            }

            var request = makeAuthorizedRequest(url: url, method: "POST")
            request.setValue("resolution=merge-duplicates,return=representation", forHTTPHeaderField: "Prefer")
            request.httpBody = bodyData

            let (data, httpResponse) = try await performDataRequest(request)
            if httpResponse.statusCode == 409 {
                let remote = await fetchRemoteWorkoutSnapshot(healthkitWorkoutUUID: dto.healthkitWorkoutUUID)
                throw CloudSyncTransportError.conflict(remoteRevision: remote.revision, remotePayloadJson: remote.payloadJson)
            }
            try validateStatusCode(httpResponse, data: data)

            let decoded = try CloudJSONCoding.makeDecoder().decode([WorkoutAnalysisCloudDTO].self, from: data)
            return decoded.first ?? dto
        }
    }

    public func fetchMealsPage(userId: Int64, since: Date?, cursor: String?, limit: Int) async throws -> CloudPage<MealCloudDTO> {
        let offset = max(0, Int(cursor ?? "0") ?? 0)
        let pageSize = max(1, limit)

        var components = URLComponents(
            url: supabaseURL.appendingPathComponent("rest/v1/meals"),
            resolvingAgainstBaseURL: false
        )!
        var queryItems = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "order", value: "updated_at.asc,id.asc"),
            URLQueryItem(name: "limit", value: "\(pageSize)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        if let since {
            let iso = since.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
            queryItems.append(URLQueryItem(name: "updated_at", value: "gte.\(iso)"))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw CloudSyncTransportError.badRequest(statusCode: 400, message: "Invalid meals GET URL")
        }

        let request = makeAuthorizedRequest(url: url, method: "GET")
        let (data, httpResponse) = try await performDataRequest(request)
        try validateStatusCode(httpResponse, data: data)

        let items = try CloudJSONCoding.makeDecoder().decode([MealCloudDTO].self, from: data)
        let hasMore = items.count == pageSize
        let nextCursor = hasMore ? String(offset + items.count) : nil
        return CloudPage(items: items, nextCursor: nextCursor, hasMore: hasMore)
    }

    public func fetchWorkoutAnalysesPage(userId: Int64, since: Date?, cursor: String?, limit: Int) async throws -> CloudPage<WorkoutAnalysisCloudDTO> {
        let offset = max(0, Int(cursor ?? "0") ?? 0)
        let pageSize = max(1, limit)

        var components = URLComponents(
            url: supabaseURL.appendingPathComponent("rest/v1/workout_analyses"),
            resolvingAgainstBaseURL: false
        )!
        var queryItems = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "order", value: "updated_at.asc,id.asc"),
            URLQueryItem(name: "limit", value: "\(pageSize)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        if let since {
            let iso = since.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
            queryItems.append(URLQueryItem(name: "updated_at", value: "gte.\(iso)"))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw CloudSyncTransportError.badRequest(statusCode: 400, message: "Invalid workout_analyses GET URL")
        }

        let request = makeAuthorizedRequest(url: url, method: "GET")
        let (data, httpResponse) = try await performDataRequest(request)
        try validateStatusCode(httpResponse, data: data)

        let items = try CloudJSONCoding.makeDecoder().decode([WorkoutAnalysisCloudDTO].self, from: data)
        let hasMore = items.count == pageSize
        let nextCursor = hasMore ? String(offset + items.count) : nil
        return CloudPage(items: items, nextCursor: nextCursor, hasMore: hasMore)
    }

    // MARK: - HTTP Helpers

    private func makeAuthorizedRequest(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func performDataRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw CloudSyncTransportError.networkUnavailable(urlError.localizedDescription)
        } catch {
            throw CloudSyncTransportError.networkUnavailable(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudSyncTransportError.serverError(statusCode: 500, message: "Non-HTTP response received")
        }
        return (data, httpResponse)
    }

    private func validateStatusCode(_ response: HTTPURLResponse, data: Data) throws {
        let code = response.statusCode
        guard !(200...299).contains(code) else { return }
        let body = String(data: data, encoding: .utf8) ?? ""

        switch code {
        case 401, 403:
            throw CloudSyncTransportError.unauthorized(statusCode: code, message: body)
        case 409:
            throw CloudSyncTransportError.conflict(remoteRevision: nil, remotePayloadJson: body.isEmpty ? nil : body)
        case 429:
            let retryAfter = response.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
            throw CloudSyncTransportError.rateLimited(retryAfterSeconds: retryAfter, message: body)
        case 400, 404, 422:
            throw CloudSyncTransportError.badRequest(statusCode: code, message: body)
        default:
            throw CloudSyncTransportError.serverError(statusCode: code, message: body)
        }
    }

    private func fetchRemoteMealDTO(userId: Int64, clientUUID: UUID?, remoteId: Int64?) async -> MealCloudDTO? {
        var components = URLComponents(
            url: supabaseURL.appendingPathComponent("rest/v1/meals"),
            resolvingAgainstBaseURL: false
        )!
        var queryItems = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "limit", value: "1")
        ]
        if let clientUUID {
            queryItems.append(URLQueryItem(name: "client_uuid", value: "eq.\(clientUUID.uuidString)"))
        } else if let remoteId {
            queryItems.append(URLQueryItem(name: "id", value: "eq.\(remoteId)"))
        } else {
            return nil
        }
        components.queryItems = queryItems
        guard let url = components.url else { return nil }

        let request = makeAuthorizedRequest(url: url, method: "GET")
        guard let (data, response) = try? await performDataRequest(request),
              (200...299).contains(response.statusCode),
              let items = try? CloudJSONCoding.makeDecoder().decode([MealCloudDTO].self, from: data) else {
            return nil
        }
        return items.first
    }

    private func fetchRemoteMealSnapshot(userId: Int64, clientUUID: UUID?, remoteId: Int64?) async -> (revision: Int?, payloadJson: String?) {
        guard let first = await fetchRemoteMealDTO(userId: userId, clientUUID: clientUUID, remoteId: remoteId) else {
            return (nil, nil)
        }
        return (first.revision, CloudJSONCoding.encodeToString(first))
    }

    private func fetchRemoteWorkoutSnapshot(healthkitWorkoutUUID: UUID) async -> (revision: Int?, payloadJson: String?) {
        var components = URLComponents(
            url: supabaseURL.appendingPathComponent("rest/v1/workout_analyses"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "healthkit_workout_uuid", value: "eq.\(healthkitWorkoutUUID.uuidString)"),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let url = components.url else { return (nil, nil) }

        let request = makeAuthorizedRequest(url: url, method: "GET")
        guard let (data, response) = try? await performDataRequest(request),
              (200...299).contains(response.statusCode),
              let items = try? CloudJSONCoding.makeDecoder().decode([WorkoutAnalysisCloudDTO].self, from: data),
              let first = items.first else {
            return (nil, nil)
        }
        return (first.revision, CloudJSONCoding.encodeToString(first))
    }
}

// MARK: - SyncCoordinator

@MainActor
public final class SyncCoordinator {
    public static let shared = SyncCoordinator(
        userId: SupabaseSyncService.shared.userId,
        transport: URLSessionCloudSyncTransport(
            supabaseURL: SupabaseSyncService.shared.supabaseURL,
            supabaseKey: SupabaseSyncService.shared.supabaseKey
        ),
        healthKitTransport: LiveHealthKitMealExportTransport()
    )

    public var userId: Int64
    private var transport: any CloudSyncTransport
    private let healthKitTransport: any HealthKitMealExportTransport
    private let outbox: SyncOutbox
    private let contextOverride: ModelContext?

    private var activeFlushTask: Task<SyncResult, Never>?
    private var activeHealthKitFlushTask: Task<SyncResult, Never>?

    public private(set) var recordedConflicts: [SyncConflictRecord] = []

    private var context: ModelContext {
        contextOverride ?? LifecoreDataStore.shared.context
    }

    public init(
        userId: Int64 = 472025574,
        transport: any CloudSyncTransport,
        healthKitTransport: any HealthKitMealExportTransport = LiveHealthKitMealExportTransport(),
        outbox: SyncOutbox = .shared,
        context: ModelContext? = nil
    ) {
        self.userId = userId
        self.transport = transport
        self.healthKitTransport = healthKitTransport
        self.outbox = outbox
        self.contextOverride = context
    }

    public func updateTransport(_ transport: any CloudSyncTransport, userId: Int64? = nil) {
        self.transport = transport
        if let userId {
            self.userId = userId
        }
    }

    // MARK: - Outbox Enqueue Helpers

    /// Ensures any unsynced `MealEntity` rows without an active cloud outbox operation are enqueued.
    public func enqueueMissingUnsyncedMeals() throws {
        let ctx = context
        let mealDescriptor = FetchDescriptor<MealEntity>(
            predicate: #Predicate { !$0.syncedToCloud && !$0.isOptimisticPending }
        )
        let unsyncedMeals = try ctx.fetch(mealDescriptor)
        guard !unsyncedMeals.isEmpty else { return }

        let existingOps = try outbox.fetchAllOperations(in: ctx).filter {
            $0.entityType == SyncEntityType.meal.rawValue
                && ($0.parsedStatus == .pending || $0.parsedStatus == .processing)
        }
        let activeMealIDs = Set(existingOps.map { $0.entityID })

        var insertedAny = false
        for meal in unsyncedMeals {
            if activeMealIDs.contains(meal.id) || activeMealIDs.contains(meal.clientUUID) {
                continue
            }
            let kind: SyncOperationKind = meal.isDeleted ? .delete : .upsert
            try outbox.enqueue(
                entityID: meal.id,
                entityType: SyncEntityType.meal.rawValue,
                operationKind: kind.rawValue,
                revision: meal.revision,
                payloadJson: MealSyncPayload(from: meal).toJsonString(),
                in: ctx
            )
            insertedAny = true
        }
        if insertedAny {
            try ctx.save()
        }
    }

    /// Ensures any unsynced `WorkoutAnalysisEntity` rows without an active cloud outbox operation are enqueued.
    public func enqueueMissingUnsyncedWorkouts() throws {
        let ctx = context
        let descriptor = FetchDescriptor<WorkoutAnalysisEntity>(
            predicate: #Predicate { !$0.syncedToCloud }
        )
        let unsyncedAnalyses = try ctx.fetch(descriptor)
        guard !unsyncedAnalyses.isEmpty else { return }

        let existingOps = try outbox.fetchAllOperations(in: ctx).filter {
            $0.entityType == SyncEntityType.workout.rawValue
                && ($0.parsedStatus == .pending || $0.parsedStatus == .processing)
        }
        let activeWorkoutIDs = Set(existingOps.map { $0.entityID })

        var insertedAny = false
        for analysis in unsyncedAnalyses {
            if activeWorkoutIDs.contains(analysis.workoutUUID) || activeWorkoutIDs.contains(analysis.id) {
                continue
            }
            let dto = WorkoutAnalysisCloudDTO(from: analysis, userId: userId, revision: analysis.revision)
            try outbox.enqueue(
                entityID: analysis.workoutUUID,
                entityType: SyncEntityType.workout.rawValue,
                operationKind: SyncOperationKind.upsert.rawValue,
                revision: dto.revision,
                payloadJson: CloudJSONCoding.encodeToString(dto),
                in: ctx
            )
            insertedAny = true
        }
        if insertedAny {
            try ctx.save()
        }
    }

    // MARK: - Serialized Outbox Flush

    /// Flushes currently pending cloud outbox operations in strict FIFO order.
    /// Concurrent callers coalesce onto the active in-flight flush task.
    @discardableResult
    public func flushOutbox() async -> SyncResult {
        if let activeTask = activeFlushTask {
            return await activeTask.value
        }

        let task = Task<SyncResult, Never> { @MainActor [weak self] in
            guard let self else { return SyncResult() }
            defer { self.activeFlushTask = nil }
            return await self.performFlushOutbox()
        }
        activeFlushTask = task
        return await task.value
    }

    private func performFlushOutbox() async -> SyncResult {
        let ctx = context
        let snapshotOps: [SyncOperationEntity]
        do {
            let pending = try outbox.fetchPendingOperations(in: ctx)
            snapshotOps = pending
                .filter {
                    $0.entityType == SyncEntityType.meal.rawValue
                        || $0.entityType == SyncEntityType.workout.rawValue
                }
                .sorted { lhs, rhs in
                    if lhs.createdAt != rhs.createdAt {
                        return lhs.createdAt < rhs.createdAt
                    }
                    return lhs.revision < rhs.revision
                }
        } catch {
            return SyncResult(errorClassification: .serverError, isCleanSuccess: false)
        }

        var succeededIDs: [UUID] = []
        var failedIDs: [UUID] = []
        var pendingIDs: [UUID] = []
        var conflicts: [SyncConflictRecord] = []
        var lastClassification: SyncErrorClassification = .none

        let snapshotIDSet = Set(snapshotOps.map { $0.operationID })

        for op in snapshotOps {
            guard op.parsedStatus == .pending else { continue }
            try? outbox.markProcessing(operationID: op.operationID, in: ctx)

            do {
                switch op.parsedEntityType {
                case .meal:
                    try await processMealOutboxOperation(op, in: ctx)
                case .workout:
                    try await processWorkoutOutboxOperation(op, in: ctx)
                case .healthkitMeal:
                    continue
                }
                try? outbox.markCompleted(operationID: op.operationID, in: ctx)
                succeededIDs.append(op.operationID)
            } catch {
                let transportError = CloudSyncTransportError.classify(error)
                let classification = transportError.classification
                lastClassification = classification

                switch transportError {
                case .conflict(let remoteRev, let remoteJson):
                    try? outbox.markFailed(operationID: op.operationID, in: ctx)
                    failedIDs.append(op.operationID)
                    let conflict = SyncConflictRecord(
                        entityID: op.entityID,
                        entityType: op.parsedEntityType,
                        localRevision: op.revision,
                        remoteRevision: remoteRev ?? op.revision,
                        localPayloadJson: op.payloadJson,
                        remotePayloadJson: remoteJson ?? "{}"
                    )
                    conflicts.append(conflict)
                    recordedConflicts.append(conflict)

                case .badRequest:
                    try? outbox.markFailed(operationID: op.operationID, in: ctx)
                    failedIDs.append(op.operationID)

                case .networkUnavailable, .unauthorized, .rateLimited, .serverError:
                    try? outbox.markRetryPending(operationID: op.operationID, in: ctx)
                    pendingIDs.append(op.operationID)
                }
            }
        }

        // Capture any newly enqueued cloud ops that arrived while the snapshot was flushing
        if let postFlushPending = try? outbox.fetchPendingOperations(in: ctx) {
            for op in postFlushPending where
                (op.entityType == SyncEntityType.meal.rawValue || op.entityType == SyncEntityType.workout.rawValue)
                && !snapshotIDSet.contains(op.operationID)
                && !pendingIDs.contains(op.operationID) {
                pendingIDs.append(op.operationID)
            }
        }

        let isClean = failedIDs.isEmpty && pendingIDs.isEmpty && conflicts.isEmpty && lastClassification == .none
        return SyncResult(
            succeededOperationIDs: succeededIDs,
            failedOperationIDs: failedIDs,
            pendingOperationIDs: pendingIDs,
            conflicts: conflicts,
            errorClassification: lastClassification,
            isCleanSuccess: isClean
        )
    }

    private func processMealOutboxOperation(_ op: SyncOperationEntity, in ctx: ModelContext) async throws {
        let localEntity = fetchMealEntity(matching: op.entityID, in: ctx)
        let dto = resolveMealCloudDTO(for: op, localEntity: localEntity)

        let hasServerRow = (localEntity?.remoteId != nil) || (dto.id != nil)
        let expectedServerRevision: Int? = (hasServerRow && op.revision > 1) ? (op.revision - 1) : nil

        let pushed = try await transport.pushMeal(dto, expectedServerRevision: expectedServerRevision)

        if let entity = localEntity {
            if let remoteId = pushed.id {
                entity.remoteId = remoteId
            }
            // Stale-ack guard: only mark synced when local revision still matches the acknowledged op revision.
            if entity.revision == op.revision {
                entity.syncedToCloud = true
            }
            try? ctx.save()
        }
    }

    private func processWorkoutOutboxOperation(_ op: SyncOperationEntity, in ctx: ModelContext) async throws {
        let localEntity = fetchWorkoutAnalysisEntity(matching: op.entityID, in: ctx)
        let dto = resolveWorkoutCloudDTO(for: op, localEntity: localEntity)

        let expectedServerRevision: Int? = (op.revision > 1) ? (op.revision - 1) : nil
        let pushed = try await transport.pushWorkoutAnalysis(dto, expectedServerRevision: expectedServerRevision)

        if let entity = localEntity {
            entity.revision = max(entity.revision, pushed.revision)
            let pendingForWorkout = (try? outbox.fetchPendingOperations(for: SyncEntityType.workout.rawValue, in: ctx)) ?? []
            let hasNewerPending = pendingForWorkout.contains {
                $0.operationID != op.operationID
                    && ($0.entityID == entity.workoutUUID || $0.entityID == entity.id)
                    && $0.revision > op.revision
            }
            if !hasNewerPending {
                entity.syncedToCloud = true
            }
            try? ctx.save()
        }
    }

    // MARK: - Paginated Incremental Cloud Pull

    /// Pulls all pages of meals and workout analyses from cloud without fixed 60/30 caps.
    /// Safe against non-empty local stores and never overwrites unsynced higher-revision local rows.
    @discardableResult
    public func pullIncrementalAll(since: Date? = nil, pageSize: Int = 50) async -> SyncPullResult {
        let ctx = context
        let effectivePageSize = max(1, pageSize)
        var pagesFetched = 0

        var pulledMeals: [MealCloudDTO] = []
        var mealCursor: String? = nil
        do {
            while true {
                let page = try await transport.fetchMealsPage(
                    userId: userId,
                    since: since,
                    cursor: mealCursor,
                    limit: effectivePageSize
                )
                pagesFetched += 1
                pulledMeals.append(contentsOf: page.items)
                if !page.hasMore || page.nextCursor == nil || page.nextCursor == mealCursor {
                    break
                }
                mealCursor = page.nextCursor
            }
        } catch {
            return SyncPullResult(
                mealsPulled: 0,
                workoutsPulled: 0,
                pagesFetched: pagesFetched,
                skippedLocalNewerCount: 0,
                errorClassification: CloudSyncTransportError.classify(error).classification
            )
        }

        var pulledWorkouts: [WorkoutAnalysisCloudDTO] = []
        var workoutCursor: String? = nil
        do {
            while true {
                let page = try await transport.fetchWorkoutAnalysesPage(
                    userId: userId,
                    since: since,
                    cursor: workoutCursor,
                    limit: effectivePageSize
                )
                pagesFetched += 1
                pulledWorkouts.append(contentsOf: page.items)
                if !page.hasMore || page.nextCursor == nil || page.nextCursor == workoutCursor {
                    break
                }
                workoutCursor = page.nextCursor
            }
        } catch {
            return SyncPullResult(
                mealsPulled: 0,
                workoutsPulled: 0,
                pagesFetched: pagesFetched,
                skippedLocalNewerCount: 0,
                errorClassification: CloudSyncTransportError.classify(error).classification
            )
        }

        // Merge meals into SwiftData
        var mealsMerged = 0
        var skippedLocalNewer = 0

        let existingMeals = (try? ctx.fetch(FetchDescriptor<MealEntity>())) ?? []
        var mealByClientUUID: [UUID: MealEntity] = [:]
        var mealByID: [UUID: MealEntity] = [:]
        var mealByRemoteID: [Int64: MealEntity] = [:]
        for entity in existingMeals {
            mealByClientUUID[entity.clientUUID] = entity
            mealByID[entity.id] = entity
            if let remoteId = entity.remoteId {
                mealByRemoteID[remoteId] = entity
            }
        }

        let activeOutboxOps = (try? outbox.fetchAllOperations(in: ctx)) ?? []
        let activeMealOpEntityIDs = Set(
            activeOutboxOps
                .filter {
                    $0.entityType == SyncEntityType.meal.rawValue
                        && ($0.parsedStatus == .pending || $0.parsedStatus == .processing || $0.parsedStatus == .failed)
                }
                .map { $0.entityID }
        )

        for dto in pulledMeals {
            let matched: MealEntity? = {
                if let cUUID = dto.clientUUID {
                    return mealByClientUUID[cUUID] ?? mealByID[cUUID]
                }
                if let rID = dto.id {
                    return mealByRemoteID[rID]
                }
                return nil
            }()

            if let existing = matched {
                let hasUnresolvedLocalOp = activeMealOpEntityIDs.contains(existing.id)
                    || activeMealOpEntityIDs.contains(existing.clientUUID)
                if !existing.syncedToCloud || hasUnresolvedLocalOp {
                    skippedLocalNewer += 1
                    continue
                }
                dto.apply(to: existing, syncedToCloud: true)
                mealByClientUUID[existing.clientUUID] = existing
                mealByID[existing.id] = existing
                if let rID = existing.remoteId {
                    mealByRemoteID[rID] = existing
                }
                mealsMerged += 1
            } else {
                let inserted = dto.toEntity(syncedToCloud: true)
                ctx.insert(inserted)
                mealByClientUUID[inserted.clientUUID] = inserted
                mealByID[inserted.id] = inserted
                if let rID = inserted.remoteId {
                    mealByRemoteID[rID] = inserted
                }
                mealsMerged += 1
            }
        }

        // Merge workout analyses into SwiftData
        var workoutsMerged = 0
        let existingWorkouts = (try? ctx.fetch(FetchDescriptor<WorkoutAnalysisEntity>())) ?? []
        var workoutByUUID: [UUID: WorkoutAnalysisEntity] = [:]
        for entity in existingWorkouts {
            workoutByUUID[entity.workoutUUID] = entity
        }
        let activeWorkoutOpIDs = Set(
            activeOutboxOps
                .filter {
                    $0.entityType == SyncEntityType.workout.rawValue
                        && ($0.parsedStatus == .pending || $0.parsedStatus == .processing || $0.parsedStatus == .failed)
                }
                .map { $0.entityID }
        )

        for dto in pulledWorkouts {
            if let existing = workoutByUUID[dto.healthkitWorkoutUUID] {
                let hasUnresolvedLocalEdit = activeWorkoutOpIDs.contains(existing.workoutUUID)
                    || activeWorkoutOpIDs.contains(existing.id)
                if !existing.syncedToCloud || hasUnresolvedLocalEdit {
                    skippedLocalNewer += 1
                    continue
                }
                dto.apply(to: existing, syncedToCloud: true)
                workoutsMerged += 1
            } else {
                let inserted = dto.toEntity(syncedToCloud: true)
                ctx.insert(inserted)
                workoutByUUID[inserted.workoutUUID] = inserted
                workoutsMerged += 1
            }
        }

        try? ctx.save()
        if contextOverride == nil || contextOverride === LifecoreDataStore.shared.context {
            MealStorageService.shared.loadMealsFromSwiftData()
        }
        if mealsMerged > 0 {
            NotificationCenter.default.post(name: .lifecoreMealDidMutate, object: nil)
        }
        if workoutsMerged > 0 {
            NotificationCenter.default.post(name: .lifecoreWorkoutDidMutate, object: nil)
        }

        return SyncPullResult(
            mealsPulled: mealsMerged,
            workoutsPulled: workoutsMerged,
            pagesFetched: pagesFetched,
            skippedLocalNewerCount: skippedLocalNewer,
            errorClassification: .none
        )
    }

    // MARK: - Serialized HealthKit Meal Export Queue

    @discardableResult
    public func enqueueHealthKitMealUpsert(
        meal: MealRecord,
        clientUUID: UUID? = nil,
        revision: Int = 1
    ) throws -> SyncOperationEntity {
        let resolvedUUID = clientUUID ?? meal.id
        let payload = HealthKitMealExportPayload(
            clientUUID: resolvedUUID,
            name: meal.name,
            kcal: meal.kcal,
            proteinG: meal.proteinG,
            fatG: meal.fatG,
            carbsG: meal.carbsG,
            sodiumMg: meal.micronutrients?.sodiumMg,
            fiberG: meal.micronutrients?.fiberG,
            date: meal.createdAt
        )
        return try outbox.enqueueHealthKitMealOperation(
            clientUUID: resolvedUUID,
            kind: .upsert,
            revision: revision,
            payloadJson: CloudJSONCoding.encodeToString(payload),
            in: context
        )
    }

    @discardableResult
    public func enqueueHealthKitMealDelete(
        clientUUID: UUID,
        revision: Int = 1
    ) throws -> SyncOperationEntity {
        try outbox.enqueueHealthKitMealOperation(
            clientUUID: clientUUID,
            kind: .delete,
            revision: revision,
            payloadJson: "{}",
            in: context
        )
    }

    /// Serially drains HealthKit meal export/delete operations in deterministic FIFO order.
    @discardableResult
    public func flushHealthKitMealExports() async -> SyncResult {
        if let activeTask = activeHealthKitFlushTask {
            return await activeTask.value
        }

        let task = Task<SyncResult, Never> { @MainActor [weak self] in
            guard let self else { return SyncResult() }
            defer { self.activeHealthKitFlushTask = nil }
            return await self.performFlushHealthKitMealExports()
        }
        activeHealthKitFlushTask = task
        return await task.value
    }

    private func performFlushHealthKitMealExports() async -> SyncResult {
        let ctx = context
        var succeededIDs: [UUID] = []
        var pendingIDs: [UUID] = []
        var attemptedFailedInPass: Set<UUID> = []
        var lastClassification: SyncErrorClassification = .none

        while true {
            let pendingOps: [SyncOperationEntity]
            do {
                pendingOps = try outbox.fetchPendingOperations(
                    for: SyncEntityType.healthkitMeal.rawValue,
                    in: ctx
                )
                .filter { !attemptedFailedInPass.contains($0.operationID) }
                .sorted { lhs, rhs in
                    if lhs.createdAt != rhs.createdAt {
                        return lhs.createdAt < rhs.createdAt
                    }
                    return lhs.revision < rhs.revision
                }
            } catch {
                lastClassification = .serverError
                break
            }

            guard let op = pendingOps.first else {
                break
            }

            try? outbox.markProcessing(operationID: op.operationID, in: ctx)

            do {
                if op.parsedKind == .delete {
                    try await healthKitTransport.deleteMeal(clientUUID: op.entityID)
                } else {
                    let payload = resolveHealthKitPayload(for: op, in: ctx)
                    try await healthKitTransport.exportMeal(
                        clientUUID: op.entityID,
                        name: payload.name,
                        kcal: payload.kcal,
                        proteinG: payload.proteinG,
                        fatG: payload.fatG,
                        carbsG: payload.carbsG,
                        sodiumMg: payload.sodiumMg,
                        fiberG: payload.fiberG,
                        date: payload.date
                    )
                }
                try? outbox.markCompleted(operationID: op.operationID, in: ctx)
                succeededIDs.append(op.operationID)
            } catch {
                try? outbox.markRetryPending(operationID: op.operationID, in: ctx)
                attemptedFailedInPass.insert(op.operationID)
                pendingIDs.append(op.operationID)
                lastClassification = .serverError
            }
        }

        let isClean = pendingIDs.isEmpty && lastClassification == .none
        return SyncResult(
            succeededOperationIDs: succeededIDs,
            failedOperationIDs: [],
            pendingOperationIDs: pendingIDs,
            conflicts: [],
            errorClassification: lastClassification,
            isCleanSuccess: isClean
        )
    }

    // MARK: - Resolution Helpers

    private func fetchMealEntity(matching entityID: UUID, in ctx: ModelContext) -> MealEntity? {
        let descriptor = FetchDescriptor<MealEntity>(
            predicate: #Predicate { $0.id == entityID || $0.clientUUID == entityID }
        )
        return (try? ctx.fetch(descriptor))?.first
    }

    private func fetchWorkoutAnalysisEntity(matching entityID: UUID, in ctx: ModelContext) -> WorkoutAnalysisEntity? {
        let descriptor = FetchDescriptor<WorkoutAnalysisEntity>(
            predicate: #Predicate { $0.workoutUUID == entityID || $0.id == entityID }
        )
        return (try? ctx.fetch(descriptor))?.first
    }

    private func resolveMealCloudDTO(for op: SyncOperationEntity, localEntity: MealEntity?) -> MealCloudDTO {
        if let data = op.payloadJson.data(using: .utf8) {
            let isoDecoder = JSONDecoder()
            isoDecoder.dateDecodingStrategy = .iso8601
            if let syncPayload = try? isoDecoder.decode(MealSyncPayload.self, from: data) {
                var dto = MealCloudDTO(from: syncPayload, userId: userId)
                if dto.id == nil, let remoteId = localEntity?.remoteId {
                    dto = MealCloudDTO(
                        id: remoteId,
                        userId: dto.userId,
                        clientUUID: dto.clientUUID,
                        mealName: dto.mealName,
                        kcal: dto.kcal,
                        kcalExact: dto.kcalExact,
                        bufferVersion: dto.bufferVersion,
                        protein: dto.protein,
                        fat: dto.fat,
                        carbs: dto.carbs,
                        weightG: dto.weightG,
                        confidence: dto.confidence,
                        tags: dto.tags,
                        micronutrients: dto.micronutrients,
                        aminoAcids: dto.aminoAcids,
                        dietaryDate: dto.dietaryDate,
                        revision: dto.revision,
                        provenance: dto.provenance,
                        isDeleted: dto.isDeleted,
                        createdAt: dto.createdAt,
                        updatedAt: dto.updatedAt
                    )
                }
                return dto
            }
            if let cloudDTO = try? CloudJSONCoding.makeDecoder().decode(MealCloudDTO.self, from: data) {
                return cloudDTO
            }
        }

        if let localEntity {
            return MealCloudDTO(from: localEntity, userId: userId)
        }

        return MealCloudDTO(
            userId: userId,
            clientUUID: op.entityID,
            mealName: "Meal",
            kcal: 0,
            protein: 0,
            fat: 0,
            carbs: 0,
            dietaryDate: FoodPrompt.dietaryDate(for: Date()),
            revision: op.revision,
            provenance: "outbox_fallback",
            isDeleted: op.parsedKind == .delete,
            createdAt: op.createdAt,
            updatedAt: op.updatedAt
        )
    }

    private func resolveWorkoutCloudDTO(for op: SyncOperationEntity, localEntity: WorkoutAnalysisEntity?) -> WorkoutAnalysisCloudDTO {
        if let data = op.payloadJson.data(using: .utf8),
           let dto = try? CloudJSONCoding.makeDecoder().decode(WorkoutAnalysisCloudDTO.self, from: data) {
            return dto
        }
        if let localEntity {
            return WorkoutAnalysisCloudDTO(from: localEntity, userId: userId, revision: op.revision)
        }
        return WorkoutAnalysisCloudDTO(
            id: UUID(),
            userId: userId,
            healthkitWorkoutUUID: op.entityID,
            workoutType: "other",
            startedAt: op.createdAt,
            distanceKm: nil,
            durationMin: 0,
            avgPaceMinKm: nil,
            avgHr: nil,
            maxHr: nil,
            elevationGainM: nil,
            efficiencyFactor: nil,
            aerobicDecouplingPct: nil,
            splitsJson: [],
            lapsJson: [],
            aiCoachReport: nil,
            revision: op.revision,
            createdAt: op.createdAt,
            updatedAt: op.updatedAt
        )
    }

    private func resolveHealthKitPayload(for op: SyncOperationEntity, in ctx: ModelContext) -> HealthKitMealExportPayload {
        if let data = op.payloadJson.data(using: .utf8) {
            if let hkPayload = try? CloudJSONCoding.makeDecoder().decode(HealthKitMealExportPayload.self, from: data) {
                return hkPayload
            }
            let isoDecoder = JSONDecoder()
            isoDecoder.dateDecodingStrategy = .iso8601
            if let syncPayload = try? isoDecoder.decode(MealSyncPayload.self, from: data) {
                let micro: Micronutrients? = {
                    guard let raw = syncPayload.micronutrientsJson,
                          let d = raw.data(using: .utf8) else { return nil }
                    return try? JSONDecoder().decode(Micronutrients.self, from: d)
                }()
                return HealthKitMealExportPayload(
                    clientUUID: syncPayload.clientUUID,
                    name: syncPayload.name,
                    kcal: syncPayload.kcal,
                    proteinG: syncPayload.proteinG,
                    fatG: syncPayload.fatG,
                    carbsG: syncPayload.carbsG,
                    sodiumMg: micro?.sodiumMg,
                    fiberG: micro?.fiberG,
                    date: syncPayload.createdAt
                )
            }
            if let cloudDTO = try? CloudJSONCoding.makeDecoder().decode(MealCloudDTO.self, from: data) {
                return HealthKitMealExportPayload(
                    clientUUID: cloudDTO.clientUUID ?? op.entityID,
                    name: cloudDTO.mealName,
                    kcal: cloudDTO.kcal,
                    proteinG: cloudDTO.protein,
                    fatG: cloudDTO.fat,
                    carbsG: cloudDTO.carbs,
                    sodiumMg: cloudDTO.micronutrients?.sodiumMg,
                    fiberG: cloudDTO.micronutrients?.fiberG,
                    date: cloudDTO.createdAt
                )
            }
        }

        if let entity = fetchMealEntity(matching: op.entityID, in: ctx) {
            return HealthKitMealExportPayload(
                clientUUID: entity.clientUUID,
                name: entity.name,
                kcal: entity.kcal,
                proteinG: entity.proteinG,
                fatG: entity.fatG,
                carbsG: entity.carbsG,
                sodiumMg: entity.micronutrients?.sodiumMg,
                fiberG: entity.micronutrients?.fiberG,
                date: entity.createdAt
            )
        }

        return HealthKitMealExportPayload(
            clientUUID: op.entityID,
            name: "Meal",
            kcal: 0,
            proteinG: 0,
            fatG: 0,
            carbsG: 0,
            sodiumMg: nil,
            fiberG: nil,
            date: op.createdAt
        )
    }
}

public struct HealthKitMealExportPayload: Codable, Sendable, Equatable {
    public let clientUUID: UUID
    public let name: String
    public let kcal: Double
    public let proteinG: Double
    public let fatG: Double
    public let carbsG: Double
    public let sodiumMg: Double?
    public let fiberG: Double?
    public let date: Date

    public init(
        clientUUID: UUID,
        name: String,
        kcal: Double,
        proteinG: Double,
        fatG: Double,
        carbsG: Double,
        sodiumMg: Double? = nil,
        fiberG: Double? = nil,
        date: Date
    ) {
        self.clientUUID = clientUUID
        self.name = name
        self.kcal = kcal
        self.proteinG = proteinG
        self.fatG = fatG
        self.carbsG = carbsG
        self.sodiumMg = sodiumMg
        self.fiberG = fiberG
        self.date = date
    }
}
