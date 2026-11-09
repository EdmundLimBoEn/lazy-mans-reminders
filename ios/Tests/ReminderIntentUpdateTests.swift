import Foundation
import XCTest
@testable import LazyMansReminders

final class ReminderIntentUpdateTests: XCTestCase {
    func testUpdatesReturnAcknowledgedRowAndPublishOnlyActiveReminders() async throws {
        let updates: [(String?, Bool?)] = [
            ("  Edited title  ", true), (nil, true),
            ("  Edited title  ", nil), ("  Edited title  ", false), (nil, false)
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
                    if request.httpMethod == "GET" {
                        return (try ReminderJSON.encoder.encode(original.isDone ? [] : [original]),
                                HTTPURLResponse(url: request.url!, statusCode: 200,
                                                httpVersion: nil, headerFields: nil)!)
                    }
                    XCTAssertEqual(request.value(forHTTPHeaderField: "Prefer"), "return=representation")
                    let data = try XCTUnwrap(request.httpBody)
                    let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
                    if completion == false {
                        XCTAssertEqual(request.httpMethod, "POST")
                        XCTAssertEqual(request.url?.path, "/rest/v1/rpc/reopen_reminder")
                        XCTAssertNil(request.url?.query)
                        XCTAssertEqual((body["p_user_id"] as? String).flatMap(UUID.init(uuidString:)), original.userID)
                        XCTAssertEqual((body["p_reminder_id"] as? String).flatMap(UUID.init(uuidString:)), original.id)
                        XCTAssertEqual(body["p_text"] as? String, title == nil ? nil : "Edited title")
                        XCTAssertNil(body["is_done"])
                    } else {
                        XCTAssertEqual(request.httpMethod, "PATCH")
                        XCTAssertEqual(request.url?.path, "/rest/v1/reminders")
                        XCTAssertEqual(body["text"] as? String, title == nil ? nil : "Edited title")
                        XCTAssertEqual(body["is_done"] as? Bool, completion)
                    }
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
            XCTAssertEqual(requests, 2, "Refresh the board, then save title and completion together")
            XCTAssertEqual(publications, 1)
        }
    }

    func testCompletingCachedTargetPreservesRemindersAddedByAnotherClient() async throws {
        let original = sample()
        let other = sample(userID: original.userID)
        var acknowledged = original
        acknowledged.isDone = true
        let suite = "ReminderIntentUpdateTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let requests = Counter()
        let publications = Counter()
        let store = ReminderStore(
            defaults: defaults, credentials: MemorySessionCredentials(),
            serviceURL: URL(string: "https://reminders.invalid")!, anonKey: "test-anon-key",
            requestData: { request in
                await requests.increment()
                let count = await requests.value
                XCTAssertEqual(request.url?.path, "/rest/v1/reminders")
                let rows: [Reminder]
                if request.httpMethod == "GET" {
                    XCTAssertEqual(count, 1, "Reconcile before mutating")
                    let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
                    XCTAssertEqual(query.first { $0.name == "is_done" }?.value, "eq.false")
                    XCTAssertNil(query.first { $0.name == "id" }, "Fetch the full board")
                    rows = [original, other]
                } else {
                    XCTAssertEqual(count, 2)
                    XCTAssertEqual(request.httpMethod, "PATCH")
                    rows = [acknowledged]
                }
                return (try ReminderJSON.encoder.encode(rows),
                        HTTPURLResponse(url: request.url!, statusCode: 200,
                                        httpVersion: nil, headerFields: nil)!)
            }
        )
        try await seed(store, defaults: defaults, reminder: original)
        let resolved = try await store.resolve(identifiers: [original.id])
        XCTAssertEqual(resolved, [original])
        let result = try await ReminderIntentActions.update(
            id: original.id, title: nil, isCompleted: true, store: store,
            publish: { board in
                await publications.increment()
                XCTAssertEqual(board, [other])
                XCTAssertEqual(LiveActivityPolicy.action(
                    lineCount: ReminderActivityPresentation.lines(from: board).count,
                    activityExists: true
                ), .update)
            }
        )
        XCTAssertEqual(result, acknowledged)
        let cache = await store.cached()
        XCTAssertEqual(cache, [other])
        let requestCount = await requests.value
        let publicationCount = await publications.value
        XCTAssertEqual(requestCount, 2)
        XCTAssertEqual(publicationCount, 1)
    }

