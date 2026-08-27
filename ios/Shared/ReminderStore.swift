import Foundation

actor ReminderStore {
    private enum StoreError: LocalizedError {
        case invalidResponse
        case requestFailed(Int)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "The reminders service returned an invalid response."
            case .requestFailed(let statusCode):
                return "The reminders service returned HTTP \(statusCode)."
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

    func saveSession(accessToken: String, refreshToken: String, expiresAt: Date) throws {
        defaults.set(
            try JSONEncoder().encode(
                SharedSession(accessToken: accessToken, expiresAt: expiresAt, refreshToken: refreshToken)
            ),
            forKey: sessionKey
        )
    }

    func clearUserData() {
        defaults.removeObject(forKey: sessionKey)
        defaults.removeObject(forKey: cacheKey)
    }

    func cached() -> [Reminder] {
        guard let data = defaults.data(forKey: cacheKey) else { return [] }
        return (try? ReminderJSON.decoder.decode([Reminder].self, from: data)) ?? []
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
        if session.isFresh() { return session }
        guard let refreshToken = session.refreshToken, !refreshToken.isEmpty else {
            return session.expiresAt > Date() ? session : nil
        }
        if let refreshed = await refreshAccessToken(refreshToken) {
            if let encoded = try? JSONEncoder().encode(refreshed) {
                defaults.set(encoded, forKey: sessionKey)
            }
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
        return session.expiresAt > Date() ? session : nil
    }

    private func refreshAccessToken(_ refreshToken: String) async -> SharedSession? {
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
        return payload.makeSession(fallbackRefreshToken: refreshToken)
    }

    /// Creates a reminder via POST, updates the App Group cache, and returns the active reminders.
    func create(text: String, userID: UUID) async throws -> [Reminder] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw StoreError.invalidResponse
        }
        if ReminderBoardLimits.isAtCapacity(cached().filter { !$0.isDone }.count) {
            throw StoreError.requestFailed(409)
        }
        guard let session = await loadFreshSession() else {
            throw StoreError.requestFailed(401)
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
        guard let session = await loadFreshSession() else {
            throw StoreError.requestFailed(401)
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
        request.httpBody = try ReminderJSON.encoder.encode(["is_done": true])

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw StoreError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            throw StoreError.requestFailed(http.statusCode)
        }

        let reminders = cached().filter { $0.id != id }
        defaults.set(try ReminderJSON.encoder.encode(reminders), forKey: cacheKey)
        return reminders
    }
}
