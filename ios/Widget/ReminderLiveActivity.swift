import ActivityKit
import SwiftUI
import WidgetKit

/// Full-width Lock Screen banner — notification-style clear glass.
/// Compact type so the phone-measured line budget can actually fit.
///
/// Compact leading, compact trailing, and minimal stay `EmptyView`. Any
/// compact text widens the collapsed Dynamic Island over status icons.
/// Live Activities HIG asks that compact content stay as narrow as possible
/// and not cover the status bar. Press-and-hold uses the expanded
/// presentation for the same board lines as the Lock Screen banner.
struct ReminderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReminderAttributes.self) { context in
            lockScreenBanner(lines: context.state.lines)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    expandedIsland(lines: context.state.lines)
                }
                // The expanded pill's bottom corner starts curving while the
                // last line is still drawing. Extra bottom margin keeps that
                // curve below the text.
                .contentMargins(.bottom, 14)
            } compactLeading: {
                EmptyView()
            } compactTrailing: {
                EmptyView()
            } minimal: {
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func lockScreenBanner(lines: [String]) -> some View {
        reminderLineStack(
            lines: lines,
            font: .system(size: LockScreenLineBudget.pointSize, weight: .semibold)
        )
        .padding(.top, 14)
        .padding(.bottom, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        // `.clear` → system Liquid Glass (matches notification Clear look).
        .activityBackgroundTint(.clear)
        .activitySystemActionForegroundColor(.primary)
    }

    @ViewBuilder
    private func expandedIsland(lines: [String]) -> some View {
        reminderLineStack(
            lines: lines,
            font: .subheadline.weight(.semibold)
        )
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .frame(maxWidth: .infinity, alignment: .leading)
        // The island background is always black. Force dark so `.primary`
        // text stays light when the phone is in light mode.
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private func reminderLineStack(lines: [String], font: Font) -> some View {
        let display = ReminderActivityPresentation.presentedLines(lines)
        VStack(alignment: .leading, spacing: LockScreenLineBudget.lineSpacing) {
            ForEach(Array(display.enumerated()), id: \.offset) { _, line in
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
