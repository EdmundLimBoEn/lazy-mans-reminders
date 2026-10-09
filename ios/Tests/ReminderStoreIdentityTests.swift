import Foundation
import XCTest
@testable import LazyMansReminders

final class ReminderStoreIdentityTests: XCTestCase {
    func testDelayedCreateCannotRestoreCacheAfterSignOut() async throws {
        try await checkDelayedMutation(.create, transition: .signOut)
    }

    func testDelayedCreateCannotAppendToAnotherAccountsCache() async throws {
        try await checkDelayedMutation(.create, transition: .switchAccount)
    }

    func testDelayedCreateCannotRestoreCacheAfterSameAccountSignsInAgain() async throws {
        try await checkDelayedMutation(.create, transition: .signInAgain)
    }

    func testDelayedCompletionCannotReturnSuccessAfterSignOut() async throws {
        try await checkDelayedMutation(.complete, transition: .signOut)
    }

    func testDelayedEditCannotChangeCacheAfterAccountSwitch() async throws {
        try await checkDelayedMutation(.edit, transition: .switchAccount)
    }

    func testDelayedCompletionCannotRemoveCacheAfterSameAccountSignsInAgain() async throws {
        try await checkDelayedMutation(.complete, transition: .signInAgain)
    }

    func testDelayedRestoreCannotRefreshAnotherAccountsBoard() async throws {
        try await checkDelayedMutation(.restore, transition: .switchAccount)
    }

    func testMutationsStillSucceedWhenOnlyTheAccessTokenChanges() async throws {
        for mutation in [Mutation.create, .edit, .complete, .restore] {
            let fixture = Fixture()
            defer { fixture.cleanUp() }
            let userID = UUID()
            let reminder = sample(userID: userID)
            try await signIn(fixture.store, userID: userID)
            fixture.seed([reminder])
            let task = Task { try await mutation.perform(on: fixture.store, reminder: reminder) }
            await fulfillment(of: [fixture.started], timeout: 3)
            try await signIn(fixture.store, userID: userID, token: "renewed-token")
            var created = sample(userID: userID, text: "New reminder")
            created.sortOrder = 1
            var updated = reminder
            updated.text = mutation == .edit ? "Edited" : reminder.text
            updated.isDone = mutation == .complete
            await fixture.network.finish(
                data: try ReminderJSON.encoder.encode([mutation == .create ? created : updated])
            )
            let result = try await task.value
            switch mutation {
            case .create: XCTAssertEqual(result, [reminder, created])
            case .edit: XCTAssertEqual(result.first?.text, "Edited")
            case .complete: XCTAssertTrue(result.isEmpty)
            case .restore: XCTAssertEqual(result, [reminder])
            }
            let cache = await fixture.store.cached()
            XCTAssertEqual(cache, result)
        }
    }

