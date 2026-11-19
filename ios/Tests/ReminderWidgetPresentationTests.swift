import WidgetKit
import XCTest
@testable import LazyMansReminders

final class ReminderWidgetPresentationTests: XCTestCase {
    func testSupportedFamiliesHaveExplicitLimits() {
        XCTAssertEqual(ReminderWidgetPresentation.lineLimit(for: .systemSmall), 4)
        XCTAssertEqual(ReminderWidgetPresentation.lineLimit(for: .systemMedium), 4)
        XCTAssertEqual(ReminderWidgetPresentation.lineLimit(for: .accessoryInline), 1)
        XCTAssertEqual(ReminderWidgetPresentation.lineLimit(for: .accessoryRectangular), 3)
    }

    func testHomeScreenHeaderRowsAndSpacerFitSmallestHeight() {
        let sizes: [(CGFloat, CGFloat)] = [(20, 15), (26, 20), (40, 30)]
        for family in [WidgetFamily.systemSmall, .systemMedium] {
            for (lineHeight, headerHeight) in sizes {
                let count = ReminderWidgetPresentation.lineLimit(
                    for: family, lineHeight: lineHeight, headerHeight: headerHeight
                )
                let height = headerHeight + CGFloat(count) * lineHeight
                    + CGFloat(count + 1) * ReminderWidgetPresentation.spacing(for: family)
                XCTAssertGreaterThanOrEqual(count, 1)
                XCTAssertLessThanOrEqual(height, 130)
            }
        }
    }

    func testLargerTextReducesHomeScreenRows() {
        for family in [WidgetFamily.systemSmall, .systemMedium] {
            XCTAssertEqual(
                ReminderWidgetPresentation.lineLimit(for: family, lineHeight: 26, headerHeight: 20),
                3
            )
        }
    }

    func testSixRemindersIncludeOverflowWithinHomeScreenLimit() {
        let reminders = (0..<6).map { index in
            Reminder(
                id: UUID(), userID: UUID(), text: "Item \(index)",
                sortOrder: index, isDone: false, createdAt: .now
            )
        }
        for family in [WidgetFamily.systemSmall, .systemMedium] {
            XCTAssertEqual(
                ReminderActivityPresentation.displayLines(
                    from: reminders, limit: ReminderWidgetPresentation.lineLimit(for: family)
                ),
                ["Item 0", "Item 1", "Item 2", "+3 more"]
            )
        }
    }

    func testAccessorySpacingAndFallbackRemainUnchanged() {
        XCTAssertEqual(ReminderWidgetPresentation.spacing(for: .accessoryInline), 2)
        XCTAssertEqual(ReminderWidgetPresentation.spacing(for: .accessoryRectangular), 2)
        XCTAssertEqual(ReminderWidgetPresentation.lineLimit(for: .systemLarge), 6)
        XCTAssertEqual(ReminderWidgetPresentation.spacing(for: .systemLarge), 8)
    }
}
