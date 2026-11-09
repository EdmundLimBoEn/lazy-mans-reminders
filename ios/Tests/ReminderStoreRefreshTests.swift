import Foundation
import XCTest
@testable import LazyMansReminders

final class ReminderStoreRefreshTests: XCTestCase {
    func testDelayedWidgetRefreshCannotOverwriteAnotherStoresAcknowledgedMutation() async throws {
        for isDone in [true, false] {
            let fixture = Fixture()
            defer { fixture.cleanUp() }
            let started = expectation(description: "Widget refresh suspended")
            var acknowledged = fixture.original
            acknowledged.text = "Acknowledged edit"
            acknowledged.isDone = isDone
            let network = Network(started: [started], mutation: acknowledged)
            // Separate actors model the independent revision counters in the app and widget.
            let app = fixture.makeStore(network)
            let widget = fixture.makeStore(network)
            try await fixture.seed(app, rows: [fixture.original])
            // Each store may have its own injected credential storage. Sign both in
            // before starting the race; only the board cache is shared by this fixture.
            try await fixture.seed(widget, rows: [fixture.original])

            let refresh = Task {
                await widget.refreshOrCachedSnapshot(refreshAuthentication: false, updateCache: false)
            }
            await fulfillment(of: [started], timeout: 3)
            let expected = try await app.update(
                id: acknowledged.id, text: acknowledged.text, isDone: isDone
            )
            XCTAssertEqual(expected, isDone ? [] : [acknowledged])
            await network.finish(0, rows: [fixture.original])

            let timeline = await refresh.value
            XCTAssertEqual(timeline, [fixture.original])
            let cache = await app.cached()
            XCTAssertEqual(cache, expected)
            await network.failRequests()
            let fallback = await widget.refreshOrCachedSnapshot(refreshAuthentication: false, updateCache: false)
            XCTAssertEqual(fallback, expected, "A mutation during the fetch must supersede its snapshot")
        }
    }

    func testWidgetRefreshReturnsFetchedTimelineWithoutUpdatingCache() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let started = expectation(description: "Widget refresh suspended")
        let network = Network(started: [started], mutation: fixture.original)
        let widget = fixture.makeStore(network)
        try await fixture.seed(widget, rows: [])
        let refresh = Task {
            await widget.refreshOrCachedSnapshot(refreshAuthentication: false, updateCache: false)
        }
        await fulfillment(of: [started], timeout: 3)
        await network.finish(0, rows: [fixture.original])

