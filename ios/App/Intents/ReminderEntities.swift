import AppIntents
import CoreSpotlight
import UniformTypeIdentifiers

#if LMR_REMINDERS_SCHEMA
import GeoToolbox

/// Single board in this app. The reminders schema requires a list entity even
/// though Lazy Man's Reminders does not have multiple lists.
@available(iOS 27.0, *)
@AppEnum(schema: .reminders.listType)
enum ReminderListType: String {
    case standard

    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .standard: "Standard"
    ]
}

@available(iOS 27.0, *)
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

    init(id: UUID, name: String, type: ReminderListType) {
        self.id = id
        self.name = name
        self.type = type
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "Lazy Man's Reminders",
            image: .init(systemName: "checklist")
        )
    }
}

@available(iOS 27.0, *)
struct ReminderListEntityQuery: EntityQuery, EnumerableEntityQuery, EntityStringQuery {
    func entities(for identifiers: [ReminderListEntity.ID]) async throws -> [ReminderListEntity] {
        identifiers.contains(ReminderListEntity.boardID) ? [.board] : []
    }

    func allEntities() async throws -> [ReminderListEntity] {
        [.board]
    }

    func suggestedEntities() async throws -> [ReminderListEntity] {
        try await allEntities()
    }

    func entities(matching string: String) async throws -> [ReminderListEntity] {
        [.board]
    }
}

@available(iOS 27.0, *)
@AppEnum(schema: .reminders.locationTriggerEvent)
enum ReminderLocationTriggerEvent: String {
    case arrive
    case depart

    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .arrive: "Arrive",
        .depart: "Depart"
    ]
}

/// Schema requires a location-trigger type. This board has no geofences, so queries are empty.
@available(iOS 27.0, *)
@AppEntity(schema: .reminders.locationTrigger)
struct ReminderLocationTriggerEntity {
    static let defaultQuery = ReminderLocationTriggerEntityQuery()

    let id: UUID
    var place: PlaceDescriptor
    var event: ReminderLocationTriggerEvent

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "Place reminder")
    }
}

@available(iOS 27.0, *)
struct ReminderLocationTriggerEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [ReminderLocationTriggerEntity.ID]) async throws -> [ReminderLocationTriggerEntity] {
        []
    }

    func suggestedEntities() async throws -> [ReminderLocationTriggerEntity] {
        []
    }

    func entities(matching string: String) async throws -> [ReminderLocationTriggerEntity] {
        []
    }
}

/// Schema requires a section type. This board has no sections, so queries are empty.
@available(iOS 27.0, *)
@AppEntity(schema: .reminders.section)
struct ReminderSectionEntity {
    static let defaultQuery = ReminderSectionEntityQuery()

    let id: UUID
    var name: String
    var list: ReminderListEntity

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

@available(iOS 27.0, *)
struct ReminderSectionEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [ReminderSectionEntity.ID]) async throws -> [ReminderSectionEntity] {
        []
    }

    func suggestedEntities() async throws -> [ReminderSectionEntity] {
        []
    }

    func entities(matching string: String) async throws -> [ReminderSectionEntity] {
        []
    }
}

@available(iOS 27.0, *)
@AppEntity(schema: .reminders.reminder)
struct ReminderEntity: IndexedEntity {
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
    var section: ReminderSectionEntity?
    var locationTrigger: ReminderLocationTriggerEntity?

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

    init(_ reminder: Reminder) {
        self.id = reminder.id
        self.title = reminder.text
        self.note = nil
        self.tags = []
        self.urls = []
        self.dueDate = nil
        self.recurrence = nil
        self.isCompleted = reminder.isDone
        self.isFlagged = nil
        self.creationDate = reminder.createdAt
        self.completionDate = nil
        self.list = ReminderListEntity.board
        self.section = nil
        self.locationTrigger = nil
    }
}

