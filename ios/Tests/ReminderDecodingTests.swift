import XCTest
@testable import LazyMansReminders

final class ReminderDecodingTests: XCTestCase {
    func testDecodesSupabaseSnakeCasePayloadWithFractionalSeconds() throws {
        let json = """
        {
          "id": "11111111-1111-4111-8111-111111111111",
          "user_id": "22222222-2222-4222-8222-222222222222",
          "text": "Book dentist",
          "sort_order": 3,
          "is_done": false,
          "created_at": "2026-08-07T12:34:56.789Z"
        }
        """.data(using: .utf8)!

        let reminder = try ReminderJSON.decoder.decode(Reminder.self, from: json)

        XCTAssertEqual(reminder.id.uuidString.lowercased(), "11111111-1111-4111-8111-111111111111")
        XCTAssertEqual(reminder.userID.uuidString.lowercased(), "22222222-2222-4222-8222-222222222222")
        XCTAssertEqual(reminder.text, "Book dentist")
        XCTAssertEqual(reminder.sortOrder, 3)
        XCTAssertFalse(reminder.isDone)

        let components = Calendar(identifier: .gregorian).dateComponents(
            in: TimeZone(secondsFromGMT: 0)!,
            from: reminder.createdAt
        )
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 8)
        XCTAssertEqual(components.day, 7)
        XCTAssertEqual(components.hour, 12)
        XCTAssertEqual(components.minute, 34)
        XCTAssertEqual(components.second, 56)
    }

    func testDecodesTimestampWithoutFractionalSeconds() throws {
        let json = """
        {
          "id": "11111111-1111-4111-8111-111111111111",
          "user_id": "22222222-2222-4222-8222-222222222222",
          "text": "Send invoice",
          "sort_order": 0,
          "is_done": true,
          "created_at": "2026-01-02T03:04:05Z"
        }
        """.data(using: .utf8)!

        let reminder = try ReminderJSON.decoder.decode(Reminder.self, from: json)
        XCTAssertTrue(reminder.isDone)
        XCTAssertEqual(reminder.sortOrder, 0)
    }

    func testRoundTripsThroughReminderJSONEncoder() throws {
        let original = Reminder(
            id: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
            userID: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!,
            text: "Round trip",
            sortOrder: 7,
            isDone: false,
            createdAt: Date(timeIntervalSince1970: 1_775_000_000)
        )

        let data = try ReminderJSON.encoder.encode(original)
        let decoded = try ReminderJSON.decoder.decode(Reminder.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testRejectsInvalidCreatedAt() {
        let json = """
        {
          "id": "11111111-1111-4111-8111-111111111111",
          "user_id": "22222222-2222-4222-8222-222222222222",
          "text": "Bad date",
          "sort_order": 0,
          "is_done": false,
          "created_at": "not-a-date"
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try ReminderJSON.decoder.decode(Reminder.self, from: json))
    }

    func testDecodesReminderArrayForCacheShape() throws {
        let json = """
        [
          {
            "id": "11111111-1111-4111-8111-111111111111",
            "user_id": "22222222-2222-4222-8222-222222222222",
            "text": "One",
            "sort_order": 0,
            "is_done": false,
            "created_at": "2026-08-07T00:00:00Z"
          },
          {
            "id": "33333333-3333-4333-8333-333333333333",
            "user_id": "22222222-2222-4222-8222-222222222222",
            "text": "Two",
            "sort_order": 1,
            "is_done": false,
            "created_at": "2026-08-07T00:00:01Z"
          }
        ]
        """.data(using: .utf8)!

        let reminders = try ReminderJSON.decoder.decode([Reminder].self, from: json)
        XCTAssertEqual(reminders.count, 2)
        XCTAssertEqual(reminders.map(\.text), ["One", "Two"])
    }
}

/*
 ReminderStore is an actor backed by App Group UserDefaults + live network calls.
 Unit-testing cache/session behavior here would require injectable defaults/URLSession
 (and a configured App Group on the simulator). Prefer ReminderJSON Codable coverage above;
 store integration belongs in a device/UI test later.
 */
