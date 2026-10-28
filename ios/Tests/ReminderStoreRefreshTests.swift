import Foundation
import XCTest
@testable import LazyMansReminders

final class ReminderStoreRefreshTests: XCTestCase {
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
                XCTAssertEqual(oldResult, [fixture.original])
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
        private var pending: [Int: CheckedContinuation<(Data, URLResponse), Error>] = [:]
        private var next = 0

        init(started: [XCTestExpectation], mutation: Reminder) {
            self.started = started
            self.mutation = mutation
        }

        func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
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

        func makeStore(_ network: Network) -> ReminderStore {
            ReminderStore(defaults: defaults, credentials: MemorySessionCredentials(), serviceURL: URL(string: "https://reminders.invalid")!,
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
