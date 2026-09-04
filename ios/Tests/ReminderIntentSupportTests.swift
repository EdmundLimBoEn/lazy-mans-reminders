import XCTest
@testable import LazyMansReminders

final class ReminderIntentSupportTests: XCTestCase {
    func testJWTExtractsSubAsUUID() {
        let token = "aaa.eyJzdWIiOiIyMjIyMjIyMi0yMjIyLTQyMjItODIyMi0yMjIyMjIyMjIyMjIifQ.bbb"
        XCTAssertEqual(
            JWTUserID.uuid(fromAccessToken: token)?.uuidString.lowercased(),
            "22222222-2222-4222-8222-222222222222"
        )
    }

    func testJWTRejectsMalformedTokens() {
        XCTAssertNil(JWTUserID.uuid(fromAccessToken: "not-a-jwt"))
        XCTAssertNil(JWTUserID.uuid(fromAccessToken: "only.one"))
        XCTAssertNil(JWTUserID.uuid(fromAccessToken: "aaa.!!!.bbb"))
    }

    func testJWTRejectsNonUUIDSub() {
        // {"sub":"not-a-uuid"}
        let token = "aaa.eyJzdWIiOiJub3QtYS11dWlkIn0.bbb"
        XCTAssertNil(JWTUserID.uuid(fromAccessToken: token))
    }

    func testTitleMatcherExactThenSubstringThenPrefix() {
        let milk = reminder(text: "Buy milk")
        let mail = reminder(text: "Mail taxes")
        let eggs = reminder(text: "Eggs")
        let done = reminder(text: "Buy milk", isDone: true)
        let all = [milk, mail, eggs, done]

        XCTAssertEqual(ReminderTitleMatcher.matches(all, query: "Buy milk").map(\.text), ["Buy milk"])
        XCTAssertEqual(ReminderTitleMatcher.matches(all, query: "milk").map(\.text), ["Buy milk"])
        XCTAssertEqual(ReminderTitleMatcher.matches(all, query: "mail").map(\.text), ["Mail taxes"])
        XCTAssertEqual(ReminderTitleMatcher.matches(all, query: "").map(\.text), ["Buy milk", "Mail taxes", "Eggs"])
        XCTAssertTrue(ReminderTitleMatcher.matches(all, query: "gym").isEmpty)
    }

    func testSpokenDialogForEmptyOneTwoAndMany() {
        XCTAssertEqual(ReminderListSpoken.joinedTitles([]), "Your board is empty.")
        XCTAssertEqual(
            ReminderListSpoken.joinedTitles(["Milk"]),
            "You have one reminder: Milk."
        )
        XCTAssertEqual(
            ReminderListSpoken.joinedTitles(["Milk", "Eggs"]),
            "You have two reminders: Milk and Eggs."
        )
        XCTAssertEqual(
            ReminderListSpoken.joinedTitles(["Milk", "Eggs", "Keys"]),
            "You have three reminders: Milk, Eggs, and Keys."
        )
    }

    func testSpokenDialogIgnoresCompletedRows() {
        let spoken = ReminderListSpoken.dialog(for: [
            reminder(text: "Milk"),
            reminder(text: "Old", isDone: true)
        ])
        XCTAssertEqual(spoken, "You have one reminder: Milk.")
    }

    func testSharedSessionResolvesUserIDFromJWT() {
        let token = "aaa.eyJzdWIiOiIyMjIyMjIyMi0yMjIyLTQyMjItODIyMi0yMjIyMjIyMjIyMjIifQ.bbb"
        let session = SharedSession(
            accessToken: token,
            expiresAt: Date(timeIntervalSince1970: 2_000_000_000),
            refreshToken: "r"
        )
        XCTAssertNil(session.userID)
        XCTAssertEqual(
            session.resolvingUserID().userID?.uuidString.lowercased(),
            "22222222-2222-4222-8222-222222222222"
        )
    }

    func testTokenRefreshResponseDecodesUserIDFromAccessToken() throws {
        let token = "aaa.eyJzdWIiOiIyMjIyMjIyMi0yMjIyLTQyMjItODIyMi0yMjIyMjIyMjIyMjIifQ.bbb"
        let json = """
        {
          "access_token": "\(token)",
          "refresh_token": "new-refresh",
          "expires_in": 120
        }
        """.data(using: .utf8)!

        let payload = try JSONDecoder().decode(TokenRefreshResponse.self, from: json)
        let session = payload.makeSession(
            fallbackRefreshToken: "old-refresh",
            now: Date(timeIntervalSince1970: 1_000)
        )

        XCTAssertEqual(session.refreshToken, "new-refresh")
        XCTAssertEqual(
            session.userID?.uuidString.lowercased(),
            "22222222-2222-4222-8222-222222222222"
        )
    }

    func testLegacySessionWithoutUserIDStillDecodes() throws {
        let payload = """
        {"accessToken":"legacy","expiresAt":566000000}
        """.data(using: .utf8)!
        let session = try JSONDecoder().decode(SharedSession.self, from: payload)
        XCTAssertNil(session.userID)
        XCTAssertNil(session.refreshToken)
    }

    private func reminder(text: String, isDone: Bool = false) -> Reminder {
        Reminder(
            id: UUID(),
            userID: UUID(),
            text: text,
            sortOrder: 0,
            isDone: isDone,
            createdAt: .now
        )
    }
}
