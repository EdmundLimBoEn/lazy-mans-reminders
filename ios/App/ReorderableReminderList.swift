import SwiftUI
import UIKit

struct ReorderableReminderList<Row: View>: UIViewRepresentable {
    let reminders: [Reminder]
    let completingIDs: Set<UUID>
    let isEnabled: Bool
    let onMove: (IndexSet, Int) -> Void
    let onDragChanged: (Bool) -> Void
    let onComplete: (Reminder) -> Void
    let onRefresh: () async -> Void
    @ViewBuilder let row: (Reminder) -> Row

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UICollectionView {
        let coordinator = context.coordinator
        var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        configuration.leadingSwipeActionsConfigurationProvider = { [weak coordinator] indexPath in
            guard let coordinator, coordinator.parent.isEnabled, !coordinator.isDragging,
                  coordinator.items.indices.contains(indexPath.item) else { return nil }
            let reminder = coordinator.items[indexPath.item]
            let action = UIContextualAction(style: .normal, title: "Complete") { _, _, finish in
                coordinator.parent.onComplete(reminder)
                finish(true)
            }
            action.image = UIImage(systemName: "checkmark.circle")
            action.backgroundColor = .systemBlue
            return UISwipeActionsConfiguration(actions: [action])
        }
        let list = UICollectionView(
            frame: .zero,
            collectionViewLayout: UICollectionViewCompositionalLayout.list(using: configuration)
        )
        list.backgroundColor = .systemGroupedBackground
        list.alwaysBounceVertical = true
        list.keyboardDismissMode = .interactive
        list.dataSource = coordinator
        list.register(UICollectionViewListCell.self, forCellWithReuseIdentifier: "reminder")
        let drag = UIPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.drag(_:)))
        drag.maximumNumberOfTouches = 1
        drag.delegate = coordinator
        list.addGestureRecognizer(drag)
        list.panGestureRecognizer.require(toFail: drag)
        coordinator.dragGesture = drag
        coordinator.list = list
        let refresh = UIRefreshControl()
        refresh.addTarget(coordinator, action: #selector(Coordinator.refresh), for: .valueChanged)
        list.refreshControl = refresh
        return list
    }

    func updateUIView(_ list: UICollectionView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        // A reload during interactive movement invalidates UIKit's source index.
        guard !coordinator.isDragging else { return }
        if coordinator.items != reminders || coordinator.renderedCompletingIDs != completingIDs
            || coordinator.renderedEnabled != isEnabled {
            coordinator.items = reminders
            coordinator.renderedCompletingIDs = completingIDs
            coordinator.renderedEnabled = isEnabled
            list.reloadData()
        }
    }

    final class Coordinator: NSObject, UICollectionViewDataSource, UIGestureRecognizerDelegate {
        var parent: ReorderableReminderList
        var items: [Reminder]
        var renderedCompletingIDs: Set<UUID>
        var renderedEnabled: Bool
        weak var list: UICollectionView?
        weak var dragGesture: UIPanGestureRecognizer?
        private(set) var isDragging = false
        private var dragOffset = CGPoint.zero

        init(parent: ReorderableReminderList) {
            self.parent = parent
            items = parent.reminders
            renderedCompletingIDs = parent.completingIDs
            renderedEnabled = parent.isEnabled
        }

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            items.count
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "reminder", for: indexPath)
            let reminder = items[indexPath.item]
            cell.contentConfiguration = UIHostingConfiguration {
                HStack(spacing: 0) {
                    parent.row(reminder)
                    ReminderDragGrip(isEnabled: parent.isEnabled && items.count > 1)
                        .accessibilityLabel("Reorder \(reminder.text)")
                        .accessibilityValue("Position \(indexPath.item + 1) of \(items.count)")
                        .accessibilityAction(named: "Move up") { [weak self] in
                            self?.moveAccessible(id: reminder.id, direction: -1)
                        }
                        .accessibilityAction(named: "Move down") { [weak self] in
                            self?.moveAccessible(id: reminder.id, direction: 1)
                        }
                }
                .padding(.leading, 8)
                .padding(.vertical, 8)
            }
            .margins(.all, 0)
            return cell
        }

        func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
            parent.isEnabled && items.count > 1 && items.indices.contains(indexPath.item)
        }

        func collectionView(_ collectionView: UICollectionView, moveItemAt source: IndexPath, to destination: IndexPath) {
            guard source.item != destination.item,
                  items.indices.contains(source.item), items.indices.contains(destination.item) else { return }
            let moved = items.remove(at: source.item)
            items.insert(moved, at: destination.item)
            // SwiftUI's move destination is before removal; UIKit's is after it.
            parent.onMove(IndexSet(integer: source.item), destination.item > source.item ? destination.item + 1 : destination.item)
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let list, let pan = gestureRecognizer as? UIPanGestureRecognizer,
                  parent.isEnabled, !isDragging else { return false }
            let point = pan.location(in: list)
            let translation = pan.translation(in: list)
            let start = CGPoint(x: point.x - translation.x, y: point.y - translation.y)
            guard let indexPath = list.indexPathForItem(at: start),
                  collectionView(list, canMoveItemAt: indexPath),
                  let frame = list.layoutAttributesForItem(at: indexPath)?.frame else { return false }
            if list.effectiveUserInterfaceLayoutDirection == .rightToLeft {
                return start.x <= frame.minX + 44
            }
            return start.x >= frame.maxX - 44
        }

        @objc func drag(_ gesture: UIPanGestureRecognizer) {
            guard let list else { return }
            let point = gesture.location(in: list)
            switch gesture.state {
            case .began:
                let translation = gesture.translation(in: list)
                let start = CGPoint(x: point.x - translation.x, y: point.y - translation.y)
                guard let indexPath = list.indexPathForItem(at: start),
                      let center = list.layoutAttributesForItem(at: indexPath)?.center,
                      list.beginInteractiveMovementForItem(at: indexPath) else { return }
                dragOffset = CGPoint(x: center.x - point.x, y: center.y - point.y)
                isDragging = true
                parent.onDragChanged(true)
                UISelectionFeedbackGenerator().selectionChanged()
            case .changed:
                guard isDragging else { return }
                list.updateInteractiveMovementTargetPosition(
                    CGPoint(x: point.x + dragOffset.x, y: point.y + dragOffset.y)
                )
            case .ended:
                guard isDragging else { return }
                list.endInteractiveMovement()
                finishDrag()
            case .cancelled, .failed:
                guard isDragging else { return }
                list.cancelInteractiveMovement()
                finishDrag()
            default:
                break
            }
        }

        private func finishDrag() {
            isDragging = false
            parent.onDragChanged(false)
        }

        func moveAccessible(id: UUID, direction: Int) {
            guard parent.isEnabled, !isDragging,
                  let source = items.firstIndex(where: { $0.id == id }),
                  items.indices.contains(source + direction) else { return }
            parent.onMove(IndexSet(integer: source), direction > 0 ? source + 2 : source - 1)
        }

        @objc func refresh() {
            Task { @MainActor in
                await parent.onRefresh()
                list?.refreshControl?.endRefreshing()
            }
        }
    }
}

private struct ReminderDragGrip: View {
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: 3) {
            dots
            dots
        }
        .foregroundStyle(.secondary)
        .opacity(isEnabled ? 1 : 0.3)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityHint("Drag to change position, or use the Move up and Move down actions")
    }

    private var dots: some View {
        VStack(spacing: 3) {
            ForEach(0..<3) { _ in Circle().frame(width: 3, height: 3) }
        }
    }
}
