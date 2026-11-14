import XCTest
@testable import LazyMansReminders

@MainActor
final class RoutineListModelTests: XCTestCase {
    func testFailedEmptyLoadAndDismissedErrorNeverClaimNoRoutines() async throws {
        let fixture = RoutineStoreFixture()
        defer { fixture.cleanUp() }
        try await fixture.signIn()
        let store = fixture.routineStore { fixture.response($0, body: "{}", status: 500) }
        let model = RoutineListModel(store: store)
        await model.refresh(userID: fixture.userID)
        XCTAssertNotNil(model.error)
        XCTAssertFalse(model.showsEmpty)
        XCTAssertFalse(model.isLoading)
        model.error = nil
        XCTAssertFalse(model.showsEmpty)
    }

    func testSuccessfulEmptyReadShowsEmptyState() async throws {
        let fixture = RoutineStoreFixture()
        defer { fixture.cleanUp() }
        try await fixture.signIn()
        let model = RoutineListModel(store: fixture.routineStore { fixture.response($0, body: "[]") })
        await model.refresh(userID: fixture.userID)
        XCTAssertTrue(model.showsEmpty)
        XCTAssertNil(model.error)
    }

    func testReadBeforeDeleteCannotRestoreDeletedRoutine() async throws {
        try await checkStaleRead(delete: true)
    }

    func testOlderReadCannotOverwriteNewerRefresh() async throws {
        try await checkStaleRead(delete: false)
    }

    private func checkStaleRead(delete: Bool) async throws {
        let fixture = RoutineStoreFixture()
        defer { fixture.cleanUp() }
        try await fixture.signIn()
        let started = expectation(description: "First read suspended")
        let network = DelayedRoutineRead(started: started)
        let model = RoutineListModel(store: fixture.routineStore { try await network.send($0) })
        let oldRead = Task { await model.refresh(userID: fixture.userID) }
        await fulfillment(of: [started], timeout: 3)
        if delete { await model.change(fixture.routine, delete: true, userID: fixture.userID) }
        else { await model.refresh(userID: fixture.userID) }
        XCTAssertTrue(model.showsEmpty)
        await network.finish(data: try ReminderJSON.encoder.encode([fixture.routine]))
        await oldRead.value
        XCTAssertTrue(model.routines.isEmpty)
        XCTAssertTrue(model.showsEmpty)
        XCTAssertFalse(model.isBusy)
        XCTAssertNil(model.error)
    }
}

private actor DelayedRoutineRead {
    let started: XCTestExpectation
    var pending: CheckedContinuation<(Data, URLResponse), Error>?
    var firstRequest: URLRequest?

    init(started: XCTestExpectation) { self.started = started }

    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        if firstRequest == nil {
            firstRequest = request
            return try await withCheckedThrowingContinuation { continuation in
                pending = continuation
                started.fulfill()
            }
        }
        return (Data("[]".utf8), HTTPURLResponse(url: request.url!, statusCode: 200,
                                               httpVersion: nil, headerFields: nil)!)
    }

    func finish(data: Data) {
        pending?.resume(returning: (data, HTTPURLResponse(url: firstRequest!.url!, statusCode: 200,
                                                        httpVersion: nil, headerFields: nil)!))
        pending = nil
    }
}
