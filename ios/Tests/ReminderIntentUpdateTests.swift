import Foundation
import XCTest
@testable import LazyMansReminders

final class ReminderIntentUpdateTests: XCTestCase {
    func testUpdatesReturnAcknowledgedRowAndPublishOnlyActiveReminders() async throws {
        let updates: [(String?, Bool?)] = [
            ("  Edited title  ", true), (nil, true),
            ("  Edited title  ", nil), ("  Edited title  ", false)
        ]
        for (title, completion) in updates {
            var original = sample()
            original.isDone = completion == false
            var acknowledged = original
            acknowledged.text = title == nil ? original.text : "Edited title"
            acknowledged.isDone = completion ?? false
            acknowledged.sortOrder = -12
            let suite = "ReminderIntentUpdateTests.\(UUID())"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            let requestCount = Counter()
            let publicationCount = Counter()
            let store = ReminderStore(
                defaults: defaults, credentials: MemorySessionCredentials(), serviceURL: URL(string: "https://reminders.invalid")!,
                anonKey: "test-anon-key",
                requestData: { request in
                    await requestCount.increment()
                    XCTAssertEqual(request.httpMethod, "PATCH")
                    XCTAssertEqual(request.value(forHTTPHeaderField: "Prefer"), "return=representation")
                    let data = try XCTUnwrap(request.httpBody)
                    let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
                    XCTAssertEqual(body["text"] as? String, title == nil ? nil : "Edited title")
                    XCTAssertEqual(body["is_done"] as? Bool, completion)
                    return (try ReminderJSON.encoder.encode([acknowledged]),
                            HTTPURLResponse(url: request.url!, statusCode: 200,
                                            httpVersion: nil, headerFields: nil)!)
                }
            )
            try await seed(store, defaults: defaults, reminder: original)
            let expectedBoard = acknowledged.isDone ? [] : [acknowledged]
            let result = try await ReminderIntentActions.update(
                id: original.id, title: title, isCompleted: completion, store: store,
                publish: { board in
                    await publicationCount.increment()
                    XCTAssertEqual(board, expectedBoard)
                }
            )
            XCTAssertEqual(result, acknowledged, "Return server metadata even when completion removes the row")
            let cache = await store.cached()
            XCTAssertEqual(cache, expectedBoard)
            let requests = await requestCount.value
            let publications = await publicationCount.value
            XCTAssertEqual(requests, 1, "Title and completion must be saved together")
            XCTAssertEqual(publications, 1)
        }
    }

    func testCombinedUpdateRejectsUnacknowledgedFieldsWithoutPublishingOrChangingCache() async throws {
        for matchesTitle in [false, true] {
            let original = sample()
            var returned = original
            returned.text = matchesTitle ? "Edited title" : original.text
            returned.isDone = !matchesTitle
            let suite = "ReminderIntentUpdateTests.\(UUID())"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            let store = ReminderStore(
                defaults: defaults, credentials: MemorySessionCredentials(), serviceURL: URL(string: "https://reminders.invalid")!,
                anonKey: "test-anon-key",
                requestData: { request in
                    return (try ReminderJSON.encoder.encode([returned]),
                            HTTPURLResponse(url: request.url!, statusCode: 200,
                                            httpVersion: nil, headerFields: nil)!)
                }
            )
            try await seed(store, defaults: defaults, reminder: original)
            do {
                _ = try await ReminderIntentActions.update(
                    id: original.id, title: "Edited title", isCompleted: true, store: store,
                    publish: { _ in XCTFail("An unacknowledged mutation must not publish") }
                )
                XCTFail("Both requested fields must be acknowledged")
            } catch {
                guard case ReminderIntentError.service = error else {
                    return XCTFail("Expected the existing service error")
                }
            }
            let cache = await store.cached()
            XCTAssertEqual(cache, [original])
        }
    }

    func testEmptyUpdateReturnsCacheButCannotProduceAnAcknowledgedRow() async throws {
        let original = sample()
        let suite = "ReminderIntentUpdateTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ReminderStore(
            defaults: defaults, credentials: MemorySessionCredentials(),
            requestData: { _ in
                XCTFail("An empty update must not make a request")
                throw URLError(.badURL)
            }
        )
        try await seed(store, defaults: defaults, reminder: original)
        let unchanged = try await store.update(id: original.id)
        XCTAssertEqual(unchanged, [original])
        do {
            _ = try await store.updateAcknowledged(id: original.id)
            XCTFail("An empty update cannot return an acknowledged row")
        } catch {
            XCTAssertEqual(error.localizedDescription,
                           "The reminder change could not be confirmed. Refresh your board and try again.")
        }
        let cache = await store.cached()
        XCTAssertEqual(cache, [original])
    }

    private actor Counter {
        var value = 0
        func increment() { value += 1 }
    }

    private func sample() -> Reminder {
        Reminder(id: UUID(), userID: UUID(), text: "Original", sortOrder: 3,
                 isDone: false, createdAt: Date(timeIntervalSince1970: 1_775_000_000))
    }

    private func seed(_ store: ReminderStore, defaults: UserDefaults, reminder: Reminder) async throws {
        try await store.saveSession(accessToken: "test-token", refreshToken: "test-refresh",
                                    expiresAt: Date().addingTimeInterval(3600), userID: reminder.userID)
        defaults.set(try ReminderJSON.encoder.encode([reminder]), forKey: "cached-reminders")
    }
}
