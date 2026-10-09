import Foundation
import Supabase
import XCTest
@testable import LazyMansReminders

@MainActor
final class AuthSessionClientTests: XCTestCase {
    private let endpoint = URL(string: "https://credential-test.invalid")!
    private let key = "sb-credential-test-auth-token"
    private let anonKey = "eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoiYW5vbiJ9.test-signature"

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
        await fulfillment(of: [refreshStarted], timeout: 2)
        guard let finishRefresh else {
            initial.cancel()
            XCTFail("The SDK did not start the expected initial refresh")
            return
        }
        var cacheAccount: UUID? = accountA
        let cleanupQueued = expectation(description: "Cleanup queued")
        let operations = AuthSessionGate.CleanupOperations(
            setEndingSession: { _ in }, unbind: {}, removeDeviceToken: {},
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
        XCTAssertEqual(order, ["refresh-A", "sign-out-A", "install-B"])
    }
}