    func testFailedBoardRefreshDoesNotMutateOrPublishCachedBoard() async throws {
        let original = sample()
        let suite = "ReminderIntentUpdateTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let requests = Counter()
        let store = ReminderStore(
            defaults: defaults, credentials: MemorySessionCredentials(),
            serviceURL: URL(string: "https://reminders.invalid")!, anonKey: "test-anon-key",
            requestData: { request in
                await requests.increment()
                XCTAssertEqual(request.httpMethod, "GET", "A failed prerequisite must prevent mutation")
                throw URLError(.notConnectedToInternet)
            }
        )
        try await seed(store, defaults: defaults, reminder: original)
        do {
            _ = try await ReminderIntentActions.update(
                id: original.id, title: nil, isCompleted: true, store: store,
                publish: { _ in XCTFail("A failed refresh must not publish the incomplete cache") }
            )
            XCTFail("A failed prerequisite refresh must propagate")
        } catch {
            guard case ReminderIntentError.service = error else {
                return XCTFail("Expected the existing service error")
            }
        }
        let cache = await store.cached()
        XCTAssertEqual(cache, [original])
        let count = await requests.value
        XCTAssertEqual(count, 1)
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
                    return (try ReminderJSON.encoder.encode(request.httpMethod == "GET" ? [original] : [returned]),
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

    func testSavedTargetResolvesCompletedReminderThenReopensWithoutCachingCompletedRows() async throws {
        let active = sample()
        var completed = sample(userID: active.userID)
        completed.isDone = true
        var reopened = completed
        reopened.isDone = false
        let deletedID = UUID()
        let suite = "ReminderIntentResolutionTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let requests = Counter()
        let store = ReminderStore(
            defaults: defaults, credentials: MemorySessionCredentials(),
            serviceURL: URL(string: "https://reminders.invalid")!, anonKey: "test-anon-key",
            requestData: { request in
                await requests.increment()
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
                if request.httpMethod == "GET" {
                    XCTAssertEqual(request.url?.path, "/rest/v1/reminders")
                    let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
                    if query.first(where: { $0.name == "is_done" })?.value == "eq.false" {
                        XCTAssertNil(query.first { $0.name == "id" })
                        return (try ReminderJSON.encoder.encode([active]),
                                HTTPURLResponse(url: request.url!, statusCode: 200,
                                                httpVersion: nil, headerFields: nil)!)
                    }
                    XCTAssertNil(query.first { $0.name == "is_done" })
                    XCTAssertEqual(query.first { $0.name == "user_id" }?.value, "eq.\(active.userID.uuidString)")
                    XCTAssertEqual(query.first { $0.name == "id" }?.value,
                                   "in.(\(completed.id.uuidString),\(deletedID.uuidString))")
                    return (try ReminderJSON.encoder.encode([completed]),
                            HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
                }
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertEqual(request.url?.path, "/rest/v1/rpc/reopen_reminder")
                let body = try XCTUnwrap(JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any])
                XCTAssertEqual((body["p_reminder_id"] as? String).flatMap(UUID.init(uuidString:)), completed.id)
                return (try ReminderJSON.encoder.encode([reopened]),
                        HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            }
        )
        try await seed(store, defaults: defaults, reminder: active)
        let resolved = try await store.resolve(identifiers: [completed.id, active.id, deletedID])
        XCTAssertEqual(resolved, [completed, active])
        let cacheAfterLookup = await store.cached()
        XCTAssertEqual(cacheAfterLookup, [active])
        let target = try XCTUnwrap(resolved.first)
        let result = try await ReminderIntentActions.update(
            id: target.id, title: nil, isCompleted: false, store: store,
            publish: { board in
                XCTAssertEqual(Set(board.map(\.id)), Set([active.id, completed.id]))
                XCTAssertTrue(board.allSatisfy { !$0.isDone })
            }
        )
        XCTAssertEqual(result, reopened)
        let count = await requests.value
        XCTAssertEqual(count, 3)
    }

    func testResolvingCachedOrEmptyTargetsDoesNotFetch() async throws {
        let active = sample()
        let suite = "ReminderIntentResolutionTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ReminderStore(
            defaults: defaults, credentials: MemorySessionCredentials(),
            requestData: { _ in
                XCTFail("Cached and empty targets require no lookup")
                throw URLError(.badURL)
            }
        )
        try await seed(store, defaults: defaults, reminder: active)
        let empty = try await store.resolve(identifiers: [])
        let cached = try await store.resolve(identifiers: [active.id])
        XCTAssertEqual(empty, [])
        XCTAssertEqual(cached, [active])
    }

    private actor Counter {
        var value = 0
        func increment() { value += 1 }
    }

    private func sample(userID: UUID = UUID()) -> Reminder {
        Reminder(id: UUID(), userID: userID, text: "Original", sortOrder: 3,
                 isDone: false, createdAt: Date(timeIntervalSince1970: 1_775_000_000))
    }

    private func seed(_ store: ReminderStore, defaults: UserDefaults, reminder: Reminder) async throws {
        try await store.saveSession(accessToken: "test-token", refreshToken: "test-refresh",
                                    expiresAt: Date().addingTimeInterval(3600), userID: reminder.userID)
        defaults.set(try ReminderJSON.encoder.encode([reminder]), forKey: "cached-reminders")
    }
}
