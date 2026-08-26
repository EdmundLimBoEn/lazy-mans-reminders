import XCTest
@testable import LazyMansReminders

final class ReminderPresentationTests: XCTestCase {
    private func reminder(text: String, sortOrder: Int = 0) -> Reminder {
        Reminder(
            id: UUID(),
            userID: UUID(),
            text: text,
            sortOrder: sortOrder,
            isDone: false,
            createdAt: .now
        )
    }

    func testDisplayLinesHonorCustomLimit() {
        let reminders = (0..<6).map { reminder(text: "Item \($0)", sortOrder: $0) }
        let lines = ReminderActivityPresentation.displayLines(from: reminders, limit: 3)
        XCTAssertEqual(lines, ["Item 0", "Item 1", "+4 more"])
    }

    func testEmptyBoardProducesNoLiveActivityLines() {
        XCTAssertTrue(ReminderActivityPresentation.lines(from: []).isEmpty)
    }

    func testDisplayLinesIncludeEmptyPlaceholder() {
        XCTAssertEqual(
            ReminderActivityPresentation.displayLines(from: []),
            ["Nothing to remember"]
        )
    }

    func testNewlinesBecomeSeparateLinesThenCap() {
        let reminders = [
            reminder(text: "a\nb\nc", sortOrder: 0),
            reminder(text: "d", sortOrder: 1),
        ]
        let lines = ReminderActivityPresentation.displayLines(from: reminders, limit: 3)
        XCTAssertEqual(lines, ["a", "b", "+2 more"])
    }

    func testLineBudgetScalesWithTallerScreens() {
        let se = LockScreenLineBudget.computeMaxLines(screenHeight: 667)
        let proMax = LockScreenLineBudget.computeMaxLines(screenHeight: 932)
        XCTAssertGreaterThanOrEqual(se, 1)
        XCTAssertGreaterThanOrEqual(proMax, se)
        XCTAssertLessThanOrEqual(proMax, LockScreenLineBudget.maxLinesCap)
    }

    func testLineBudgetClampsExtremes() {
        let tiny = LockScreenLineBudget.computeMaxLines(screenHeight: 1)
        XCTAssertGreaterThanOrEqual(tiny, LockScreenLineBudget.minLines)
        let huge = LockScreenLineBudget.computeMaxLines(screenHeight: 5000)
        XCTAssertLessThanOrEqual(huge, LockScreenLineBudget.maxLinesCap)
        XCTAssertGreaterThanOrEqual(huge, tiny)
    }
}
