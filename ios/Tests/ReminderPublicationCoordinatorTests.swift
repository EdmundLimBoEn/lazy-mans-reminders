import Foundation
import XCTest
@testable import LazyMansReminders

final class ReminderPublicationCoordinatorTests: XCTestCase {
    func testCleanupWaitsForOldPublicationPausedBeforeSpotlightIndex() async throws {
        try await checkCleanupWaits(pause: .beforeIndex)
    }

    func testCleanupWaitsForOldPublicationPausedBeforeLiveActivityStart() async throws {
        try await checkCleanupWaits(pause: .beforeActivity)
    }

    func testQueuedCleanupThenApplyLoadsReplacementAccountsCache() async throws {
        let old = sample("Account A")
        let replacement = sample("Account B")
        let fixture = Fixture(reminders: [old])
        let first = Task { try await fixture.coordinator.apply([old]) }
        await fulfillment(of: [fixture.paused], timeout: 3)
        await fixture.surfaces.setCache([])
        let cleanup = Task { try await fixture.coordinator.clear() }
        await waitForQueue(1, on: fixture.coordinator)
        let delayed = Task { try await fixture.coordinator.apply([old], notify: false) }
        await waitForQueue(2, on: fixture.coordinator)
        await fixture.surfaces.setCache([replacement])
        await fixture.surfaces.resume()
        try await first.value
        try await cleanup.value
        try await delayed.value
        let snapshot = await fixture.surfaces.snapshot()
        XCTAssertEqual(snapshot.transactions, [.board(notify: true), .clear, .board(notify: false)])
        XCTAssertEqual(snapshot.indexed, [replacement])
        XCTAssertEqual(snapshot.activity, [replacement])
        XCTAssertEqual(snapshot.published, [[old], [], [replacement]])
    }

    func testStaleApplyAfterCompletedCleanupCannotRestoreOldReminders() async throws {
        let old = sample("Account A")
        let fixture = Fixture(reminders: [], pause: nil)
        try await fixture.coordinator.clear()
        try await fixture.coordinator.apply([old])
        let snapshot = await fixture.surfaces.snapshot()
        XCTAssertEqual(snapshot.published, [[], []])
        XCTAssertTrue(snapshot.indexed.isEmpty)
        XCTAssertTrue(snapshot.activity.isEmpty)
    }

    func testReindexPathsShareCleanupGateAndReadCurrentCache() async throws {
        let old = sample("Account A")
        let replacement = sample("Account B", id: old.id)
        let other = sample("Another B reminder", userID: replacement.userID)
        let fixture = Fixture(reminders: [old])
        let first = Task { try await fixture.coordinator.reindexAll() }
        await fulfillment(of: [fixture.paused], timeout: 3)
        await fixture.surfaces.setCache([])
        let cleanup = Task { try await fixture.coordinator.clear() }
        await waitForQueue(1, on: fixture.coordinator)
        let partial = Task { try await fixture.coordinator.reindex(identifiers: [old.id]) }
        await waitForQueue(2, on: fixture.coordinator)
        let full = Task { try await fixture.coordinator.reindexAll() }
        await waitForQueue(3, on: fixture.coordinator)
        await fixture.surfaces.setCache([replacement, other])
        let beforeResume = await fixture.surfaces.snapshot()
        XCTAssertEqual(beforeResume.loads, 1, "Queued work must not capture the old cache")
        await fixture.surfaces.resume()
        try await first.value
        try await cleanup.value
        try await partial.value
        try await full.value
        let snapshot = await fixture.surfaces.snapshot()
        XCTAssertEqual(snapshot.transactions, [.replaceIndex, .clear, .index, .replaceIndex])
        XCTAssertEqual(snapshot.published, [[old], [], [replacement], [replacement, other]])
        XCTAssertEqual(snapshot.indexed, [replacement, other])
        XCTAssertTrue(snapshot.activity.isEmpty, "Reindexing must only publish Spotlight")
    }

    func testIdentifierReindexPreservesUnrelatedItemsAndDoesNotReplaceAll() async throws {
        let unrelated = sample("Already indexed")
        let requested = sample("Requested", userID: unrelated.userID)
        let fixture = Fixture(reminders: [unrelated], pause: nil)
        try await fixture.coordinator.reindexAll()
        await fixture.surfaces.setCache([requested])
        try await fixture.coordinator.reindex(identifiers: [requested.id, UUID()])
        let snapshot = await fixture.surfaces.snapshot()
        XCTAssertEqual(snapshot.indexed, [unrelated, requested])
        XCTAssertEqual(snapshot.published.last, [requested])
    }

