import CoreSpotlight
import Foundation
import WidgetKit

/// Reloads the widget, Live Activity, Spotlight index, and in-app board after
/// a mutation from the UI, a push, or a Siri / Shortcuts intent.
enum ReminderBoardSync {
    static func apply(_ reminders: [Reminder], notify: Bool = true) async {
        WidgetCenter.shared.reloadAllTimelines()
        await ReminderLiveActivityController.sync(reminders: reminders)
        if #available(iOS 26.0, *) {
            await ReminderSpotlightIndex.replaceAll(reminders)
        }
        if notify {
            NotificationCenter.default.post(name: .didUpdateReminders, object: nil)
        }
    }

    static func clear() async {
        await apply([])
    }
}

@available(iOS 26.0, *)
enum ReminderSpotlightIndex {
    static let name = "systems.edmundlim.LazyMansReminders.reminders"

    static var searchableIndex: CSSearchableIndex {
        CSSearchableIndex(name: name)
    }

    static func replaceAll(_ reminders: [Reminder]) async {
        do {
            try await searchableIndex.deleteAllSearchableItems()
            try await index(reminders)
        } catch {
            print("Spotlight replace failed: \(error.localizedDescription)")
        }
    }

    static func index(_ reminders: [Reminder]) async throws {
        let entities = reminders.filter { !$0.isDone }.map(ReminderEntity.init)
        guard !entities.isEmpty else { return }
        try await searchableIndex.indexAppEntities(entities)
    }
}
