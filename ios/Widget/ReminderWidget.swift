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
            let cached = await ReminderStore.shared.cached()
            let reminders = context.isPreview && cached.isEmpty ? Self.samples : cached
            completion(ReminderEntry(date: .now, reminders: reminders))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReminderEntry>) -> Void) {
        Task {
            let reminders = await ReminderStore.shared.cached()
            let entry = ReminderEntry(date: .now, reminders: reminders)
            completion(Timeline(entries: [entry], policy: .never))
        }
    }

    private static let samples = [
        Reminder(
            id: UUID(),
            userID: UUID(),
            text: "Book dentist",
            sortOrder: 0,
            isDone: false,
            createdAt: .now
        ),
        Reminder(
            id: UUID(),
            userID: UUID(),
            text: "Send the invoice",
            sortOrder: 1,
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
            inline
        default:
            rectangular
        }
    }

    private var inline: some View {
        Group {
            if let first = entry.reminders.first {
                Label(first.text, systemImage: "circle")
            } else {
                Label("Nothing to remember", systemImage: "checkmark.circle")
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "rectangle.stack.fill")
                Text("REMINDERS")
            }
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.secondary)

            if entry.reminders.isEmpty {
                Text("Nothing to remember")
                    .font(.system(size: 13, weight: .medium))
            } else {
                ForEach(entry.reminders.prefix(3)) { reminder in
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Image(systemName: "circle")
                            .font(.system(size: 7))
                        Text(reminder.text)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { Color.clear }
    }
}

@main
struct ReminderWidget: Widget {
    let kind = "ReminderWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReminderProvider()) { entry in
            ReminderWidgetView(entry: entry)
        }
        .configurationDisplayName("Lazy Man's Reminders")
        .description("Your reminders, where you can't ignore them.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}
