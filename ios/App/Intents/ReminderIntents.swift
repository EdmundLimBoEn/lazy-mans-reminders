import AppIntents
import SwiftUI

@available(iOS 27.0, *)
enum ReminderIntentError: Error, CustomLocalizedStringResourceConvertible {
    case signedOut
    case emptyText
    case atCapacity
    case notFound
    case nothingToUpdate
    case service(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .signedOut:
            "Sign in to Lazy Man's Reminders on this iPhone first."
        case .emptyText:
            "What should I add to your board?"
        case .atCapacity:
            "Your board is full. Complete a reminder or combine lines first."
        case .notFound:
            "I couldn't find that reminder on your board."
        case .nothingToUpdate:
            "Nothing to change on that reminder."
        case .service(let message):
            LocalizedStringResource(stringLiteral: message)
        }
    }
}

@available(iOS 27.0, *)
enum ReminderIntentActions {
    static func requireSession() async throws {
        guard await ReminderStore.shared.isSignedIn() else {
            throw ReminderIntentError.signedOut
        }
    }

    static func loadActive(preferNetwork: Bool) async throws -> [Reminder] {
        try await requireSession()
        if preferNetwork {
            return await ReminderStore.shared.refreshOrCached()
        }
        return await ReminderStore.shared.cached()
    }

    static func create(title: String) async throws -> Reminder {
        try await requireSession()
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ReminderIntentError.emptyText }
        let current = await ReminderStore.shared.refreshOrCached()
        if ReminderBoardLimits.isAtCapacity(current.filter { !$0.isDone }.count) {
            throw ReminderIntentError.atCapacity
        }
        do {
            let updated = try await ReminderStore.shared.create(text: trimmed)
            await ReminderBoardSync.apply(updated)
            guard let created = updated.last(where: { $0.text == trimmed }) ?? updated.last else {
                throw ReminderIntentError.service("The reminder was not returned after saving.")
            }
            return created
        } catch {
            throw map(error)
        }
    }

    static func complete(id: UUID) async throws -> String {
        try await requireSession()
        let current = try await loadActive(preferNetwork: true)
        guard let reminder = current.first(where: { $0.id == id && !$0.isDone }) else {
            throw ReminderIntentError.notFound
        }
        do {
            let updated = try await ReminderStore.shared.markDone(id: id)
            await ReminderBoardSync.apply(updated)
            return reminder.text
        } catch {
            throw map(error)
        }
    }

    static func update(id: UUID, title: String?, isCompleted: Bool?) async throws -> Reminder {
        try await requireSession()
        if title == nil, isCompleted == nil {
            throw ReminderIntentError.nothingToUpdate
        }
        if isCompleted == true {
            let text = try await complete(id: id)
            return Reminder(
                id: id,
                userID: await ReminderStore.shared.currentUserID() ?? UUID(),
                text: text,
                sortOrder: 0,
                isDone: true,
                createdAt: .now
            )
        }
        do {
            let updated = try await ReminderStore.shared.update(
                id: id,
                text: title,
                isDone: isCompleted
            )
            await ReminderBoardSync.apply(updated)
            if let reminder = updated.first(where: { $0.id == id }) {
                return reminder
            }
            // Completed items drop out of the active cache.
            return Reminder(
                id: id,
                userID: await ReminderStore.shared.currentUserID() ?? UUID(),
                text: title ?? "",
                sortOrder: 0,
                isDone: isCompleted ?? false,
                createdAt: .now
            )
        } catch {
            throw map(error)
        }
    }

    private static func map(_ error: Error) -> ReminderIntentError {
        let message = error.localizedDescription
        if message.localizedCaseInsensitiveContains("sign in") || message.contains("401") {
            return .signedOut
        }
        if message.contains("post-it")
            || message.localizedCaseInsensitiveContains("full")
            || message.contains("409") {
            return .atCapacity
        }
        if message.localizedCaseInsensitiveContains("empty") {
            return .emptyText
        }
        return .service(message)
    }
}

