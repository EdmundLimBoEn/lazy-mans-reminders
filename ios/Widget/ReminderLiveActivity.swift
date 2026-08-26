import ActivityKit
import SwiftUI
import WidgetKit

/// Full-width Lock Screen banner — notification-style clear glass.
/// Compact type so the phone-measured line budget can actually fit.
struct ReminderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReminderAttributes.self) { context in
            lockScreenBanner(lines: context.state.lines)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.lines.first ?? "Reminders")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
            } compactLeading: {
                Text("LM")
                    .font(.caption2.weight(.bold))
            } compactTrailing: {
                Text(context.state.lines.first ?? "")
                    .font(.caption2)
                    .lineLimit(1)
            } minimal: {
                Text("LM")
                    .font(.caption2.weight(.bold))
            }
        }
    }

    @ViewBuilder
    private func lockScreenBanner(lines: [String]) -> some View {
        let limit = ReminderBoardLimits.lockScreenMaxLines
        let display = Array(
            (lines.isEmpty ? ["Nothing to remember"] : lines).prefix(limit)
        )

        VStack(alignment: .leading, spacing: LockScreenLineBudget.lineSpacing) {
            ForEach(Array(display.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(size: LockScreenLineBudget.pointSize, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        // `.clear` → system Liquid Glass (matches notification Clear look).
        .activityBackgroundTint(.clear)
        .activitySystemActionForegroundColor(.primary)
    }
}
