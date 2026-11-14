import XCTest
@testable import LazyMansReminders

final class RoutineStoreTests: XCTestCase {
    func testListSelectsOnlyWebColumnsAndOwnerInCreatedOrder() async throws {
        let fixture = RoutineStoreFixture()
        defer { fixture.cleanUp() }
        try await fixture.signIn()
        let store = fixture.routineStore { request in
            XCTAssertEqual(request.httpMethod, "GET")
            self.assertRequest(request, fixture: fixture)
            let query = self.query(request)
            XCTAssertEqual(query["select"], RoutineStore.columns)
            XCTAssertEqual(query["order"], "created_at.asc")
            XCTAssertNil(request.httpBody)
            return fixture.response(request, body: "[]")
        }
        let routines = try await store.list(userID: fixture.userID)
        XCTAssertTrue(routines.isEmpty)
    }

    func testCreateAndUpdateWriteOnlyAllowedColumns() async throws {
        for editing in [false, true] {
            let fixture = RoutineStoreFixture()
            defer { fixture.cleanUp() }
            try await fixture.signIn()
            let routine = fixture.routine
            let store = fixture.routineStore { request in
                self.assertRequest(request, fixture: fixture)
                XCTAssertEqual(request.httpMethod, editing ? "PATCH" : "POST")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Prefer"), "return=representation")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
                XCTAssertEqual(self.query(request)["id"], editing ? "eq.\(routine.id.uuidString)" : nil)
                let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
                let expected = Set(["text", "interval_days", "start_date", "local_time", "timezone"])
                XCTAssertEqual(Set(body.keys), editing ? expected : expected.union(["user_id", "enabled"]))
                XCTAssertNil(body["next_run_at"])
                XCTAssertEqual(body["text"] as? String, "Uniform")
                XCTAssertEqual(body["local_time"] as? String, "19:00:00")
                if editing {
                    XCTAssertEqual(body["start_date"] as? String, "2026-10-12")
                    XCTAssertNil(body["enabled"], "Editing must not resume a paused routine")
                } else {
                    XCTAssertEqual(body["user_id"] as? String, fixture.userID.uuidString)
                    XCTAssertEqual(body["enabled"] as? Bool, true)
                    XCTAssertEqual(body["interval_days"] as? Int, 1)
                }
                return fixture.response(request, body: "[{\"id\":\"\(routine.id)\"}]")
            }
            var draft = RoutineDraft(routine: editing ? routine : nil)
            draft.text = "  Uniform \n"
            try await store.save(draft, userID: fixture.userID)
        }
    }

    func testPauseResumeAndDeleteOnlyTouchRoutineDefinition() async throws {
        let fixture = RoutineStoreFixture()
        defer { fixture.cleanUp() }
        try await fixture.signIn()
        for enabled in [false, true] {
            let store = fixture.routineStore { request in
                self.assertRequest(request, fixture: fixture)
                XCTAssertEqual(request.httpMethod, "PATCH")
                XCTAssertEqual(self.query(request)["id"], "eq.\(fixture.routine.id)")
                let body = try JSONDecoder().decode([String: Bool].self, from: XCTUnwrap(request.httpBody))
                XCTAssertEqual(body, ["enabled": enabled])
                return fixture.response(request, body: "[{\"id\":\"\(fixture.routine.id)\"}]")
            }
            try await store.setEnabled(enabled, id: fixture.routine.id, userID: fixture.userID)
        }
        let store = fixture.routineStore { request in
            self.assertRequest(request, fixture: fixture)
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(self.query(request)["id"], "eq.\(fixture.routine.id)")
            XCTAssertNil(request.httpBody)
            return fixture.response(request, body: "", status: 204)
        }
        try await store.delete(id: fixture.routine.id, userID: fixture.userID)
    }

    func testQuotaMessageIsPreserved() async throws {
        let fixture = RoutineStoreFixture()
        defer { fixture.cleanUp() }
        try await fixture.signIn()
        let message = "You can have at most 50 routines. Delete a routine before adding another."
        let store = fixture.routineStore { request in
            fixture.response(request, body: "{\"message\":\"\(message)\"}", status: 400)
        }
        var draft = RoutineDraft()
        draft.text = "Extra"
        do {
            try await store.save(draft, userID: fixture.userID)
            XCTFail("Expected quota error")
        } catch { XCTAssertEqual(error.localizedDescription, message) }
    }

