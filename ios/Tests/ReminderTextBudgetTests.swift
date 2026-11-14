import UIKit
import WidgetKit
import XCTest
@testable import LazyMansReminders

final class ReminderTextBudgetTests: XCTestCase {
    func testDefaultSingleRemindersUseHeightWithoutInterRowGaps() {
        let widget = ReminderWidgetPresentation.textBudget(for: .systemSmall, lineHeight: 20)
        XCTAssertEqual(widget.fontScale, 1)
        XCTAssertEqual(widget.lineLimit(displayedRows: 1), 5)
        XCTAssertEqual(widget.lineLimit(displayedRows: 4), 1)

        let island = ReminderActivityPresentation.expandedIslandTextBudget(lineHeight: 20)
        XCTAssertEqual(island.fontScale, 1)
        XCTAssertEqual(island.lineLimit(displayedRows: 1), 5)
        XCTAssertEqual(island.lineLimit(displayedRows: 5), 1)
    }

    func testAX5SizedRowsFitWithOverflowAndSingleReminderWrapping() {
        for height in [40.0, 50.0, 60.0, 64.0, 70.5] {
            for family in [WidgetFamily.systemSmall, .systemMedium] {
                let budget = ReminderWidgetPresentation.textBudget(for: family, lineHeight: height, showsHeader: false)
                let rows = ReminderWidgetPresentation.lineLimit(for: family, lineHeight: budget.lineHeight, showsHeader: false)
                XCTAssertGreaterThanOrEqual(rows, 2)
                XCTAssertLessThanOrEqual(CGFloat(rows) * (budget.lineHeight + 6), 130)
                assertWrappingFits(budget)

                let reminders = (0..<6).map { reminder("Item \($0)", sortOrder: $0) }
                let display = ReminderActivityPresentation.displayLines(from: reminders, limit: rows)
                XCTAssertEqual(display.first, "Item 0")
                XCTAssertEqual(display.last, "+\(7 - rows) more")
                XCTAssertEqual(display.count, rows)
            }

            let budget = ReminderActivityPresentation.expandedIslandTextBudget(lineHeight: height)
            let display = ReminderActivityPresentation.expandedIslandLines(
                ["a", "b", "c", "d", "e", "+7 more"], lineHeight: budget.lineHeight
            )
            XCTAssertEqual(display, ["a", "+11 more"])
            XCTAssertLessThanOrEqual(CGFloat(display.count) * budget.lineHeight + 3 + 48, 160)
            assertWrappingFits(budget)
        }
    }

    func testRectangularAccessoryWrapsOnlyWithinItsSixtyPointHeight() {
        let normal = ReminderWidgetPresentation.textBudget(for: .accessoryRectangular, lineHeight: 15)
        XCTAssertEqual(ReminderWidgetPresentation.lineLimit(for: .accessoryRectangular, lineHeight: normal.lineHeight), 3)
        XCTAssertEqual(normal.lineLimit(displayedRows: 1), 4)
        for height in [40.0, 50.0, 64.0] {
            let budget = ReminderWidgetPresentation.textBudget(for: .accessoryRectangular, lineHeight: height)
            XCTAssertEqual(ReminderWidgetPresentation.lineLimit(for: .accessoryRectangular, lineHeight: budget.lineHeight), 1)
            XCTAssertEqual(budget.lineLimit(displayedRows: 1), 1)
            assertWrappingFits(budget, minimumLines: 1)
        }
    }

    func testLockScreenWrappingAndRowsFitEvenTheSmallestCachedBudget() {
        let baseHeight = ceil(UIFont.systemFont(ofSize: LockScreenLineBudget.pointSize, weight: .semibold).lineHeight)
        for baseCount in [1, 3, 4, 5, 6, 8, 16] {
            for height in [baseHeight, baseHeight * 2.5, baseHeight * 3.5, 70.5] {
                let budget = LockScreenLineBudget.textBudget(lineHeight: height, baseLimit: baseCount)
                let rows = LockScreenLineBudget.scaledLineLimit(lineHeight: budget.lineHeight, baseLimit: baseCount)
                let originalHeight = CGFloat(baseCount) * (baseHeight + 3) + LockScreenLineBudget.verticalPadding
                XCTAssertGreaterThanOrEqual(rows, min(2, baseCount))
                XCTAssertLessThanOrEqual(rows, baseCount)
                XCTAssertLessThanOrEqual(
                    CGFloat(rows) * (budget.lineHeight + 3) + LockScreenLineBudget.verticalPadding,
                    originalHeight
                )
                assertWrappingFits(budget, minimumLines: min(2, baseCount))
            }
        }
    }

