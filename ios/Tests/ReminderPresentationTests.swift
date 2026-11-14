import XCTest
@testable import LazyMansReminders

final class ReminderPresentationTests: XCTestCase {
    func testSavedUnicodeBoardFitsLocallyRequestedActivityContent() throws {
        for text in [String(repeating: "漢", count: 500), String(repeating: "😀", count: 500)] {
            let reminders = (0..<6).map { reminder(text: text, sortOrder: $0) }
            let lines = ReminderActivityPresentation.lines(from: reminders)
            let data = try JSONEncoder().encode(ReminderAttributes.ContentState(lines: lines))
            let attributes = try JSONEncoder().encode(ReminderAttributes())
            XCTAssertLessThanOrEqual(data.count + attributes.count, 4096)
            XCTAssertTrue(lines.contains { $0.contains("…") })
        }
    }

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

    func testClearMomentContentKeepsItsCopyOnEveryLiveActivitySurface() {
        let state = ReminderActivityPresentation.finalState(for: .boardEmpty)
        XCTAssertEqual(state.lines, ["Nothing to do."])
        XCTAssertEqual(ReminderActivityPresentation.presentedLines(state.lines), ["Nothing to do."])
        XCTAssertEqual(ReminderActivityPresentation.lockScreenLines(state.lines, lineHeight: 40), ["Nothing to do."])
        XCTAssertEqual(ReminderActivityPresentation.expandedIslandLines(state.lines, lineHeight: 40), ["Nothing to do."])
        XCTAssertEqual(ReminderActivityPresentation.displayLines(from: []), ["Nothing to remember"])
    }

    func testAccountCleanupDoesNotUseClearMomentCopy() {
        XCTAssertEqual(ReminderActivityPresentation.finalState(for: .clear).lines, [])
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

    func testExpandedIslandKeepsFourAndFiveLinesInOrder() {
        for count in [4, 5] {
            let lines = (0..<count).map { "Item \($0)" }
            XCTAssertEqual(ReminderActivityPresentation.expandedIslandLines(lines), lines)
        }
    }

    func testExpandedIslandIncludesOverflowWithinFiveRows() {
        for count in [6, 16] {
            let lines = (0..<count).map { "Item \($0)" }
            XCTAssertEqual(
                ReminderActivityPresentation.expandedIslandLines(lines),
                ["Item 0", "Item 1", "Item 2", "Item 3", "+\(count - 4) more"]
            )
        }
    }

    func testExpandedIslandPreservesPreviouslyCountedOverflow() {
        let lines = ["a", "b", "c", "d", "e", "+7 more"]
        XCTAssertEqual(
            ReminderActivityPresentation.expandedIslandLines(lines),
            ["a", "b", "c", "d", "+8 more"]
        )
        let short = ["a", "+7 more"]
        XCTAssertEqual(ReminderActivityPresentation.expandedIslandLines(short), short)
    }

    func testExpandedIslandUsesExistingEmptyState() {
        XCTAssertEqual(
            ReminderActivityPresentation.expandedIslandLines([]),
            ["Nothing to remember"]
        )
    }

    func testExpandedIslandReducesRowsForLargerText() {
        let lines = (0..<6).map { "Item \($0)" }
        XCTAssertEqual(
            ReminderActivityPresentation.expandedIslandLines(lines, lineHeight: 26),
            ["Item 0", "Item 1", "+4 more"]
        )
        XCTAssertEqual(
            ReminderActivityPresentation.expandedIslandLines(lines, lineHeight: 40),
            ["Item 0", "+5 more"]
        )
    }

    func testExpandedIslandRowsLeaveRoomForChromeAndCorners() {
        let lines = (0..<16).map { "Item \($0)" }
        for height in [20.0, 23.5, 26.0, 30.0, 40.0] {
            let display = ReminderActivityPresentation.expandedIslandLines(lines, lineHeight: height)
            let textHeight = CGFloat(display.count) * ceil(height)
                + CGFloat(display.count - 1) * LockScreenLineBudget.lineSpacing
            XCTAssertLessThanOrEqual(display.count, 5)
            XCTAssertLessThanOrEqual(textHeight + 48, 160)
        }
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
