import XCTest
@testable import LazyMansReminders

final class MemorySessionCredentials: SessionCredentialStorage {
    var data: Data?
    var unavailable = false
    enum Failure: Error { case unavailable }
    func read() throws -> Data? {
        if unavailable { throw Failure.unavailable }
        return data
    }
    func write(_ data: Data) throws {
        if unavailable { throw Failure.unavailable }
        self.data = data
    }
    func insertIfAbsent(_ data: Data) throws {
        if unavailable { throw Failure.unavailable }
        if self.data == nil { self.data = data }
    }
    func delete() throws {
        if unavailable { throw Failure.unavailable }
        data = nil
    }
}

final class SharedSessionStorageTests: XCTestCase {
    func testLegacyMigrationSurvivesRecreationAndRemovesPreferencesCopy() throws {
        try withStorage { storage, credentials, defaults in
            let legacy = Data("legacy-session".utf8)
            defaults.set(legacy, forKey: "shared-session")
            XCTAssertEqual(try storage.read(), legacy)
            XCTAssertNil(defaults.object(forKey: "shared-session"))
            XCTAssertEqual(credentials.data, legacy)
            let widget = SharedSessionStorage(defaults: defaults, credentials: credentials)
            XCTAssertEqual(try widget.read(), legacy)
        }
    }

    func testUnavailableKeychainDoesNotReturnOrLoseLegacyCredentials() throws {
        try withStorage { storage, credentials, defaults in
            let legacy = Data("legacy-session".utf8)
            defaults.set(legacy, forKey: "shared-session")
            credentials.unavailable = true
            XCTAssertThrowsError(try storage.read())
            XCTAssertEqual(defaults.data(forKey: "shared-session"), legacy)
            credentials.unavailable = false
            XCTAssertEqual(try storage.read(), legacy)
            XCTAssertNil(defaults.object(forKey: "shared-session"))
        }
    }

    func testMigrationWriteFailurePreservesOnlyCopy() throws {
        final class WriteFailure: SessionCredentialStorage {
            func read() throws -> Data? { nil }
            func write(_ data: Data) throws { throw MemorySessionCredentials.Failure.unavailable }
            func insertIfAbsent(_ data: Data) throws { try write(data) }
            func delete() throws {}
        }
        try withStorage { _, _, defaults in
            let legacy = Data("legacy-session".utf8)
            defaults.set(legacy, forKey: "shared-session")
            let storage = SharedSessionStorage(defaults: defaults, credentials: WriteFailure())
            XCTAssertThrowsError(try storage.read())
            XCTAssertEqual(defaults.data(forKey: "shared-session"), legacy)
        }
    }

    func testConcurrentSaveWinsOverMigrationSnapshot() throws {
        final class ConcurrentSave: SessionCredentialStorage {
            var data: Data?
            func read() throws -> Data? { data }
            func write(_ data: Data) throws { self.data = data }
            func insertIfAbsent(_ data: Data) throws {
                // The other process saves between migration's read and insert.
                self.data = Data("new-session".utf8)
            }
            func delete() throws { data = nil }
        }
        try withStorage { _, _, defaults in
            defaults.set(Data("legacy".utf8), forKey: "shared-session")
            let storage = SharedSessionStorage(defaults: defaults, credentials: ConcurrentSave())
            XCTAssertEqual(try storage.read(), Data("new-session".utf8))
            XCTAssertNil(defaults.object(forKey: "shared-session"))
        }
    }

    func testExistingKeychainWinsOverLegacyCopy() throws {
        try withStorage { storage, credentials, defaults in
            credentials.data = Data("rotated-session".utf8)
            defaults.set(Data("stale-session".utf8), forKey: "shared-session")
            XCTAssertEqual(try storage.read(), credentials.data)
            XCTAssertNil(defaults.object(forKey: "shared-session"))
        }
    }

    func testFailedDeletionCannotResurrectSessionAfterRestart() throws {
        try withStorage { storage, credentials, defaults in
            try storage.write(Data("session".utf8))
            defaults.set(Data("legacy".utf8), forKey: "shared-session")
            credentials.unavailable = true
            storage.clear()
            XCTAssertNil(defaults.object(forKey: "shared-session"))
            let restarted = SharedSessionStorage(defaults: defaults, credentials: credentials)
            XCTAssertNil(try restarted.read())
            credentials.unavailable = false
            XCTAssertNil(try restarted.read())
            // Reads leave failed cleanup masked; only an explicit save replaces it.
            XCTAssertEqual(credentials.data, Data("session".utf8))
            try restarted.write(Data("new-session".utf8))
            XCTAssertEqual(try restarted.read(), Data("new-session".utf8))
        }
    }

    func testWidgetReadCannotDeleteSessionSavedAfterObservingSignOut() throws {
        final class InterleavingDefaults: UserDefaults {
            var afterSignOutRead: (() throws -> Void)?

            override func bool(forKey defaultName: String) -> Bool {
                let observed = super.bool(forKey: defaultName)
                if defaultName == "shared-session-signed-out", let action = afterSignOutRead {
                    afterSignOutRead = nil
                    // Resume the widget with its old observation after the app saves.
                    XCTAssertNoThrow(try action())
                }
                return observed
            }
        }

        let suite = "SharedSessionStorageTests.\(UUID())"
        let defaults = InterleavingDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let credentials = MemorySessionCredentials()
        let app = SharedSessionStorage(defaults: defaults, credentials: credentials)
        let widget = SharedSessionStorage(defaults: defaults, credentials: credentials)
        try app.write(Data("old-session".utf8))
        app.clear()

        let newSession = Data("new-session".utf8)
        defaults.afterSignOutRead = { try app.write(newSession) }
        XCTAssertNil(try widget.read())
        XCTAssertEqual(credentials.data, newSession)
        XCTAssertEqual(try widget.read(), newSession)
        XCTAssertEqual(try app.read(), newSession)
    }

    func testStoreSavesRotatesAndClearsWithoutPreferencesCredentials() async throws {
        let suite = "SharedSessionStorageTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let credentials = MemorySessionCredentials()
        let store = ReminderStore(defaults: defaults, credentials: credentials)
        let userID = UUID()
        for token in ["initial", "rotated"] {
            try await store.saveSession(accessToken: token, refreshToken: "refresh-\(token)",
                                        expiresAt: Date().addingTimeInterval(3600), userID: userID)
            XCTAssertNil(defaults.object(forKey: "shared-session"))
            let saved = try JSONDecoder().decode(SharedSession.self, from: XCTUnwrap(credentials.data))
            XCTAssertEqual(saved.accessToken, token)
            XCTAssertEqual(saved.refreshToken, "refresh-\(token)")
        }
        let widget = ReminderStore(defaults: defaults, credentials: credentials)
        let signedIn = await widget.isSignedIn()
        XCTAssertTrue(signedIn)
        await store.clearUserData()
        XCTAssertNil(credentials.data)
        let signedOut = await widget.isSignedIn()
        XCTAssertFalse(signedOut)
    }

    private func withStorage(_ body: (SharedSessionStorage, MemorySessionCredentials, UserDefaults) throws -> Void) rethrows {
        let suite = "SharedSessionStorageTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let credentials = MemorySessionCredentials()
        try body(SharedSessionStorage(defaults: defaults, credentials: credentials), credentials, defaults)
    }
}
