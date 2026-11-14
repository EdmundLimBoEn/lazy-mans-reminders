import XCTest
@testable import LazyMansReminders

final class RoutineScheduleTests: XCTestCase {
    private func instant(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

    func testWeeklyStartMatchesEveryWebFixture() throws {
        let fixtures: [(String, String, Int, String)] = [
            ("UTC", "2026-10-13T12:00:00Z", 1, "2026-10-19"),
            ("UTC", "2026-10-12T20:00:00Z", 1, "2026-10-12"),
            ("UTC", "2026-12-31T23:00:00Z", 1, "2027-01-04"),
            ("America/New_York", "2026-10-26T01:00:00Z", 0, "2026-10-25"),
            ("Asia/Bangkok", "2026-10-25T23:00:00Z", 0, "2026-11-01"),
            ("Pacific/Kiritimati", "2026-12-31T12:00:00Z", 5, "2027-01-01"),
            ("America/New_York", "2027-01-01T01:00:00Z", 4, "2026-12-31"),
            ("America/New_York", "2026-03-08T04:30:00Z", 0, "2026-03-08"),
            ("America/New_York", "2026-11-01T03:30:00Z", 1, "2026-11-02")
        ]
        for (zone, now, weekday, expected) in fixtures {
            XCTAssertEqual(try RoutineSchedule.weeklyStartDate(weekday: weekday, timezone: zone,
                                                              now: instant(now)), expected, "\(zone): \(now)")
        }
        XCTAssertEqual(RoutineSchedule.weekdays,
                       ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"])
    }

    func testLocalDateKeepsCalendarDateAcrossYearBoundary() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let local = calendar.date(from: DateComponents(year: 2026, month: 12, day: 31, hour: 23))!
        XCTAssertEqual(RoutineSchedule.localDate(local), "2026-12-31")
        XCTAssertEqual(RoutineSchedule.localDate(instant("2026-12-31T12:00:00Z"),
                                                 timezone: TimeZone(identifier: "Pacific/Kiritimati")!), "2027-01-01")
    }

    func testSummaryParityAndDailyChoice() {
        var routine = sample()
        XCTAssertEqual(RoutineSchedule.summary(routine), "Every Monday at 19:00 · Asia/Singapore")
        routine.intervalDays = 3
        XCTAssertEqual(RoutineSchedule.summary(routine), "Every 3 days at 19:00 · Asia/Singapore")
        routine.intervalDays = 1
        routine.localTime = "19:00"
        XCTAssertEqual(RoutineSchedule.summary(routine), "Every day at 19:00 · Asia/Singapore")
    }

    func testDecodeTimesAndISOTimestamps() throws {
        for time in ["19:00", "19:00:00"] {
            for timestamp in ["2026-10-12T11:00:00Z", "2026-10-12T11:00:00.123456+00:00"] {
                let json = """
                {"id":"11111111-1111-4111-8111-111111111111","text":"Uniform",
                 "interval_days":7,"start_date":"2026-10-12","local_time":"\(time)",
                 "timezone":"Asia/Singapore","enabled":true,"next_run_at":"\(timestamp)"}
                """
                let routine = try ReminderJSON.decoder.decode(Routine.self, from: Data(json.utf8))
                XCTAssertEqual(routine.localTime, time)
                XCTAssertEqual(routine.nextRunAt.timeIntervalSince1970,
                               instant("2026-10-12T11:00:00Z").timeIntervalSince1970, accuracy: 0.2)
                XCTAssertEqual(RoutineDraft(routine: routine).hour, 19)
                XCTAssertEqual(RoutineDraft(routine: routine).minute, 0)
            }
        }
    }

    func testWeeklyEditRetainsStartForTextOrTimeButRecomputesChangedSchedule() throws {
        let now = instant("2026-11-14T12:00:00Z")
        var draft = RoutineDraft(routine: sample())
        XCTAssertFalse(draft.weeklyStartChanged)
        draft.text = " New text "
        draft.hour = 20
        let values = try draft.values(now: now)
        XCTAssertEqual(values.startDate, "2026-10-12")
        XCTAssertEqual(values.text, "New text")
        XCTAssertEqual(values.localTime, "20:00:00")
        var future = sample()
        future.startDate = "2027-01-04"
        XCTAssertEqual(try RoutineDraft(routine: future).values(now: now).startDate, "2027-01-04")
        draft.weekday = 2
        XCTAssertEqual(try draft.values(now: now).startDate, "2026-11-17")
        draft = RoutineDraft(routine: sample())
        draft.timezone = "America/New_York"
        XCTAssertEqual(try draft.values(now: now).startDate, "2026-11-16")
        draft = RoutineDraft(routine: sample())
        draft.cadence = .days
        draft.cadence = .weekly
        XCTAssertEqual(try draft.values(now: now).startDate, "2026-11-16")
        // Like the web's sticky weeklyStartChanged, changing back still recomputes.
        draft = RoutineDraft(routine: sample())
        draft.weekday = 2
        draft.weekday = 1
        XCTAssertEqual(try draft.values(now: now).startDate, "2026-11-16")
    }

    func testNewDailyStartsTodayInChosenZoneAndIntervalsKeepChosenStart() throws {
        var draft = RoutineDraft(timezone: TimeZone(identifier: "Pacific/Kiritimati")!)
        draft.text = "Daily"
        let values = try draft.values(now: instant("2026-12-31T12:00:00Z"))
        XCTAssertEqual(values.intervalDays, 1)
        XCTAssertEqual(values.startDate, "2027-01-01")
        draft.cadence = .days
        draft.days = "365"
        draft.startDate = "2027-02-01"
        XCTAssertEqual(try draft.values().intervalDays, 365)
        XCTAssertEqual(try draft.values().startDate, "2027-02-01")
    }

    func testValidationMatchesServerBoundsAndDoesNotSilentlyTruncate() throws {
        var draft = RoutineDraft()
        XCTAssertThrowsError(try draft.values())
        draft.text = String(repeating: "a", count: 500)
        XCTAssertNoThrow(try draft.values())
        draft.text += "a"
        XCTAssertThrowsError(try draft.values())
        draft.text = "Valid"
        draft.timezone = "not/a-zone"
        XCTAssertThrowsError(try draft.values()) { error in
            XCTAssertEqual(error.localizedDescription, "Enter a valid timezone, such as Asia/Singapore.")
        }
        draft.timezone = "UTC"
        draft.cadence = .days
        for days in ["0", "366", "1.5", ""] {
            draft.days = days
            XCTAssertThrowsError(try draft.values())
        }
        draft.days = "1"
        draft.startDate = "2026-02-30"
        XCTAssertThrowsError(try draft.values())
    }

    func testNextRunUsesRoutineTimezoneAndPausedHasNoNextLine() {
        var routine = sample()
        let label = RoutineSchedule.status(routine, locale: Locale(identifier: "en_US_POSIX"))
        XCTAssertTrue(label.contains("7:00"), label)
        XCTAssertTrue(label.hasSuffix("· Asia/Singapore"))
        routine.enabled = false
        XCTAssertEqual(RoutineSchedule.status(routine), "Paused")
    }

    func testEmptyStateRequiresSuccessfulEmptyRead() {
        XCTAssertTrue(RoutinePresentation.showsEmpty(isLoading: false, hasLoaded: true, count: 0, loadFailed: false))
        XCTAssertFalse(RoutinePresentation.showsEmpty(isLoading: true, hasLoaded: false, count: 0, loadFailed: false))
        XCTAssertFalse(RoutinePresentation.showsEmpty(isLoading: false, hasLoaded: false, count: 0, loadFailed: true))
        XCTAssertFalse(RoutinePresentation.showsEmpty(isLoading: false, hasLoaded: true, count: 0, loadFailed: true))
        XCTAssertFalse(RoutinePresentation.showsEmpty(isLoading: false, hasLoaded: true, count: 1, loadFailed: false))
    }

    private func sample() -> Routine {
        Routine(id: UUID(), text: "Uniform", intervalDays: 7, startDate: "2026-10-12", localTime: "19:00:00",
                timezone: "Asia/Singapore", enabled: true, nextRunAt: instant("2026-10-12T11:00:00Z"))
    }
}
