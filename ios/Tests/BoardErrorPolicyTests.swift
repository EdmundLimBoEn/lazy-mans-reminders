import XCTest
@testable import LazyMansReminders

final class BoardErrorPolicyTests: XCTestCase {
    func testAnnouncementTransitions() {
        var policy = BoardErrorAnnouncementPolicy()
        let message = URLError(.notConnectedToInternet).localizedDescription
        XCTAssertNil(policy.update(nil))
        XCTAssertEqual(policy.update(message), message)
        XCTAssertNil(policy.update(message))
        XCTAssertNil(policy.update(nil))
        XCTAssertEqual(policy.update(message), message)
        XCTAssertNil(policy.update(message))
    }
}
