import XCTest
import SwiftData
@testable import Lifecore

@MainActor
final class ConfigurationTests: XCTestCase {

    private var isolatedContainer: ModelContainer!
    private var isolatedContext: ModelContext!
    private var inMemoryStore: InMemoryCredentialStore!

    override func setUp() async throws {
        try await super.setUp()
        let fixture = AppEnvironment.fixture()
        AppEnvironment.current = fixture
        isolatedContainer = fixture.modelContainer
        isolatedContext = ModelContext(isolatedContainer)
        inMemoryStore = InMemoryCredentialStore()
        AppConfiguration.credentialStoreOverride = inMemoryStore
    }

    override func tearDown() async throws {
        AppConfiguration.credentialStoreOverride = nil
        inMemoryStore = nil
        isolatedContext = nil
        isolatedContainer = nil
        AppEnvironment.reset()
        UserDefaults.standard.removeObject(forKey: "GEMINI_API_KEY")
        try await super.tearDown()
    }

    // MARK: - 1. Missing API Key Error in Live Mode

    func testMissingAPIKeyThrowsErrorInLiveMode() async {
        // Given: Live environment with unconfigured API key
        AppEnvironment.current = AppEnvironment(
            mode: .live,
            modelContainer: isolatedContainer,
            healthProvider: LiveHealthDataProvider(),
            aiProvider: LiveAIProvider(),
            syncProvider: LiveSyncProvider()
        )
        GeminiService.shared.setApiKey("")
        inMemoryStore.clearAll()

        // When/Then: Calling analyzeFood must throw missingApiKey error and never fabricate meals
        do {
            _ = try await GeminiService.shared.analyzeFood(imageJpegData: nil, textDescription: "Вівсянка з яблуком")
            XCTFail("Expected missingApiKey error when no key is configured in live mode")
        } catch GeminiError.missingApiKey {
            // Expected
        } catch GeminiServiceError.missingAPIKey {
            // Expected
        } catch {
            XCTFail("Unexpected error caught: \(error)")
        }
    }

    // MARK: - 2. InMemoryCredentialStore Thread Safety & Operations

    func testInMemoryCredentialStoreOperationsAndThreadSafety() throws {
        let store = InMemoryCredentialStore()

        // Set, Get, Delete
        try store.setCredential("secret_gemini_key", forKey: CredentialKeys.geminiAPIKey)
        XCTAssertEqual(store.getCredential(forKey: CredentialKeys.geminiAPIKey), "secret_gemini_key")

        try store.setCredential("supabase_token_123", forKey: CredentialKeys.supabaseAccessToken)
        XCTAssertEqual(store.getCredential(forKey: CredentialKeys.supabaseAccessToken), "supabase_token_123")

        try store.deleteCredential(forKey: CredentialKeys.geminiAPIKey)
        XCTAssertNil(store.getCredential(forKey: CredentialKeys.geminiAPIKey))

        // Empty string treated as delete
        try store.setCredential("", forKey: CredentialKeys.supabaseAccessToken)
        XCTAssertNil(store.getCredential(forKey: CredentialKeys.supabaseAccessToken))

        // Concurrent access stress
        DispatchQueue.concurrentPerform(iterations: 100) { i in
            let key = "concurrent_key_\(i % 10)"
            try? store.setCredential("val_\(i)", forKey: key)
            _ = store.getCredential(forKey: key)
        }
    }

    // MARK: - 3. AppConfiguration Migration from UserDefaults

    func testAppConfigurationMigratesFromUserDefaults() throws {
        let store = InMemoryCredentialStore()
        let testLegacyKey = "AIzaSy_LEGACY_MIGRATED_KEY_12345"

        UserDefaults.standard.set(testLegacyKey, forKey: "GEMINI_API_KEY")

        let resolved = AppConfiguration.resolveGeminiAPIKey(
            credentialStore: store,
            userDefaults: .standard
        )

        // 1. Value returned correctly
        XCTAssertEqual(resolved, testLegacyKey)

        // 2. Persisted into CredentialStore
        XCTAssertEqual(store.getCredential(forKey: CredentialKeys.geminiAPIKey), testLegacyKey)

        // 3. Removed from UserDefaults
        XCTAssertNil(UserDefaults.standard.string(forKey: "GEMINI_API_KEY"))
    }

