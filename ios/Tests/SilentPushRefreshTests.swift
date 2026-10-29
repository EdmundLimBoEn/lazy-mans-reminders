import Foundation
import UIKit
import XCTest
@testable import LazyMansReminders

@MainActor
final class SilentPushRefreshTests: XCTestCase {
    func testFixtureKeepsCredentialsInMemoryAndIsolatedBetweenStores() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let store = fixture.store(Network(rows: []))
        try await fixture.signIn(store)

        let signedIn = await store.containsSession(accessToken: "test-token", refreshToken: "test-refresh")
        XCTAssertTrue(signedIn)

        // Even with the same defaults, a new fixture store must not inherit credentials
        // from a shared Keychain (which is unavailable in unsigned simulator tests).
        let otherStore = fixture.store(Network(rows: []))
        let inheritedSession = await otherStore.containsSession(accessToken: "test-token", refreshToken: "test-refresh")
        XCTAssertFalse(inheritedSession)
    }

    func testRefreshSkipsCleanupAndReportsChangedAndUnchangedBoards() async throws {
        for changed in [false, true] {
            let fixture = Fixture()
            defer { fixture.cleanUp() }
            let rows = changed ? [fixture.reminder] : []
            let network = Network(rows: rows)
            let store = fixture.store(network)
            try await fixture.signIn(store)
            let deadline = Gate()
            var results: [UIBackgroundFetchResult] = []
            var published: [[Reminder]] = []
            let work = SilentPushRefresh.start(
                store: store,
                waitForDeadline: { await deadline.wait() },
                publish: { published.append($0) },
                completion: { results.append($0) }
            )
            await fulfillment(of: [deadline.started], timeout: 3)
            await work.value
            await deadline.release()
            XCTAssertEqual(results, [changed ? .newData : .noData])
            XCTAssertEqual(published, [rows])
            let paths = await network.paths
            XCTAssertEqual(paths, ["/rest/v1/reminders"])
        }
    }

    func testNetworkFailureCompletesOnceWithoutPublishing() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let network = Network(rows: [], fails: true)
        let store = fixture.store(network)
        try await fixture.signIn(store)
        var results: [UIBackgroundFetchResult] = []
        let work = SilentPushRefresh.start(
            store: store,
            publish: { _ in XCTFail("Failed fetch must not publish") },
            completion: { results.append($0) }
        )
        await work.value
        XCTAssertEqual(results, [.failed])
    }

    func testDeadlineCompletesBeforeStalledFetchReturnsAndRejectsLateSnapshot() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let stalledFetch = Gate()
        let deadline = Gate()
        let network = Network(rows: [fixture.reminder], gate: stalledFetch)
        let store = fixture.store(network)
        try await fixture.signIn(store)
        let completed = expectation(description: "Deadline completes notification")
        var results: [UIBackgroundFetchResult] = []
        let work = SilentPushRefresh.start(
            store: store,
            waitForDeadline: { await deadline.wait() },
            publish: { _ in XCTFail("Expired fetch must not publish") },
            completion: { results.append($0); completed.fulfill() }
        )
        await fulfillment(of: [stalledFetch.started, deadline.started], timeout: 3)
        await deadline.release()
        await fulfillment(of: [completed], timeout: 3)
        XCTAssertTrue(work.isCancelled)
        // This mock deliberately ignores cancellation, like an uncooperative dependency.
        await stalledFetch.release()
        await work.value
        XCTAssertEqual(results, [.failed])
        let cached = await store.cached()
        XCTAssertEqual(cached, [])
    }

    func testDeadlineAlsoBoundsPublicationAndIgnoresItsLateCompletion() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let store = fixture.store(Network(rows: []))
        try await fixture.signIn(store)
        let publication = Gate()
        let deadline = Gate()
        let completed = expectation(description: "Deadline completes during publication")
        var results: [UIBackgroundFetchResult] = []
        let work = SilentPushRefresh.start(
            store: store,
            waitForDeadline: { await deadline.wait() },
            publish: { _ in await publication.wait() },
            completion: { results.append($0); completed.fulfill() }
        )
        await fulfillment(of: [publication.started, deadline.started], timeout: 3)
        await deadline.release()
        await fulfillment(of: [completed], timeout: 3)
        XCTAssertTrue(work.isCancelled)
        await publication.release()
        await work.value
        XCTAssertEqual(results, [.failed])
    }

    private actor Gate {
        nonisolated let started = XCTestExpectation(description: "Operation suspended")
        private var continuation: CheckedContinuation<Void, Never>?

        func wait() async {
            await withCheckedContinuation {
                continuation = $0
                started.fulfill()
            }
        }

        func release() {
            continuation?.resume()
            continuation = nil
        }
    }

    private actor Network {
        let rows: [Reminder]
        let gate: Gate?
        let fails: Bool
        private(set) var paths: [String] = []

        init(rows: [Reminder], gate: Gate? = nil, fails: Bool = false) {
            self.rows = rows
            self.gate = gate
            self.fails = fails
        }

        func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
            paths.append(request.url!.path)
            if let gate { await gate.wait() }
            if fails { throw URLError(.notConnectedToInternet) }
            return (
                try ReminderJSON.encoder.encode(rows),
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            )
        }
    }

    private struct Fixture {
        let suite = "SilentPushRefreshTests.\(UUID())"
        let defaults: UserDefaults
        let reminder = Reminder(id: UUID(), userID: UUID(), text: "Test", sortOrder: 0,
                                isDone: false, createdAt: Date(timeIntervalSince1970: 1_775_000_000))

        init() { defaults = UserDefaults(suiteName: suite)! }

        func store(_ network: Network) -> ReminderStore {
            ReminderStore(defaults: defaults, credentials: MemorySessionCredentials(),
                          serviceURL: URL(string: "https://reminders.invalid")!,
                          anonKey: "test-key", requestData: { try await network.send($0) })
        }

        func signIn(_ store: ReminderStore) async throws {
            try await store.saveSession(accessToken: "test-token", refreshToken: "test-refresh",
                                        expiresAt: Date().addingTimeInterval(3600), userID: reminder.userID)
        }

        func cleanUp() { defaults.removePersistentDomain(forName: suite) }
    }
}
