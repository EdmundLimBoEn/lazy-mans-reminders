import AppIntents
import SwiftUI
import UIKit

struct ReminderListView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
    @State private var completingIDs: Set<UUID> = []
    @State private var isReordering = false
    @State private var boardRevision = 0
    @State private var isDragging = false
    @State private var hasDeferredBoardUpdate = false
    @State private var showAccount = false
    @AppStorage(BoardSetupTip.storageKey) private var setupTipDismissed = false
    @FocusState private var composerFocused: Bool
    @ScaledMetric(relativeTo: .body) private var addVisualSize: CGFloat = 28

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && !hasLoaded && reminders.isEmpty {
                    AccessibleProgressView("Loading reminders")
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
            .navigationBarTitleDisplayMode(.large)
            .modifier(BoardNavigationSubtitle(text: boardSubtitle))
            .safeAreaInset(edge: .bottom, spacing: 0) {
                composer
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if let error, !reminders.isEmpty {
                    BoardErrorBanner(message: error) {
                        self.error = nil
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAccount = true
                    } label: {
                        Label("Account", systemImage: "person.crop.circle")
                    }
                    .accessibilityHint("Sign out, privacy, and delete account")
                }
            }
            .refreshable { await refresh() }
            .task(id: scenePhase == .active && auth.isSharedSessionReady) {
                guard scenePhase == .active else { return }
                await refresh()
            }
            .sensoryFeedback(.success, trigger: hapticTick)
            .sensoryFeedback(.error, trigger: errorTick)
            .onReceive(NotificationCenter.default.publisher(for: .didUpdateReminders)) { _ in
                hasDeferredBoardUpdate = true
                Task { await replayDeferredBoardUpdate() }
            }
            .task(id: isDragging || isReordering) {
                await replayDeferredBoardUpdate()
            }
            .sheet(isPresented: $showAccount) {
                AccountView()
                    .environmentObject(auth)
                    .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationContentInteraction(.scrolls)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var boardSubtitle: String {
        "\(reminders.count) of \(ReminderBoardLimits.maxActive)"
    }

    private var prefersSolidChrome: Bool {
        ReminderAccessibility.usesSolidBackground(
            reduceTransparency: reduceTransparency, increasedContrast: colorSchemeContrast == .increased
        )
    }

    private var emptyBoard: some View {
        ScrollView {
            VStack(spacing: 24) {
                ContentUnavailableView {
                    Label("All Clear", systemImage: "checkmark.circle")
                } description: {
                    Text("Nothing on your board. Add a reminder below.")
                }
                if BoardSetupTip.shouldShow(
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
                    .padding(.horizontal, 20)
                    .transition(.opacity)
                }
                boardSiriTip
            }
            .frame(maxWidth: .infinity, minHeight: 320)
        }
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
            } actions: {
                Button {
                    Task { await refresh() }
                } label: {
                    if isLoading {
                        AccessibleProgressView()
                            .controlSize(.regular)
                    } else {
                        Text("Try Again")
                    }
                }
                .disabled(isLoading)
                .accessibilityLabel("Try Again")
                .accessibilityValue(ReminderAccessibility.progressValue(isBusy: isLoading))
            }
            .frame(maxWidth: .infinity, minHeight: 320)
        }
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
            onSnooze: { reminder, option in Task { await snooze(reminder, option: option) } },
            onRefresh: { await refresh() }
        ) { reminder in
            ReminderRow(
                reminder: reminder,
                isCompleting: completingIDs.contains(reminder.id)
            ) {
                Task { await markDone(reminder) }
            }
            .reminderOnscreenIdentity(reminder.id)
        }
        .modifier(BoardScrollEdge())
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if atCapacity {
                Text(ReminderBoardLimits.postItHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)
                    .accessibilityAddTraits(.isStaticText)
            }

            HStack(alignment: .center, spacing: 8) {
                TextField(
                    atCapacity ? "Board full — combine lines instead" : "New reminder",
                    text: Binding(get: { draft.text }, set: { draft.edit($0) }),
                    axis: .vertical
                )
                .font(.body)
                .tint(.primary)
                .lineLimit(1...(dynamicTypeSize.isAccessibilitySize ? 2 : 4))
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

                if ComposerKeyboardDismiss.isVisible(focused: composerFocused) {
                    Button { composerFocused = false } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Done")
                    .accessibilityHint("Dismisses the keyboard")
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .transition(.opacity)
                }

                Button {
                    Task { await addReminder() }
                } label: {
                    Group {
                        if draft.isSubmitting {
                            AccessibleProgressView()
                                .controlSize(.small)
                                .accessibilityHidden(true)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(canAdd ? Color(.systemBackground) : Color(.tertiaryLabel))
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(width: min(44, addVisualSize), height: min(44, addVisualSize))
                    .background {
                        Circle()
                            .fill(canAdd ? Color.primary : Color(.quaternarySystemFill))
                    }
                    .frame(width: addHitSize, height: addHitSize)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canAdd)
                .accessibilityLabel("Add reminder")
                .accessibilityValue(ReminderAccessibility.progressValue(isBusy: draft.isSubmitting))
                .accessibilityHint("Saves the text as a new reminder")
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
            .padding(.leading, 14)
            .padding(.trailing, 5)
            .padding(.vertical, 7)
            .background {
                composerFieldBackground
            }
            .accessibilityElement(children: .contain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(alignment: .top) {
            LinearGradient(
                colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 36)
            .offset(y: -36)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .background(Color(.systemBackground).allowsHitTesting(false))
        .accessibilityElement(children: .contain)
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
                    colorSchemeContrast == .increased ? Color.primary
                        : (composerFocused ? Color(.tertiaryLabel) : Color(.separator)),
                    lineWidth: colorSchemeContrast == .increased || prefersSolidChrome ? 1 : 0.5
                )
            }
            .shadow(color: .black.opacity(composerFocused ? 0.06 : 0), radius: 12, y: 4)
    }

    private var addHitSize: CGFloat {
        max(44, min(44, addVisualSize) + 16)
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
        if !ReminderAccessibility.allowsAnimation(reduceMotion: reduceMotion) {
            updates()
        } else {
            withAnimation(.easeInOut(duration: 0.2), updates)
        }
    }

    private func presentError(_ message: String) {
        let isNewError = error != message
        error = message
        errorTick += 1
        if isNewError {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    private func refresh() async {
        guard auth.isSharedSessionReady else { return }
        guard !isReordering && !isDragging else { return }
        let revision = boardRevision
        if !hasLoaded {
            isLoading = true
        } else if reminders.isEmpty && error != nil {
            isLoading = true
        }
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

    private func snooze(_ reminder: Reminder, option: ReminderSnooze) async {
        guard !isReordering, !isDragging, !completingIDs.contains(reminder.id) else { return }
        completingIDs.insert(reminder.id)
        defer { completingIDs.remove(reminder.id) }
        do {
            let updated = try await ReminderStore.shared.snooze(id: reminder.id, until: option.until())
            error = nil
            animateBoard { reminders = updated }
            await ReminderBoardSync.apply(reminders, notify: false)
            hapticTick += 1
            UIAccessibility.post(notification: .announcement, argument: "Snoozed \(reminder.text)")
        } catch {
            presentError(error.localizedDescription)
        }
    }

    private func markDone(_ reminder: Reminder) async {
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
    let onDismiss: () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.primary)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss error")
        }
        .padding(.leading, 16)
        .padding(.trailing, 4)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if ReminderAccessibility.usesSolidBackground(
                reduceTransparency: reduceTransparency, increasedContrast: colorSchemeContrast == .increased
            ) {
                Color(.secondarySystemGroupedBackground)
            } else {
                Rectangle().fill(.regularMaterial)
            }
        }
        .overlay(alignment: .bottom) {
            Divider()
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

private struct BoardScrollEdge: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectStyle(.soft, for: .bottom)
        } else {
            content
        }
    }
}

private struct ReminderRow: View {
    @Environment(\.colorSchemeContrast) private var contrast
    let reminder: Reminder
    let isCompleting: Bool
    let onComplete: () -> Void

    var body: some View {
        Button(action: onComplete) {
            Label {
                Text(reminder.text)
                    .font(.body)
                    .kerning(-0.1)
                    .foregroundStyle(isCompleting ? .secondary : .primary)
                    .strikethrough(isCompleting)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } icon: {
                Image(systemName: ReminderAccessibility.completionSymbol(isCompleting: isCompleting))
                    .font(.title3.weight(contrast == .increased ? .semibold : .light))
                    .foregroundStyle(contrast == .increased ? Color.primary
                        : (isCompleting ? Color.accentColor : Color(.tertiaryLabel)))
                    .frame(minWidth: 44, minHeight: 44, alignment: .center)
                    .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .disabled(isCompleting)
        .opacity(isCompleting && contrast != .increased ? 0.55 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reminder.text)
        .accessibilityInputLabels([reminder.text])
        .accessibilityValue(ReminderAccessibility.completionValue(isCompleting: isCompleting))
        .accessibilityHint("Marks this reminder complete")
        .accessibilityAddTraits(.isButton)
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
