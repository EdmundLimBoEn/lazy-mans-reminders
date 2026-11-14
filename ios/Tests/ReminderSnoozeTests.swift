import Foundation
import XCTest
@testable import LazyMansReminders

final class ReminderSnoozeTests: XCTestCase {
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    private func calendar(_ zone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    func testThreeHoursIsElapsedTimeAcrossDST() {
        let now = date("2026-03-08T06:30:00Z")
        XCTAssertEqual(ReminderSnooze.threeHours.until(now: now, calendar: calendar("America/New_York")),
                       date("2026-03-08T09:30:00Z"))
    }

    func testTonightUsesLocalEightAndFallsBackToOneHourAfterEight() {
        let singapore = calendar("Asia/Singapore")
        for (now, expected) in [
            ("2026-11-14T03:00:00Z", "2026-11-14T12:00:00Z"),
            ("2026-11-14T12:00:00Z", "2026-11-14T12:00:00Z"),
            ("2026-11-14T12:00:01Z", "2026-11-14T13:00:01Z"),
            ("2026-11-14T15:30:00Z", "2026-11-14T16:30:00Z")
        ] {
            XCTAssertEqual(ReminderSnooze.tonight.until(now: date(now), calendar: singapore), date(expected))
        }
    }

    func testTomorrowUsesNextLocalDayAtNineIncludingDSTAndYearBoundary() {
        for (zone, now, expected) in [
            ("Asia/Singapore", "2026-12-31T15:30:00Z", "2027-01-01T01:00:00Z"),
            ("America/New_York", "2026-03-07T17:00:00Z", "2026-03-08T13:00:00Z"),
            ("America/New_York", "2026-10-31T16:00:00Z", "2026-11-01T14:00:00Z")
        ] {
            XCTAssertEqual(ReminderSnooze.tomorrow.until(now: date(now), calendar: calendar(zone)), date(expected))
        }
    }

    func testOptionalSnoozeDecodingAndVisibilityBoundary() throws {
        let now = date("2026-11-14T12:00:00Z")
        let legacy = """
        {"id":"11111111-1111-4111-8111-111111111111","user_id":"22222222-2222-4222-8222-222222222222",
         "text":"Test","sort_order":0,"is_done":false,"created_at":"2026-11-14T11:00:00Z"}
        """
        var reminder = try ReminderJSON.decoder.decode(Reminder.self, from: Data(legacy.utf8))
        XCTAssertNil(reminder.snoozedUntil)
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(legacy.utf8)) as? [String: Any])
        payload["snoozed_until"] = "2026-11-14T12:00:00Z"
        let serverRow = try ReminderJSON.decoder.decode(Reminder.self, from: JSONSerialization.data(withJSONObject: payload))
        XCTAssertEqual(serverRow.snoozedUntil, now)
        XCTAssertTrue(reminder.isVisible(at: now))
        for offset in [-1.0, 0, 1] {
            reminder.snoozedUntil = now.addingTimeInterval(offset)
            let decoded = try ReminderJSON.decoder.decode(Reminder.self, from: ReminderJSON.encoder.encode(reminder))
            XCTAssertEqual(decoded.snoozedUntil, reminder.snoozedUntil)
            XCTAssertEqual(decoded.isVisible(at: now), offset <= 0)
        }
        reminder.isDone = true
        reminder.snoozedUntil = nil
        XCTAssertFalse(reminder.isVisible(at: now))
    }
}
