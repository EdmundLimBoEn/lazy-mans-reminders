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
