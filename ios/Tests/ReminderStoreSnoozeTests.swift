import Foundation
import XCTest
@testable import LazyMansReminders

final class ReminderStoreSnoozeTests: XCTestCase {
    private func sample() -> Reminder {
        Reminder(id: UUID(), userID: UUID(), text: "Test", sortOrder: 0, isDone: false, createdAt: Date())
    }

    func testRefreshAndWidgetCacheHideFutureSnoozesButIncludeDueRows() async throws {
        let suite = "SnoozeRefresh.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let visible = sample()
        var sleeping = visible
        sleeping.snoozedUntil = Date().addingTimeInterval(3600)
        var expired = visible
        expired.snoozedUntil = Date().addingTimeInterval(-1)
        let rows = [visible, sleeping, expired]
        let store = ReminderStore(defaults: defaults, credentials: MemorySessionCredentials(),
                                  serviceURL: URL(string: "https://reminders.invalid")!, anonKey: "test",
                                  requestData: { request in
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            XCTAssertEqual(query.first { $0.name == "is_done" }?.value, "eq.false")
            XCTAssertEqual(query.first { $0.name == "or" }?.value, "(snoozed_until.is.null,snoozed_until.lte.now)")
            return (try ReminderJSON.encoder.encode(rows), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        try await store.saveSession(accessToken: "token", refreshToken: "refresh", expiresAt: Date().addingTimeInterval(3600), userID: visible.userID)
        defaults.set(try ReminderJSON.encoder.encode(rows), forKey: "cached-reminders")
        let cached = await store.cached()
        XCTAssertEqual(cached, [visible, expired])
        let refreshed = try await store.refresh(performMaintenance: false, updateCache: false)
        XCTAssertEqual(refreshed, [visible, expired])
        let widget = await store.widgetCached()
        XCTAssertEqual(widget, [visible, expired])
    }

    func testSnoozeRequiresAcknowledgedTimestampAndKeepsCacheOnFailure() async throws {
        let original = sample()
        let until = Date().addingTimeInterval(10800)
        var snoozed = original
        snoozed.snoozedUntil = until
        let wrongOwner = Reminder(id: original.id, userID: UUID(), text: original.text, sortOrder: 0,
                              isDone: false, createdAt: original.createdAt, snoozedUntil: until)
        var wrongTime = snoozed
        wrongTime.snoozedUntil = until.addingTimeInterval(60)
        for returned in [[], [original], [wrongTime], [wrongOwner], [snoozed, snoozed], [snoozed]] {
            let suite = "SnoozeAck.\(UUID())"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            let store = ReminderStore(defaults: defaults, credentials: MemorySessionCredentials(),
                                      serviceURL: URL(string: "https://reminders.invalid")!, anonKey: "test",
                                      requestData: { request in
                XCTAssertEqual(request.httpMethod, "PATCH")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Prefer"), "return=representation")
                let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
                XCTAssertEqual(query.first { $0.name == "is_done" }?.value, "eq.false")
                let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: String]
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let sentUntil = try XCTUnwrap(formatter.date(from: XCTUnwrap(body["snoozed_until"])))
                XCTAssertEqual(sentUntil.timeIntervalSince(until), 0, accuracy: 0.001)
                return (try ReminderJSON.encoder.encode(returned), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            })
            try await store.saveSession(accessToken: "token", refreshToken: "refresh", expiresAt: Date().addingTimeInterval(3600), userID: original.userID)
            defaults.set(try ReminderJSON.encoder.encode([original]), forKey: "cached-reminders")
            do {
                let result = try await store.snooze(id: original.id, until: until)
                XCTAssertEqual(returned, [snoozed])
                XCTAssertEqual(result, [])
            } catch {
                XCTAssertNotEqual(returned, [snoozed])
            }
            let cached = await store.cached()
            XCTAssertEqual(cached, returned == [snoozed] ? [] : [original])
        }
    }

    func testPendingSnoozeRejectsDuplicateMutationAndCannotSurviveIdentityChange() async throws {
        for switchAccount in [false, true] {
            let original = sample()
            let until = Date().addingTimeInterval(3600)
            var acknowledged = original
            acknowledged.snoozedUntil = until
            let started = expectation(description: "Snooze awaiting acknowledgement")
            let network = HeldResponse(method: "PATCH", started: started, rows: [acknowledged])
            let suite = "SnoozeIdentity.\(UUID())"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            let store = ReminderStore(defaults: defaults, credentials: MemorySessionCredentials(),
                                      serviceURL: URL(string: "https://reminders.invalid")!, anonKey: "test",
                                      requestData: { try await network.send($0) })
            try await store.saveSession(accessToken: "token", refreshToken: "refresh", expiresAt: Date().addingTimeInterval(3600), userID: original.userID)
            defaults.set(try ReminderJSON.encoder.encode([original]), forKey: "cached-reminders")
            let mutation = Task { try await store.snooze(id: original.id, until: until) }
            await fulfillment(of: [started], timeout: 3)
            do {
                _ = try await store.markDone(id: original.id)
                XCTFail("Pending snooze must reserve the row")
            } catch {}
            if switchAccount {
                try await store.saveSession(accessToken: "other-token", refreshToken: "other-refresh", expiresAt: Date().addingTimeInterval(3600), userID: UUID())
            } else {
                await store.clearUserData()
            }
            await network.release()
            do {
                _ = try await mutation.value
                XCTFail("A stale snooze acknowledgement must fail after identity changes")
            } catch {}
            let cache = await store.cached()
            XCTAssertTrue(cache.isEmpty)
        }
    }

    func testRefreshStartedBeforeSnoozeCannotRestoreTheRow() async throws {
        let original = sample()
        let until = Date().addingTimeInterval(3600)
        var acknowledged = original
        acknowledged.snoozedUntil = until
        let started = expectation(description: "Old refresh awaiting response")
        let network = HeldResponse(method: "GET", started: started, rows: [original], immediateRows: [acknowledged])
        let suite = "SnoozeRevision.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ReminderStore(defaults: defaults, credentials: MemorySessionCredentials(),
                                  serviceURL: URL(string: "https://reminders.invalid")!, anonKey: "test",
                                  requestData: { try await network.send($0) })
        try await store.saveSession(accessToken: "token", refreshToken: "refresh", expiresAt: Date().addingTimeInterval(3600), userID: original.userID)
        defaults.set(try ReminderJSON.encoder.encode([original]), forKey: "cached-reminders")
        let refresh = Task { try await store.refresh(performMaintenance: false) }
        await fulfillment(of: [started], timeout: 3)
        let snoozed = try await store.snooze(id: original.id, until: until)
        XCTAssertTrue(snoozed.isEmpty)
        await network.release()
        let refreshed = try await refresh.value
        XCTAssertTrue(refreshed.isEmpty)
        let cache = await store.cached()
        XCTAssertTrue(cache.isEmpty)
    }

    private actor HeldResponse {
        let method: String
        let started: XCTestExpectation
        let rows: [Reminder]
        let immediateRows: [Reminder]
        var continuation: CheckedContinuation<Void, Never>?
        var released = false

        init(method: String, started: XCTestExpectation, rows: [Reminder], immediateRows: [Reminder] = []) {
            self.method = method
            self.started = started
            self.rows = rows
            self.immediateRows = immediateRows
        }

        func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
            if request.httpMethod == method {
                started.fulfill()
                if !released { await withCheckedContinuation { continuation = $0 } }
            }
            return (try ReminderJSON.encoder.encode(request.httpMethod == method ? rows : immediateRows),
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }

        func release() {
            released = true
            continuation?.resume()
            continuation = nil
        }
    }

}
