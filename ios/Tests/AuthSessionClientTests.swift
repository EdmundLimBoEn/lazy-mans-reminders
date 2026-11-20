import Foundation
import Security
import Supabase
import XCTest
@testable import LazyMansReminders

@MainActor
final class AuthSessionClientTests: XCTestCase {
    private let endpoint = URL(string: "https://credential-test.invalid")!
    private let key = "sb-credential-test-auth-token"
    private let anonKey = "eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoiYW5vbiJ9.test-signature"
    private let sdkService = "systems.edmundlim.reminders.sdk-auth"

    private final class MemoryStorage: AuthLocalStorage, @unchecked Sendable {
        private let lock = NSLock()
        private var values: [String: Data] = [:]
        private var readObserver: (@Sendable () -> Void)?

        func observeReads(_ observer: (@Sendable () -> Void)?) {
            lock.lock()
            defer { lock.unlock() }
            readObserver = observer
        }

        func store(key: String, value: Data) throws {
            lock.lock()
            defer { lock.unlock() }
            values[key] = value
        }

        func retrieve(key: String) throws -> Data? {
            lock.lock()
            let value = values[key]
            let observer = readObserver
            lock.unlock()
            observer?()
            return value
        }

        func remove(key: String) throws {
            lock.lock()
            defer { lock.unlock() }
            values.removeValue(forKey: key)
        }
    }

