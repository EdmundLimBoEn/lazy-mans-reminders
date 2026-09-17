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

    func testPreviewLinesCapLikeTheLockScreenOverflow() {
        let lines = (0..<8).map { "Item \($0)" }
        XCTAssertEqual(
            ReminderActivityPresentation.previewLines(lines, limit: 3),
            ["Item 0", "Item 1", "+6 more"]
        )
        XCTAssertEqual(
            ReminderActivityPresentation.previewLines(["Milk", "Eggs"]),
            ["Milk", "Eggs"]
        )
    }

    func testPresentedLinesUseTheEmptyBoardPlaceholder() {
        XCTAssertEqual(
            ReminderActivityPresentation.presentedLines([]),
            ["Nothing to remember"]
        )
    }

    func testPresentedLinesKeepAShortBoardInOrder() {
        XCTAssertEqual(
            ReminderActivityPresentation.presentedLines(["Milk", "Eggs"]),
            ["Milk", "Eggs"]
        )
    }

    func testPresentedLinesClipToTheLockScreenBudgetWithoutAnOverflowFooter() {
        let lines = (0..<20).map { "Item \($0)" }
        let display = ReminderActivityPresentation.presentedLines(lines)
        XCTAssertEqual(display, Array(lines.prefix(ReminderBoardLimits.lockScreenMaxLines)))
        XCTAssertFalse(display.contains { $0.hasPrefix("+") && $0.hasSuffix(" more") })
    }

    func testMarqueeStopsWhenReduceMotionIsOn() {
        XCTAssertTrue(
            LockScreenMarqueePolicy.shouldScroll(overflow: 20, reduceMotion: false)
        )
        XCTAssertFalse(
            LockScreenMarqueePolicy.shouldScroll(overflow: 20, reduceMotion: true)
        )
        XCTAssertFalse(
            LockScreenMarqueePolicy.shouldScroll(overflow: 0.2, reduceMotion: false)
        )
    }
}
