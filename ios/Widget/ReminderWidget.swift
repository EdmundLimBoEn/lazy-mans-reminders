import SwiftUI
import UIKit
import WidgetKit

struct ReminderEntry: TimelineEntry {
    let date: Date
    let reminders: [Reminder]
    /// Horizontal pixel offset applied when a line is wider than the card.
    let scrollOffset: CGFloat
    /// Content width used for marquee overflow (from `context.displaySize`).
    let contentWidth: CGFloat

    /// One visible line per reminder (and per embedded newline).
    var lines: [String] {
        if reminders.isEmpty { return ["Nothing to remember"] }
        return reminders.flatMap { reminder in
            reminder.text
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
    }
}

enum LockScreenCardMetrics {
    static let fontSize: CGFloat = 15
    static let fontWeight = UIFont.Weight.semibold
    static let lineSpacing: CGFloat = 3
    static let horizontalPadding: CGFloat = 16
    static let verticalPadding: CGFloat = 12
    static let holdDuration: TimeInterval = 1.0
    static let endHoldDuration: TimeInterval = 1.0
    static let pointsPerSecond: CGFloat = 28
    static let frameInterval: TimeInterval = 1.0 / 20.0
    /// Fallback when `displaySize` is unavailable (previews).
    static let fallbackContentWidth: CGFloat = 320

    static var uiFont: UIFont {
        .systemFont(ofSize: fontSize, weight: fontWeight)
    }

    static var font: Font {
        .system(size: fontSize, weight: .semibold)
    }

    static func textWidth(_ string: String) -> CGFloat {
        ceil((string as NSString).size(withAttributes: [.font: uiFont]).width)
    }

    static func overflowWidth(for lines: [String], contentWidth: CGFloat) -> CGFloat {
        lines.map { max(0, textWidth($0) - contentWidth) }.max() ?? 0
    }

    static func contentWidth(from context: TimelineProviderContext) -> CGFloat {
        max(1, context.displaySize.width - (horizontalPadding * 2))
    }
}

struct ReminderProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReminderEntry {
        ReminderEntry(
            date: .now,
            reminders: Self.samples,
            scrollOffset: 0,
            contentWidth: LockScreenCardMetrics.contentWidth(from: context)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ReminderEntry) -> Void) {
        Task {
            let cached = await ReminderStore.shared.cached()
            let reminders = context.isPreview && cached.isEmpty ? Self.samples : cached
            completion(
                ReminderEntry(
                    date: .now,
                    reminders: reminders,
                    scrollOffset: 0,
                    contentWidth: LockScreenCardMetrics.contentWidth(from: context)
                )
            )
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReminderEntry>) -> Void) {
        Task {
            let reminders = await ReminderStore.shared.cached()
            completion(
                Self.timeline(
                    for: reminders,
                    contentWidth: LockScreenCardMetrics.contentWidth(from: context),
                    startingAt: .now
                )
            )
        }
    }

    /// Hold 1s, then step the scroll offset via WidgetKit timeline entries.
    /// (`TimelineView` animations do not reliably tick on the Lock Screen.)
    private static func timeline(
        for reminders: [Reminder],
        contentWidth: CGFloat,
        startingAt now: Date
    ) -> Timeline<ReminderEntry> {
        let probe = ReminderEntry(
            date: now,
            reminders: reminders,
            scrollOffset: 0,
            contentWidth: contentWidth
        )
        let overflow = LockScreenCardMetrics.overflowWidth(
            for: probe.lines,
            contentWidth: contentWidth
        )

        guard overflow > 0.5 else {
            return Timeline(
                entries: [probe],
                policy: .after(now.addingTimeInterval(15 * 60))
            )
        }

        let scrollDuration = TimeInterval(overflow / LockScreenCardMetrics.pointsPerSecond)
        let cycle =
            LockScreenCardMetrics.holdDuration
            + scrollDuration
            + LockScreenCardMetrics.endHoldDuration

        let loopCount = 3
        let step = LockScreenCardMetrics.frameInterval
        var entries: [ReminderEntry] = []
        var t: TimeInterval = 0
        let total = cycle * Double(loopCount)

        while t <= total {
            entries.append(
                ReminderEntry(
                    date: now.addingTimeInterval(t),
                    reminders: reminders,
                    scrollOffset: offset(
                        at: t,
                        overflow: overflow,
                        cycle: cycle,
                        scrollDuration: scrollDuration
                    ),
                    contentWidth: contentWidth
                )
            )
            t += step
        }

        return Timeline(entries: entries, policy: .after(now.addingTimeInterval(total)))
    }

    private static func offset(
        at elapsed: TimeInterval,
        overflow: CGFloat,
        cycle: TimeInterval,
        scrollDuration: TimeInterval
    ) -> CGFloat {
        let t = elapsed.truncatingRemainder(dividingBy: max(cycle, 0.001))
        if t < LockScreenCardMetrics.holdDuration {
            return 0
        }
        if t < LockScreenCardMetrics.holdDuration + scrollDuration {
            let progress = (t - LockScreenCardMetrics.holdDuration) / scrollDuration
            return CGFloat(progress) * overflow
        }
        return overflow
    }

    private static let samples = [
        Reminder(
            id: UUID(),
            userID: UUID(),
            text: "cable and phone stand",
            sortOrder: 0,
            isDone: false,
            createdAt: .now
        )
    ]
}

struct ReminderWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ReminderEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(entry.lines.joined(separator: " · "))
                .containerBackground(for: .widget) { Color.clear }
        default:
            // Body-only notification layout: text fills the full system slot.
            // Do NOT use `AccessoryWidgetBackground` — that paints the old murky
            // accessory material and insets a smaller card. Clear container
            // background lets iOS 26 Liquid Glass (user's Clear setting) own the
            // full widget bounds.
            VStack(alignment: .leading, spacing: LockScreenCardMetrics.lineSpacing) {
                ForEach(Array(entry.lines.enumerated()), id: \.offset) { _, line in
                    reminderLine(line)
                }
            }
            .padding(.horizontal, LockScreenCardMetrics.horizontalPadding)
            .padding(.vertical, LockScreenCardMetrics.verticalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .containerBackground(for: .widget) {
                Color.clear
            }
        }
    }

    @ViewBuilder
    private func reminderLine(_ line: String) -> some View {
        let overflows =
            LockScreenCardMetrics.textWidth(line) > entry.contentWidth + 0.5

        if overflows {
            Text(line)
                .font(LockScreenCardMetrics.font)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .offset(x: -entry.scrollOffset)
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
        } else {
            Text(line)
                .font(LockScreenCardMetrics.font)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(1)
        }
    }
}

struct ReminderWidget: Widget {
    let kind = "ReminderWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReminderProvider()) { entry in
            ReminderWidgetView(entry: entry)
        }
        .configurationDisplayName("Lazy Man's Reminders")
        .description("Your reminders, where you can't ignore them.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

@main
struct ReminderWidgets: WidgetBundle {
    var body: some Widget {
        ReminderWidget()
        ReminderLiveActivity()
    }
}
