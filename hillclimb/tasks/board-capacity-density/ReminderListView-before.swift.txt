import AppIntents
import SwiftUI
import UIKit

struct ReminderListView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @State private var hapticTick = 0
    @State private var errorTick = 0
    @State private var reminders: [Reminder] = []
    @State private var draft = ReminderDraft()
    @State private var isLoading = true
    @State private var hasLoaded = false
    @State private var error: String?
    @State private var errorAnnouncementPolicy = BoardErrorAnnouncementPolicy()
    @State private var completingIDs: Set<UUID> = []
    @State private var isReordering = false
    @State private var boardRevision = 0
    @State private var isDragging = false
    @State private var hasDeferredBoardUpdate = false
    @State private var showAccount = false
    @State private var accountDetent: PresentationDetent = .large
    @AppStorage(BoardSetupTip.storageKey) private var setupTipDismissed = false
    @FocusState private var composerFocused: Bool
    @ScaledMetric(relativeTo: .body) private var addVisualSize: CGFloat = 28

#if DEBUG
    init(hillclimb mode: HillclimbDemo.Mode? = nil) {
        if let mode {
            _reminders = State(initialValue: HillclimbDemo.reminders(for: mode))
            _isLoading = State(initialValue: false)
            _hasLoaded = State(initialValue: true)
            _showAccount = State(initialValue: mode == .account)
            switch HillclimbDemo.argument("--hillclimb-board-state") {
            case "loading":
                _reminders = State(initialValue: [])
                _isLoading = State(initialValue: true)
                _hasLoaded = State(initialValue: false)
            case "error-empty", "error-populated":
                if HillclimbDemo.argument("--hillclimb-board-state") == "error-empty" {
                    _reminders = State(initialValue: [])
                }
                _error = State(initialValue: URLError(.notConnectedToInternet).localizedDescription)
            default: break
            }
        }
    }
#endif

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && !hasLoaded && reminders.isEmpty {
                    ProgressView {
                        Text("Loading reminders")
                            .foregroundStyle(Color.primary)
                            .modifier(HillclimbFrameProbe(key: "loadingLabel"))
                    }
                        .accessibilityIdentifier("board.loading")
                        .accessibilityLabel("Loading reminders")
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if reminders.isEmpty, let error {
                    failedBoard(error)
                } else if reminders.isEmpty {
                    emptyBoard
                } else {
                    reminderList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .navigationTitle("Your Board")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(BoardNavigationSubtitle(text: boardSubtitle))
            .safeAreaInset(edge: .bottom, spacing: 0) {
                composer
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if let error, !reminders.isEmpty {
                    BoardErrorBanner(message: error, isLoading: isLoading, onRetry: {
                        Task { await retryBoard() }
                    }, onDismiss: { self.error = nil })
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAccount = true
                    } label: {
                        Label("Account", systemImage: "person.crop.circle")
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Sign out, privacy, and delete account")
                }
            }
            .task(id: scenePhase == .active && auth.isSharedSessionReady) {
                guard scenePhase == .active else { return }
                await refresh()
            }
            .onAppear { announceBoardError(error) }
            .onChange(of: error) { _, message in announceBoardError(message) }
            .sensoryFeedback(.success, trigger: hapticTick)
            .sensoryFeedback(.error, trigger: errorTick)
            .onReceive(NotificationCenter.default.publisher(for: .didUpdateReminders)) { _ in
                hasDeferredBoardUpdate = true
                Task { await replayDeferredBoardUpdate() }
            }
            .task(id: isDragging || isReordering) {
                await replayDeferredBoardUpdate()
            }
            .onChange(of: showAccount) { _, presented in
                if !presented { accountDetent = .large }
            }
            .sheet(isPresented: $showAccount) {
                AccountView()
                    .environmentObject(auth)
                    .presentationDetents([.medium, .large], selection: $accountDetent)
                    .presentationDragIndicator(.visible)
                    .presentationContentInteraction(.scrolls)
            }
        }
    }

    private var boardSubtitle: String {
        "\(reminders.count) of \(ReminderBoardLimits.maxActive)"
    }

    private var prefersSolidChrome: Bool {
        reduceTransparency || colorSchemeContrast == .increased
    }

    private var emptyBoard: some View {
        ScrollView {
            VStack(spacing: 24) {
                ContentUnavailableView {
                    Label("All Clear", systemImage: "checkmark.circle")
                } description: {
                    Text("Nothing on your board. Add a reminder below.")
                        .foregroundStyle(.primary.opacity(0.75))
                }
                if !composerFocused && BoardSetupTip.shouldShow(
                    hasLoaded: hasLoaded,
                    isBoardEmpty: reminders.isEmpty,
                    hasError: error != nil,
                    isDismissed: setupTipDismissed
                ) {
                    BoardSetupTipCard {
                        withAnimation(reduceMotion ? nil : .default) {
                            setupTipDismissed = true
                        }
                    }
                    .foregroundStyle(.primary.opacity(0.75))
                    .padding(.horizontal, 20)
                    .transition(.opacity)
                }
                if !composerFocused { boardSiriTip }
            }
            .frame(maxWidth: .infinity, minHeight: 320)
        }
        .refreshable { await refresh() }
    }

    @ViewBuilder
    private var boardSiriTip: some View {
#if LMR_REMINDERS_SCHEMA
        if #available(iOS 27.0, *) {
            SiriTipView(intent: ListRemindersIntent())
                .padding(.horizontal, 20)
        }
