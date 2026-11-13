import Foundation
import SwiftData

// MARK: - Sync Operation Model

public enum SyncOperationStatus: String, Codable, Sendable {
    case pending
    case processing
    case completed
    case failed
}

public enum SyncOperationKind: String, Codable, Sendable {
    case upsert
    case delete
}

public enum SyncEntityType: String, Codable, Sendable {
    case meal
    case workout
}

@Model
public final class SyncOperationEntity {
    @Attribute(.unique) public var operationID: UUID
    public var entityID: UUID
    public var entityType: String       // "meal", "workout"
    public var operationKind: String     // "upsert", "delete"
    public var revision: Int
    public var payloadJson: String
    public var attempts: Int
    public var lastAttemptAt: Date?
    public var status: String           // "pending", "processing", "completed", "failed"
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        operationID: UUID = UUID(),
        entityID: UUID,
        entityType: String,
        operationKind: String,
        revision: Int,
        payloadJson: String,
        attempts: Int = 0,
        lastAttemptAt: Date? = nil,
        status: String = SyncOperationStatus.pending.rawValue,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.operationID = operationID
        self.entityID = entityID
        self.entityType = entityType
        self.operationKind = operationKind
        self.revision = revision
        self.payloadJson = payloadJson
        self.attempts = attempts
        self.lastAttemptAt = lastAttemptAt
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var parsedStatus: SyncOperationStatus {
        SyncOperationStatus(rawValue: status) ?? .pending
    }

    public var parsedKind: SyncOperationKind {
        SyncOperationKind(rawValue: operationKind) ?? .upsert
    }

    public var parsedEntityType: SyncEntityType {
        SyncEntityType(rawValue: entityType) ?? .meal
    }
}

// MARK: - Sync Payload Contracts

public struct MealSyncPayload: Codable, Sendable {
    public let clientUUID: UUID
    public let name: String
    public let kcal: Double
    public let kcalExact: Double?
    public let bufferVersion: Int
    public let proteinG: Double
    public let fatG: Double
    public let carbsG: Double
    public let weightG: Double?
    public let confidence: Double?
    public let tags: [String]
    public let micronutrientsJson: String?
    public let aminoAcidsJson: String?
    public let dietaryDate: String
    public let createdAt: Date
    public let updatedAt: Date
    public let revision: Int
    public let provenance: String
    public let isDeleted: Bool
    public let legacyRemoteId: Int64?

    public init(from entity: MealEntity) {
        self.clientUUID = entity.clientUUID
        self.name = entity.name
        self.kcal = entity.kcal
        self.kcalExact = entity.kcalExact
        self.bufferVersion = entity.bufferVersion
        self.proteinG = entity.proteinG
        self.fatG = entity.fatG
        self.carbsG = entity.carbsG
        self.weightG = entity.weightG
        self.confidence = entity.confidence
        self.tags = entity.tags
        self.micronutrientsJson = entity.micronutrientsJson
        self.aminoAcidsJson = entity.aminoAcidsJson
        self.dietaryDate = entity.dietaryDate
        self.createdAt = entity.createdAt
        self.updatedAt = entity.updatedAt
        self.revision = entity.revision
        self.provenance = entity.provenance
        self.isDeleted = entity.isDeleted
        self.legacyRemoteId = entity.remoteId
    }

    public func toJsonString() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }
}

// MARK: - SyncOutbox

@MainActor
public final class SyncOutbox {
    public static let shared = SyncOutbox()

    private var defaultContext: ModelContext {
        LifecoreDataStore.shared.context
    }

    public init() {}

    /// Enqueues an operation into the outbox.
    /// If a custom context is passed, the operation is inserted into that context
    /// without saving, allowing callers to commit the mutation and outbox operation atomically.
    @discardableResult
    public func enqueue(
        entityID: UUID,
        entityType: String,
        operationKind: String,
        revision: Int,
        payloadJson: String,
        in customContext: ModelContext? = nil
    ) throws -> SyncOperationEntity {
        let ctx = customContext ?? defaultContext
        let op = SyncOperationEntity(
            operationID: UUID(),
            entityID: entityID,
            entityType: entityType,
            operationKind: operationKind,
            revision: revision,
            payloadJson: payloadJson,
            attempts: 0,
            lastAttemptAt: nil,
            status: SyncOperationStatus.pending.rawValue,
            createdAt: Date(),
            updatedAt: Date()
        )
        ctx.insert(op)

        // Save immediately only if using default standalone context
        if customContext == nil {
            try ctx.save()
        }
        return op
    }

