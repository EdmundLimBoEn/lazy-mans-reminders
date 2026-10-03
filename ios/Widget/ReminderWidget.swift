import SwiftUI
import WidgetKit

struct ReminderEntry: TimelineEntry {
    let date: Date
    let reminders: [Reminder]
}

struct ReminderProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReminderEntry {
        ReminderEntry(date: .now, reminders: Self.samples)
    }

    func getSnapshot(in context: Context, completion: @escaping (ReminderEntry) -> Void) {
        Task {
            let reminders = await ReminderStore.shared.cached()
            completion(ReminderEntry(date: .now, reminders: context.isPreview ? Self.samples : reminders))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReminderEntry>) -> Void) {
        Task {
            let reminders = await ReminderStore.shared.refreshOrCached(refreshAuthentication: false)
            let now = Date()
            completion(Timeline(
                entries: [ReminderEntry(date: now, reminders: reminders)],
                policy: .after(now.addingTimeInterval(30 * 60))
            ))
        }
    }

    private static let samples = [
        Reminder(id: UUID(), userID: UUID(), text: "cable and phone stand", sortOrder: 0, isDone: false, createdAt: .now),
        Reminder(id: UUID(), userID: UUID(), text: "do chinese homework", sortOrder: 1, isDone: false, createdAt: .now),
    ]
}

struct ReminderWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ReminderEntry

    private var lines: [String] {
        ReminderActivityPresentation.displayLines(from: entry.reminders, limit: lineLimit)
    }

    private var lineLimit: Int {
        switch family {
        case .accessoryInline: return 1
        case .accessoryRectangular: return 3
        case .systemSmall: return 4
        default: return 6
        }
    }

    private var isAccessory: Bool {
        family == .accessoryInline || family == .accessoryRectangular
    }

    var body: some View {
        Group {
            if family == .accessoryInline {
                Text(lines.joined(separator: " · "))
            } else {
                VStack(alignment: .leading, spacing: isAccessory ? 2 : 8) {
                    if !isAccessory {
                        Text("Your Board")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(isAccessory ? .caption : .subheadline)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !isAccessory { Spacer(minLength: 0) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .containerBackground(for: .widget) {
            if isAccessory { Color.clear } else { Color(.systemBackground) }
        }
        .widgetURL(URL(string: "lazymansreminders://board"))
    }
}

struct ReminderWidget: Widget {
    let kind = "ReminderWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReminderProvider()) { entry in
            ReminderWidgetView(entry: entry)
        }
        .configurationDisplayName("Board")
        .description("Keep your reminders on the Home Screen or Lock Screen, even after a Live Activity ends.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct ReminderWidgets: WidgetBundle {
    var body: some Widget {
        ReminderWidget()
        ReminderLiveActivity()
    }
}