#else
        SiriTipView(intent: ListRemindersIntent())
            .padding(.horizontal, 20)
#endif
    }

    private func failedBoard(_ message: String) -> some View {
        ScrollView {
            ContentUnavailableView {
                Label("Couldn’t Load Board", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
                    .foregroundStyle(Color.primary)
                    .modifier(HillclimbFrameProbe(key: "errorDescription"))
            } actions: {
                Button {
                    Task { await retryBoard() }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView()
                                .controlSize(.regular)
                        } else {
                            Text("Try Again")
                        }
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .disabled(isLoading)
                .accessibilityLabel(isLoading ? "Loading reminders" : "Try Again")
            }
            .frame(maxWidth: .infinity, minHeight: 320)
        }
        .refreshable { await refresh() }
    }

    private var reminderList: some View {
        ReorderableReminderList(
            reminders: reminders,
            completingIDs: completingIDs,
            isEnabled: !reorderDisabled,
            onMove: moveReminders,
            onDragChanged: { dragging in
                isDragging = dragging
                if dragging {
                    boardRevision += 1
                    composerFocused = false
                }
            },
            onComplete: { reminder in Task { await markDone(reminder) } },
            onRefresh: { await refresh() }
        ) { reminder in
            ReminderRow(
                reminder: reminder,
                isCompleting: completingIDs.contains(reminder.id)
            ) {
                Task { await markDone(reminder) }
            }
            .reminderOnscreenIdentity(reminder.id)
            .modifier(HillclimbRowProbe(id: reminder.id, text: reminder.text))
        }
        .modifier(BoardScrollEdge())
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if atCapacity {
                Text(ReminderBoardLimits.postItHint)
                    .modifier(HillclimbFrameProbe(key: "capacityHint"))
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)
                    .accessibilityAddTraits(.isStaticText)
            }

            HStack(alignment: .center, spacing: 8) {
                if atCapacity {
                    Text("Board full — combine lines instead")
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .modifier(HillclimbCapacityProbe())
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Board full — combine lines instead")
                        .accessibilityAddTraits(.isStaticText)
                        .accessibilityIdentifier("board.capacity")
                        .accessibilityHint("Board is full. Complete a reminder or combine lines.")
                } else {
                TextField(
                    "New reminder",
                    text: Binding(get: { draft.text }, set: { draft.edit($0) }),
                    axis: .vertical
                )
                .font(.body)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .onTapGesture {
                    if !atCapacity && !isReordering && !isDragging && !draft.isSubmitting {
                        composerFocused = true
                    }
                }
                .accessibilityElement(children: .combine)
                .tint(.primary)
                .lineLimit(1...4)
                .textInputAutocapitalization(.sentences)
                .focused($composerFocused)
                .disabled(atCapacity || isReordering || isDragging || draft.isSubmitting)
                .submitLabel(.return)
                .accessibilityLabel("New reminder")
                .accessibilityHint(
                    atCapacity
                        ? "Board is full. Complete a reminder or combine lines."
                        : "Adds a reminder to your board and Lock Screen"
                )
                .onSubmit { Task { await addReminder() } }

                }

                if composerFocused {
                    Button { composerFocused = false } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Done")
                    .accessibilityHint("Dismisses the keyboard")
                    .transition(.opacity)
                }

                if !atCapacity {
                    Button {
                        Task { await addReminder() }
                    } label: {
                        Group {
                            if draft.isSubmitting {
                                ProgressView()
                                    .controlSize(.small)
                                    .accessibilityHidden(true)
                            } else {
                                Image(systemName: "arrow.up")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(canAdd ? Color(.systemBackground) : Color(.tertiaryLabel))
                                    .accessibilityHidden(true)
                            }
                        }
                        .frame(width: addVisualSize, height: addVisualSize)
                        .background {
                            Circle()
                                .fill(canAdd ? Color.primary : Color(.quaternarySystemFill))
                        }
                        .frame(width: addHitSize, height: addHitSize)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canAdd)
                    .accessibilityLabel(draft.isSubmitting ? "Adding reminder" : "Add reminder")
                    .accessibilityHint("Saves the text as a new reminder")
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 5)
            .padding(.vertical, 7)
            .background {
                if !atCapacity { composerFieldBackground }
            }
            .accessibilityElement(children: .contain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(Color(.systemBackground).allowsHitTesting(false))
        .accessibilityElement(children: .contain)
        .modifier(HillclimbComposerProbe())
    }

    @ViewBuilder
    private var composerFieldBackground: some View {
        // Quiet, solid field with a hairline edge: reads the same in light
        // and dark and does not depend on what scrolls underneath it.
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        shape
            .fill(Color(.secondarySystemBackground))
            .overlay {
                shape.strokeBorder(
                    composerFocused ? Color(.tertiaryLabel) : Color(.separator),
                    lineWidth: colorSchemeContrast == .increased || prefersSolidChrome ? 1 : 0.5
                )
            }
            .shadow(color: .black.opacity(composerFocused ? 0.06 : 0), radius: 12, y: 4)
    }

    private var addHitSize: CGFloat {
        max(44, addVisualSize + 16)
    }

    private var atCapacity: Bool {
        ReminderBoardLimits.isAtCapacity(reminders.count)
    }

    private var canAdd: Bool {
        !atCapacity && !isReordering && !isDragging && draft.canSubmit
    }

    private var reorderDisabled: Bool {
        isReordering || isLoading || draft.isSubmitting
            || reminders.contains { completingIDs.contains($0.id) }
    }

    private func moveReminders(from offsets: IndexSet, to destination: Int) {
#if DEBUG
        if HillclimbDemo.isActive {
            guard HillclimbDemo.argument("--hillclimb-board-interaction") == "local", !reorderDisabled else { return }
            reminders.move(fromOffsets: offsets, toOffset: destination)
            HillclimbGeometry.shared.boardMoves += 1
            return
        }
#endif
        guard !reorderDisabled else { return }
        let previousIDs = reminders.map(\.id)
        reminders.move(fromOffsets: offsets, toOffset: destination)
        let ids = reminders.map(\.id)
        guard ids != previousIDs else { return }
        isReordering = true
        boardRevision += 1
        error = nil
        Task {
            defer { isReordering = false }
            do {
                reminders = try await ReminderStore.shared.reorder(ids: ids)
                await ReminderBoardSync.apply(reminders, notify: false)
                hapticTick += 1
                UIAccessibility.post(notification: .announcement, argument: "Reminder order saved")
            } catch {
                reminders = await ReminderStore.shared.refreshOrCached()
                await ReminderBoardSync.apply(reminders, notify: false)
                presentError(error.localizedDescription)
            }
        }
    }

    private func replayDeferredBoardUpdate() async {
#if DEBUG
        guard !HillclimbDemo.isActive else { return }
#endif
        while hasDeferredBoardUpdate && !isDragging && !isReordering {
            let revision = boardRevision
            let cached = await ReminderStore.shared.cached()
            // A new drag/save may have started while reading the actor's cache.
            guard !isDragging && !isReordering else { return }
            guard revision == boardRevision else { continue }
            reminders = cached
            hasDeferredBoardUpdate = false
        }
    }

    private func animateBoard(_ updates: () -> Void) {
        if reduceMotion {
            updates()
        } else {
            withAnimation(.easeInOut(duration: 0.2), updates)
        }
    }

    private func announceBoardError(_ message: String?) {
        if let announcement = errorAnnouncementPolicy.update(message) {
            UIAccessibility.post(notification: .announcement, argument: announcement)
#if DEBUG
            if HillclimbDemo.isActive {
                HillclimbGeometry.shared.boardErrorAnnouncements.append(announcement)
            }
#endif
        }
    }

    private func presentError(_ message: String) {
        error = message
        errorTick += 1
    }

    private func retryBoard() async {
        guard !isLoading else { return }
#if DEBUG
        if HillclimbDemo.isActive {
            guard HillclimbDemo.argument("--hillclimb-board-retry") == "recover" else { return }
            HillclimbGeometry.shared.boardRetryAttempts += 1
            isLoading = true
            defer { isLoading = false }
            await Task.yield()
            error = nil
            return
        }
#endif
        isLoading = true
        defer { isLoading = false }
        await refresh()
    }

    private func refresh() async {
#if DEBUG
        guard !HillclimbDemo.isActive else { return }
#endif
        guard auth.isSharedSessionReady else { return }
        guard !isReordering && !isDragging else { return }
        let revision = boardRevision
        if !hasLoaded {
            isLoading = true
        } else if reminders.isEmpty && error != nil {
            isLoading = true
        }
        defer { isLoading = false }
        do {
            let refreshed = try await ReminderBoardSync.refreshForeground()
            guard revision == boardRevision, !isReordering, !isDragging else { return }
            reminders = refreshed
            error = nil
        } catch {
            guard !Task.isCancelled else { return }
            guard revision == boardRevision, !isReordering, !isDragging else { return }
            reminders = await ReminderStore.shared.cached()
            presentError(error.localizedDescription)
        }
        isLoading = false
        hasLoaded = true
    }

    private func addReminder() async {
#if DEBUG
        guard !HillclimbDemo.isActive else { return }
#endif
        guard canAdd, let userID = auth.session?.user.id else { return }
        if atCapacity {
            presentError(ReminderBoardLimits.postItHint)
            return
        }
        guard let value = draft.beginSubmission() else { return }
        do {
            let updated = try await ReminderStore.shared.create(text: value, userID: userID)
            error = nil
            animateBoard { reminders = updated }
            await ReminderBoardSync.apply(reminders, notify: false)
            composerFocused = true
            hapticTick += 1
            UIAccessibility.post(
                notification: .announcement,
                argument: "Reminder added"
            )
            draft.finishSubmission(succeeded: true)
        } catch {
            draft.finishSubmission(succeeded: false)
            presentError(error.localizedDescription)
        }
    }

    private func markDone(_ reminder: Reminder) async {
#if DEBUG
        if HillclimbDemo.isActive {
            guard HillclimbDemo.argument("--hillclimb-board-interaction") == "local",
                  !isReordering, !isDragging, reminders.contains(where: { $0.id == reminder.id }) else { return }
            animateBoard { reminders.removeAll { $0.id == reminder.id } }
            HillclimbGeometry.shared.boardCompletions += 1
            hapticTick += 1
            UIAccessibility.post(notification: .announcement, argument: "Completed \(reminder.text)")
            return
        }
#endif
        guard !isReordering, !isDragging, !completingIDs.contains(reminder.id) else { return }
        completingIDs.insert(reminder.id)
        defer { completingIDs.remove(reminder.id) }
        do {
            let updated = try await ReminderStore.shared.markDone(id: reminder.id)
            error = nil
            animateBoard { reminders = updated }
            await ReminderBoardSync.apply(reminders, notify: false)
            hapticTick += 1
            UIAccessibility.post(
                notification: .announcement,
                argument: "Completed \(reminder.text)"
            )
        } catch {
            presentError(error.localizedDescription)
        }
    }
}

private struct BoardErrorBanner: View {
    let message: String
    let isLoading: Bool
    let onRetry: () -> Void
    let onDismiss: () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.primary)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true)
                Text("Couldn’t Load Board")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
            Text(message)
                .font(.footnote)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onRetry) {
                Text("Try Again")
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .disabled(isLoading)
        }
        .padding(.leading, 16)
        .padding(.trailing, 4)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if reduceTransparency || colorSchemeContrast == .increased {
                Color(.secondarySystemGroupedBackground)
            } else {
                Rectangle().fill(.regularMaterial)
            }
        }
        .overlay(alignment: .bottom) {
            Divider()
        }
        .accessibilityElement(children: .contain)

    }
}

