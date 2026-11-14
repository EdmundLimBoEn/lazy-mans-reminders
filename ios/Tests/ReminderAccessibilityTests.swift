import SwiftUI
import UIKit
import WidgetKit
import XCTest
@testable import LazyMansReminders

final class ReminderAccessibilityTests: XCTestCase {
    func testMotionPolicyStopsIndeterminateAndBoardAnimations() {
        XCTAssertFalse(ReminderAccessibility.allowsAnimation(reduceMotion: true))
        XCTAssertTrue(ReminderAccessibility.allowsAnimation(reduceMotion: false))
        for overflow in [0.0, 0.5, 1.0, 1_000.0] {
            XCTAssertFalse(LockScreenMarqueePolicy.shouldScroll(overflow: overflow, reduceMotion: true))
        }
    }

    func testEitherContrastSettingRequestsAnOpaqueBackground() {
        for reduceTransparency in [false, true] {
            for increasedContrast in [false, true] {
                XCTAssertEqual(
                    ReminderAccessibility.usesSolidBackground(
                        reduceTransparency: reduceTransparency, increasedContrast: increasedContrast
                    ),
                    reduceTransparency || increasedContrast
                )
            }
        }
    }

    func testCompletionHasAShapeAndSpokenStateIndependentOfColor() {
        XCTAssertEqual(ReminderAccessibility.completionSymbol(isCompleting: false), "circle")
        XCTAssertEqual(ReminderAccessibility.completionSymbol(isCompleting: true), "checkmark.circle.fill")
        XCTAssertEqual(ReminderAccessibility.completionValue(isCompleting: false), "Active")
        XCTAssertEqual(ReminderAccessibility.completionValue(isCompleting: true), "Completing")
        XCTAssertEqual(ReminderAccessibility.progressValue(isBusy: true), "In progress")
        XCTAssertEqual(ReminderAccessibility.progressValue(isBusy: false), "")
    }

    func testWidgetSpeechPreservesLongMultilineTextAndOmitsCompletedItems() {
        let longText = String(repeating: "Remember this. ", count: 100) + "\nSecond line"
        let active = reminder(longText)
        let completed = reminder("Already done", isDone: true)
        XCTAssertEqual(ReminderActivityPresentation.accessibilitySummary(from: [active, completed]), longText)
        XCTAssertEqual(ReminderActivityPresentation.accessibilitySummary(from: nil), "Couldn’t Load Board")
        XCTAssertEqual(ReminderActivityPresentation.accessibilitySummary(from: []), "Nothing to remember")
        XCTAssertEqual(ReminderActivityPresentation.accessibilitySummary(from: [completed]), "Nothing to remember")
        XCTAssertEqual(ReminderActivityPresentation.accessibilitySummary(lines: []), "Nothing to remember")
        XCTAssertEqual(ReminderActivityPresentation.accessibilitySummary(lines: ["Milk", "+7 more"]), "Milk; +7 more")
    }

    func testClearMomentSpeaksExactCopyAndKeepsWidgetEmptySpeech() {
        let state = ReminderActivityPresentation.finalState(for: .boardEmpty)
        XCTAssertEqual(ReminderActivityPresentation.accessibilitySummary(lines: state.lines), "Nothing to do.")
        XCTAssertEqual(ReminderActivityPresentation.accessibilitySummary(from: []), "Nothing to remember")
    }

    func testLastCompletionAnnouncesTheClearMomentAfterTheReminder() {
        XCTAssertEqual(
            ReminderAccessibility.completionAnnouncement(text: "Milk", boardIsEmpty: true),
            "Completed Milk\nNothing to do."
        )
        XCTAssertEqual(
            ReminderAccessibility.completionAnnouncement(text: "Milk", boardIsEmpty: false),
            "Completed Milk"
        )
    }

