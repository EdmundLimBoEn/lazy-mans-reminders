import AppIntents

@available(iOS 27.0, *)
struct ReminderShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor { .purple }

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ListRemindersIntent(),
            phrases: [
                "List reminders in \(.applicationName)",
                "Show my reminders in \(.applicationName)",
                "What is on my board in \(.applicationName)",
                "Read my reminders in \(.applicationName)"
            ],
            shortTitle: "List reminders",
            systemImageName: "checklist"
        )
        AppShortcut(
            intent: CreateReminderIntent(),
            phrases: [
                "Add a reminder in \(.applicationName)",
                "Create a reminder in \(.applicationName)",
                "Remind me in \(.applicationName)",
                "New reminder in \(.applicationName)"
            ],
            shortTitle: "New reminder",
            systemImageName: "plus"
        )
        AppShortcut(
            intent: CompleteReminderIntent(),
            phrases: [
                "Complete a reminder in \(.applicationName)",
                "Mark a reminder as done in \(.applicationName)",
                "Mark this as done in \(.applicationName)",
                "Finish a reminder in \(.applicationName)"
            ],
            shortTitle: "Complete reminder",
            systemImageName: "checkmark.circle"
        )
    }
}
