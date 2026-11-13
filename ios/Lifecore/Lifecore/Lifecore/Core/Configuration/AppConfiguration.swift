import Foundation

// MARK: - AppConfiguration

public enum AppConfiguration {
    // MARK: - Supabase Public Configuration

    public static let defaultSupabaseURL = URL(string: "https://khmviccwbuktnvdxhnwg.supabase.co")!
    public static let defaultSupabaseAnonKey = "sb_publishable_kf0wGKz9z9VpZiu_hQe0xQ_6WTvrpXy"

    public static var supabaseURL: URL {
        if let envUrlString = ProcessInfo.processInfo.environment["SUPABASE_URL"],
           let url = URL(string: envUrlString),
           !envUrlString.isEmpty {
            return url
        }
        return defaultSupabaseURL
    }

    public static var supabaseAnonKey: String {
        if let envKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"],
           !envKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return envKey
        }
        return defaultSupabaseAnonKey
    }

    // MARK: - Active Credential Store Resolver

    public static var credentialStoreOverride: CredentialStore?

    public static func activeCredentialStore() -> CredentialStore {
        if let override = credentialStoreOverride {
            return override
        }
        if AppEnvironment.current.isFixtureMode {
            return InMemoryCredentialStore.shared
        }
        return KeychainCredentialStore.shared
    }

    // MARK: - Gemini API Key Resolution

    /// Resolves the active Gemini API key following the strict precedence:
    /// 1. CredentialStore (`KeychainCredentialStore` in live mode, `InMemoryCredentialStore` in fixture/tests)
    /// 2. One-time transparent migration from legacy `UserDefaults.standard.string(forKey: "GEMINI_API_KEY")`
    /// 3. Environment variable `GEMINI_API_KEY` (developer / CI overrides)
    /// 4. `nil` when unconfigured (strictly NO bundled or XOR/obfuscated secret key).
    public static func resolveGeminiAPIKey(
        credentialStore: CredentialStore? = nil,
        userDefaults: UserDefaults = .standard
    ) -> String? {
        let store = credentialStore ?? activeCredentialStore()

        // 1. Check CredentialStore
        if let storedKey = store.getCredential(forKey: CredentialKeys.geminiAPIKey),
           !storedKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return storedKey.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let legacyStoreKey = store.getCredential(forKey: "GEMINI_API_KEY"),
           !legacyStoreKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return legacyStoreKey.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 2. One-time migration from UserDefaults
        if let legacyUDKey = userDefaults.string(forKey: "GEMINI_API_KEY"),
           !legacyUDKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let migratedKey = legacyUDKey.trimmingCharacters(in: .whitespacesAndNewlines)
            try? store.setCredential(migratedKey, forKey: CredentialKeys.geminiAPIKey)
            userDefaults.removeObject(forKey: "GEMINI_API_KEY")
            return migratedKey
        }

        // 3. Process environment variable
        if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"],
           !envKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return envKey.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 4. Return nil (unconfigured) — no bundled secret key
        return nil
    }
}
