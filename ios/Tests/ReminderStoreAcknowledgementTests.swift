import Foundation
import XCTest
@testable import LazyMansReminders

final class ReminderStoreAcknowledgementTests: XCTestCase {
    func testZeroRowsRejectCompletionEditAndReopenWithoutChangingCache() async throws {
        for mutation in Mutation.allCases {
            try await assertRejected(Data("[]".utf8), mutation: mutation,
                                     message: "This reminder is no longer available. Refresh your board and try again.")
        }
    }

    func testWrongIDOwnerAndMultipleRowsRejectWithoutChangingCache() async throws {
        let original = sample()
        let wrongID = sample(userID: original.userID)
        let wrongOwner = sample(id: original.id)
        for rows in [[wrongID], [wrongOwner], [original, original]] {
            for mutation in Mutation.allCases {
                try await assertRejected(try ReminderJSON.encoder.encode(rows), original: original,
                                         mutation: mutation,
                                         message: "The reminder change could not be confirmed. Refresh your board and try again.")
            }
        }
    }

    func testMalformedOrIncompleteRepresentationRejectsWithoutChangingCache() async throws {
        let original = sample()
        let valid = try ReminderJSON.encoder.encode([original])
        var rows = try XCTUnwrap(JSONSerialization.jsonObject(with: valid) as? [[String: Any]])
        rows[0].removeValue(forKey: "is_done")
        let missingField = try JSONSerialization.data(withJSONObject: rows)
        rows[0]["is_done"] = "false"
        let wrongType = try JSONSerialization.data(withJSONObject: rows)
        rows[0]["is_done"] = false
        rows[0]["created_at"] = "not-a-date"
        let badDate = try JSONSerialization.data(withJSONObject: rows)
        for data in [Data(), Data("not json".utf8), Data("{}".utf8), missingField, wrongType, badDate] {
            try await assertRejected(data, original: original, mutation: .edit,
                                     message: "The reminders service returned an invalid response.")
        }
    }

    func testHTTPFailureKeepsCache() async throws {
        try await assertRejected(Data("[]".utf8), mutation: .complete, status: 403,
                                 message: "The reminders service returned HTTP 403.")
    }