    func testThrowingReindexReleasesGateForQueuedCleanup() async throws {
        let old = sample("Account A")
        let fixture = Fixture(reminders: [old], failFirst: true)
        let first = Task { try await fixture.coordinator.reindex(identifiers: [old.id]) }
        await fulfillment(of: [fixture.paused], timeout: 3)
        await fixture.surfaces.setCache([])
        let cleanup = Task { try await fixture.coordinator.clear() }
        await waitForQueue(1, on: fixture.coordinator)
        await fixture.surfaces.resume()
        do {
            try await first.value
            XCTFail("Reindex errors must propagate")
        } catch {
            XCTAssertTrue(error is FakeFailure)
        }
        try await cleanup.value
        let snapshot = await fixture.surfaces.snapshot()
        XCTAssertEqual(snapshot.transactions, [.index, .clear])
        XCTAssertTrue(snapshot.indexed.isEmpty)
        XCTAssertTrue(snapshot.activity.isEmpty)
    }

    private func checkCleanupWaits(pause: Pause) async throws {
        let old = sample("Account A")
        let fixture = Fixture(reminders: [old], pause: pause)
        let first = Task { try await fixture.coordinator.apply([old]) }
        await fulfillment(of: [fixture.paused], timeout: 3)
        await fixture.surfaces.setCache([])
        let cleanup = Task { try await fixture.coordinator.clear() }
        await waitForQueue(1, on: fixture.coordinator)
        let suspended = await fixture.surfaces.snapshot()
        XCTAssertEqual(suspended.transactions, [.board(notify: true)])
        XCTAssertEqual(suspended.loads, 1)
        await fixture.surfaces.resume()
        try await first.value
        try await cleanup.value
        let snapshot = await fixture.surfaces.snapshot()
        XCTAssertEqual(snapshot.transactions, [.board(notify: true), .clear])
        XCTAssertEqual(snapshot.published, [[old], []])
        XCTAssertTrue(snapshot.indexed.isEmpty)
        XCTAssertTrue(snapshot.activity.isEmpty)
    }

    private func waitForQueue(_ count: Int, on coordinator: ReminderPublicationCoordinator) async {
        for _ in 0..<10_000 {
            if await coordinator.queuedPublicationCount == count { return }
            await Task.yield()
        }
        XCTFail("Publication did not enter the queue")
    }

    private func sample(_ text: String, id: UUID = UUID(), userID: UUID = UUID()) -> Reminder {
        Reminder(id: id, userID: userID, text: text, sortOrder: 0, isDone: false, createdAt: Date())
    }

    private enum Pause { case beforeActivity, beforeIndex }
    private struct FakeFailure: Error {}

    private struct Fixture {
        let paused: XCTestExpectation
        let surfaces: FakeSurfaces
        let coordinator: ReminderPublicationCoordinator

        init(reminders: [Reminder], pause: Pause? = .beforeIndex, failFirst: Bool = false) {
            let paused = XCTestExpectation(description: "Old publication suspended")
            self.paused = paused
            let surfaces = FakeSurfaces(cache: reminders, paused: paused, pause: pause, failFirst: failFirst)
            self.surfaces = surfaces
            coordinator = ReminderPublicationCoordinator(
                load: { await surfaces.load() },
                publish: { try await surfaces.publish($0, $1) }
            )
        }
    }

    private actor FakeSurfaces {
        typealias Publication = ReminderPublicationCoordinator.Publication
        struct Snapshot {
            let loads: Int
            let transactions: [Publication]
            let published: [[Reminder]]
            let activity: [Reminder]
            let indexed: [Reminder]
        }

        private var cache: [Reminder]
        private let paused: XCTestExpectation
        private let pause: Pause?
        private let failFirst: Bool
        private var pending: CheckedContinuation<Void, Never>?
        private var loads = 0
        private var transactions: [Publication] = []
        private var published: [[Reminder]] = []
        private var activity: [Reminder] = []
        private var indexed: [Reminder] = []

        init(cache: [Reminder], paused: XCTestExpectation, pause: Pause?, failFirst: Bool) {
            self.cache = cache
            self.paused = paused
            self.pause = pause
            self.failFirst = failFirst
        }

        func load() -> [Reminder] {
            loads += 1
            return cache
        }
        func setCache(_ reminders: [Reminder]) { cache = reminders }

        func publish(_ reminders: [Reminder], _ publication: Publication) async throws {
            let isFirst = transactions.isEmpty
            transactions.append(publication)
            published.append(reminders)
            if isFirst && pause == .beforeActivity { await suspend() }
            switch publication {
            case .board, .clear: activity = reminders
            case .index, .replaceIndex: break
            }
            if publication != .index { indexed = [] }
            if isFirst && pause == .beforeIndex { await suspend() }
            if isFirst && failFirst { throw FakeFailure() }
            indexed.removeAll { item in reminders.contains { $0.id == item.id } }
            indexed.append(contentsOf: reminders.filter { !$0.isDone })
        }

        private func suspend() async {
            await withCheckedContinuation { continuation in
                pending = continuation
                paused.fulfill()
            }
        }

        func resume() {
            pending?.resume()
            pending = nil
        }

        func snapshot() -> Snapshot {
            Snapshot(loads: loads, transactions: transactions, published: published, activity: activity, indexed: indexed)
        }
    }
}