    // MARK: - 4. AppConfiguration Never Bundles Hardcoded Secrets

    func testAppConfigurationNeverReturnsBundledSecretKey() {
        let store = InMemoryCredentialStore()
        UserDefaults.standard.removeObject(forKey: "GEMINI_API_KEY")

        // In absence of environment variable or stored key, must return nil
        if ProcessInfo.processInfo.environment["GEMINI_API_KEY"] == nil {
            let resolved = AppConfiguration.resolveGeminiAPIKey(
                credentialStore: store,
                userDefaults: .standard
            )
            XCTAssertNil(resolved, "AppConfiguration must never bundle or return a fallback hardcoded secret key")
        }

        XCTAssertEqual(GeminiService.defaultApiKey, "", "GeminiService.defaultApiKey must be empty")
    }

    // MARK: - 5. Expired Session Token Detection

    func testAccountSessionManagerDetectsExpiredToken() {
        let activeUUID = UUID()

        // Expired in past
        let expiredSession = SessionState(
            authUserID: activeUUID,
            accessToken: "expired_token_123",
            expiresAt: Date().addingTimeInterval(-300)
        )
        XCTAssertTrue(expiredSession.isTokenExpired)

        // Valid in future
        let validSession = SessionState(
            authUserID: activeUUID,
            accessToken: "valid_token_123",
            expiresAt: Date().addingTimeInterval(3600)
        )
        XCTAssertFalse(validSession.isTokenExpired)

        // Session without expiresAt never expires automatically
        let nonExpiringSession = SessionState(
            authUserID: activeUUID,
            accessToken: "permanent_token",
            expiresAt: nil
        )
        XCTAssertFalse(nonExpiringSession.isTokenExpired)
    }

    // MARK: - 6. SignOut and SwitchAccount Isolates Outbox

    func testSignOutAndSwitchAccountIsolatesOutboxOperations() throws {
        let store = InMemoryCredentialStore()
        let sessionManager = AccountSessionManager(credentialStore: store)

        let userA = SessionState(authUserID: UUID(), accessToken: "token_user_a")
        let userB = SessionState(authUserID: UUID(), accessToken: "token_user_b")

        // 1. Establish User A session and enqueue pending outbox operation
        sessionManager.setSession(userA)
        XCTAssertEqual(sessionManager.authUserID, userA.authUserID)
        XCTAssertEqual(store.getCredential(forKey: CredentialKeys.supabaseAccessToken), "token_user_a")

        try SyncOutbox.shared.enqueue(
            entityID: UUID(),
            entityType: "meal",
            operationKind: "upsert",
            revision: 1,
            payloadJson: "{}",
            in: isolatedContext
        )

        let pendingBefore = try SyncOutbox.shared.fetchPendingOperations(in: isolatedContext)
        XCTAssertEqual(pendingBefore.count, 1)

        // 2. Switch to User B: must purge User A's outbox queue to isolate accounts
        sessionManager.switchAccount(to: userB, in: isolatedContext)
        XCTAssertEqual(sessionManager.authUserID, userB.authUserID)
        XCTAssertEqual(store.getCredential(forKey: CredentialKeys.supabaseAccessToken), "token_user_b")

        let pendingAfterSwitch = try SyncOutbox.shared.fetchPendingOperations(in: isolatedContext)
        XCTAssertEqual(pendingAfterSwitch.count, 0, "Account A pending outbox operations must be purged on switch to Account B")

        // 3. User B enqueues an operation
        try SyncOutbox.shared.enqueue(
            entityID: UUID(),
            entityType: "workout",
            operationKind: "upsert",
            revision: 1,
            payloadJson: "{}",
            in: isolatedContext
        )
        let pendingUserB = try SyncOutbox.shared.fetchPendingOperations(in: isolatedContext)
        XCTAssertEqual(pendingUserB.count, 1)

        // 4. Sign out: must clear tokens and purge pending outbox queue
        sessionManager.signOut(in: isolatedContext)
        XCTAssertNil(sessionManager.currentSession)
        XCTAssertNil(store.getCredential(forKey: CredentialKeys.supabaseAccessToken))

        let pendingAfterSignOut = try SyncOutbox.shared.fetchPendingOperations(in: isolatedContext)
        XCTAssertEqual(pendingAfterSignOut.count, 0, "Outbox operations must be purged on signOut")
    }
}
