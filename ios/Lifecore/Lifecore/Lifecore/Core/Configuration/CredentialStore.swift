import Foundation
import Security
import os

// MARK: - Credential Keys

public enum CredentialKeys {
    public static let geminiAPIKey = "com.lifecore.credential.gemini_api_key"
    public static let supabaseAccessToken = "com.lifecore.credential.supabase_access_token"
    public static let supabaseRefreshToken = "com.lifecore.credential.supabase_refresh_token"
    public static let supabaseAuthUserID = "com.lifecore.credential.supabase_auth_user_id"
}

// MARK: - Credential Store Error

public enum CredentialStoreError: Error, LocalizedError, Sendable, Equatable {
    case keychainError(OSStatus)
    case invalidEncoding

    public var errorDescription: String? {
        switch self {
        case .keychainError(let status):
            return "Keychain operation failed with OSStatus \(status)."
        case .invalidEncoding:
            return "Credential could not be encoded as valid UTF-8 data."
        }
    }
}

// MARK: - CredentialStore Protocol

public protocol CredentialStore: AnyObject, Sendable {
    func getCredential(forKey key: String) -> String?
    func setCredential(_ value: String, forKey key: String) throws
    func deleteCredential(forKey key: String) throws
}

extension CredentialStore {
    public var geminiAPIKey: String? {
        get { getCredential(forKey: CredentialKeys.geminiAPIKey) }
        set {
            if let val = newValue, !val.isEmpty {
                try? setCredential(val, forKey: CredentialKeys.geminiAPIKey)
            } else {
                try? deleteCredential(forKey: CredentialKeys.geminiAPIKey)
            }
        }
    }

    public var supabaseAccessToken: String? {
        get { getCredential(forKey: CredentialKeys.supabaseAccessToken) }
        set {
            if let val = newValue, !val.isEmpty {
                try? setCredential(val, forKey: CredentialKeys.supabaseAccessToken)
            } else {
                try? deleteCredential(forKey: CredentialKeys.supabaseAccessToken)
            }
        }
    }

    public var supabaseRefreshToken: String? {
        get { getCredential(forKey: CredentialKeys.supabaseRefreshToken) }
        set {
            if let val = newValue, !val.isEmpty {
                try? setCredential(val, forKey: CredentialKeys.supabaseRefreshToken)
            } else {
                try? deleteCredential(forKey: CredentialKeys.supabaseRefreshToken)
            }
        }
    }
}

// MARK: - Keychain Credential Store

public final class KeychainCredentialStore: CredentialStore, @unchecked Sendable {
    public static let shared = KeychainCredentialStore()

    private let service: String
    private let lock = NSLock()

    public init(service: String = "com.lifecore.credentials") {
        self.service = service
    }

    public func getCredential(forKey key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: kCFBooleanTrue as Any,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    public func setCredential(_ value: String, forKey key: String) throws {
        lock.lock()
        defer { lock.unlock() }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            try deleteCredentialLocked(forKey: key)
            return
        }

        guard let data = trimmed.data(using: .utf8) else {
            throw CredentialStoreError.invalidEncoding
        }

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]

        let attributesToUpdate: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData] = data
            addQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw CredentialStoreError.keychainError(addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw CredentialStoreError.keychainError(updateStatus)
        }
    }

    public func deleteCredential(forKey key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        try deleteCredentialLocked(forKey: key)
    }

    private func deleteCredentialLocked(forKey key: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw CredentialStoreError.keychainError(status)
        }
    }
}

// MARK: - In-Memory Credential Store (Testing & Fixture Mode)

public final class InMemoryCredentialStore: CredentialStore, @unchecked Sendable {
    public static let shared = InMemoryCredentialStore()

    private let lock = NSLock()
    private var storage: [String: String]

    public init(initialEntries: [String: String] = [:]) {
        self.storage = initialEntries
    }

    public func getCredential(forKey key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    public func setCredential(_ value: String, forKey key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            storage.removeValue(forKey: key)
        } else {
            storage[key] = trimmed
        }
    }

    public func deleteCredential(forKey key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: key)
    }

    public func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
    }
}
