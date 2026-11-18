import Foundation
import Security
import Supabase

struct DeviceOnlyAuthStorage: AuthLocalStorage {
    private let accessibility = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String

    private func query(for key: String) -> [String: Any] {
        // Match the pinned SDK's default Keychain service, account and access group.
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "supabase.gotrue.swift",
         kSecAttrAccount as String: key]
    }

    private func check(_ status: OSStatus) throws {
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    func store(key: String, value: Data) throws {
        let item = query(for: key)
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
        let item = query(for: key)
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
        let status = SecItemDelete(query(for: key) as CFDictionary)
        if status != errSecItemNotFound { try check(status) }
    }
}
