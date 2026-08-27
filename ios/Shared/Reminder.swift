import Foundation

struct Reminder: Codable, Identifiable, Hashable {
    let id: UUID
    let userID: UUID
    var text: String
    var sortOrder: Int
    var isDone: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, text
        case userID = "user_id"
        case sortOrder = "sort_order"
        case isDone = "is_done"
        case createdAt = "created_at"
    }
}

struct SharedSession: Codable, Equatable {
    let accessToken: String
    let expiresAt: Date
    var refreshToken: String?

    /// True when the access token is usable, with a short leeway so in-flight
    /// widget / background refresh does not race the JWT expiry.
    func isFresh(at now: Date = Date(), leeway: TimeInterval = 60) -> Bool {
        expiresAt > now.addingTimeInterval(leeway)
    }
}

/// GoTrue `/auth/v1/token?grant_type=refresh_token` body. Kept next to
/// `SharedSession` so widget/background refresh can mint a new access token
/// without the Supabase Swift client (the widget target does not link it).
struct TokenRefreshResponse: Decodable, Equatable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: TimeInterval?
    let expiresIn: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case expiresIn = "expires_in"
    }

    func makeSession(fallbackRefreshToken: String, now: Date = Date()) -> SharedSession {
        let expires: Date
        if let expiresAt {
            expires = Date(timeIntervalSince1970: expiresAt)
        } else if let expiresIn {
            expires = now.addingTimeInterval(expiresIn)
        } else {
            expires = now.addingTimeInterval(3600)
        }
        return SharedSession(
            accessToken: accessToken,
            expiresAt: expires,
            refreshToken: refreshToken ?? fallbackRefreshToken
        )
    }
}

extension Notification.Name {
    static let didRefreshSharedSession = Notification.Name("didRefreshSharedSession")
}

enum ReminderJSON {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    /// Decodes Supabase timestamps with or without fractional seconds.
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) { return date }
            let regular = ISO8601DateFormatter()
            if let date = regular.date(from: value) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO-8601 date"
            )
        }
        return decoder
    }()
}
