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

    func saveSession(accessToken: String, expiresAt: Date) throws {
        defaults.set(try JSONEncoder().encode(SharedSession(accessToken: accessToken, expiresAt: expiresAt)), forKey: sessionKey)
    }

    func clearUserData() {
        defaults.removeObject(forKey: sessionKey)
        defaults.removeObject(forKey: cacheKey)
    }

    func cached() -> [Reminder] {
        guard let data = defaults.data(forKey: cacheKey) else { return [] }
        return (try? Self.decoder.decode([Reminder].self, from: data)) ?? []
    }

    func refresh() async throws -> [Reminder] {
        guard
            let data = defaults.data(forKey: sessionKey),
            let session = try? JSONDecoder().decode(SharedSession.self, from: data),
            session.expiresAt > Date()
        else {
            return cached()
        }

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

        let reminders = try Self.decoder.decode([Reminder].self, from: responseData)
        defaults.set(try Self.encoder.encode(reminders), forKey: cacheKey)
        return reminders
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) { return date }
            let regular = ISO8601DateFormatter()
            if let date = regular.date(from: value) { return date }
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "Invalid ISO-8601 date"
            )
        }
        return decoder
    }()
}
