import Foundation
import XCTest
@testable import LazyMansReminders

final class ReminderStoreTokenRefreshTests: XCTestCase {
    func testOverlappingSessionLoadsShareOneRefreshGrant() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let extraGrant = expectation(description: "second refresh grant")
        extraGrant.isInverted = true
        let network = GrantNetwork(firstStarted: fixture.started, extraGrant: extraGrant)
        let store = fixture.makeStore(network)
        let userID = UUID()
        try await store.saveSession(
            accessToken: "old-access", refreshToken: "R1",
            expiresAt: Date().addingTimeInterval(45), userID: userID
        )

        let first = Task { await store.isSignedIn() }
        await fulfillment(of: [fixture.started], timeout: 3)
        let second = Task { await store.isSignedIn() }
        await fulfillment(of: [extraGrant], timeout: 0.3)
        try await network.finishFirst(accessToken: "new-access", refreshToken: "R2")

        let firstSignedIn = await first.value
        let secondSignedIn = await second.value
        XCTAssertTrue(firstSignedIn)
        XCTAssertTrue(secondSignedIn)
        let grants = await network.grantTokens
        XCTAssertEqual(grants, ["R1"])
        let rotated = await store.containsSession(accessToken: "new-access", refreshToken: "R2")
        XCTAssertTrue(rotated)
    }

    func testStaleHostSessionCannotReplaceAFreshRotatedRefreshToken() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let store = fixture.makeStore()
        let userID = UUID()
        try await store.saveSession(
            accessToken: "old-access", refreshToken: "R1",
            expiresAt: Date().addingTimeInterval(-60), userID: userID
        )
        try await store.saveSession(
            accessToken: "new-access", refreshToken: "R2",
            expiresAt: Date().addingTimeInterval(3600), userID: userID
        )
        try await store.saveSession(
            accessToken: "old-access", refreshToken: "R1",
            expiresAt: Date().addingTimeInterval(-60), userID: userID
        )
        let keptRotated = await store.containsSession(accessToken: "new-access", refreshToken: "R2")
        XCTAssertTrue(keptRotated)
        let keptRefresh = await store.freshSession(for: userID)?.refreshToken
        XCTAssertEqual(keptRefresh, "R2")
    }

    private actor GrantNetwork {
        let firstStarted: XCTestExpectation
        let extraGrant: XCTestExpectation
        private(set) var grantTokens: [String] = []
        private var pending: CheckedContinuation<(Data, URLResponse), Error>?

        init(firstStarted: XCTestExpectation, extraGrant: XCTestExpectation) {
            self.firstStarted = firstStarted
            self.extraGrant = extraGrant
        }

        func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
            XCTAssertEqual(request.url?.path, "/auth/v1/token")
            let body = try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: String]
            let token = try XCTUnwrap(body?["refresh_token"])
            grantTokens.append(token)
            if grantTokens.count > 1 {
                extraGrant.fulfill()
                return (
                    Data(),
                    HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
                )
            }
            return try await withCheckedThrowingContinuation { continuation in
                pending = continuation
                firstStarted.fulfill()
            }
        }

        func finishFirst(accessToken: String, refreshToken: String) throws {
            let data = try JSONSerialization.data(withJSONObject: [
                "access_token": accessToken,
                "refresh_token": refreshToken,
                "expires_in": 3600,
            ])
            guard let pending else {
                XCTFail("Expected suspended refresh grant")
                return
            }
            self.pending = nil
            pending.resume(returning: (
                data,
                HTTPURLResponse(
                    url: URL(string: "https://reminders.invalid/auth/v1/token")!,
                    statusCode: 200, httpVersion: nil, headerFields: nil
                )!
            ))
        }
    }

    private struct Fixture {
        let suite = "ReminderStoreTokenRefreshTests.\(UUID())"
        let defaults: UserDefaults
        let credentials = MemorySessionCredentials()
        let started: XCTestExpectation

        init() {
            defaults = UserDefaults(suiteName: suite)!
            started = XCTestExpectation(description: "Refresh grant suspended")
        }

        func makeStore(_ network: GrantNetwork) -> ReminderStore {
            ReminderStore(
                defaults: defaults, credentials: credentials,
                serviceURL: URL(string: "https://reminders.invalid")!,
                anonKey: "test-key",
                requestData: { try await network.send($0) }
            )
        }

        func makeStore() -> ReminderStore {
            ReminderStore(
                defaults: defaults, credentials: credentials,
                serviceURL: URL(string: "https://reminders.invalid")!,
                anonKey: "test-key",
                requestData: { _ in throw URLError(.notConnectedToInternet) }
            )
        }

        func cleanUp() { defaults.removePersistentDomain(forName: suite) }
    }
}