    func testTransportFailureKeepsCache() async throws {
        let original = sample()
        let fixture = Fixture(data: Data(), transportFailure: true)
        defer { fixture.cleanUp() }
        try await fixture.signInAndSeed(original)
        do {
            _ = try await fixture.store.markDone(id: original.id)
            XCTFail("Transport failure must throw")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .timedOut)
        }
        let cache = await fixture.store.cached()
        XCTAssertEqual(cache, [original])
    }

    func testCompletionEditAndReopenApplyReturnedRowWithoutFollowupFetch() async throws {
        for mutation in Mutation.allCases {
            var original = sample()
            original.isDone = mutation == .reopen
            var returned = original
            returned.text = mutation == .edit ? "Client text" : "Server text"
            returned.sortOrder = -1
            returned.isDone = mutation == .complete
            let fixture = Fixture(data: try ReminderJSON.encoder.encode([returned]))
            defer { fixture.cleanUp() }
            try await fixture.signInAndSeed(original)
            let result = try await mutation.perform(fixture.store, id: original.id)
            XCTAssertEqual(result, returned.isDone ? [] : [returned])
            let cache = await fixture.store.cached()
            XCTAssertEqual(cache, result)
        }
    }

    func testIgnoredRequestedFieldsRejectCompletionEditReopenAndCombinedUpdate() async throws {
        let original = sample()
        let conflict = "The reminder change could not be confirmed. Refresh your board and try again."
        try await assertRejected(try ReminderJSON.encoder.encode([original]), original: original,
                                 mutation: .complete, message: conflict)
        try await assertRejected(try ReminderJSON.encoder.encode([original]), original: original,
                                 mutation: .edit, message: conflict)
        var completed = original
        completed.isDone = true
        try await assertRejected(try ReminderJSON.encoder.encode([completed]), original: completed,
                                 mutation: .reopen, message: conflict)
        for matchesText in [false, true] {
            var returned = original
            returned.text = matchesText ? "Client text" : original.text
            returned.isDone = !matchesText
            let fixture = Fixture(data: try ReminderJSON.encoder.encode([returned]))
            defer { fixture.cleanUp() }
            try await fixture.signInAndSeed(original)
            do {
                _ = try await fixture.store.update(id: original.id, text: "Client text", isDone: true)
                XCTFail("Both requested fields must match")
            } catch {
                XCTAssertEqual(error.localizedDescription, conflict)
            }
            let cache = await fixture.store.cached()
            XCTAssertEqual(cache, [original])
        }
    }

    func testCreateRequiresOneValidOwnedRowAndUsesServerValues() async throws {
        let original = sample()
        var created = sample(userID: original.userID)
        created.text = "New reminder"
        created.sortOrder = -1
        let wrongOwner = sample()
        var wrongText = created
        wrongText.text = "Ignored request"
        var wrongCompletion = created
        wrongCompletion.isDone = true
        for rows in [[], [wrongOwner], [created, created], [wrongText], [wrongCompletion]] {
            let fixture = Fixture(data: try ReminderJSON.encoder.encode(rows), method: "POST")
            defer { fixture.cleanUp() }
            try await fixture.signInAndSeed(original)
            do {
                _ = try await fixture.store.create(text: "New reminder")
                XCTFail("Unacknowledged create must throw")
            } catch {
                XCTAssertFalse(error.localizedDescription.isEmpty)
            }
            let cache = await fixture.store.cached()
            XCTAssertEqual(cache, [original])
        }
        let fixture = Fixture(data: try ReminderJSON.encoder.encode([created]), method: "POST")
        defer { fixture.cleanUp() }
        try await fixture.signInAndSeed(original)
        let result = try await fixture.store.create(text: "New reminder")
        XCTAssertEqual(result, [created, original])
        let cache = await fixture.store.cached()
        XCTAssertEqual(cache, result)
    }

    func testCreateRejectsMalformedResponseWithoutChangingCache() async throws {
        let original = sample()
        for data in [Data(), Data("{}".utf8)] {
            let fixture = Fixture(data: data, method: "POST")
            defer { fixture.cleanUp() }
            try await fixture.signInAndSeed(original)
            do {
                _ = try await fixture.store.create(text: "New reminder")
                XCTFail("Malformed create must throw")
            } catch {
                XCTAssertEqual(error.localizedDescription, "The reminders service returned an invalid response.")
            }
            let cache = await fixture.store.cached()
            XCTAssertEqual(cache, [original])
        }
    }

    func testCreateCannotUseAnotherOwnerEvenWithAValidResponse() async throws {
        let original = sample()
        let fixture = Fixture(data: try ReminderJSON.encoder.encode([original]), method: "NO REQUEST")
        defer { fixture.cleanUp() }
        try await fixture.signInAndSeed(original)
        do {
            _ = try await fixture.store.create(text: "New reminder", userID: UUID())
            XCTFail("Explicit owner must match the session")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Sign in to Lazy Man's Reminders on this iPhone first.")
        }
        let cache = await fixture.store.cached()
        XCTAssertEqual(cache, [original])
    }

    private func assertRejected(
        _ data: Data, original: Reminder? = nil, mutation: Mutation,
        status: Int = 200, message: String
    ) async throws {
        let reminder = original ?? sample()
        let fixture = Fixture(data: data, status: status)
        defer { fixture.cleanUp() }
        try await fixture.signInAndSeed(reminder)
        let cachedBytes = fixture.defaults.data(forKey: "cached-reminders")
        do {
            _ = try await mutation.perform(fixture.store, id: reminder.id)
            XCTFail("Unacknowledged mutation must throw")
        } catch {
            XCTAssertEqual(error.localizedDescription, message)
        }
        XCTAssertEqual(fixture.defaults.data(forKey: "cached-reminders"), cachedBytes)
    }

    private enum Mutation: CaseIterable {
        case complete, edit, reopen

        func perform(_ store: ReminderStore, id: UUID) async throws -> [Reminder] {
            switch self {
            case .complete: return try await store.markDone(id: id)
            case .edit: return try await store.update(id: id, text: "Client text")
            case .reopen: return try await store.update(id: id, isDone: false)
            }
        }
    }

    private func sample(id: UUID = UUID(), userID: UUID = UUID()) -> Reminder {
        Reminder(id: id, userID: userID, text: "Original", sortOrder: 0, isDone: false,
                 createdAt: Date(timeIntervalSince1970: 1_775_000_000))
    }

    private struct Fixture {
        let suiteName = "ReminderStoreAcknowledgementTests.\(UUID().uuidString)"
        let defaults: UserDefaults
        let store: ReminderStore

        init(data: Data, status: Int = 200, method: String = "PATCH", transportFailure: Bool = false) {
            defaults = UserDefaults(suiteName: suiteName)!
            store = ReminderStore(
                defaults: defaults, serviceURL: URL(string: "https://reminders.invalid")!,
                anonKey: "test-anon-key",
                requestData: { request in
                    XCTAssertEqual(request.httpMethod, method, "Reopen must not issue a followup GET/RPC")
                    XCTAssertEqual(request.value(forHTTPHeaderField: "Prefer"), "return=representation")
                    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
                    if transportFailure { throw URLError(.timedOut) }
                    return (data, HTTPURLResponse(url: request.url!, statusCode: status,
                                                 httpVersion: nil, headerFields: nil)!)
                }
            )
        }

        func signInAndSeed(_ reminder: Reminder) async throws {
            try await store.saveSession(accessToken: "test-token", refreshToken: "test-refresh",
                                        expiresAt: Date().addingTimeInterval(3600), userID: reminder.userID)
            defaults.set(try ReminderJSON.encoder.encode([reminder]), forKey: "cached-reminders")
        }

        func cleanUp() { defaults.removePersistentDomain(forName: suiteName) }
    }
}
