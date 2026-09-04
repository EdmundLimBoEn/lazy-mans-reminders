import AppIntents
import CoreSpotlight
import UniformTypeIdentifiers

/// Single board in this app. The reminders schema requires a list entity even
/// though Lazy Man's Reminders does not have multiple lists.
@available(iOS 26.0, *)
@AppEnum(schema: .reminders.listType)
enum ReminderListType: String {
    case standard

    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .standard: "Standard"
    ]
}

@available(iOS 26.0, *)
@AppEntity(schema: .reminders.list)
struct ReminderListEntity {
    static let defaultQuery = ReminderListEntityQuery()

    static let boardID = UUID(uuidString: "a1b2c3d4-e5f6-4789-8abc-1234567890ab")!

    static var board: ReminderListEntity {
        ReminderListEntity(id: boardID, name: "Your board", type: .standard)
    }

    let id: UUID
    var name: String
    var type: ReminderListType

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "Lazy Man's Reminders",
            image: .init(systemName: "checklist")
        )
    }
}

@available(iOS 26.0, *)
struct ReminderListEntityQuery: EntityQuery, EnumerableEntityQuery {
    func entities(for identifiers: [ReminderListEntity.ID]) async throws -> [ReminderListEntity] {
        identifiers.contains(ReminderListEntity.boardID) ? [.board] : []
    }

    func allEntities() async throws -> [ReminderListEntity] {
        [.board]
    }

    func suggestedEntities() async throws -> [ReminderListEntity] {
        try await allEntities()
    }
}

@available(iOS 26.0, *)
@AppEntity(schema: .reminders.reminder)
struct ReminderEntity {
    static let defaultQuery = ReminderEntityQuery()

    let id: UUID
    var title: String
    var note: AttributedString?
    var tags: Set<String>
    var urls: [URL]
    var dueDate: DateComponents?
    var recurrence: Calendar.RecurrenceRule?
    var isCompleted: Bool
    var isFlagged: Bool?
    var creationDate: Date?
    var completionDate: Date?
    var list: ReminderListEntity

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: isCompleted ? "Completed" : "On your board",
            image: .init(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
        )
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(itemContentType: UTType.text.identifier)
        attributes.displayName = title
        attributes.title = title
        attributes.textContent = title
        attributes.contentDescription = "Reminder on your Lazy Man's Reminders board"
        attributes.identifier = id.uuidString
        return attributes
    }
}

@available(iOS 26.0, *)
extension ReminderEntity: IndexedEntity {
    init(_ reminder: Reminder) {
        self.init(
            id: reminder.id,
            title: reminder.text,
            note: nil,
            tags: [],
            urls: [],
            dueDate: nil,
            recurrence: nil,
            isCompleted: reminder.isDone,
            isFlagged: nil,
            creationDate: reminder.createdAt,
            completionDate: nil,
            list: .board
        )
    }
}

@available(iOS 26.0, *)
struct ReminderEntityQuery: IndexedEntityQuery, EnumerableEntityQuery, EntityStringQuery {
    func entities(for identifiers: [ReminderEntity.ID]) async throws -> [ReminderEntity] {
        var reminders = await ReminderStore.shared.cached()
        let missing = identifiers.filter { id in !reminders.contains { $0.id == id } }
        if !missing.isEmpty {
            reminders = (try? await ReminderStore.shared.refresh()) ?? reminders
        }
        return identifiers.compactMap { id in
            reminders.first { $0.id == id }.map(ReminderEntity.init)
        }
    }

    func allEntities() async throws -> [ReminderEntity] {
        let reminders = (try? await ReminderStore.shared.refresh())
            ?? await ReminderStore.shared.cached()
        return reminders.filter { !$0.isDone }.map(ReminderEntity.init)
    }

    func suggestedEntities() async throws -> [ReminderEntity] {
        let reminders = await ReminderStore.shared.cached()
        return reminders.filter { !$0.isDone }.map(ReminderEntity.init)
    }

    func entities(matching string: String) async throws -> [ReminderEntity] {
        let reminders = (try? await ReminderStore.shared.refresh())
            ?? await ReminderStore.shared.cached()
        return ReminderTitleMatcher.matches(reminders, query: string).map(ReminderEntity.init)
    }

    func reindexEntities(
        for identifiers: [ReminderEntity.ID],
        indexDescription: CSSearchableIndexDescription
    ) async throws {
        let reminders = (try? await ReminderStore.shared.refresh())
            ?? await ReminderStore.shared.cached()
        try await ReminderSpotlightIndex.index(
            reminders.filter { identifiers.contains($0.id) }
        )
    }

    func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {
        let reminders = (try? await ReminderStore.shared.refresh())
            ?? await ReminderStore.shared.cached()
        try await ReminderSpotlightIndex.replaceAll(reminders)
    }
}
