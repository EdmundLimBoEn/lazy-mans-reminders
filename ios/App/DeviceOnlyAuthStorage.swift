import Foundation
import Security
import Supabase

struct DeviceOnlyAuthStorage: AuthLocalStorage {
    private let accessibility = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String
    private let legacyService = "supabase.gotrue.swift"
    private let privateService = "systems.edmundlim.reminders.sdk-auth"

    private func query(for key: String) throws -> [String: Any] {
        let bundle = Bundle.main
        guard let sharedGroup = bundle.object(forInfoDictionaryKey: "SHARED_KEYCHAIN_ACCESS_GROUP") as? String,
              let appGroup = bundle.object(forInfoDictionaryKey: "APP_GROUP_ID") as? String,
              !appGroup.isEmpty, sharedGroup.hasSuffix(appGroup),
              let bundleID = bundle.bundleIdentifier, bundleID != appGroup else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(errSecMissingEntitlement))
        }

        // Both groups use AppIdentifierPrefix. The app ID is already a private group.
        let prefix = String(sharedGroup.dropLast(appGroup.count))
        guard prefix.isEmpty || prefix.hasSuffix(".") else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(errSecMissingEntitlement))
        }
        let privateGroup = prefix + bundleID
        var item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyService,
            kSecAttrAccessGroup as String: sharedGroup
        ]
        // Move the whole SDK service atomically so pending verifiers move even on a session read.
        // A separate service avoids collisions with SDK items from before Keychain sharing.
        let status = SecItemUpdate(item as CFDictionary, [
            kSecAttrAccessGroup as String: privateGroup,
            kSecAttrService as String: privateService,
            kSecAttrAccessible as String: accessibility
        ] as CFDictionary)
        if status != errSecItemNotFound { try check(status) }

        item[kSecAttrAccessGroup as String] = privateGroup
        item[kSecAttrService as String] = privateService
        item[kSecAttrAccount as String] = key
        return item
    }

    private func legacyPrivateItem(_ item: [String: Any]) -> [String: Any] {
        item.merging([kSecAttrService as String: legacyService]) { _, service in service }
    }

    private func check(_ status: OSStatus) throws {
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    func store(key: String, value: Data) throws {
        let item = try query(for: key)
        let attributes: [String: Any] = [
            kSecAttrAccessible as String: accessibility,
            kSecValueData as String: value
        ]
        var status = SecItemUpdate(item as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(item.merging(attributes) { _, new in new } as CFDictionary, nil)
            if status == errSecDuplicateItem {
                status = SecItemUpdate(item as CFDictionary, attributes as CFDictionary)
            }
        }
        try check(status)
    }

    func retrieve(key: String) throws -> Data? {
        let item = try query(for: key)
        if let data = try read(item) { return data }
        return try read(legacyPrivateItem(item))
    }

    private func read(_ item: [String: Any]) throws -> Data? {
        var lookup = item
        lookup[kSecReturnAttributes as String] = true
        lookup[kSecReturnData as String] = true
        var result: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        try check(status)
        guard let attributes = result as? [String: Any],
              let data = attributes[kSecValueData as String] as? Data else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(errSecDecode))
        }
        if attributes[kSecAttrAccessible as String] as? String != accessibility {
            // Change only the protection so a concurrent token refresh keeps its value.
            let protection = [kSecAttrAccessible as String: accessibility]
            let update = SecItemUpdate(item as CFDictionary, protection as CFDictionary)
            if update == errSecItemNotFound { return nil }
            try check(update)
        }
        return data
    }

    func remove(key: String) throws {
        let item = try query(for: key)
        // Remove the fallback first so an interrupted removal can't restore stale credentials.
        try delete(legacyPrivateItem(item))
        try delete(item)
    }

    private func delete(_ item: [String: Any]) throws {
        let status = SecItemDelete(item as CFDictionary)
        if status != errSecItemNotFound { try check(status) }
    }
}