    func testMissingUpdateAcknowledgementIsNotSuccess() async throws {
        let fixture = RoutineStoreFixture()
        defer { fixture.cleanUp() }
        try await fixture.signIn()
        let store = fixture.routineStore { fixture.response($0, body: "[]") }
        do {
            try await store.save(RoutineDraft(routine: fixture.routine), userID: fixture.userID)
            XCTFail("Expected unavailable error")
        } catch {
            XCTAssertEqual(error.localizedDescription, "This routine is no longer available. Refresh and try again.")
        }
    }

    func testWrongOwnerNeverSendsRequest() async throws {
        let fixture = RoutineStoreFixture()
        defer { fixture.cleanUp() }
        try await fixture.signIn()
        let store = fixture.routineStore { request in
            XCTFail("Wrong identity must not send HTTP")
            return fixture.response(request, body: "[]")
        }
        do {
            _ = try await store.list(userID: UUID())
            XCTFail("Expected signed out")
        } catch { XCTAssertEqual(error.localizedDescription, "Sign in to Notepad on this iPhone first.") }
    }

    func testIdentityChangesDuringReadOrWriteRejectResultButTokenRotationDoesNot() async throws {
        for method in ["GET", "PATCH"] {
            for transition in ["signOut", "switchAccount", "signInAgain", "rotateToken"] {
                let fixture = RoutineStoreFixture()
                defer { fixture.cleanUp() }
                try await fixture.signIn()
                let store = fixture.routineStore { request in
                    switch transition {
                    case "signOut": await fixture.sessionStore.clearUserData()
                    case "switchAccount": try await fixture.signIn(userID: UUID())
                    case "signInAgain":
                        await fixture.sessionStore.clearUserData()
                        try await fixture.signIn()
                    default: try await fixture.signIn(token: "rotated")
                    }
                    return fixture.response(request, body: method == "GET" ? "[]" : "[{\"id\":\"\(fixture.routine.id)\"}]")
                }
                do {
                    if method == "GET" { _ = try await store.list(userID: fixture.userID) }
                    else { try await store.setEnabled(false, id: fixture.routine.id, userID: fixture.userID) }
                    XCTAssertEqual(transition, "rotateToken", "Stale identity returned success")
                } catch {
                    XCTAssertNotEqual(transition, "rotateToken")
                    XCTAssertEqual(error.localizedDescription, "Sign in to Notepad on this iPhone first.")
                }
            }
        }
    }

    private func query(_ request: URLRequest) -> [String: String] {
        Dictionary(uniqueKeysWithValues: URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            .queryItems!.map { ($0.name, $0.value!) })
    }

    private func assertRequest(_ request: URLRequest, fixture: RoutineStoreFixture) {
        XCTAssertEqual(request.url?.path, "/rest/v1/routine_reminders")
        XCTAssertEqual(query(request)["user_id"], "eq.\(fixture.userID.uuidString)")
        XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "test-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-notepad-client"), "ios")
    }
}

struct RoutineStoreFixture {
    let suite = "RoutineStoreTests.\(UUID())"
    let defaults: UserDefaults
    let userID = UUID()
    let sessionStore: ReminderStore
    let routine = Routine(id: UUID(), text: "Uniform", intervalDays: 7, startDate: "2026-10-12",
                          localTime: "19:00:00", timezone: "Asia/Singapore", enabled: false, nextRunAt: Date())

    init() {
        defaults = UserDefaults(suiteName: suite)!
        sessionStore = ReminderStore(defaults: defaults, credentials: MemorySessionCredentials())
    }

    func signIn(userID: UUID? = nil, token: String = "test-token") async throws {
        try await sessionStore.saveSession(accessToken: token, refreshToken: "refresh",
                                            expiresAt: Date().addingTimeInterval(3600), userID: userID ?? self.userID)
    }

    func routineStore(requestData: @escaping (URLRequest) async throws -> (Data, URLResponse)) -> RoutineStore {
        RoutineStore(sessionStore: sessionStore, serviceURL: URL(string: "https://routines.invalid")!,
                     anonKey: "test-key", requestData: requestData)
    }

    func response(_ request: URLRequest, body: String, status: Int = 200) -> (Data, URLResponse) {
        (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }

    func cleanUp() { defaults.removePersistentDomain(forName: suite) }
}
