import UIKit

@MainActor
final class SilentPushRefresh {
    private var completion: ((UIBackgroundFetchResult) -> Void)?
    private var work: Task<Void, Never>?
    private var deadline: Task<Void, Never>?

    private init(completion: @escaping (UIBackgroundFetchResult) -> Void) {
        self.completion = completion
    }

    // Leave time for iOS to finish the notification's 30-second background window.
    @discardableResult
    static func start(
        store: ReminderStore = .shared,
        waitForDeadline: @escaping () async throws -> Void = {
            try await Task.sleep(nanoseconds: 25_000_000_000)
        },
        publish: @escaping ([Reminder]) async -> Void = { await ReminderBoardSync.apply($0) },
        completion: @escaping (UIBackgroundFetchResult) -> Void
    ) -> Task<Void, Never> {
        let refresh = SilentPushRefresh(completion: completion)
        let work = Task { @MainActor in
            do {
                try Task.checkCancellation()
                let previous = await store.cached()
                try Task.checkCancellation()
                let refreshed = try await store.refresh(performMaintenance: false)
                try Task.checkCancellation()
                await publish(refreshed)
                try Task.checkCancellation()
                refresh.finish(previous == refreshed ? .noData : .newData)
            } catch {
                refresh.finish(.failed)
            }
        }
        refresh.work = work
        // Separate tasks let the deadline complete even if work ignores cancellation.
        refresh.deadline = Task { @MainActor in
            do {
                try await waitForDeadline()
                try Task.checkCancellation()
                refresh.finish(.failed)
            } catch { }
        }
        return work
    }

    private func finish(_ result: UIBackgroundFetchResult) {
        guard let completion else { return }
        self.completion = nil
        work?.cancel()
        deadline?.cancel()
        work = nil
        deadline = nil
        completion(result)
    }
}
