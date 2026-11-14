import SwiftUI

@MainActor
final class RoutineListModel: ObservableObject {
    @Published private(set) var routines: [Routine] = []
    @Published private(set) var isLoading = true
    @Published private(set) var hasLoaded = false
    @Published private(set) var loadFailed = false
    @Published private(set) var isBusy = false
    @Published var error: String?
    private var revision = 0
    private let store: RoutineStore

    init(store: RoutineStore = .shared) { self.store = store }

    enum SaveError: LocalizedError {
        case busy

        var errorDescription: String? {
            "A routine change is in progress. Try again."
        }
    }

    var showsEmpty: Bool {
        RoutinePresentation.showsEmpty(isLoading: isLoading, hasLoaded: hasLoaded,
                                       count: routines.count, loadFailed: loadFailed)
    }

    func refresh(userID: UUID) async {
        guard !isBusy else { return }
        revision += 1
        let readRevision = revision
        isLoading = true
        defer { if revision == readRevision { isLoading = false } }
        do {
            let rows = try await store.list(userID: userID)
            guard revision == readRevision, !Task.isCancelled else { return }
            routines = rows
            hasLoaded = true
            loadFailed = false
            error = nil
        } catch {
            guard revision == readRevision, !Task.isCancelled else { return }
            loadFailed = true
            self.error = error.localizedDescription
        }
    }

    func save(_ draft: RoutineDraft, userID: UUID) async throws {
        guard !isBusy else { throw SaveError.busy }
        beginMutation()
        do {
            try await store.save(draft, userID: userID)
            endMutation()
            await refresh(userID: userID)
        } catch {
            endMutation()
            throw error
        }
    }

    func change(_ routine: Routine, delete: Bool, userID: UUID) async {
        guard !isBusy else { return }
        beginMutation()
        do {
            if delete {
                try await store.delete(id: routine.id, userID: userID)
                routines.removeAll { $0.id == routine.id }
            } else {
                try await store.setEnabled(!routine.enabled, id: routine.id, userID: userID)
                if let index = routines.firstIndex(where: { $0.id == routine.id }) {
                    routines[index].enabled = !routine.enabled
                }
            }
            endMutation()
            await refresh(userID: userID)
        } catch {
            endMutation()
            self.error = error.localizedDescription
        }
    }

    private func beginMutation() {
        revision += 1
        isBusy = true
        isLoading = false
        error = nil
    }

    private func endMutation() {
        // Invalidate reads started before or during this write, even on failure.
        revision += 1
        isBusy = false
    }
}