    func testLockScreenScalingNeverExceedsTheExistingMeasuredHeight() {
        let baseHeight = ceil(UIFont.systemFont(ofSize: LockScreenLineBudget.pointSize, weight: .semibold).lineHeight)
        for baseCount in [1, 3, 6, 16] {
            XCTAssertEqual(LockScreenLineBudget.scaledLineLimit(lineHeight: baseHeight, baseLimit: baseCount), baseCount)
            for height in [baseHeight, baseHeight * 1.5, baseHeight * 2.5] {
                let count = LockScreenLineBudget.scaledLineLimit(lineHeight: height, baseLimit: baseCount)
                XCTAssertGreaterThanOrEqual(count, 1)
                XCTAssertLessThanOrEqual(count, baseCount)
                // A one-row surface is irreducible; larger normal budgets must stay within their original height.
                if baseCount >= 3 {
                    XCTAssertLessThanOrEqual(CGFloat(count) * (ceil(height) + 3), CGFloat(baseCount) * (baseHeight + 3))
                }
            }
        }
    }

    func testAX3FontsAndBoundedSurfaceBudgets() {
        // AX5 is deliberately capped to AX3 only on the bounded extension surfaces.
        let categories: [UIContentSizeCategory] = [.large, .extraExtraExtraLarge,
                                                 .accessibilityMedium, .accessibilityExtraLarge]
        let lines = (0..<16).map { "Item \($0)" }
        for category in categories {
            let traits = UITraitCollection(preferredContentSizeCategory: category)
            let rowHeight = ceil(UIFontMetrics(forTextStyle: .subheadline).scaledValue(for: 20, compatibleWith: traits))
            let captionHeight = ceil(UIFontMetrics(forTextStyle: .caption1).scaledValue(for: 15, compatibleWith: traits))
            let island = ReminderActivityPresentation.expandedIslandLines(lines, lineHeight: rowHeight)
            XCTAssertLessThanOrEqual(CGFloat(island.count) * rowHeight + CGFloat(island.count - 1) * 3 + 48, 160)
            for family in [WidgetFamily.systemSmall, .systemMedium] {
                let count = ReminderWidgetPresentation.lineLimit(for: family, lineHeight: rowHeight, headerHeight: captionHeight)
                XCTAssertLessThanOrEqual(captionHeight + CGFloat(count) * rowHeight + CGFloat(count + 1) * 6, 130)
            }
            let accessoryCount = ReminderWidgetPresentation.lineLimit(for: .accessoryRectangular, lineHeight: captionHeight)
            XCTAssertLessThanOrEqual(CGFloat(accessoryCount) * captionHeight + CGFloat(accessoryCount - 1) * 2, 60)
        }
        let ax3 = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraLarge)
        XCTAssertGreaterThanOrEqual(UIFontMetrics(forTextStyle: .subheadline).scaledValue(for: 15, compatibleWith: ax3), 30)
        let ax3Height = UIFontMetrics(forTextStyle: .subheadline).scaledValue(for: 20, compatibleWith: ax3)
        let count = ReminderWidgetPresentation.lineLimit(for: .systemSmall, lineHeight: ax3Height, showsHeader: false)
        XCTAssertGreaterThanOrEqual(count, 2, "Keep a reminder plus overflow, instead of only an overflow footer")
        XCTAssertLessThanOrEqual(CGFloat(count) * (ceil(ax3Height) + 6), 130)
    }

    func testPrimaryForegroundOnOpaqueSurfacesHasTextContrast() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            for contrast in [UIAccessibilityContrast.normal, .high] {
                let traits = UITraitCollection(traitsFrom: [UITraitCollection(userInterfaceStyle: style),
                                                          UITraitCollection(accessibilityContrast: contrast)])
                for background in [UIColor.systemBackground, .secondarySystemBackground, .secondarySystemGroupedBackground] {
                    let foreground = luminance(UIColor.label.resolvedColor(with: traits))
                    let backdrop = luminance(background.resolvedColor(with: traits))
                    let ratio = (max(foreground, backdrop) + 0.05) / (min(foreground, backdrop) + 0.05)
                    XCTAssertGreaterThanOrEqual(ratio, 4.5)
                }
            }
        }
    }

    private func luminance(_ color: UIColor) -> CGFloat {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        XCTAssertTrue(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        XCTAssertEqual(alpha, 1, accuracy: 0.001)
        func linear(_ component: CGFloat) -> CGFloat {
            component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    private func reminder(_ text: String, isDone: Bool = false) -> Reminder {
        Reminder(id: UUID(), userID: UUID(), text: text, sortOrder: 0, isDone: isDone, createdAt: .now)
    }
}
