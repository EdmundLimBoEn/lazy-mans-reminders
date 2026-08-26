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

struct SharedSession: Codable {
    let accessToken: String
    let expiresAt: Date
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
