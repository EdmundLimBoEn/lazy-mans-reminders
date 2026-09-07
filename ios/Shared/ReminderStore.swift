import Foundation

actor ReminderStore {
    private enum StoreError: LocalizedError {
        case invalidResponse
        case requestFailed(Int)
        case signedOut
        case atCapacity
        case emptyText
        case tooLong

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "The reminders service returned an invalid response."
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

    private let cacheKey = "cached-reminders"
    private let sessionKey = "shared-session"

    private var defaults: UserDefaults {
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
        defaults.removeObject(forKey: sessionKey)
        defaults.removeObject(forKey: cacheKey)
    }

    func cached() -> [Reminder] {
        guard let data = defaults.data(forKey: cacheKey) else { return [] }
        return (try? ReminderJSON.decoder.decode([Reminder].self, from: data)) ?? []
    }

    /// Fallback helper. `??` uses a sync autoclosure, so `?? await cached()` does not compile.
    func refreshOrCached() async -> [Reminder] {
        do {
            return try await refresh()
        } catch {
            return cached()
        }
    }

    func refresh() async throws -> [Reminder] {
        guard let session = await loadFreshSession() else {
            return cached()
        }

        // Best-effort: drop this user's done reminders older than 7 days (DB trigger sets completed_at).
        await deleteOldCompletedReminders(accessToken: session.accessToken)

        var components = URLComponents(
            url: AppConfig.supabaseURL.appending(path: "rest/v1/reminders"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "is_done", value: "eq.false"),
            URLQueryItem(name: "order", value: "sort_order.asc,created_at.asc")
        ]
        var request = URLRequest(url: components.url!)
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw StoreError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            throw StoreError.requestFailed(http.statusCode)
        }

        let reminders = try ReminderJSON.decoder.decode([Reminder].self, from: responseData)
        defaults.set(try ReminderJSON.encoder.encode(reminders), forKey: cacheKey)
        return reminders
    }

    /// Invokes `delete_old_completed_reminders` RPC. Failures are ignored so refresh still works.
    private func deleteOldCompletedReminders(accessToken: String) async {
        var request = URLRequest(
            url: AppConfig.supabaseURL.appending(path: "rest/v1/rpc/delete_old_completed_reminders")
        )
        request.httpMethod = "POST"
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)
        _ = try? await URLSession.shared.data(for: request)
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
        let resolved = session.resolvingUserID()
        if resolved.userID != session.userID {
            persist(resolved)
        }
        if resolved.isFresh() { return resolved }
        guard let refreshToken = resolved.refreshToken, !refreshToken.isEmpty else {
            return resolved.expiresAt > Date() ? resolved : nil
        }
        if let refreshed = await refreshAccessToken(refreshToken, userID: resolved.userID) {
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
            url: AppConfig.supabaseURL.appending(path: "auth/v1/token"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])

        guard
            let (data, response) = try? await URLSession.shared.data(for: request),
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
        guard let session = await loadFreshSession() else {
            throw StoreError.signedOut
        }
        guard let userID = userID ?? session.userID ?? cached().first?.userID else {
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
        var request = URLRequest(url: AppConfig.supabaseURL.appending(path: "rest/v1/reminders"))
        request.httpMethod = "POST"
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try ReminderJSON.encoder.encode(
            CreateBody(text: trimmed, userID: userID, sortOrder: nextOrder)
        )
        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw StoreError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            throw StoreError.requestFailed(http.statusCode)
        }

        let created = try ReminderJSON.decoder.decode([Reminder].self, from: responseData)
        var reminders = cached()
        reminders.append(contentsOf: created)
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
        guard let session = await loadFreshSession() else {
            throw StoreError.signedOut
        }

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
            url: AppConfig.supabaseURL.appending(path: "rest/v1/reminders"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(id.uuidString)")
        ]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "PATCH"
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try ReminderJSON.encoder.encode(
            UpdateBody(text: trimmed, isDone: isDone)
        )

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw StoreError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            throw StoreError.requestFailed(http.statusCode)
        }

        if isDone == true {
            let reminders = cached().filter { $0.id != id }
            defaults.set(try ReminderJSON.encoder.encode(reminders), forKey: cacheKey)
            return reminders
        }
        if isDone == false {
            return try await refresh()
        }
        if let trimmed {
            var reminders = cached()
            if let index = reminders.firstIndex(where: { $0.id == id }) {
                reminders[index].text = trimmed
                defaults.set(try ReminderJSON.encoder.encode(reminders), forKey: cacheKey)
            }
            return reminders
        }
        return cached()
    }
}
