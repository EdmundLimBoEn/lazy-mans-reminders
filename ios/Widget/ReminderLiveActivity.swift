import ActivityKit
import SwiftUI
import WidgetKit

/// Full-width Lock Screen banner — same glass + proportions as a system
/// notification, but content-only (no title header / app icon row).
struct ReminderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReminderAttributes.self) { context in
            lockScreenBanner(lines: context.state.lines)
        } dynamicIsland: { context in
            let summary = context.state.lines.joined(separator: " · ")
            return DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text(summary)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(4)
                        .minimumScaleFactor(0.85)
                }
            } compactLeading: {
                // Intentionally empty — no glyph/header chrome.
                EmptyView()
            } compactTrailing: {
                Text(context.state.lines.first ?? "")
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
            } minimal: {
                EmptyView()
            }
        }
    }

    /// Matches notification body layout: leading text, system padding,
    /// clear tint so iOS 26 Liquid Glass follows the user's Clear setting.
    @ViewBuilder
    private func lockScreenBanner(lines: [String]) -> some View {
        let display = lines.isEmpty ? ["Nothing to remember"] : lines
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(display.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Critical: `.clear` opts into system Liquid Glass (Clear Home Screen /
        // Lock Screen glass). Opaque tints force the murky “widget” material.
        .activityBackgroundTint(.clear)
        .activitySystemActionForegroundColor(.primary)
    }
}
