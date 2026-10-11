import SwiftUI
import UIKit
import XCTest
@testable import LazyMansReminders

@MainActor
final class ReminderListReorderingTests: XCTestCase {
    private typealias Board = ReorderableReminderList<Text>

    private func board(enabled: Bool = true, onMove: @escaping (IndexSet, Int) -> Void) -> Board {
        let userID = UUID()
        return Board(
            reminders: (0..<4).map {
                Reminder(id: UUID(), userID: userID, text: "Item \($0)", sortOrder: $0,
                         isDone: false, createdAt: .now)
            },
            completingIDs: [], isEnabled: enabled,
            onMove: onMove, onDragChanged: { _ in },
            onComplete: { _ in XCTFail("Reordering must not complete a reminder") },
            onRefresh: {}, row: { Text($0.text) }
        )
    }

    func testNativeMoveDownMatchesSwiftUIRemovalSemantics() {
        var moves: [(IndexSet, Int)] = []
        let parent = board { moves.append(($0, $1)) }
        let coordinator = parent.makeCoordinator()
        let list = collection(coordinator)
        coordinator.collectionView(list, moveItemAt: IndexPath(item: 0, section: 0),
                                   to: IndexPath(item: 3, section: 0))
        XCTAssertEqual(coordinator.items.map(\.id), [parent.reminders[1].id, parent.reminders[2].id,
                                                    parent.reminders[3].id, parent.reminders[0].id])
        XCTAssertEqual(moves.count, 1)
        XCTAssertEqual(moves.first?.0, IndexSet(integer: 0))
        XCTAssertEqual(moves.first?.1, 4)
    }

    func testNativeMoveUpMatchesSwiftUIRemovalSemantics() {
        var destination: Int?
        let parent = board { _, target in destination = target }
        let coordinator = parent.makeCoordinator()
        let list = collection(coordinator)
        coordinator.collectionView(list, moveItemAt: IndexPath(item: 3, section: 0),
                                   to: IndexPath(item: 0, section: 0))
        XCTAssertEqual(coordinator.items.first?.id, parent.reminders.last?.id)
        XCTAssertEqual(destination, 0)
    }

    func testUnchangedDropDoesNotSave() {
        let parent = board { _, _ in XCTFail("An unchanged drop must not save") }
        let coordinator = parent.makeCoordinator()
        let list = collection(coordinator)
        coordinator.collectionView(list, moveItemAt: IndexPath(item: 2, section: 0),
                                   to: IndexPath(item: 2, section: 0))
        XCTAssertEqual(coordinator.items, parent.reminders)
    }

    func testDisabledBoardCannotMoveByTouchOrAccessibility() {
        let parent = board(enabled: false) { _, _ in XCTFail("Saving board cannot reorder") }
        let coordinator = parent.makeCoordinator()
        let list = collection(coordinator)
        XCTAssertFalse(coordinator.collectionView(list, canMoveItemAt: IndexPath(item: 0, section: 0)))
        coordinator.moveAccessible(id: parent.reminders[1].id, direction: -1)
    }

    func testAccessibilityMovesRespectEdgesAndUseCurrentIdentity() {
        var moves: [(IndexSet, Int)] = []
        let parent = board { moves.append(($0, $1)) }
        let coordinator = parent.makeCoordinator()
        coordinator.moveAccessible(id: parent.reminders[0].id, direction: -1)
        coordinator.moveAccessible(id: parent.reminders[3].id, direction: 1)
        coordinator.moveAccessible(id: UUID(), direction: 1)
        XCTAssertTrue(moves.isEmpty)
        coordinator.moveAccessible(id: parent.reminders[1].id, direction: 1)
        XCTAssertEqual(moves.first?.0, IndexSet(integer: 1))
        XCTAssertEqual(moves.first?.1, 3)
    }

    func testOnlyTheDottedGripStartsDragging() throws {
        let parent = board { _, _ in }
        let coordinator = parent.makeCoordinator()
        let list = collection(coordinator)
        let frame = try XCTUnwrap(list.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))?.frame)
        let pan = PositionedPan()
        pan.point = CGPoint(x: frame.maxX - 22, y: frame.midY)
        XCTAssertTrue(coordinator.gestureRecognizerShouldBegin(pan))
        pan.point.x = frame.midX
        XCTAssertFalse(coordinator.gestureRecognizerShouldBegin(pan))
        // Hit testing uses the original touch even after the finger leaves the grip.
        pan.point.x = frame.maxX - 62
        pan.offset.x = -40
        XCTAssertTrue(coordinator.gestureRecognizerShouldBegin(pan))
        list.semanticContentAttribute = .forceRightToLeft
        pan.offset = .zero
        pan.point.x = frame.minX + 22
        XCTAssertTrue(coordinator.gestureRecognizerShouldBegin(pan))
        pan.point.x = frame.maxX - 22
        XCTAssertFalse(coordinator.gestureRecognizerShouldBegin(pan))
    }

    private func collection(_ coordinator: Board.Coordinator) -> UICollectionView {
        let list = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 600),
            collectionViewLayout: UICollectionViewCompositionalLayout.list(
                using: UICollectionLayoutListConfiguration(appearance: .insetGrouped)
            )
        )
        list.register(UICollectionViewListCell.self, forCellWithReuseIdentifier: "reminder")
        list.dataSource = coordinator
        coordinator.list = list
        list.reloadData()
        list.layoutIfNeeded()
        return list
    }
}

private final class PositionedPan: UIPanGestureRecognizer {
    var point = CGPoint.zero
    var offset = CGPoint.zero
    override func location(in view: UIView?) -> CGPoint { point }
    override func translation(in view: UIView?) -> CGPoint { offset }
}
