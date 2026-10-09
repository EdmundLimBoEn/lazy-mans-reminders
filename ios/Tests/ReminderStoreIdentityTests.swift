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

    func testFailedNearExpiryRefreshRejectsCreateAfterSameAccountSignsInAgain() async throws {
        try await checkFailedAuthRefresh(.create)
    }

    func testFailedNearExpiryRefreshRejectsUpdatesAfterSameAccountSignsInAgain() async throws {
        for mutation in [Mutation.edit, .complete, .restore] {
            try await checkFailedAuthRefresh(mutation)
        }
    }

    func testFailedNearExpiryRefreshRejectsBoardRefreshAfterSameAccountSignsInAgain() async throws {
        try await checkFailedAuthRefresh(nil)
    }

    func testSameUserNewJWTSessionRejectsOutstandingMutationsWithoutClearingData() async throws {
        for mutation in [Mutation.create, .edit, .complete, .restore] {
            let fixture = Fixture()
            defer { fixture.cleanUp() }
            let userID = UUID()
            let reminder = sample(userID: userID)
            try await signIn(fixture.store, userID: userID, token: jwt(userID: userID, sessionID: UUID()))
            fixture.seed([reminder])
            let task = Task { try await mutation.perform(on: fixture.store, reminder: reminder) }
            await fulfillment(of: [fixture.started], timeout: 3)
            try await signIn(fixture.store, userID: userID, token: jwt(userID: userID, sessionID: UUID()))
            var acknowledged = reminder
            if mutation == .create { acknowledged.text = "New reminder" }
            if mutation == .edit { acknowledged.text = "Edited" }
            acknowledged.isDone = mutation == .complete
            await fixture.network.finish(data: try ReminderJSON.encoder.encode([acknowledged]))
            await assertSignedOut(task)
            let cache = await fixture.store.cached()
            XCTAssertEqual(cache, [reminder])
            let count = await fixture.network.requestCount
            XCTAssertEqual(count, 1)
        }
    }

    func testSameJWTSessionAllowsTokenRotationDuringMutation() async throws {
        for mutation in [Mutation.create, .edit, .complete, .restore] {
            let fixture = Fixture()
            defer { fixture.cleanUp() }
            let userID = UUID()
            let sessionID = UUID()
            let reminder = sample(userID: userID)
            let token = try jwt(userID: userID, sessionID: sessionID)
            try await signIn(fixture.store, userID: userID, token: token)
            fixture.seed([reminder])
            let task = Task { try await mutation.perform(on: fixture.store, reminder: reminder) }
            await fulfillment(of: [fixture.started], timeout: 3)
            let rotated = try jwt(userID: userID, sessionID: sessionID, issuedAt: 2)
            XCTAssertNotEqual(rotated, token)
            try await signIn(fixture.store, userID: userID, token: rotated)
            let preserved = await fixture.store.cached()
            XCTAssertEqual(preserved, [reminder], "Same-session rotation must preserve the board")
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

    func testSameUserNewJWTSessionRejectsOutstandingBoardRefresh() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let userID = UUID()
        try await signIn(fixture.store, userID: userID, token: jwt(userID: userID, sessionID: UUID()))
        let task = Task { try await fixture.store.refresh(performMaintenance: false) }
        await fulfillment(of: [fixture.started], timeout: 3)
        try await signIn(fixture.store, userID: userID, token: jwt(userID: userID, sessionID: UUID()))
        await fixture.network.finish(data: try ReminderJSON.encoder.encode([sample(userID: userID)]))
        await assertSignedOut(task)
        let cache = await fixture.store.cached()
        XCTAssertTrue(cache.isEmpty)
    }

    func testLegacySessionWithoutSessionIDStillDecodesAndAllowsMutation() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let userID = UUID()
        let token = try jwt(userID: userID, sessionID: nil)
        let legacy: [String: Any] = [
            "accessToken": token,
            "expiresAt": Date().addingTimeInterval(3600).timeIntervalSinceReferenceDate
        ]
        fixture.defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: "shared-session")
        let reminder = sample(userID: userID)
        let task = Task { try await fixture.store.create(text: reminder.text) }
        await fulfillment(of: [fixture.started], timeout: 3)
        await fixture.network.finish(data: try ReminderJSON.encoder.encode([reminder]))
        let result = try await task.value
        XCTAssertEqual(result, [reminder])
    }

    func testAccountSwitchClearsForeignCacheWithoutSignOutAndRejectsLateCreate() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let userA = UUID()
        let userB = UUID()
        let privateReminder = sample(userID: userA)
        try await signIn(fixture.store, userID: userA, token: jwt(userID: userA, sessionID: UUID()))
        fixture.seed([privateReminder])
        let task = Task { try await fixture.store.create(text: "Pending A reminder") }
        await fulfillment(of: [fixture.started], timeout: 3)
        try await signIn(fixture.store, userID: userB, token: jwt(userID: userB, sessionID: UUID()))
        let cacheAfterSwitch = await fixture.store.cached()
        XCTAssertTrue(cacheAfterSwitch.isEmpty, "Widgets must not carry A's board into B's session")
        var acknowledged = privateReminder
        acknowledged.text = "Pending A reminder"
        await fixture.network.finish(data: try ReminderJSON.encoder.encode([acknowledged]))
        await assertSignedOut(task)
        let finalCache = await fixture.store.cached()
        XCTAssertTrue(finalCache.isEmpty)
    }

    func testFixtureBuffersCompletionUntilLateRequestStarts() async throws {
        let started = XCTestExpectation(description: "Late HTTP request")
        let network = PausedNetwork(started: started)
        let data = Data("buffered response".utf8)
        await network.finish(data: data, statusCode: 400)
        let completed = XCTestExpectation(description: "Buffered response returned")
        let task = Task {
            let result = try await network.send(URLRequest(url: URL(string: "https://reminders.invalid")!))
            completed.fulfill()
            return result
        }
        await fulfillment(of: [started, completed], timeout: 3)
        // Release a suspended send after a failed assertion if buffering regresses.
        await network.finish(data: data, statusCode: 400)
        let (received, response) = try await task.value
        XCTAssertEqual(received, data)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 400)
    }

    func testFailedAuthRefreshUsesFreshSameSessionAfterRefreshTokenRotation() async throws {
        for mutation in [Mutation.create, .edit, .complete] {
            try await checkConcurrentAuthRotation(mutation, authStatus: 400)
        }
        try await checkConcurrentAuthRotation(nil, authStatus: 400)
    }

    func testDelayedSuccessfulAuthRefreshCannotOverwriteFreshSameSessionRotation() async throws {
        try await checkConcurrentAuthRotation(.edit, authStatus: 200)
    }

    func testFailedAuthRefreshDoesNotFallBackToOriginalAfterRotationToExpiredTokens() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let userID = UUID()
        let sessionID = UUID()
        try await signIn(
            fixture.store, userID: userID, token: jwt(userID: userID, sessionID: sessionID),
            expiresIn: 45, refreshToken: "R1"
        )
        let task = Task { await fixture.store.isSignedIn() }
        await fulfillment(of: [fixture.started], timeout: 3)
        try await signIn(
            fixture.store, userID: userID, token: jwt(userID: userID, sessionID: sessionID, issuedAt: 2),
            expiresIn: -1, refreshToken: "R2"
        )
        await fixture.network.finish(data: Data(), statusCode: 400)
        let signedIn = await task.value
        XCTAssertFalse(signedIn, "A rotated unusable session must not fall back to the original token")
    }

    func testFailedAuthRefreshRejectsFreshNewJWTSessionWithoutSignOut() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let userID = UUID()
        try await signIn(
            fixture.store, userID: userID, token: jwt(userID: userID, sessionID: UUID()),
            expiresIn: 45, refreshToken: "R1"
        )
        let task = Task { await fixture.store.isSignedIn() }
        await fulfillment(of: [fixture.started], timeout: 3)
        let replacement = try jwt(userID: userID, sessionID: UUID(), issuedAt: 2)
        try await signIn(fixture.store, userID: userID, token: replacement, refreshToken: "R2")
        await fixture.network.finish(data: Data(), statusCode: 400)
        let signedIn = await task.value
        XCTAssertFalse(signedIn, "An old request cannot adopt a different auth session")
        let savedData = try XCTUnwrap(fixture.defaults.data(forKey: "shared-session"))
        let saved = try JSONDecoder().decode(SharedSession.self, from: savedData)
        XCTAssertEqual(saved.accessToken, replacement)
        XCTAssertEqual(saved.refreshToken, "R2")
    }

    private func checkConcurrentAuthRotation(_ mutation: Mutation?, authStatus: Int) async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let userID = UUID()
        let sessionID = UUID()
        let reminder = sample(userID: userID)
        try await signIn(
            fixture.store, userID: userID, token: jwt(userID: userID, sessionID: sessionID),
            expiresIn: 45, refreshToken: "R1"
        )
        fixture.seed([reminder])
        let task = Task {
            if let mutation { return try await mutation.perform(on: fixture.store, reminder: reminder) }
            return try await fixture.store.refresh(performMaintenance: false)
        }
        await fulfillment(of: [fixture.started], timeout: 3)
        let rotated = try jwt(userID: userID, sessionID: sessionID, issuedAt: 2)
        try await signIn(fixture.store, userID: userID, token: rotated, refreshToken: "R2")
        var returned = reminder
        if mutation == .edit { returned.text = "Edited" }
        if mutation == .complete { returned.isDone = true }
        if mutation == .create { returned = sample(userID: userID); returned.sortOrder = 1 }
        let lateAuthData = try JSONSerialization.data(withJSONObject: [
            "access_token": jwt(userID: userID, sessionID: sessionID, issuedAt: 3),
            "refresh_token": "late-R1-response", "expires_in": 3600
        ])
        await fixture.network.finish(
            data: authStatus == 200 ? lateAuthData : Data(), statusCode: authStatus,
            reminderData: try ReminderJSON.encoder.encode([returned])
        )
        let result = try await task.value
        switch mutation {
        case .create: XCTAssertEqual(result, [reminder, returned])
        case .edit: XCTAssertEqual(result, [returned])
        case .complete: XCTAssertTrue(result.isEmpty)
        case nil: XCTAssertEqual(result, [returned])
        case .restore: XCTFail("Restore needs a separate maintenance response")
        }
        let requests = await fixture.network.requests
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.first?.url?.path, "/auth/v1/token")
        let authBody = try XCTUnwrap(requests.first?.httpBody)
        let authPayload = try JSONSerialization.jsonObject(with: authBody) as? [String: String]
        XCTAssertEqual(authPayload?["refresh_token"], "R1")
        XCTAssertEqual(requests.last?.value(forHTTPHeaderField: "Authorization"), "Bearer \(rotated)")
        let savedData = try XCTUnwrap(fixture.defaults.data(forKey: "shared-session"))
        let saved = try JSONDecoder().decode(SharedSession.self, from: savedData)
        XCTAssertEqual(saved.accessToken, rotated)
        XCTAssertEqual(saved.refreshToken, "R2")
        let cache = await fixture.store.cached()
        XCTAssertEqual(cache, result)
    }

    private func checkFailedAuthRefresh(_ mutation: Mutation?) async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let userID = UUID()
        let reminder = sample(userID: userID)
        try await signIn(
            fixture.store, userID: userID,
            token: jwt(userID: userID, sessionID: UUID()), expiresIn: 45
        )
        fixture.seed([reminder])
        let task = Task {
            if let mutation { return try await mutation.perform(on: fixture.store, reminder: reminder) }
            return try await fixture.store.refresh(performMaintenance: false)
        }
        await fulfillment(of: [fixture.started], timeout: 3)
        let requestURL = await fixture.network.requestURL
        XCTAssertEqual(requestURL?.path, "/auth/v1/token")
        await fixture.store.clearUserData()
        let replacementToken = try jwt(userID: userID, sessionID: UUID())
        try await signIn(fixture.store, userID: userID, token: replacementToken)
        let replacement = sample(userID: userID, id: reminder.id, text: "New login's reminder")
        fixture.seed([replacement])
        await fixture.network.finish(data: Data(), statusCode: 400)
        await assertSignedOut(task)
        let cache = await fixture.store.cached()
        XCTAssertEqual(cache, [replacement])
        let count = await fixture.network.requestCount
        XCTAssertEqual(count, 1, "Obsolete authentication must not send a reminders request")
        let sessionData = try XCTUnwrap(fixture.defaults.data(forKey: "shared-session"))
        let session = try JSONDecoder().decode(SharedSession.self, from: sessionData)
        XCTAssertEqual(session.accessToken, replacementToken)
    }

    private func jwt(userID: UUID, sessionID: UUID?, issuedAt: Int = 1) throws -> String {
        var claims: [String: Any] = ["sub": userID.uuidString, "iat": issuedAt]
        if let sessionID { claims["session_id"] = sessionID.uuidString }
        let encoded = try JSONSerialization.data(withJSONObject: claims).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "e30.\(encoded).test-signature"
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

    private func signIn(
        _ store: ReminderStore, userID: UUID, token: String = "test-token", expiresIn: TimeInterval = 3600,
        refreshToken: String = "test-refresh"
    ) async throws {
        try await store.saveSession(
            accessToken: token, refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(expiresIn), userID: userID
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
        var requestURL: URL?
        var requests: [URLRequest] = []
        private var reminderData: Data?
        private var completion: (Data, URLResponse)?
        private var pending: CheckedContinuation<(Data, URLResponse), Error>?

        init(started: XCTestExpectation) { self.started = started }

        func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
            requestCount += 1
            requestURL = request.url
            requests.append(request)
            if requestCount > 1 {
                guard request.url?.path == "/rest/v1/reminders", let reminderData else {
                    throw URLError(.cancelled)
                }
                return (
                    reminderData,
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                )
            }
            if let completion {
                started.fulfill()
                return completion
            }
            return try await withCheckedThrowingContinuation { continuation in
                pending = continuation
                started.fulfill()
            }
        }

        func finish(data: Data, statusCode: Int = 200, reminderData: Data? = nil) {
            guard completion == nil else { return }
            self.reminderData = reminderData
            let result: (Data, URLResponse) = (
                data,
                HTTPURLResponse(
                    url: URL(string: "https://reminders.invalid/rest/v1/reminders")!,
                    statusCode: statusCode, httpVersion: nil, headerFields: nil
                )!
            )
            completion = result
            pending?.resume(returning: result)
            pending = nil
        }
    }
}
