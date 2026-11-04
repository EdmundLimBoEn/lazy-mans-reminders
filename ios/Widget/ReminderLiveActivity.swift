import ActivityKit
import SwiftUI
import WidgetKit

/// Full-width Lock Screen banner — notification-style clear glass.
/// Scaled type with a separate height budget for each native surface.
///
/// Compact leading, compact trailing, and minimal stay `EmptyView`. Any
/// compact text widens the collapsed Dynamic Island over status icons.
/// Live Activities HIG asks that compact content stay as narrow as possible
/// and not cover the status bar. Press-and-hold uses the expanded
/// presentation for the same board lines as the Lock Screen banner.
struct ReminderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReminderAttributes.self) { context in
            lockScreenBanner(state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    expandedIsland(state: context.state)
                }
                // The expanded pill's bottom corner starts curving while the
                // last line is still drawing. Extra bottom margin keeps that
                // curve below the text.
                .contentMargins(.bottom, 20)
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
    private func lockScreenBanner(state: ReminderAttributes.ContentState) -> some View {
        ReminderActivityLinesView(lines: state.lines, hiddenLineCount: state.hiddenLineCount, surface: .lockScreen)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        // `.clear` → system Liquid Glass (matches notification Clear look).
        .activityBackgroundTint(.clear)
        .activitySystemActionForegroundColor(.primary)
    }

    @ViewBuilder
    private func expandedIsland(state: ReminderAttributes.ContentState) -> some View {
        ReminderActivityLinesView(lines: state.lines, hiddenLineCount: state.hiddenLineCount, surface: .island)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .frame(maxWidth: .infinity, alignment: .leading)
        // The island background is always black. Force dark so `.primary`
        // text stays light when the phone is in light mode.
        .environment(\.colorScheme, .dark)
    }

}