    func testActualAX3AndAX5FontsFitConservativeLineHeightsIncludingBoldText() {
        for category in [UIContentSizeCategory.large, .accessibilityExtraLarge, .accessibilityExtraExtraExtraLarge] {
            let traits = UITraitCollection(preferredContentSizeCategory: category)
            let metrics = UIFontMetrics(forTextStyle: .subheadline)
            let rowHeight = metrics.scaledValue(for: 20, compatibleWith: traits)
            let pointSize = metrics.scaledValue(for: 15, compatibleWith: traits)
            let home = ReminderWidgetPresentation.textBudget(
                for: .systemSmall, lineHeight: rowHeight, showsHeader: !category.isAccessibilityCategory
            )
            let island = ReminderActivityPresentation.expandedIslandTextBudget(lineHeight: rowHeight)
            let baseHeight = ceil(UIFont.systemFont(ofSize: 15, weight: .semibold).lineHeight)
            let lock = LockScreenLineBudget.textBudget(
                lineHeight: metrics.scaledValue(for: baseHeight, compatibleWith: traits), baseLimit: 5
            )
            for budget in [home, island, lock] {
                for weight in [UIFont.Weight.regular, .semibold, .bold] {
                    let font = UIFont.systemFont(ofSize: pointSize * budget.fontScale, weight: weight)
                    XCTAssertLessThanOrEqual(font.lineHeight, budget.lineHeight)
                    XCTAssertGreaterThanOrEqual(font.pointSize, 15)
                }
                assertWrappingFits(budget)
            }

            let captionMetrics = UIFontMetrics(forTextStyle: .caption1)
            let accessory = ReminderWidgetPresentation.textBudget(
                for: .accessoryRectangular,
                lineHeight: captionMetrics.scaledValue(for: 15, compatibleWith: traits)
            )
            let caption = UIFont.systemFont(
                ofSize: captionMetrics.scaledValue(for: 12, compatibleWith: traits) * accessory.fontScale
            )
            XCTAssertLessThanOrEqual(caption.lineHeight, accessory.lineHeight)
            assertWrappingFits(accessory, minimumLines: 1)
        }
    }

    func testLockScreenAX5OverflowIncludesPreviouslyHiddenRows() {
        for baseCount in [4, 5, 6, 8] {
            let budget = LockScreenLineBudget.textBudget(lineHeight: 64, baseLimit: baseCount)
            XCTAssertEqual(
                ReminderActivityPresentation.lockScreenLines(
                    ["a", "b", "c", "d", "e", "+7 more"], lineHeight: budget.lineHeight, baseLimit: baseCount
                ),
                ["a", "+11 more"]
            )
        }
    }

    func testLongReminderAndPlaceholdersKeepFullTextBeforeVisualWrapping() {
        let long = String(repeating: "Bring the notebook and charging cable 漢字 😀. ", count: 30)
        let reminders = [reminder(long)]
        let budget = ReminderActivityPresentation.expandedIslandTextBudget(lineHeight: 64)
        XCTAssertEqual(ReminderActivityPresentation.displayLines(from: reminders, limit: 2), [long])
        XCTAssertEqual(ReminderActivityPresentation.expandedIslandLines([long], lineHeight: budget.lineHeight), [long])
        XCTAssertEqual(ReminderActivityPresentation.lockScreenLines([long], lineHeight: budget.lineHeight), [long])
        XCTAssertEqual(ReminderActivityPresentation.accessibilitySummary(from: reminders), long)
        XCTAssertEqual(ReminderActivityPresentation.accessibilitySummary(lines: [long, "Second reminder"]), long + "; Second reminder")
        XCTAssertEqual(budget.lineLimit(displayedRows: 1), 2)
        XCTAssertEqual(ReminderActivityPresentation.displayLines(from: nil, limit: 2), ["Couldn’t Load Board"])
        XCTAssertEqual(ReminderActivityPresentation.expandedIslandLines([], lineHeight: budget.lineHeight), ["Nothing to remember"])
    }

    private func assertWrappingFits(
        _ budget: ReminderTextBudget, minimumLines: Int = 2,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let wrappedLines = budget.lineLimit(displayedRows: 1)
        XCTAssertGreaterThanOrEqual(wrappedLines, minimumLines, file: file, line: line)
        XCTAssertLessThanOrEqual(CGFloat(wrappedLines) * budget.lineHeight, budget.contentHeight, file: file, line: line)
        XCTAssertEqual(budget.lineLimit(displayedRows: 2), 1, file: file, line: line)
        XCTAssertGreaterThan(budget.fontScale, 0, file: file, line: line)
        XCTAssertLessThanOrEqual(budget.fontScale, 1, file: file, line: line)
    }

    private func reminder(_ text: String, sortOrder: Int = 0) -> Reminder {
        Reminder(id: UUID(), userID: UUID(), text: text, sortOrder: sortOrder, isDone: false, createdAt: .now)
    }
}
