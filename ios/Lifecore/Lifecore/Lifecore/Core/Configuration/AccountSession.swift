import Foundation
import Combine
import SwiftData

// MARK: - Notifications

public extension Notification.Name {
    static let lifecoreAccountDidSignOut = Notification.Name("lifecore.accountDidSignOut")
    static let lifecoreAccountDidChange = Notification.Name("lifecore.accountDidChange")
}

// MARK: - SessionState

nonisolated public struct SessionState: Equatable, Sendable {
    public let authUserID: UUID
    public let accessToken: String
    public let refreshToken: String?
    public let expiresAt: Date?
    public let verifiedLegacyUserId: Int64?

    public init(
        authUserID: UUID,
        accessToken: String,
        refreshToken: String? = nil,
        expiresAt: Date? = nil,
        verifiedLegacyUserId: Int64? = nil
    ) {
        self.authUserID = authUserID
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.verifiedLegacyUserId = verifiedLegacyUserId
    }

    /// Evaluates if access token has passed its expiration timestamp.
    public var isTokenExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return expiresAt <= Date()
    }
}

// MARK: - AccountSessionManager

@MainActor
public final class AccountSessionManager: ObservableObject {
    public static let shared = AccountSessionManager()

    // Thread-safe shadow storage for nonisolated background transport queries
    nonisolated private final class SessionBox: @unchecked Sendable {
        let lock = NSLock()
        var session: SessionState?
    }
    nonisolated private static let sessionBox = SessionBox()

    @Published public private(set) var currentSession: SessionState?

    private let credentialStore: any CredentialStore

    public init(credentialStore: (any CredentialStore)? = nil) {
        let resolvedStore = credentialStore ?? AppConfiguration.activeCredentialStore()
        self.credentialStore = resolvedStore

        // Attempt hydrating session state from credentialStore if tokens exist
        if let token = resolvedStore.getCredential(forKey: CredentialKeys.supabaseAccessToken),
           let userUUIDString = resolvedStore.getCredential(forKey: CredentialKeys.supabaseAuthUserID),
           let userUUID = UUID(uuidString: userUUIDString) {
            let refresh = resolvedStore.getCredential(forKey: CredentialKeys.supabaseRefreshToken)
            let hydrated = SessionState(authUserID: userUUID, accessToken: token, refreshToken: refresh)
            self.currentSession = hydrated
            Self.updateCachedSession(hydrated)
        }
    }

    public var isAuthenticated: Bool {
        guard let session = currentSession else { return false }
        return !session.isTokenExpired
    }

    public var isTokenExpired: Bool {
        guard let session = currentSession else { return false }
        return session.isTokenExpired
    }

    public var authUserID: UUID? {
        currentSession?.authUserID
    }

    public var accessToken: String? {
        guard let session = currentSession, !session.isTokenExpired else { return nil }
        return session.accessToken
    }

    public var verifiedLegacyUserId: Int64? {
        currentSession?.verifiedLegacyUserId
    }

    // MARK: - Session Mutations

    /// Sets the active session and securely persists the access and refresh tokens into the CredentialStore.
    public func setSession(_ session: SessionState) {
        self.currentSession = session
        Self.updateCachedSession(session)
        persistTokensToStore(session)
        NotificationCenter.default.post(name: .lifecoreAccountDidChange, object: nil)
    }

    /// Signs out the active user, securely clears tokens from the CredentialStore,
    /// and purges pending outbox operations to prevent cross-account mutation leak.
    public func signOut(in context: ModelContext? = nil) {
        clearTokensFromStore()
        purgePendingOutbox(in: context)
        self.currentSession = nil
        Self.updateCachedSession(nil)
        NotificationCenter.default.post(name: .lifecoreAccountDidSignOut, object: nil)
    }

    /// Switches account session to a new user. If the user identity changes,
    /// Account A's pending outbox queue is purged/isolated before adopting Account B.
    public func switchAccount(to newSession: SessionState, in context: ModelContext? = nil) {
        if currentSession?.authUserID != newSession.authUserID {
            purgePendingOutbox(in: context)
        }
        setSession(newSession)
    }

    // MARK: - Outbox Cross-Account Isolation Hook

    /// Purges all pending and in-flight operations from SyncOutbox to strictly guarantee
    /// Account A's unpushed mutations are never replayed under Account B's cloud credentials.
    public func purgePendingOutbox(in customContext: ModelContext? = nil) {
        let ctx = customContext ?? LifecoreDataStore.shared.context
        let pending = SyncOperationStatus.pending.rawValue
        let processing = SyncOperationStatus.processing.rawValue
        let failed = SyncOperationStatus.failed.rawValue

        let descriptor = FetchDescriptor<SyncOperationEntity>(
            predicate: #Predicate { $0.status == pending || $0.status == processing || $0.status == failed }
        )
        if let ops = try? ctx.fetch(descriptor) {
            for op in ops {
                ctx.delete(op)
            }
            try? ctx.save()
        }
    }

    // MARK: - Thread-Safe Static Accessors (for background transports)

    private nonisolated static func updateCachedSession(_ session: SessionState?) {
        sessionBox.lock.lock()
        defer { sessionBox.lock.unlock() }
        sessionBox.session = session
    }

    public nonisolated static func currentAccessTokenIfValid() throws -> String? {
        sessionBox.lock.lock()
        defer { sessionBox.lock.unlock() }
        guard let session = sessionBox.session else { return nil }
        if session.isTokenExpired {
            throw CloudSyncTransportError.unauthorized(statusCode: 401, message: "Session token expired")
        }
        return session.accessToken
    }

    public nonisolated static func isCurrentSessionExpired() -> Bool {
        sessionBox.lock.lock()
        defer { sessionBox.lock.unlock() }
        guard let session = sessionBox.session else { return false }
        return session.isTokenExpired
    }

    // MARK: - Token Store Persistence Helpers

    private func persistTokensToStore(_ session: SessionState) {
        try? credentialStore.setCredential(session.accessToken, forKey: CredentialKeys.supabaseAccessToken)
        if let refresh = session.refreshToken {
            try? credentialStore.setCredential(refresh, forKey: CredentialKeys.supabaseRefreshToken)
        } else {
            try? credentialStore.deleteCredential(forKey: CredentialKeys.supabaseRefreshToken)
        }
        try? credentialStore.setCredential(session.authUserID.uuidString, forKey: CredentialKeys.supabaseAuthUserID)
    }

    private func clearTokensFromStore() {
        try? credentialStore.deleteCredential(forKey: CredentialKeys.supabaseAccessToken)
        try? credentialStore.deleteCredential(forKey: CredentialKeys.supabaseRefreshToken)
        try? credentialStore.deleteCredential(forKey: CredentialKeys.supabaseAuthUserID)
    }
}