    func testDelayedRefreshStillCannotRestoreCacheAfterSignOut() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let reminder = sample(userID: UUID())
        try await signIn(fixture.store, userID: reminder.userID)
        let task = Task { try await fixture.store.refresh(performMaintenance: false) }
        await fulfillment(of: [fixture.started], timeout: 3)
        await fixture.store.clearUserData()
        await fixture.network.finish(data: try ReminderJSON.encoder.encode([reminder]))
        await assertSignedOut(task)
        let cache = await fixture.store.cached()
        XCTAssertTrue(cache.isEmpty)
    }

    private enum Mutation: Equatable {
        case create, edit, complete, restore

        func perform(on store: ReminderStore, reminder: Reminder) async throws -> [Reminder] {
            switch self {
            case .create: return try await store.create(text: "New reminder", userID: reminder.userID)
            case .edit: return try await store.update(id: reminder.id, text: "Edited")
            case .complete: return try await store.markDone(id: reminder.id)
            case .restore: return try await store.update(id: reminder.id, isDone: false)
            }
        }
    }

    private enum Transition {
        case signOut, switchAccount, signInAgain
    }

    private func checkDelayedMutation(_ mutation: Mutation, transition: Transition) async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let oldUser = UUID()
        let reminder = sample(userID: oldUser)
        try await signIn(fixture.store, userID: oldUser)
        fixture.seed([reminder])
        let task = Task { try await mutation.perform(on: fixture.store, reminder: reminder) }
        await fulfillment(of: [fixture.started], timeout: 3)

        await fixture.store.clearUserData()
        var expected: [Reminder] = []
        if transition != .signOut {
            let userID = transition == .switchAccount ? UUID() : oldUser
            try await signIn(fixture.store, userID: userID)
            // Same ID makes erroneous edit/remove writes observable, even after relogin.
            expected = [sample(userID: userID, id: reminder.id, text: "Replacement cache")]
            fixture.seed(expected)
        }
        var acknowledged = reminder
        if mutation == .create { acknowledged.text = "New reminder" }
        if mutation == .edit { acknowledged.text = "Edited" }
        acknowledged.isDone = mutation == .complete
        await fixture.network.finish(data: try ReminderJSON.encoder.encode([acknowledged]))
        await assertSignedOut(task)
        let cache = await fixture.store.cached()
        XCTAssertEqual(cache, expected)
        let requestCount = await fixture.network.requestCount
        XCTAssertEqual(requestCount, 1, "Obsolete restore must not fetch the replacement board")
    }

    private func assertSignedOut(_ task: Task<[Reminder], Error>) async {
        do {
            _ = try await task.value
            XCTFail("Obsolete request must throw instead of returning reminders to board sync")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Sign in to Lazy Man's Reminders on this iPhone first.")
        }
    }

    private func signIn(_ store: ReminderStore, userID: UUID, token: String = "test-token") async throws {
        try await store.saveSession(
            accessToken: token, refreshToken: "test-refresh",
            expiresAt: Date().addingTimeInterval(3600), userID: userID
        )
    }

    private func sample(userID: UUID, id: UUID = UUID(), text: String = "Private reminder") -> Reminder {
        Reminder(
            id: id, userID: userID, text: text, sortOrder: 0,
            isDone: false, createdAt: Date(timeIntervalSince1970: 1_775_000_000)
        )
    }

    private struct Fixture {
        let suiteName = "ReminderStoreIdentityTests.\(UUID().uuidString)"
        let defaults: UserDefaults
        let store: ReminderStore
        let network: PausedNetwork
        let started: XCTestExpectation

        init() {
            defaults = UserDefaults(suiteName: suiteName)!
            started = XCTestExpectation(description: "HTTP request suspended")
            network = PausedNetwork(started: started)
            let pausedNetwork = network
            store = ReminderStore(
                defaults: defaults,
                serviceURL: URL(string: "https://reminders.invalid")!,
                anonKey: "test-anon-key",
                requestData: { try await pausedNetwork.send($0) }
            )
        }

        func seed(_ reminders: [Reminder]) {
            defaults.set(try! ReminderJSON.encoder.encode(reminders), forKey: "cached-reminders")
        }

        func cleanUp() {
            defaults.removePersistentDomain(forName: suiteName)
        }
    }

    private actor PausedNetwork {
        let started: XCTestExpectation
        var requestCount = 0
        private var pending: CheckedContinuation<(Data, URLResponse), Error>?

        init(started: XCTestExpectation) { self.started = started }

        func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
            requestCount += 1
            guard requestCount == 1 else { throw URLError(.cancelled) }
            return try await withCheckedThrowingContinuation { continuation in
                pending = continuation
                started.fulfill()
            }
        }

        func finish(data: Data) {
            pending?.resume(returning: (
                data,
                HTTPURLResponse(
                    url: URL(string: "https://reminders.invalid/rest/v1/reminders")!,
                    statusCode: 200, httpVersion: nil, headerFields: nil
                )!
            ))
            pending = nil
        }
    }
}