private struct BoardScrollEdge: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectHidden(true, for: .bottom)
        } else {
            content
        }
    }
}

private struct ReminderRow: View {
    let reminder: Reminder
    let isCompleting: Bool
    let onComplete: () -> Void
    @ScaledMetric(relativeTo: .body) private var firstLineHeight: CGFloat = 20.3

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: onComplete) {
                Image(systemName: isCompleting ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.light))
                    .foregroundStyle(isCompleting ? Color.accentColor : Color(.secondaryLabel))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .modifier(HillclimbFrameProbe(key: "circle-" + reminder.id.uuidString))
            }
            .buttonStyle(.plain)
            .disabled(isCompleting)
            .accessibilityLabel(reminder.text)
            .accessibilityValue(isCompleting ? "Completing" : "Active")
            .accessibilityHint("Marks this reminder complete")
            .accessibilityAction(named: "Complete", onComplete)
            Text(reminder.text)
                .font(.body)
                .kerning(-0.1)
                .foregroundStyle(isCompleting ? .secondary : .primary)
                .strikethrough(isCompleting)
                .multilineTextAlignment(.leading)
                .modifier(HillclimbTextProbe(id: reminder.id, text: reminder.text))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, max(0, (44 - firstLineHeight) / 2))
                .accessibilityHidden(true)
        }
        .opacity(isCompleting ? 0.55 : 1)
    }
}

private struct BoardNavigationSubtitle: ViewModifier {
    let text: String

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.navigationSubtitle(text)
        } else {
            content
        }
    }
}

struct BoardErrorAnnouncementPolicy {
    private var visibleMessage: String?

    mutating func update(_ message: String?) -> String? {
        defer { visibleMessage = message }
        guard let message, message != visibleMessage else { return nil }
        return message
    }
}
