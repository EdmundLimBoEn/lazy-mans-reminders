import CoreSpotlight
import Foundation
import WidgetKit

/// Reloads the widget, Live Activity, Spotlight index, and in-app board after
/// a mutation from the UI, a push, or a Siri / Shortcuts intent.
enum ReminderBoardSync {
    private static let coordinator = ReminderPublicationCoordinator(
        load: { await ReminderStore.shared.cached() },
        publish: publish
    )

    static func apply(_ reminders: [Reminder], notify: Bool = true) async {
        try? await coordinator.apply(reminders, notify: notify)
    }

    static func clear() async {
        try? await coordinator.clear()
    }

    static func reindex(identifiers: [UUID]) async throws {
        try await coordinator.reindex(identifiers: identifiers)
    }

    static func reindexAll() async throws {
        try await coordinator.reindexAll()
    }

    private static func publish(
        _ reminders: [Reminder], publication: ReminderPublicationCoordinator.Publication
    ) async throws {
        switch publication {
        case .index, .replaceIndex:
#if LMR_REMINDERS_SCHEMA
            if #available(iOS 27.0, *) {
                if publication == .index {
                    try await ReminderSpotlightIndex.index(reminders)
                } else {
                    try await ReminderSpotlightIndex.replaceAll(reminders)
                }
            }
#else
            if #available(iOS 18.0, *) {
                if publication == .index {
                    try await ReminderSpotlightIndex.index(reminders)
                } else {
                    try await ReminderSpotlightIndex.replaceAll(reminders)
                }
            }
#endif
            return
        case .board, .clear:
            break
        }

        WidgetCenter.shared.reloadAllTimelines()
        await ReminderLiveActivityController.sync(reminders: reminders)
        do {
#if LMR_REMINDERS_SCHEMA
            if #available(iOS 27.0, *) {
                try await ReminderSpotlightIndex.replaceAll(reminders)
            }
#else
            if #available(iOS 18.0, *) {
                try await ReminderSpotlightIndex.replaceAll(reminders)
            }
#endif
        } catch {
            print("Spotlight replace failed: \(error.localizedDescription)")
        }
        let notify: Bool
        if case .board(let requested) = publication { notify = requested } else { notify = true }
        if notify {
            NotificationCenter.default.post(name: .didUpdateReminders, object: nil)
        }
    }
}

#if LMR_REMINDERS_SCHEMA
@available(iOS 27.0, *)
#else
@available(iOS 18.0, *)
#endif
enum ReminderSpotlightIndex {
    static let name = "systems.edmundlim.LazyMansReminders.reminders"

    static var searchableIndex: CSSearchableIndex {
        CSSearchableIndex(name: name)
    }

    static func replaceAll(_ reminders: [Reminder]) async throws {
        try await searchableIndex.deleteAllSearchableItems()
        try await index(reminders)
    }

    static func index(_ reminders: [Reminder]) async throws {
        let entities = reminders.filter { !$0.isDone }.map(ReminderEntity.init)
        guard !entities.isEmpty else { return }
        try await searchableIndex.indexAppEntities(entities)
    }
}
