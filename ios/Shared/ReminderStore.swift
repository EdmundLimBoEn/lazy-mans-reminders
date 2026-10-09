import Foundation

actor ReminderStore {
    private enum StoreError: LocalizedError {
        case invalidResponse
        case reminderUnavailable
        case mutationConflict
        case requestFailed(Int)
        case signedOut
        case atCapacity
        case emptyText
        case tooLong

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "The reminders service returned an invalid response."
            case .reminderUnavailable:
                return "This reminder is no longer available. Refresh your board and try again."
            case .mutationConflict:
                return "The reminder change could not be confirmed. Refresh your board and try again."
            case .requestFailed(let statusCode):
                return "The reminders service returned HTTP \(statusCode)."
            case .signedOut:
                return "Sign in to Lazy Man's Reminders on this iPhone first."
            case .atCapacity:
                return ReminderBoardLimits.postItHint
            case .emptyText:
                return "Reminder text is empty."
            case .tooLong:
                return "Keep each reminder to 500 characters."
            }
        }
    }

    static let shared = ReminderStore()

    private let injectedDefaults: UserDefaults?
    private let serviceURL: URL?
    private let anonKey: String?
    private var pendingUpdates: [UUID: UUID] = [:]
    private let requestData: (URLRequest) async throws -> (Data, URLResponse)

    init(
        defaults: UserDefaults? = nil,
        serviceURL: URL? = nil,
        anonKey: String? = nil,
        requestData: @escaping (URLRequest) async throws -> (Data, URLResponse) = {
            try await URLSession.shared.data(for: $0)
        }
    ) {
        self.injectedDefaults = defaults
        self.serviceURL = serviceURL
        self.anonKey = anonKey
        self.requestData = requestData
    }

    private var supabaseURL: URL { serviceURL ?? AppConfig.supabaseURL }
    private var supabaseAnonKey: String { anonKey ?? AppConfig.supabaseAnonKey }

    private let cacheKey = "cached-reminders"
    private let sessionKey = "shared-session"
    private let identityRevisionKey = "shared-session-identity-revision"

    private func storedSession() -> SharedSession? {
        guard let data = defaults.data(forKey: sessionKey),
              let session = try? JSONDecoder().decode(SharedSession.self, from: data) else { return nil }
        return session.resolvingUserID()
    }

    private var defaults: UserDefaults {
        if let injectedDefaults { return injectedDefaults }
        guard let defaults = UserDefaults(suiteName: AppConfig.appGroupID) else {
            fatalError("App Group \(AppConfig.appGroupID) is not configured")
        }
        return defaults
    }

    func saveSession(
        accessToken: String,
        refreshToken: String,
        expiresAt: Date,
        userID: UUID? = nil
    ) throws {
        let session = SharedSession(
            accessToken: accessToken,
            expiresAt: expiresAt,
            refreshToken: refreshToken,
            userID: userID ?? JWTUserID.uuid(fromAccessToken: accessToken)
        )
        let previous = storedSession()
        if previous?.userID != session.userID {
            defaults.removeObject(forKey: cacheKey)
        }
        if previous == nil || previous?.userID != session.userID
            || authSessionID(previous?.accessToken) != authSessionID(session.accessToken) {
            defaults.set(UUID().uuidString, forKey: identityRevisionKey)
        }
        persist(session)
    }

    func currentUserID() async -> UUID? {
        if let session = await loadFreshSession(), let userID = session.userID {
            return userID
        }
        return cached().first?.userID
    }

    func isSignedIn() async -> Bool {
        await loadFreshSession() != nil
    }

    func clearUserData() {
        defaults.set(UUID().uuidString, forKey: identityRevisionKey)
        defaults.removeObject(forKey: sessionKey)
        defaults.removeObject(forKey: cacheKey)
    }

    func cached() -> [Reminder] {
        guard let data = defaults.data(forKey: cacheKey) else { return [] }
        return (try? ReminderJSON.decoder.decode([Reminder].self, from: data)) ?? []
    }

    /// Fallback helper. `??` uses a sync autoclosure, so `?? await cached()` does not compile.
    func refreshOrCached(refreshAuthentication: Bool = true) async -> [Reminder] {
        do {
            return try await refresh(performMaintenance: false, refreshAuthentication: refreshAuthentication)
        } catch {
            return cached()
        }
    }

    func refresh(
        performMaintenance: Bool = true,
        refreshAuthentication: Bool = true
    ) async throws -> [Reminder] {
        let identityRevision = defaults.string(forKey: identityRevisionKey)
        // Extensions use a valid shared JWT but never rotate the host SDK's refresh token.
        let candidate = refreshAuthentication ? await loadFreshSession() : storedSession()
        guard let session = candidate, session.expiresAt > Date() else {
            throw StoreError.signedOut
        }

        try requireCurrentIdentity(session, revision: identityRevision)

        // Best-effort: drop this user's done reminders older than 7 days (DB trigger sets completed_at).
        if performMaintenance {
            await deleteOldCompletedReminders(accessToken: session.accessToken)
            try requireCurrentIdentity(session, revision: identityRevision)
        }

        var components = URLComponents(
            url: supabaseURL.appending(path: "rest/v1/reminders"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "is_done", value: "eq.false"),
            URLQueryItem(name: "order", value: "sort_order.asc,created_at.asc")
        ]
        var request = URLRequest(url: components.url!, timeoutInterval: 15)
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")

        let (responseData, response) = try await requestData(request)
        guard let http = response as? HTTPURLResponse else {
            throw StoreError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            throw StoreError.requestFailed(http.statusCode)
        }

        let reminders = try ReminderJSON.decoder.decode([Reminder].self, from: responseData)
        try requireCurrentIdentity(session, revision: identityRevision)
        defaults.set(try ReminderJSON.encoder.encode(reminders), forKey: cacheKey)
        return reminders
    }

    // Actor methods can resume after sign-out while an HTTP request is suspended.
    private func requireCurrentIdentity(_ session: SharedSession, revision: String?) throws {
        guard defaults.string(forKey: identityRevisionKey) == revision,
              let current = storedSession(),
              current.userID == session.userID,
              authSessionID(current.accessToken) == authSessionID(session.accessToken)
        else { throw StoreError.signedOut }
    }

    // Unverified JWT metadata is used only for local cache identity, never authorization.
    // Supabase keeps session_id stable across token rotation; legacy tokens may omit it.
    private func authSessionID(_ token: String?) -> UUID? {
        guard let token else { return nil }
        let segments = token.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3,
              let data = JWTUserID.decodeBase64URL(String(segments[1])),
              let claims = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = claims["session_id"] as? String else { return nil }
        return UUID(uuidString: value)
    }

    /// Invokes `delete_old_completed_reminders` RPC. Failures are ignored so refresh still works.
    private func deleteOldCompletedReminders(accessToken: String) async {
        var request = URLRequest(
            url: supabaseURL.appending(path: "rest/v1/rpc/delete_old_completed_reminders")
        )
        request.httpMethod = "POST"
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)
        _ = try? await requestData(request)
    }

    /// Loads the App Group session, refreshing the JWT when it is near expiry so
    /// background push handling and the lock-screen widget stay in sync after
    /// the access token's ~1h lifetime. Widget timelines only read `cached()`.
    private func loadFreshSession() async -> SharedSession? {
        guard
            let data = defaults.data(forKey: sessionKey),
            let session = try? JSONDecoder().decode(SharedSession.self, from: data)
        else {
            return nil
        }
        let identityRevision = defaults.string(forKey: identityRevisionKey)
        let resolved = session.resolvingUserID()
        if resolved.userID != session.userID {
            persist(resolved)
        }
        if resolved.isFresh() { return resolved }
        guard let refreshToken = resolved.refreshToken, !refreshToken.isEmpty else {
            return resolved.expiresAt > Date() ? resolved : nil
        }
        let refreshed = await refreshAccessToken(refreshToken, userID: resolved.userID)
        do {
            try requireCurrentIdentity(resolved, revision: identityRevision)
        } catch {
            return nil
        }
        guard let current = storedSession() else { return nil }
        // The host SDK may have rotated this same session while our request awaited HTTP.
        // Use its fresh credentials and never overwrite them with a delayed response.
        if current.refreshToken != refreshToken || current.accessToken != resolved.accessToken {
            return current.isFresh() ? current : nil
        }
        if let refreshed {
            persist(refreshed)
            NotificationCenter.default.post(
                name: .didRefreshSharedSession,
                object: nil,
                userInfo: [
                    "accessToken": refreshed.accessToken,
                    "refreshToken": refreshed.refreshToken ?? refreshToken,
                ]
            )
            return refreshed
        }
        return resolved.expiresAt > Date() ? resolved : nil
    }

    private func persist(_ session: SharedSession) {
        if let encoded = try? JSONEncoder().encode(session) {
            defaults.set(encoded, forKey: sessionKey)
        }
    }

    private func refreshAccessToken(_ refreshToken: String, userID: UUID?) async -> SharedSession? {
        var components = URLComponents(
            url: supabaseURL.appending(path: "auth/v1/token"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])

        guard
            let (data, response) = try? await requestData(request),
            let http = response as? HTTPURLResponse,
            200..<300 ~= http.statusCode,
            let payload = try? JSONDecoder().decode(TokenRefreshResponse.self, from: data)
        else {
            return nil
        }
        return payload.makeSession(fallbackRefreshToken: refreshToken, userID: userID)
    }

    /// Creates a reminder via POST, updates the App Group cache, and returns the active reminders.
    func create(text: String, userID: UUID? = nil) async throws -> [Reminder] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw StoreError.emptyText
        }
        guard trimmed.count <= 500 else {
            throw StoreError.tooLong
        }
        if ReminderBoardLimits.isAtCapacity(cached().filter { !$0.isDone }.count) {
            throw StoreError.atCapacity
        }
        let identityRevision = defaults.string(forKey: identityRevisionKey)
        guard let session = await loadFreshSession() else {
            throw StoreError.signedOut
        }
        try requireCurrentIdentity(session, revision: identityRevision)
        guard let ownerID = session.userID,
              userID == nil || userID == ownerID else {
            throw StoreError.signedOut
        }

        let nextOrder = (cached().map(\.sortOrder).max() ?? -1) + 1
        struct CreateBody: Encodable {
            let text: String
            let userID: UUID
            let sortOrder: Int

            enum CodingKeys: String, CodingKey {
                case text
                case userID = "user_id"
                case sortOrder = "sort_order"
            }
        }
        var request = URLRequest(url: supabaseURL.appending(path: "rest/v1/reminders"))
        request.httpMethod = "POST"
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try ReminderJSON.encoder.encode(
            CreateBody(text: trimmed, userID: ownerID, sortOrder: nextOrder)
        )
        let (responseData, response) = try await requestData(request)
        guard let http = response as? HTTPURLResponse else {
            throw StoreError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            throw StoreError.requestFailed(http.statusCode)
        }

        try requireCurrentIdentity(session, revision: identityRevision)
        let created = try acknowledgedReminder(responseData, ownerID: ownerID, text: trimmed, isDone: false)
        return try cacheAcknowledgedReminder(created)
    }

    private func acknowledgedReminder(
        _ data: Data, ownerID: UUID, id: UUID? = nil, text: String? = nil, isDone: Bool? = nil
    ) throws -> Reminder {
        guard let rows = try? ReminderJSON.decoder.decode([Reminder].self, from: data) else {
            throw StoreError.invalidResponse
        }
        guard !rows.isEmpty else { throw StoreError.reminderUnavailable }
        guard rows.count == 1, let reminder = rows.first,
              reminder.userID == ownerID,
              id == nil || reminder.id == id,
              text == nil || reminder.text == text,
              isDone == nil || reminder.isDone == isDone else {
            throw StoreError.mutationConflict
        }
        return reminder
    }

    private func cacheAcknowledgedReminder(_ reminder: Reminder) throws -> [Reminder] {
        var reminders = cached().filter { $0.id != reminder.id && !$0.isDone }
        if !reminder.isDone { reminders.append(reminder) }
        reminders.sort {
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            return $0.createdAt < $1.createdAt
        }
        defaults.set(try ReminderJSON.encoder.encode(reminders), forKey: cacheKey)
        return reminders
    }

    /// Marks a reminder done via PATCH, updates the App Group cache, and returns the remaining active reminders.
    func markDone(id: UUID) async throws -> [Reminder] {
        try await update(id: id, isDone: true)
    }

    /// Patches text and/or completion. Returns the active (not done) cache afterwards.
    func update(id: UUID, text: String? = nil, isDone: Bool? = nil) async throws -> [Reminder] {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed {
            guard !trimmed.isEmpty else { throw StoreError.emptyText }
            guard trimmed.count <= 500 else { throw StoreError.tooLong }
        }
        guard trimmed != nil || isDone != nil else {
            return cached()
        }
        let mutationID = UUID()
        pendingUpdates[id] = mutationID
        defer {
            if pendingUpdates[id] == mutationID { pendingUpdates.removeValue(forKey: id) }
        }
        let identityRevision = defaults.string(forKey: identityRevisionKey)
        guard let session = await loadFreshSession(), let ownerID = session.userID else {
            throw StoreError.signedOut
        }
        try requireCurrentIdentity(session, revision: identityRevision)
        guard pendingUpdates[id] == mutationID else { throw StoreError.mutationConflict }

        struct UpdateBody: Encodable {
            var text: String?
            var isDone: Bool?

            enum CodingKeys: String, CodingKey {
                case text
                case isDone = "is_done"
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                if let text { try container.encode(text, forKey: .text) }
                if let isDone { try container.encode(isDone, forKey: .isDone) }
            }
        }

        var components = URLComponents(
            url: supabaseURL.appending(path: "rest/v1/reminders"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(id.uuidString)")
        ]
        var request = URLRequest(url: components.url!, timeoutInterval: 15)
        request.httpMethod = "PATCH"
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try ReminderJSON.encoder.encode(
            UpdateBody(text: trimmed, isDone: isDone)
        )

        let (responseData, response) = try await requestData(request)
        guard let http = response as? HTTPURLResponse else {
            throw StoreError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            throw StoreError.requestFailed(http.statusCode)
        }

        try requireCurrentIdentity(session, revision: identityRevision)
        // A returned row is a snapshot; a newer same-ID request makes it obsolete.
        guard pendingUpdates[id] == mutationID else { throw StoreError.mutationConflict }
        let updated = try acknowledgedReminder(responseData, ownerID: ownerID, id: id, text: trimmed, isDone: isDone)
        return try cacheAcknowledgedReminder(updated)
    }
}
