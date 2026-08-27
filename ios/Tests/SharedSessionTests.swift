import XCTest
@testable import LazyMansReminders

final class SharedSessionTests: XCTestCase {
    func testIsFreshUsesLeeway() {
        let now = Date(timeIntervalSince1970: 1_775_000_000)
        let fresh = SharedSession(
            accessToken: "a",
            expiresAt: now.addingTimeInterval(120),
            refreshToken: "r"
        )
        let expiring = SharedSession(
            accessToken: "a",
            expiresAt: now.addingTimeInterval(30),
            refreshToken: "r"
        )
        let expired = SharedSession(
            accessToken: "a",
            expiresAt: now.addingTimeInterval(-1),
            refreshToken: "r"
        )

        XCTAssertTrue(fresh.isFresh(at: now))
        XCTAssertFalse(expiring.isFresh(at: now))
        XCTAssertTrue(expiring.isFresh(at: now, leeway: 0))
        XCTAssertFalse(expired.isFresh(at: now, leeway: 0))
    }

    func testDecodesLegacySessionWithoutRefreshToken() throws {
        let payload = """
        {"accessToken":"legacy","expiresAt":566000000}
        """.data(using: .utf8)!
        let session = try JSONDecoder().decode(SharedSession.self, from: payload)
        XCTAssertEqual(session.accessToken, "legacy")
        XCTAssertNil(session.refreshToken)
    }

    func testTokenRefreshResponsePrefersExpiresAtUnix() throws {
        let json = """
        {
          "access_token": "new-access",
          "refresh_token": "new-refresh",
          "expires_at": 1775000000,
          "expires_in": 3600
        }
        """.data(using: .utf8)!

        let payload = try JSONDecoder().decode(TokenRefreshResponse.self, from: json)
        let session = payload.makeSession(
            fallbackRefreshToken: "old-refresh",
            now: Date(timeIntervalSince1970: 1)
        )

        XCTAssertEqual(session.accessToken, "new-access")
        XCTAssertEqual(session.refreshToken, "new-refresh")
        XCTAssertEqual(session.expiresAt, Date(timeIntervalSince1970: 1_775_000_000))
    }

    func testTokenRefreshResponseFallsBackToExpiresInAndOldRefreshToken() throws {
        let json = """
        {
          "access_token": "new-access",
          "expires_in": 120
        }
        """.data(using: .utf8)!

        let now = Date(timeIntervalSince1970: 1_000)
        let payload = try JSONDecoder().decode(TokenRefreshResponse.self, from: json)
        let session = payload.makeSession(fallbackRefreshToken: "old-refresh", now: now)

        XCTAssertEqual(session.refreshToken, "old-refresh")
        XCTAssertEqual(session.expiresAt, now.addingTimeInterval(120))
    }
}