@available(iOS 27.0, *)
struct ReminderIntentSnippetView: View {
    let headline: String
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(headline)
                .font(.headline)
            if lines.isEmpty {
                Text("Nothing on your board.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(lines.joined(separator: "\n"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

/// Siri AI (iOS 27) uses this schema for “add a reminder / remind me to …”.
@available(iOS 27.0, *)
@AppIntent(schema: .reminders.createReminder)
struct CreateReminderIntent {
    var title: String
    var list: ReminderListEntity?
    var note: AttributedString?
    var isFlagged: Bool?
    var images: [IntentFile]
    var tags: Set<String>
    var urls: [URL]
    var dueDate: DateComponents?
    var recurrence: Calendar.RecurrenceRule?

    @MainActor
    func perform() async throws -> some ReturnsValue<ReminderEntity> & ProvidesDialog & ShowsSnippetView {
        var text = title
        if let note {
            let extra = String(note.characters).trimmingCharacters(in: .whitespacesAndNewlines)
            if !extra.isEmpty, extra != text {
                text = "\(text) — \(extra)"
            }
        }
        let reminder = try await ReminderIntentActions.create(title: text)
        let entity = ReminderEntity(reminder)
        return .result(
            value: entity,
            dialog: "Added \(reminder.text) to your board.",
            view: ReminderIntentSnippetView(headline: "Added", lines: [reminder.text])
        )
    }
}

/// Siri AI uses this schema for “mark this as done / complete …” and title edits.
@available(iOS 27.0, *)
@AppIntent(schema: .reminders.updateReminder)
struct UpdateReminderIntent {
    var target: ReminderEntity
    var title: String?
    var note: AttributedString?
    var tags: Set<String>?
    var urls: [URL]?
    var dueDate: DateComponents?
    var recurrence: Calendar.RecurrenceRule?
    var isCompleted: Bool?
    var isFlagged: Bool?
    var list: ReminderListEntity?

    @MainActor
    func perform() async throws -> some ReturnsValue<ReminderEntity> & ProvidesDialog & ShowsSnippetView {
        var nextTitle = title
        if let note {
            let extra = String(note.characters).trimmingCharacters(in: .whitespacesAndNewlines)
            if !extra.isEmpty {
                nextTitle = extra
            }
        }
        let updated = try await ReminderIntentActions.update(
            id: target.id,
            title: nextTitle,
            isCompleted: isCompleted
        )
        let entity = ReminderEntity(updated)
        let dialog: String
        if updated.isDone {
            dialog = "Completed \(updated.text)."
        } else if let nextTitle {
            dialog = "Updated the reminder to \(nextTitle)."
        } else {
            dialog = "Updated \(updated.text)."
        }
        return .result(
            value: entity,
            dialog: IntentDialog(stringLiteral: dialog),
            view: ReminderIntentSnippetView(
                headline: updated.isDone ? "Completed" : "Updated",
                lines: [updated.text]
            )
        )
    }
}

/// Shortcuts-friendly complete path. Siri AI still prefers `UpdateReminderIntent`.
@available(iOS 27.0, *)
struct CompleteReminderIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Reminder"
    static var description = IntentDescription(
        "Marks a reminder on your board as done.",
        categoryName: "Reminders",
        searchKeywords: ["complete", "done", "finish", "check off"]
    )

    static var parameterSummary: some ParameterSummary {
        Summary("Complete \(\.$reminder)")
    }

    @Parameter(title: "Reminder")
    var reminder: ReminderEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let text = try await ReminderIntentActions.complete(id: reminder.id)
        return .result(
            dialog: "Completed \(text).",
            view: ReminderIntentSnippetView(headline: "Completed", lines: [text])
        )
    }
}

/// Explicit list action for “list my reminders / what’s on my board”.
@available(iOS 27.0, *)
struct ListRemindersIntent: AppIntent {
    static var title: LocalizedStringResource = "List Reminders"
    static var description = IntentDescription(
        "Lists the reminders currently on your board.",
        categoryName: "Reminders",
        searchKeywords: ["list", "show", "board", "reminders", "what's on"]
    )

    static var parameterSummary: some ParameterSummary {
        Summary("List reminders")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[ReminderEntity]> & ProvidesDialog & ShowsSnippetView {
        let reminders = try await ReminderIntentActions.loadActive(preferNetwork: true)
        let active = reminders.filter { !$0.isDone }
        let entities = active.map(ReminderEntity.init)
        let spoken = ReminderListSpoken.dialog(for: active)
        let headline = active.isEmpty ? "All clear" : "Your board"
        return .result(
            value: entities,
            dialog: IntentDialog(stringLiteral: spoken),
            view: ReminderIntentSnippetView(headline: headline, lines: active.map(\.text))
        )
    }
}

@available(iOS 27.0, *)
@AppIntent(schema: .system.open)
struct OpenReminderIntent: OpenIntent {
    var target: ReminderEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .didUpdateReminders, object: nil)
        return .result()
    }
}

extension View {
    /// Lets Siri resolve “this reminder” / “that third one” from the on-screen board.
    @ViewBuilder
    func reminderOnscreenIdentity(_ id: UUID) -> some View {
        if #available(iOS 27.0, *) {
            self.appEntityIdentifier(EntityIdentifier(for: ReminderEntity.self, identifier: id))
        } else {
            self
        }
    }
}