@available(iOS 27.0, *)
struct ReminderEntityQuery: IndexedEntityQuery, EnumerableEntityQuery, EntityStringQuery {
    func entities(for identifiers: [ReminderEntity.ID]) async throws -> [ReminderEntity] {
        var reminders = await ReminderStore.shared.cached()
        let missing = identifiers.filter { id in !reminders.contains { $0.id == id } }
        if !missing.isEmpty {
            reminders = await ReminderStore.shared.refreshOrCached()
        }
        return identifiers.compactMap { id in
            reminders.first { $0.id == id }.map(ReminderEntity.init)
        }
    }

    func allEntities() async throws -> [ReminderEntity] {
        let reminders = await ReminderStore.shared.refreshOrCached()
        return reminders.filter { !$0.isDone }.map(ReminderEntity.init)
    }

    func suggestedEntities() async throws -> [ReminderEntity] {
        let reminders = await ReminderStore.shared.cached()
        return reminders.filter { !$0.isDone }.map(ReminderEntity.init)
    }

    func entities(matching string: String) async throws -> [ReminderEntity] {
        let reminders = await ReminderStore.shared.refreshOrCached()
        return ReminderTitleMatcher.matches(reminders, query: string).map(ReminderEntity.init)
    }

    func reindexEntities(
        for identifiers: [ReminderEntity.ID],
        indexDescription: CSSearchableIndexDescription
    ) async throws {
        let reminders = await ReminderStore.shared.refreshOrCached()
        try await ReminderSpotlightIndex.index(
            reminders.filter { identifiers.contains($0.id) }
        )
    }

    func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {
        let reminders = await ReminderStore.shared.refreshOrCached()
        try await ReminderSpotlightIndex.replaceAll(reminders)
    }
}

#else

struct ReminderEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Reminder"
    static var defaultQuery = ReminderEntityQuery()

    var id: UUID
    @Property(title: "Title")
    var title: String
    @Property(title: "Completed")
    var isCompleted: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: isCompleted ? "Completed" : "On your board",
            image: .init(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
        )
    }

    init(_ reminder: Reminder) {
        self.id = reminder.id
        self.title = reminder.text
        self.isCompleted = reminder.isDone
    }
}

struct ReminderEntityQuery: EntityQuery, EnumerableEntityQuery, EntityStringQuery {
    func entities(for identifiers: [ReminderEntity.ID]) async throws -> [ReminderEntity] {
        var reminders = await ReminderStore.shared.cached()
        let missing = identifiers.filter { id in !reminders.contains { $0.id == id } }
        if !missing.isEmpty {
            reminders = await ReminderStore.shared.refreshOrCached()
        }
        return identifiers.compactMap { id in
            reminders.first { $0.id == id }.map(ReminderEntity.init)
        }
    }

    func allEntities() async throws -> [ReminderEntity] {
        let reminders = await ReminderStore.shared.refreshOrCached()
        return reminders.filter { !$0.isDone }.map(ReminderEntity.init)
    }

    func suggestedEntities() async throws -> [ReminderEntity] {
        let reminders = await ReminderStore.shared.cached()
        return reminders.filter { !$0.isDone }.map(ReminderEntity.init)
    }

    func entities(matching string: String) async throws -> [ReminderEntity] {
        let reminders = await ReminderStore.shared.refreshOrCached()
        return ReminderTitleMatcher.matches(reminders, query: string).map(ReminderEntity.init)
    }
}

@available(iOS 18.0, *)
extension ReminderEntity: IndexedEntity {
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

@available(iOS 18.0, *)
extension ReminderEntityQuery: IndexedEntityQuery {
    func reindexEntities(
        for identifiers: [ReminderEntity.ID],
        indexDescription: CSSearchableIndexDescription
    ) async throws {
        let reminders = await ReminderStore.shared.refreshOrCached()
        try await ReminderSpotlightIndex.index(
            reminders.filter { identifiers.contains($0.id) }
        )
    }

    func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {
        let reminders = await ReminderStore.shared.refreshOrCached()
        try await ReminderSpotlightIndex.replaceAll(reminders)
    }
}

#endif