    private final class NoNetworkProtocol: URLProtocol {
        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
        }
        override func stopLoading() { }
    }

    private func noNetworkSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NoNetworkProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func session(userID: UUID, expired: Bool = false) -> Session {
        let now = Date()
        return Session(accessToken: "test-access-\(userID)", tokenType: "bearer", expiresIn: 3600,
                       expiresAt: now.timeIntervalSince1970 + (expired ? -60 : 3600),
                       refreshToken: "test-refresh-\(userID)",
                       user: User(id: userID, appMetadata: [:], userMetadata: [:], aud: "authenticated",
                                  createdAt: now, updatedAt: now))
    }

    private func keychainQuery(for key: String, group: String,
                               service: String = "supabase.gotrue.swift") -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrAccessGroup as String: group
        ]
    }

    private func keychainAttributes(_ item: [String: Any]) throws -> [String: Any] {
        let query = item.merging([
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecReturnPersistentRef as String: true
        ]) { _, new in new }
        var result: CFTypeRef?
        XCTAssertEqual(SecItemCopyMatching(query as CFDictionary, &result), errSecSuccess)
        return try XCTUnwrap(result as? [String: Any])
    }

    private func keychainGroups() throws -> (shared: String, app: String) {
        let bundle = Bundle.main
        let shared = try XCTUnwrap(bundle.object(forInfoDictionaryKey: "SHARED_KEYCHAIN_ACCESS_GROUP") as? String)
        let appGroup = try XCTUnwrap(bundle.object(forInfoDictionaryKey: "APP_GROUP_ID") as? String)
        let bundleID = try XCTUnwrap(bundle.bundleIdentifier)
        return (shared, String(shared.dropLast(appGroup.count)) + bundleID)
    }

    private func deleteSDKFixtures(_ keys: [String], groups: (shared: String, app: String)) {
        for key in keys {
            SecItemDelete(keychainQuery(for: key, group: groups.shared) as CFDictionary)
            SecItemDelete(keychainQuery(for: key, group: groups.app) as CFDictionary)
            SecItemDelete(keychainQuery(for: key, group: groups.app, service: sdkService) as CFDictionary)
        }
    }

    func testReadingLegacySDKSessionMovesSessionAndVerifierOutOfSharedGroup() throws {
        let project = UUID().uuidString.lowercased()
        let key = "sb-\(project)-auth-token"
        let verifierKey = "\(key)-code-verifier"
        let groups = try keychainGroups()
        let sharedSession = keychainQuery(for: key, group: groups.shared)
        let sharedVerifier = keychainQuery(for: verifierKey, group: groups.shared)
        let widgetItem = keychainQuery(for: key, group: groups.shared,
                                       service: "systems.edmundlim.reminders.shared-session")
        let legacy = KeychainLocalStorage(accessGroup: groups.shared)
        let oldAppStorage = KeychainLocalStorage(accessGroup: groups.app)
        let original = session(userID: UUID())
        let verifier = Data("fixture-verifier".utf8)
        let widgetCredential = Data("fixture-widget-credential".utf8)
        defer {
            deleteSDKFixtures([key, verifierKey], groups: groups)
            SecItemDelete(widgetItem as CFDictionary)
        }
        // Before Keychain sharing, the SDK could write the same account in the app ID group.
        let older = try JSONEncoder().encode(session(userID: UUID()))
        try oldAppStorage.store(key: key, value: older)
        try legacy.store(key: key, value: JSONEncoder().encode(original))
        try legacy.store(key: verifierKey, value: verifier)
        let widgetAttributes = widgetItem.merging([kSecValueData as String: widgetCredential]) { _, new in new }
        XCTAssertEqual(SecItemAdd(widgetAttributes as CFDictionary, nil), errSecSuccess)
        let before = try keychainAttributes(sharedSession)
        XCTAssertEqual(try keychainAttributes(sharedVerifier)[kSecValueData as String] as? Data, verifier)
        XCTAssertEqual(before[kSecAttrAccessible as String] as? String, kSecAttrAccessibleAfterFirstUnlock as String)
        let reference = try XCTUnwrap(before[kSecValuePersistentRef as String] as? Data)

        let client = AuthSessionClient(supabaseURL: URL(string: "https://\(project).invalid")!, supabaseKey: anonKey)
        XCTAssertEqual(client.auth.currentSession?.refreshToken, original.refreshToken)
        let after = try keychainAttributes(keychainQuery(for: key, group: groups.app, service: sdkService))
        XCTAssertEqual(after[kSecValuePersistentRef as String] as? Data, reference)
        XCTAssertEqual(after[kSecAttrAccessible as String] as? String, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
        let movedVerifier = try keychainAttributes(keychainQuery(for: verifierKey, group: groups.app, service: sdkService))
        XCTAssertEqual(movedVerifier[kSecValueData as String] as? Data, verifier)
        XCTAssertEqual(movedVerifier[kSecAttrAccessible as String] as? String, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
        XCTAssertEqual(SecItemCopyMatching(sharedSession as CFDictionary, nil), errSecItemNotFound)
        XCTAssertEqual(SecItemCopyMatching(sharedVerifier as CFDictionary, nil), errSecItemNotFound)
        XCTAssertEqual(try keychainAttributes(widgetItem)[kSecValueData as String] as? Data, widgetCredential)
        XCTAssertEqual(try oldAppStorage.retrieve(key: key), older)

        try DeviceOnlyAuthStorage().remove(key: key)
        XCTAssertNil(try DeviceOnlyAuthStorage().retrieve(key: key))
    }

    func testOldAppPrivateRecordCanStillBeRead() throws {
        let key = "sb-\(UUID())-auth-token"
        let groups = try keychainGroups()
        defer { deleteSDKFixtures([key], groups: groups) }
        let credential = Data("fixture-private-credential".utf8)
        try KeychainLocalStorage(accessGroup: groups.app).store(key: key, value: credential)
        XCTAssertEqual(try DeviceOnlyAuthStorage().retrieve(key: key), credential)
    }

    func testNewSDKCredentialsArePrivateAndDeviceOnly() async throws {
        let project = UUID().uuidString.lowercased()
        let key = "sb-\(project)-auth-token"
        let verifierKey = "\(key)-code-verifier"
        let groups = try keychainGroups()
        defer { deleteSDKFixtures([key, verifierKey], groups: groups) }
        let payload = try AuthClient.Configuration.jsonEncoder.encode(session(userID: UUID()))
        let client = AuthSessionClient(
            supabaseURL: URL(string: "https://\(project).invalid")!, supabaseKey: anonKey,
            authFetch: { request in
                (payload, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                          headerFields: ["Content-Type": "application/json"])!)
            }
        )
        _ = try await client.auth.signIn(email: "user@example.invalid", password: "fixture-only")
        _ = try client.auth.getOAuthSignInURL(provider: .google)
        for account in [key, verifierKey] {
            let attributes = try keychainAttributes(keychainQuery(for: account, group: groups.app, service: sdkService))
            XCTAssertEqual(attributes[kSecAttrAccessible as String] as? String,
                           kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
            let sharedItem = keychainQuery(for: account, group: groups.shared)
            XCTAssertEqual(SecItemCopyMatching(sharedItem as CFDictionary, nil), errSecItemNotFound)
        }
    }

    func testConstructingClientDoesNotStartAnSDKInitialRefreshOutsideGate() async throws {
        let storage = MemoryStorage()
        try storage.store(key: key, value: JSONEncoder().encode(session(userID: UUID(), expired: true)))
        let unexpectedRead = expectation(description: "No SDK-owned initial-session subscription")
        unexpectedRead.isInverted = true
        storage.observeReads { unexpectedRead.fulfill() }
        let network = noNetworkSession()
        defer { network.invalidateAndCancel() }
        let client = AuthSessionClient(supabaseURL: endpoint, supabaseKey: anonKey, storage: storage,
                                       authFetch: { _ in throw URLError(.notConnectedToInternet) },
                                       globalSession: network)
        await fulfillment(of: [unexpectedRead], timeout: 0.25)
        storage.observeReads(nil)
        // Keep the actual pinned SDK clients alive throughout the observation window.
        XCTAssertNotNil(client.auth.currentSession)
    }

    func testPinnedSDKInitialRefreshFinishesBeforeCleanupAndSuccessfulBSignIn() async throws {
        let storage = MemoryStorage()
        let accountA = UUID()
        let accountB = UUID()
        let refreshedA = session(userID: accountA)
        let signedInB = session(userID: accountB)
        try storage.store(key: key, value: JSONEncoder().encode(session(userID: accountA, expired: true)))
        let gate = AuthSessionGate()
        let refreshStarted = expectation(description: "Gated initial emission refreshes A")
        var finishRefresh: CheckedContinuation<Void, Never>?
        var order: [String] = []
        let network = noNetworkSession()
        defer { network.invalidateAndCancel() }
        let client = AuthSessionClient(
            supabaseURL: endpoint, supabaseKey: anonKey, storage: storage,
            authFetch: { request in
                let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                               httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
                if components?.queryItems?.contains(where: { $0.value == "refresh_token" }) == true {
                    await withCheckedContinuation { pending in
                        Task { @MainActor in
                            finishRefresh = pending
                            refreshStarted.fulfill()
                        }
                    }
                    await MainActor.run { order.append("refresh-A") }
                    return (try AuthClient.Configuration.jsonEncoder.encode(refreshedA), response)
                }
                if request.url?.path.hasSuffix("/logout") == true {
                    await MainActor.run { order.append("sign-out-A") }
                    return (Data("{}".utf8), response)
                }
                if components?.queryItems?.contains(where: { $0.value == "password" }) == true {
                    await MainActor.run { order.append("install-B") }
                    return (try AuthClient.Configuration.jsonEncoder.encode(signedInB), response)
                }
                throw URLError(.unsupportedURL)
            }, globalSession: network
        )
        let initial = Task {
            await gate.withLock { await client.auth.onAuthStateChange { _, _ in } }
        }
        // A cold CI simulator can stall while the SDK starts its first refresh.
        // The continuation below controls the race; startup latency is not under test.
        await fulfillment(of: [refreshStarted], timeout: 30)
        guard let finishRefresh else {
            initial.cancel()
            XCTFail("The SDK did not start the expected initial refresh")
            return
        }
        var cacheAccount: UUID? = accountA
        let cleanupQueued = expectation(description: "Cleanup queued")
        let operations = AuthSessionGate.CleanupOperations(
            setEndingSession: { _ in },
            pauseRegistration: { order.append("pause") },
            resumeRegistration: { order.append("resume") },
            unbind: {}, removeDeviceToken: {},
            signOutSDK: { try? await client.auth.signOut() }, clearPublishedSession: {},
            clearUserData: { cacheAccount = nil }, clearBoard: {}
        )
        let cleanup = Task {
            cleanupQueued.fulfill()
            await gate.cleanUp(operations: operations)
        }
        await fulfillment(of: [cleanupQueued], timeout: 2)
        let callbackQueued = expectation(description: "B sign-in queued")
        let replacement = Task {
            callbackQueued.fulfill()
            return try await gate.withLock {
                let next = try await client.auth.signIn(email: "b@example.invalid", password: "fixture-only")
                cacheAccount = next.user.id
                return next
            }
        }
        await fulfillment(of: [callbackQueued], timeout: 2)
        XCTAssertTrue(order.isEmpty)
        finishRefresh.resume()
        let registration = await initial.value
        defer { registration.remove() }
        await cleanup.value
        let completedB = try await replacement.value
        XCTAssertEqual(completedB.user.id, accountB)
        XCTAssertEqual(client.auth.currentSession?.user.id, accountB)
        XCTAssertEqual(cacheAccount, accountB)
        XCTAssertEqual(order, ["refresh-A", "pause", "sign-out-A", "resume", "install-B"])
    }
}
