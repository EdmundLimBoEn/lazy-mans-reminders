import Foundation
import Security

protocol SessionCredentialStorage {
    func read() throws -> Data?
    func write(_ data: Data) throws
    func insertIfAbsent(_ data: Data) throws
    func delete() throws
}

struct KeychainSessionStorage: SessionCredentialStorage {
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "systems.edmundlim.reminders.shared-session",
         kSecAttrAccount as String: "session",
         kSecAttrAccessGroup as String: Bundle.main.object(forInfoDictionaryKey: "SHARED_KEYCHAIN_ACCESS_GROUP") as? String ?? "",
         kSecAttrSynchronizable as String: false]
    }

    struct Failure: Error { let status: OSStatus }

    func read() throws -> Data? {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw Failure(status: status) }
        return result as? Data
    }

    func write(_ data: Data) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
            // Another process may have created the shared item concurrently.
            if status == errSecDuplicateItem {
                status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            }
        }
        guard status == errSecSuccess else { throw Failure(status: status) }
    }

    func insertIfAbsent(_ data: Data) throws {
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else { throw Failure(status: status) }
    }

    func delete() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw Failure(status: status) }
    }
}

/// Preferences retain only the legacy migration source and a non-secret sign-out marker.
struct SharedSessionStorage {
    let defaults: UserDefaults
    let credentials: SessionCredentialStorage
    private let legacyKey = "shared-session"
    private let signedOutKey = "shared-session-signed-out"

    func read() throws -> Data? {
        if defaults.bool(forKey: signedOutKey) {
            // Reads must not perform deferred cleanup: another process can save a
            // new session after we observe this marker. Failed sign-out deletion
            // stays masked until an explicit write replaces the credentials.
            return nil
        }
        if let data = try credentials.read() {
            defaults.removeObject(forKey: legacyKey)
            return data
        }
        guard let legacy = defaults.data(forKey: legacyKey) else { return nil }
        // Never discard the only copy if Keychain is temporarily unavailable.
        // A concurrent app/widget save must win over this legacy snapshot.
        try credentials.insertIfAbsent(legacy)
        let migrated = try credentials.read()
        defaults.removeObject(forKey: legacyKey)
        return migrated
    }

    func write(_ data: Data) throws {
        try credentials.write(data)
        defaults.removeObject(forKey: legacyKey)
        defaults.removeObject(forKey: signedOutKey)
    }

    func clear() {
        // Keep sign-out effective even before first unlock or if deletion fails.
        defaults.set(true, forKey: signedOutKey)
        defaults.removeObject(forKey: legacyKey)
        try? credentials.delete()
    }
}