    /// Fetches all pending operations, optionally filtered by entity type.
    public func fetchPendingOperations(
        for entityType: String? = nil,
        in customContext: ModelContext? = nil
    ) throws -> [SyncOperationEntity] {
        let ctx = customContext ?? defaultContext
        let pendingStatus = SyncOperationStatus.pending.rawValue
        let descriptor = FetchDescriptor<SyncOperationEntity>(
            predicate: #Predicate { $0.status == pendingStatus },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let operations = try ctx.fetch(descriptor)
        if let entityType = entityType {
            return operations.filter { $0.entityType == entityType }
        }
        return operations
    }

    /// Fetches all operations regardless of status.
    public func fetchAllOperations(in customContext: ModelContext? = nil) throws -> [SyncOperationEntity] {
        let ctx = customContext ?? defaultContext
        let descriptor = FetchDescriptor<SyncOperationEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try ctx.fetch(descriptor)
    }

    /// Marks an operation as currently processing and increments attempts.
    public func markProcessing(operationID: UUID, in customContext: ModelContext? = nil) throws {
        let ctx = customContext ?? defaultContext
        let descriptor = FetchDescriptor<SyncOperationEntity>(
            predicate: #Predicate { $0.operationID == operationID }
        )
        guard let op = try ctx.fetch(descriptor).first else {
            throw PersistenceError.entityNotFound(operationID)
        }
        op.status = SyncOperationStatus.processing.rawValue
        op.attempts += 1
        op.lastAttemptAt = Date()
        op.updatedAt = Date()
        try ctx.save()
    }

    /// Marks an operation as completed.
    public func markCompleted(operationID: UUID, in customContext: ModelContext? = nil) throws {
        let ctx = customContext ?? defaultContext
        let descriptor = FetchDescriptor<SyncOperationEntity>(
            predicate: #Predicate { $0.operationID == operationID }
        )
        guard let op = try ctx.fetch(descriptor).first else {
            throw PersistenceError.entityNotFound(operationID)
        }
        op.status = SyncOperationStatus.completed.rawValue
        op.updatedAt = Date()
        try ctx.save()
    }

    /// Marks an operation as failed.
    public func markFailed(operationID: UUID, in customContext: ModelContext? = nil) throws {
        let ctx = customContext ?? defaultContext
        let descriptor = FetchDescriptor<SyncOperationEntity>(
            predicate: #Predicate { $0.operationID == operationID }
        )
        guard let op = try ctx.fetch(descriptor).first else {
            throw PersistenceError.entityNotFound(operationID)
        }
        op.status = SyncOperationStatus.failed.rawValue
        op.updatedAt = Date()
        try ctx.save()
    }

    /// Records a retry attempt without changing the state to completed.
    public func recordAttempt(operationID: UUID, in customContext: ModelContext? = nil) throws {
        let ctx = customContext ?? defaultContext
        let descriptor = FetchDescriptor<SyncOperationEntity>(
            predicate: #Predicate { $0.operationID == operationID }
        )
        guard let op = try ctx.fetch(descriptor).first else {
            throw PersistenceError.entityNotFound(operationID)
        }
        op.attempts += 1
        op.lastAttemptAt = Date()
        op.updatedAt = Date()
        try ctx.save()
    }

    /// Purges all completed operations to keep the outbox compact.
    public func purgeCompleted(in customContext: ModelContext? = nil) throws {
        let ctx = customContext ?? defaultContext
        let completed = SyncOperationStatus.completed.rawValue
        let descriptor = FetchDescriptor<SyncOperationEntity>(
            predicate: #Predicate { $0.status == completed }
        )
        let completedOps = try ctx.fetch(descriptor)
        for op in completedOps {
            ctx.delete(op)
        }
        try ctx.save()
    }
}
