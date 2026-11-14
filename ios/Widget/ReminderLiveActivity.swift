import ActivityKit
import SwiftUI
import WidgetKit
import UIKit

/// Full-width Lock Screen banner — notification-style clear glass.
/// Compact type so the phone-measured line budget can actually fit.
///
/// Compact leading, compact trailing, and minimal stay `EmptyView`. Any
/// compact text widens the collapsed Dynamic Island over status icons.
/// Live Activities HIG asks that compact content stay as narrow as possible
/// and not cover the status bar. Press-and-hold uses the expanded
/// presentation for a shorter preview of the Lock Screen board.
struct ReminderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReminderAttributes.self) { context in
            LockScreenReminderBanner(lines: context.state.lines)
                .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                .widgetURL(URL(string: "lazymansreminders://board"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedReminderIsland(lines: context.state.lines)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                }
                // The expanded pill's bottom corner starts curving while the
                // last line is still drawing. Extra bottom margin keeps that
                // curve below the text.
                .contentMargins(.bottom, 24)
            } compactLeading: {
                EmptyView()
            } compactTrailing: {
                EmptyView()
            } minimal: {
                EmptyView()
            }
            .widgetURL(URL(string: "lazymansreminders://board"))
        }
    }
}

private struct LockScreenReminderBanner: View {
    let lines: [String]
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.legibilityWeight) private var legibilityWeight
    @ScaledMetric(relativeTo: .subheadline) private var pointSize = LockScreenLineBudget.pointSize
    @ScaledMetric(relativeTo: .subheadline) private var lineHeight = ceil(
        UIFont.systemFont(ofSize: LockScreenLineBudget.pointSize, weight: .semibold).lineHeight
    )

    var body: some View {
        ReminderActivityLineStack(
            lines: ReminderActivityPresentation.lockScreenLines(lines, lineHeight: lineHeight),
            font: .system(size: pointSize, weight: legibilityWeight == .bold ? .bold : .semibold)
        )
        .padding(.top, 14)
        .padding(.bottom, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        // `.clear` → system Liquid Glass (matches notification Clear look).
        .activityBackgroundTint(ReminderAccessibility.usesSolidBackground(
            reduceTransparency: reduceTransparency, increasedContrast: contrast == .increased
        ) ? Color(.systemBackground) : .clear)
        .activitySystemActionForegroundColor(.primary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your Board")
        .accessibilityValue(ReminderActivityPresentation.accessibilitySummary(lines: lines))
        .accessibilityHint("Opens your board in Notepad")
    }
}

private struct ExpandedReminderIsland: View {
    let lines: [String]
    @ScaledMetric(relativeTo: .subheadline) private var islandLineHeight: CGFloat = 20

    var body: some View {
        ReminderActivityLineStack(
            lines: ReminderActivityPresentation.expandedIslandLines(lines, lineHeight: islandLineHeight),
            font: .subheadline.weight(.semibold)
        )
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        // The island background is always black. Force dark so `.primary`
        // text stays light when the phone is in light mode.
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your Board")
        .accessibilityValue(ReminderActivityPresentation.accessibilitySummary(lines: lines))
        .accessibilityHint("Opens your board in Notepad")
    }
}

private struct ReminderActivityLineStack: View {
    let lines: [String]
    let font: Font

    var body: some View {
        VStack(alignment: .leading, spacing: LockScreenLineBudget.lineSpacing) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(font)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
