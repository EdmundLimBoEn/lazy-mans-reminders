import SwiftUI
import UIKit
import WidgetKit

struct ReminderEntry: TimelineEntry {
    let date: Date
    let reminders: [Reminder]
    let scrollOffset: CGFloat
    let contentWidth: CGFloat

    var lines: [String] {
        ReminderActivityPresentation.displayLines(
            from: reminders,
            limit: ReminderBoardLimits.lockScreenMaxLines
        )
    }
}

enum LockScreenAccessoryMetrics {
    static let fontSize = LockScreenLineBudget.pointSize
    static let fontWeight = UIFont.Weight.semibold
    static let lineSpacing = LockScreenLineBudget.lineSpacing
    static let horizontalPadding: CGFloat = 16
    static let topPadding: CGFloat = 12
    static let bottomPadding: CGFloat = 12
    static let holdDuration: TimeInterval = 1.0
    static let endHoldDuration: TimeInterval = 1.0
    static let pointsPerSecond: CGFloat = 28
    static let frameInterval: TimeInterval = 1.0 / 20.0

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
            contentWidth: LockScreenAccessoryMetrics.contentWidth(from: context)
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
                    contentWidth: LockScreenAccessoryMetrics.contentWidth(from: context)
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
                    contentWidth: LockScreenAccessoryMetrics.contentWidth(from: context),
                    startingAt: .now
                )
            )
        }
    }

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
        let overflow = LockScreenAccessoryMetrics.overflowWidth(
            for: probe.lines,
            contentWidth: contentWidth
        )

        guard LockScreenMarqueePolicy.shouldScroll(
            overflow: overflow,
            reduceMotion: UIAccessibility.isReduceMotionEnabled
        ) else {
            return Timeline(
                entries: [probe],
                policy: .after(now.addingTimeInterval(15 * 60))
            )
        }

        let scrollDuration = TimeInterval(overflow / LockScreenAccessoryMetrics.pointsPerSecond)
        let cycle =
            LockScreenAccessoryMetrics.holdDuration
            + scrollDuration
            + LockScreenAccessoryMetrics.endHoldDuration

        let loopCount = 3
        let step = LockScreenAccessoryMetrics.frameInterval
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
        if t < LockScreenAccessoryMetrics.holdDuration {
            return 0
        }
        if t < LockScreenAccessoryMetrics.holdDuration + scrollDuration {
            let progress = (t - LockScreenAccessoryMetrics.holdDuration) / scrollDuration
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
        ),
        Reminder(
            id: UUID(),
            userID: UUID(),
            text: "do chinese homework",
            sortOrder: 1,
            isDone: false,
            createdAt: .now
        ),
    ]
}

/// Lock Screen accessories only — Home Screen widgets can't match the
/// notification clear-glass Live Activity look, so we don't ship them.
struct ReminderWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let entry: ReminderEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(entry.lines.joined(separator: " · "))
                .containerBackground(for: .widget) { Color.clear }
        default:
            VStack(alignment: .leading, spacing: LockScreenAccessoryMetrics.lineSpacing) {
                ForEach(Array(entry.lines.enumerated()), id: \.offset) { _, line in
                    reminderLine(line)
                }
            }
            .padding(.horizontal, LockScreenAccessoryMetrics.horizontalPadding)
            .padding(.top, LockScreenAccessoryMetrics.topPadding)
            .padding(.bottom, LockScreenAccessoryMetrics.bottomPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .containerBackground(for: .widget) { Color.clear }
        }
    }

    @ViewBuilder
    private func reminderLine(_ line: String) -> some View {
        let overflow =
            LockScreenAccessoryMetrics.textWidth(line) - entry.contentWidth
        let marquee = LockScreenMarqueePolicy.shouldScroll(
            overflow: overflow,
            reduceMotion: reduceMotion
        )

        if marquee {
            Text(line)
                .font(LockScreenAccessoryMetrics.font)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .offset(x: -entry.scrollOffset)
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
        } else {
            Text(line)
                .font(LockScreenAccessoryMetrics.font)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ReminderWidget: Widget {
    let kind = "ReminderWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReminderProvider()) { entry in
            ReminderWidgetView(entry: entry)
        }
        .configurationDisplayName("Lock Screen")
        .description("See your active reminders on the Lock Screen.")
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
