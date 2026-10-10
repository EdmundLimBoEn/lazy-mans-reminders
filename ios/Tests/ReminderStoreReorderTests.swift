import Foundation
import XCTest
@testable import LazyMansReminders

final class ReminderStoreReorderTests: XCTestCase {
    func testReorderSavesAndCachesAcknowledgedOrderInOneRequest() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let original = fixture.reminders
        let reordered = [original[2], original[0], original[1]].enumerated().map { index, reminder in
            var updated = reminder
            updated.sortOrder = index
            return updated
        }
        let ids = reordered.map(\.id)
        let store = fixture.makeStore { request in
            XCTAssertEqual(request.url?.path, "/rest/v1/rpc/reorder_reminders")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            let body = try XCTUnwrap(request.httpBody)
            let fields = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: [String]])
            XCTAssertEqual(fields["p_ids"], ids.map(\.uuidString))
            return fixture.response(try ReminderJSON.encoder.encode(reordered), request: request)
        }
        try await fixture.seed(store)
        let result = try await store.reorder(ids: ids)
        XCTAssertEqual(result, reordered)
        let cache = await store.cached()
        XCTAssertEqual(cache, reordered)
    }

    func testInvalidResponsesAndFailuresLeaveOriginalCacheUntouched() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        var reordered = Array(fixture.reminders.reversed())
        for index in reordered.indices { reordered[index].sortOrder = index }
        var wrongOrder = reordered
        wrongOrder[0].sortOrder = 99
        var wrongOwner = reordered
        wrongOwner[0] = Reminder(id: reordered[0].id, userID: UUID(), text: "Other account",
                                 sortOrder: 0, isDone: false, createdAt: Date())
        var completed = reordered
        completed[0].isDone = true
        for (data, status) in [
            (Data("[]".utf8), 200), (Data("not json".utf8), 200),
            (try ReminderJSON.encoder.encode(wrongOrder), 200),
            (try ReminderJSON.encoder.encode(wrongOwner), 200),
            (try ReminderJSON.encoder.encode(completed), 200),
            (try ReminderJSON.encoder.encode(reordered), 409),
            (Data(), 0),
        ] {
            let store = fixture.makeStore { request in
                if status == 0 { throw URLError(.timedOut) }
                return fixture.response(data, request: request, status: status)
            }
            try await fixture.seed(store)
            let before = fixture.defaults.data(forKey: "cached-reminders")
            do {
                _ = try await store.reorder(ids: reordered.map(\.id))
                XCTFail("Unconfirmed reorder must fail")
            } catch {
                XCTAssertFalse(error.localizedDescription.isEmpty)
            }
            XCTAssertEqual(fixture.defaults.data(forKey: "cached-reminders"), before)
        }
    }

    func testDuplicateMissingAndUnknownIDsAreRejectedWithoutRequest() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let store = fixture.makeStore { _ in
            XCTFail("Invalid order must not reach the server")
            throw URLError(.badURL)
        }
        try await fixture.seed(store)
        let ids = fixture.reminders.map(\.id)
        for invalid in [[ids[0], ids[0], ids[2]], Array(ids.dropLast()), [UUID(), ids[1], ids[2]]] {
            do {
                _ = try await store.reorder(ids: invalid)
                XCTFail("Invalid order must fail")
            } catch {}
        }
        let unchanged = try await store.reorder(ids: ids)
        XCTAssertEqual(unchanged, fixture.reminders)
    }

    func testDelayedReorderDoesNotRepopulateCacheAfterSignOut() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let started = expectation(description: "Reorder started")
        let network = DelayedNetwork(started: started)
        let store = fixture.makeStore { request in try await network.send(request) }
        try await fixture.seed(store)
        var reordered = Array(fixture.reminders.reversed())
        for index in reordered.indices { reordered[index].sortOrder = index }
        let task = Task { try await store.reorder(ids: reordered.map(\.id)) }
        await fulfillment(of: [started], timeout: 3)
        let duringSave = await store.cached()
        XCTAssertEqual(duringSave, fixture.reminders)
        await store.clearUserData()
        await network.finish(try ReminderJSON.encoder.encode(reordered))
        do {
            _ = try await task.value
            XCTFail("Signed-out save must fail")
        } catch {}
        let cache = await store.cached()
        XCTAssertTrue(cache.isEmpty)
    }

    func testDelayedRefreshCannotOverwriteSavedOrder() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        var reordered = Array(fixture.reminders.reversed())
        for index in reordered.indices { reordered[index].sortOrder = index }
        let started = expectation(description: "Refresh started")
        let network = DelayedNetwork(started: started, reorderData: try ReminderJSON.encoder.encode(reordered))
        let store = fixture.makeStore { request in try await network.send(request) }
        try await fixture.seed(store)
        let refresh = Task { try await store.refresh(performMaintenance: false) }
        await fulfillment(of: [started], timeout: 3)
        _ = try await store.reorder(ids: reordered.map(\.id))
        await network.finish(try ReminderJSON.encoder.encode(fixture.reminders))
        let refreshed = try await refresh.value
        XCTAssertEqual(refreshed, reordered)
        let cache = await store.cached()
        XCTAssertEqual(cache, reordered)
    }

    private actor DelayedNetwork {
        let started: XCTestExpectation
        private var continuation: CheckedContinuation<(Data, URLResponse), Error>?
        private var request: URLRequest?
        private let reorderData: Data?
        init(started: XCTestExpectation, reorderData: Data? = nil) {
            self.started = started
            self.reorderData = reorderData
        }
        func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
            if request.httpMethod == "POST", let reorderData {
                return (reorderData, HTTPURLResponse(url: request.url!, statusCode: 200,
                                                     httpVersion: nil, headerFields: nil)!)
            }
            self.request = request
            return try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                started.fulfill()
            }
        }
        func finish(_ data: Data) {
            guard let request, let continuation else { return }
            self.continuation = nil
            continuation.resume(returning: (data, HTTPURLResponse(url: request.url!, statusCode: 200,
                                                                   httpVersion: nil, headerFields: nil)!))
        }
    }

    private struct Fixture {
        let suiteName = "ReminderStoreReorderTests.\(UUID())"
        let defaults: UserDefaults
        let reminders: [Reminder]
        init() {
            defaults = UserDefaults(suiteName: suiteName)!
            let owner = UUID()
            reminders = (0..<3).map { index in
                Reminder(id: UUID(), userID: owner, text: "Note \(index)", sortOrder: index * 3,
                         isDone: false, createdAt: Date(timeIntervalSince1970: 1_775_000_000))
            }
        }
        func makeStore(_ send: @escaping (URLRequest) async throws -> (Data, URLResponse)) -> ReminderStore {
            ReminderStore(defaults: defaults, serviceURL: URL(string: "https://reminders.invalid")!,
                          anonKey: "test-key", requestData: send)
        }
        func seed(_ store: ReminderStore) async throws {
            try await store.saveSession(accessToken: "test-token", refreshToken: "test-refresh",
                                        expiresAt: Date().addingTimeInterval(3600), userID: reminders[0].userID)
            defaults.set(try ReminderJSON.encoder.encode(reminders), forKey: "cached-reminders")
        }
        func response(_ data: Data, request: URLRequest, status: Int = 200) -> (Data, URLResponse) {
            (data, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
        }
        func cleanUp() { defaults.removePersistentDomain(forName: suiteName) }
    }
}