        let timeline = await refresh.value
        let cache = await widget.cached()
        XCTAssertEqual(timeline, [fixture.original])
        XCTAssertEqual(cache, [])
    }

    func testFailedWidgetRefreshFallsBackToAppCache() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let network = Network(started: [], mutation: fixture.original, failsRequests: true)
        let widget = fixture.makeStore(network)
        try await fixture.seed(widget, rows: [fixture.original])

        let timeline = await widget.refreshOrCachedSnapshot(refreshAuthentication: false, updateCache: false)
        let cache = await widget.cached()
        XCTAssertEqual(timeline, [fixture.original])
        XCTAssertEqual(cache, [fixture.original])
        let requests = await network.requestCount
        XCTAssertEqual(requests, 1, "Fallback must follow a failed fetch, not a missing session")
    }

    func testFailedWidgetRefreshWithoutUsableCacheShowsBoardError() async throws {
        for cache in [nil, Data("invalid cache".utf8)] as [Data?] {
            let fixture = Fixture()
            defer { fixture.cleanUp() }
            let network = Network(started: [], mutation: fixture.original, failsRequests: true)
            let widget = fixture.makeStore(network)
            try await fixture.seed(widget, rows: [])
            fixture.defaults.set(cache, forKey: "cached-reminders")
            fixture.defaults.set(cache, forKey: "widget-reminders-snapshot")

            let cached = await widget.widgetCached()
            XCTAssertNil(cached)
            let snapshot = await widget.refreshOrCachedSnapshot(refreshAuthentication: false, updateCache: false)

            XCTAssertNil(snapshot)
            XCTAssertEqual(ReminderActivityPresentation.displayLines(from: snapshot), ["Couldn’t Load Board"])
            let requests = await network.requestCount
            XCTAssertEqual(requests, 1)
        }
    }

    func testHTTPFailureWithoutCacheShowsBoardError() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let widget = ReminderStore(
            defaults: fixture.defaults, credentials: MemorySessionCredentials(),
            serviceURL: URL(string: "https://reminders.invalid")!, anonKey: "test-key",
            requestData: { request in
                (Data(), HTTPURLResponse(url: request.url!, statusCode: 503,
                                         httpVersion: nil, headerFields: nil)!)
            }
        )
        try await fixture.seed(widget, rows: [])
        fixture.defaults.removeObject(forKey: "cached-reminders")

        let snapshot = await widget.refreshOrCachedSnapshot(refreshAuthentication: false, updateCache: false)

        XCTAssertNil(snapshot)
        XCTAssertEqual(ReminderActivityPresentation.displayLines(from: snapshot), ["Couldn’t Load Board"])
    }

    func testFailedWidgetRefreshWithCachedEmptyBoardShowsEmptyState() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let network = Network(started: [], mutation: fixture.original, failsRequests: true)
        let widget = fixture.makeStore(network)
        try await fixture.seed(widget, rows: [])

        let snapshot = await widget.refreshOrCachedSnapshot(refreshAuthentication: false, updateCache: false)

        XCTAssertEqual(snapshot, [])
        XCTAssertEqual(ReminderActivityPresentation.displayLines(from: snapshot), ["Nothing to remember"])
    }

    func testSuccessfulEmptyWidgetRefreshWithoutCacheShowsEmptyState() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let started = expectation(description: "Widget refresh suspended")
        let network = Network(started: [started], mutation: fixture.original)
        let widget = fixture.makeStore(network)
        try await fixture.seed(widget, rows: [])
        fixture.defaults.removeObject(forKey: "cached-reminders")

        let refresh = Task {
            await widget.refreshOrCachedSnapshot(refreshAuthentication: false, updateCache: false)
        }
        await fulfillment(of: [started], timeout: 3)
        await network.finish(0, rows: [])
        let snapshot = await refresh.value

        XCTAssertEqual(snapshot, [])
        XCTAssertEqual(ReminderActivityPresentation.displayLines(from: snapshot), ["Nothing to remember"])
        XCTAssertNil(fixture.defaults.data(forKey: "cached-reminders"))

        await network.failRequests()
        let fallback = await widget.refreshOrCachedSnapshot(refreshAuthentication: false, updateCache: false)
        XCTAssertEqual(fallback, [], "A successful empty widget snapshot is usable without an app cache")
        let cached = await widget.widgetCached()
        XCTAssertEqual(cached, [])
    }

    func testSuccessfulWidgetSnapshotSurvivesFailureAndProcessRestart() async throws {
        for empty in [true, false] {
            let fixture = Fixture()
            defer { fixture.cleanUp() }
            let started = expectation(description: "Widget refresh suspended")
            let network = Network(started: [started], mutation: fixture.original)
            let credentials = MemorySessionCredentials()
            let widget = fixture.makeStore(network, credentials: credentials)
            try await fixture.seed(widget, rows: [fixture.original])
            var edited = fixture.original
            edited.text = "Remote edit"
            let expected = empty ? [] : [edited]
            let refresh = Task {
                await widget.refreshOrCachedSnapshot(refreshAuthentication: false, updateCache: false)
            }
            await fulfillment(of: [started], timeout: 3)
            await network.finish(0, rows: expected)
            let fetched = await refresh.value
            XCTAssertEqual(fetched, expected)
            await network.failRequests()

            // Widget processes are short lived; the last result must survive a new store.
            let restarted = fixture.makeStore(network, credentials: credentials)
            let fallback = await restarted.refreshOrCachedSnapshot(refreshAuthentication: false, updateCache: false)
            XCTAssertEqual(fallback, expected)
            let snapshot = await restarted.widgetCached()
            XCTAssertEqual(snapshot, expected)
            let appCache = await restarted.cached()
            XCTAssertEqual(appCache, [fixture.original])

            try await restarted.saveSession(accessToken: "test-token", refreshToken: "test-refresh",
                                            expiresAt: .distantPast, userID: fixture.original.userID)
            let expired = await restarted.refreshOrCachedSnapshot(refreshAuthentication: false, updateCache: false)
            XCTAssertEqual(expired, expected)
            let requests = await network.requestCount
            XCTAssertEqual(requests, 2, "Expired shared credentials must use the saved snapshot without a request")

            await restarted.clearUserData()
            try await fixture.seed(restarted, rows: [fixture.original])
            let signedInAgain = await restarted.refreshOrCachedSnapshot(refreshAuthentication: false, updateCache: false)
            XCTAssertEqual(signedInAgain, [fixture.original], "A new session must not reuse the previous snapshot")
        }
    }

    func testNewerAppMutationSupersedesWidgetSnapshot() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let started = expectation(description: "Widget refresh suspended")
        var edited = fixture.original
        edited.text = "App edit"
        let network = Network(started: [started], mutation: edited)
        let credentials = MemorySessionCredentials()
        let widget = fixture.makeStore(network, credentials: credentials)
        let app = fixture.makeStore(network, credentials: credentials)
        try await fixture.seed(app, rows: [fixture.original])
        let refresh = Task {
            await widget.refreshOrCachedSnapshot(refreshAuthentication: false, updateCache: false)
        }
        await fulfillment(of: [started], timeout: 3)
        await network.finish(0, rows: [])
        let fetched = await refresh.value
        XCTAssertEqual(fetched, [])
        _ = try await app.update(id: edited.id, text: edited.text)
        await network.failRequests()
        let fallback = await widget.refreshOrCachedSnapshot(refreshAuthentication: false, updateCache: false)
        XCTAssertEqual(fallback, [edited])
    }

    func testAccountSwitchInvalidatesSuccessfulWidgetSnapshot() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let started = expectation(description: "Widget refresh suspended")
        let network = Network(started: [started], mutation: fixture.original)
        let widget = fixture.makeStore(network)
        try await fixture.seed(widget, rows: [])
        let refresh = Task {
            await widget.refreshOrCachedSnapshot(refreshAuthentication: false, updateCache: false)
        }
        await fulfillment(of: [started], timeout: 3)
        await network.finish(0, rows: [fixture.original])
        let fetched = await refresh.value
        XCTAssertEqual(fetched, [fixture.original])
        try await widget.saveSession(accessToken: "other-token", refreshToken: "other-refresh",
                                     expiresAt: .distantFuture, userID: UUID())
        await network.failRequests()
        let fallback = await widget.refreshOrCachedSnapshot(refreshAuthentication: false, updateCache: false)
        XCTAssertNil(fallback)
    }

    func testDelayedRefreshCannotOverwriteAcknowledgedMutations() async throws {
        for mutation in ["create", "complete", "edit", "reopen"] {
            let fixture = Fixture()
            defer { fixture.cleanUp() }
            let started = expectation(description: "Old refresh suspended")
            var acknowledged = fixture.original
            acknowledged.text = "Acknowledged"
            acknowledged.isDone = mutation == "complete"
            let initial = mutation == "create" || mutation == "reopen" ? [] : [fixture.original]
            let network = Network(started: [started], mutation: acknowledged)
            let store = fixture.makeStore(network)
            try await fixture.seed(store, rows: initial)

            let refresh = Task { try await store.refresh(performMaintenance: false) }
            await fulfillment(of: [started], timeout: 3)
            let expected: [Reminder]
            switch mutation {
            case "create": expected = try await store.create(text: acknowledged.text)
            case "complete": expected = try await store.markDone(id: acknowledged.id)
            case "edit": expected = try await store.update(id: acknowledged.id, text: acknowledged.text)
            default: expected = try await store.update(id: acknowledged.id, isDone: false)
            }
            XCTAssertEqual(expected, acknowledged.isDone ? [] : [acknowledged])
            await network.finish(0, rows: initial)
            let result = try await refresh.value
            let cache = await store.cached()
            XCTAssertEqual(result, expected, mutation)
            XCTAssertEqual(cache, expected, mutation)
        }
    }

    func testFailedNewerRefreshDoesNotDiscardOlderSuccessfulResponse() async throws {
        for emptyCache in [true, false] {
            let fixture = Fixture()
            defer { fixture.cleanUp() }
            let first = expectation(description: "Older refresh suspended")
            let second = expectation(description: "Newer refresh suspended")
            let network = Network(started: [first, second], mutation: fixture.original)
            let store = fixture.makeStore(network)
            try await fixture.seed(store, rows: emptyCache ? [] : [fixture.original])

            let older = Task { try await store.refresh(performMaintenance: false) }
            await fulfillment(of: [first], timeout: 3)
            let newer = Task { try await store.refresh(performMaintenance: false) }
            await fulfillment(of: [second], timeout: 3)
            await network.fail(1)
            do {
                _ = try await newer.value
                XCTFail("Expected the newer refresh to fail")
            } catch {
                XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
            }

            var updated = fixture.original
            updated.text = "Successful remote edit"
            await network.finish(0, rows: [updated])
            let result = try await older.value
            let cache = await store.cached()
            XCTAssertEqual(result, [updated])
            XCTAssertEqual(cache, [updated])
        }
    }

    func testOlderRefreshCannotOverwriteNewerRefreshInEitherResponseOrder() async throws {
        for newestFirst in [true, false] {
            let fixture = Fixture()
            defer { fixture.cleanUp() }
            let first = expectation(description: "First refresh suspended")
            let second = expectation(description: "Second refresh suspended")
            let network = Network(started: [first, second], mutation: fixture.original)
            let store = fixture.makeStore(network)
            try await fixture.seed(store, rows: [fixture.original])
            let older = Task { try await store.refresh(performMaintenance: false) }
            await fulfillment(of: [first], timeout: 3)
            let newer = Task { try await store.refresh(performMaintenance: false) }
            await fulfillment(of: [second], timeout: 3)
            var updated = fixture.original
            updated.text = "Newest snapshot"
            if newestFirst {
                await network.finish(1, rows: [updated])
                let result = try await newer.value
                XCTAssertEqual(result, [updated])
                await network.finish(0, rows: [])
                let oldResult = try await older.value
                XCTAssertEqual(oldResult, [updated])
            } else {
                await network.finish(0, rows: [])
                let oldResult = try await older.value
                XCTAssertEqual(oldResult, [], "A pending newer refresh must not discard a successful response")
                await network.finish(1, rows: [updated])
                let result = try await newer.value
                XCTAssertEqual(result, [updated])
            }
            let cache = await store.cached()
            XCTAssertEqual(cache, [updated])
        }
    }

    private actor Network {
        let started: [XCTestExpectation]
        let mutation: Reminder
        var failsRequests: Bool
        private(set) var requestCount = 0
        private var pending: [Int: CheckedContinuation<(Data, URLResponse), Error>] = [:]
        private var next = 0

        init(started: [XCTestExpectation], mutation: Reminder, failsRequests: Bool = false) {
            self.started = started
            self.mutation = mutation
            self.failsRequests = failsRequests
        }

        func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
            requestCount += 1
            if failsRequests { throw URLError(.notConnectedToInternet) }
            if request.httpMethod == "POST" || request.httpMethod == "PATCH" {
                return try response([mutation])
            }
            XCTAssertEqual(request.httpMethod, "GET")
            let index = next
            next += 1
            return try await withCheckedThrowingContinuation { continuation in
                pending[index] = continuation
                started[index].fulfill()
            }
        }

        func failRequests() { failsRequests = true }

        func fail(_ index: Int) {
            guard let continuation = pending.removeValue(forKey: index) else {
                XCTFail("Expected suspended refresh")
                return
            }
            continuation.resume(throwing: URLError(.notConnectedToInternet))
        }

        func finish(_ index: Int, rows: [Reminder]) {
            guard let continuation = pending.removeValue(forKey: index) else {
                XCTFail("Expected suspended refresh")
                return
            }
            continuation.resume(with: Result { try response(rows) })
        }

        private func response(_ rows: [Reminder]) throws -> (Data, URLResponse) {
            (try ReminderJSON.encoder.encode(rows),
             HTTPURLResponse(url: URL(string: "https://reminders.invalid/rest/v1/reminders")!,
                             statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
    }

    private struct Fixture {
        let suite = "ReminderStoreRefreshTests.\(UUID())"
        let defaults: UserDefaults
        let original = Reminder(id: UUID(), userID: UUID(), text: "Original", sortOrder: 0,
                                isDone: false, createdAt: Date(timeIntervalSince1970: 1_775_000_000))

        init() { defaults = UserDefaults(suiteName: suite)! }

        func makeStore(_ network: Network, credentials: MemorySessionCredentials = MemorySessionCredentials()) -> ReminderStore {
            ReminderStore(defaults: defaults, credentials: credentials, serviceURL: URL(string: "https://reminders.invalid")!,
                          anonKey: "test-key", requestData: { try await network.send($0) })
        }

        func seed(_ store: ReminderStore, rows: [Reminder]) async throws {
            try await store.saveSession(accessToken: "test-token", refreshToken: "test-refresh",
                                        expiresAt: Date().addingTimeInterval(3600), userID: original.userID)
            defaults.set(try ReminderJSON.encoder.encode(rows), forKey: "cached-reminders")
        }

        func cleanUp() { defaults.removePersistentDomain(forName: suite) }
    }
}
