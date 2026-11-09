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

    func testProductionMultilinePipelineConservesOriginalCountAcrossCaps() throws {
        let originals = (1...10).map { "Line \($0)" }
        let state = ReminderActivityPresentation.state(from: [reminder(text: originals.joined(separator: "\n"))], limit: 6)
        XCTAssertEqual(state.lines, Array(originals.prefix(5)) + ["+5 more"])
        XCTAssertEqual(state.hiddenLineCount, 5)
        let roundtrip = try JSONDecoder().decode(ReminderAttributes.ContentState.self, from: JSONEncoder().encode(state))
        for limit in 1...8 {
            let capped = ReminderActivityPresentation.cappedState(roundtrip, limit: limit)
            XCTAssertEqual(capped.lines.count - 1 + (capped.hiddenLineCount ?? 0), 10)
            XCTAssertLessThanOrEqual(capped.lines.count, limit)
        }
        XCTAssertEqual(ReminderActivityPresentation.surfaceLines(roundtrip, limit: 4), Array(originals.prefix(3)) + ["+7 more"])
    }

    func testLiteralSummaryTextIsNeverInterpretedAsMetadata() {
        let state = ReminderActivityPresentation.state(from: [reminder(text: "+5 more\nSecond\nThird")], limit: 6)
        XCTAssertEqual(state.hiddenLineCount, 0)
        XCTAssertEqual(ReminderActivityPresentation.surfaceLines(state, limit: 2), ["+5 more", "+2 more"])
    }

    func testLegacyDecodeAndBackwardCompatibleEncode() throws {
        struct Legacy: Codable { var lines: [String] }
        let legacy = try JSONEncoder().encode(Legacy(lines: ["One", "+5 more"]))
        let decoded = try JSONDecoder().decode(ReminderAttributes.ContentState.self, from: legacy)
        XCTAssertNil(decoded.hiddenLineCount)
        XCTAssertEqual(decoded.lines, ["One", "+5 more"])
        let state = ReminderActivityPresentation.state(from: [reminder(text: (1...10).map(String.init).joined(separator: "\n"))], limit: 6)
        let old = try JSONDecoder().decode(Legacy.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(old.lines, ["1", "2", "3", "4", "5", "+5 more"])
    }

    func testEmptyWhitespaceAndAllDoneStatesHaveNoHiddenOriginals() {
        var done = reminder(text: "Done\nDone again")
        done.isDone = true
        for reminders in [[], [done], [reminder(text: " \n\n ")]] {
            let state = ReminderActivityPresentation.state(from: reminders)
            XCTAssertEqual(state.lines, [])
            XCTAssertEqual(state.hiddenLineCount, 0)
            XCTAssertEqual(ReminderActivityPresentation.surfaceLines(state, limit: 1), ["Nothing to remember"])
        }
    }

    func testHugeUnicodeStateCountsMetadataAndConservesOriginals() throws {
        for text in ["漢", "😀", "é", "\"\\"] {
            let reminders = [reminder(text: (0..<10).map { _ in String(repeating: text, count: 6000) }.joined(separator: "\n"))]
            let state = ReminderActivityPresentation.state(from: reminders, limit: 6)
            let bytes = try JSONEncoder().encode(state).count + JSONEncoder().encode(ReminderAttributes()).count
            XCTAssertLessThanOrEqual(bytes, 4096)
            for limit in [1, 2, 4, 6] {
                let capped = ReminderActivityPresentation.cappedState(state, limit: limit)
                let hidden = capped.hiddenLineCount ?? 0
                XCTAssertEqual(capped.lines.count - (hidden > 0 ? 1 : 0) + hidden, 10)
                XCTAssertFalse(capped.lines.contains(""))
            }
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
