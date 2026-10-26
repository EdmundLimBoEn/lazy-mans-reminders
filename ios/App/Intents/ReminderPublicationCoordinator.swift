import Foundation

actor ReminderPublicationCoordinator {
    enum Publication: Equatable {
        case board(notify: Bool)
        case clear
        case index
        case replaceIndex
    }

    private let load: () async -> [Reminder]
    private let publish: ([Reminder], Publication) async throws -> Void
    private var isPublishing = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    var queuedPublicationCount: Int { waiters.count }

    init(
        load: @escaping () async -> [Reminder],
        publish: @escaping ([Reminder], Publication) async throws -> Void
    ) {
        self.load = load
        self.publish = publish
    }

    // Callers may hold a completed result from an earlier account. Only the
    // cache loaded inside the publication gate can supply published reminders.
    func apply(_ reminders: [Reminder], notify: Bool = true) async throws {
        try await run(.board(notify: notify))
    }

    func clear() async throws {
        try await run(.clear)
    }

    func refresh(_ fetch: () async throws -> [Reminder]) async throws -> [Reminder] {
        try Task.checkCancellation()
        // Restore a saved board before network/auth refresh, including when offline.
        // An empty cache is not evidence that a remote board was cleared.
        try await run(.board(notify: false), onlyIfNonempty: true)
        _ = try await fetch()
        try Task.checkCancellation()
        try await run(.board(notify: false))
        return await load()
    }

    func reindex(identifiers: [UUID]) async throws {
        try await run(.index, identifiers: identifiers)
    }

    func reindexAll() async throws {
        try await run(.replaceIndex)
    }

    private func run(
        _ publication: Publication, identifiers: [UUID]? = nil, onlyIfNonempty: Bool = false
    ) async throws {
        await acquire()
        defer { release() }
        let current = await load()
        if onlyIfNonempty && current.isEmpty { return }
        let reminders: [Reminder]
        if publication == .clear {
            reminders = []
        } else if let identifiers {
            reminders = current.filter { identifiers.contains($0.id) }
        } else {
            reminders = current
        }
        try await publish(reminders, publication)
    }

    private func acquire() async {
        if !isPublishing {
            isPublishing = true
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    private func release() {
        if waiters.isEmpty {
            isPublishing = false
        } else {
            // Ownership transfers to the oldest waiter without opening the gate
            // to a reentrant call while that waiter resumes.
            waiters.removeFirst().resume()
        }
    }
}

/// Used only inside the publication gate, so replacement and invalidation cannot overlap.
/// Keep the exact snapshot (including owner IDs) to avoid digest collisions.
actor ReminderSpotlightSnapshot {
    private var indexed: [Reminder]?

    func invalidate() {
        indexed = nil
    }

    func replace(
        _ reminders: [Reminder], force: Bool = false,
        using replace: ([Reminder]) async throws -> Void
    ) async throws {
        guard force || indexed != reminders else { return }
        // A failed replacement may already have deleted the previous index.
        indexed = nil
        try await replace(reminders)
        indexed = reminders
    }
}
