import SwiftUI
import UIKit

struct ReminderListView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @State private var hapticTick = 0
    @State private var errorTick = 0
    @State private var reminders: [Reminder] = []
    @State private var draft = ""
    @State private var isLoading = true
    @State private var hasLoaded = false
    @State private var isAdding = false
    @State private var error: String?
    @State private var completingIDs: Set<UUID> = []
    @State private var showAccount = false
    @FocusState private var composerFocused: Bool
    @ScaledMetric(relativeTo: .body) private var addVisualSize: CGFloat = 28

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && !hasLoaded && reminders.isEmpty {
                    ProgressView("Loading reminders")
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
            .background(Color(.systemGroupedBackground))
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
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { composerFocused = false }
                }
            }
            .refreshable { await refresh() }
            .task { await refresh() }
            .sensoryFeedback(.success, trigger: hapticTick)
            .sensoryFeedback(.error, trigger: errorTick)
            .onReceive(NotificationCenter.default.publisher(for: .didUpdateReminders)) { _ in
                Task { reminders = await ReminderStore.shared.cached() }
            }
            .sheet(isPresented: $showAccount) {
                AccountView()
                    .environmentObject(auth)
                    .presentationDetents([.medium, .large])
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
            ContentUnavailableView {
                Label("All Clear", systemImage: "checkmark.circle")
            } description: {
                Text("Nothing on your board. Add a reminder below.")
            }
            .frame(maxWidth: .infinity, minHeight: 320)
        }
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
                        ProgressView()
                            .controlSize(.regular)
                    } else {
                        Text("Try Again")
                    }
                }
                .disabled(isLoading)
                .accessibilityLabel("Try Again")
            }
            .frame(maxWidth: .infinity, minHeight: 320)
        }
    }

    private var reminderList: some View {
        List {
            ForEach(reminders) { reminder in
                ReminderRow(
                    reminder: reminder,
                    isCompleting: completingIDs.contains(reminder.id)
                ) {
                    Task { await markDone(reminder) }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button("Complete", systemImage: "checkmark.circle") {
                        Task { await markDone(reminder) }
                    }
                    .tint(.accentColor)
                    .disabled(completingIDs.contains(reminder.id))
                    .accessibilityHint("Marks this reminder complete")
                }
                .reminderOnscreenIdentity(reminder.id)
            }
        }
        .listStyle(.insetGrouped)
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
                    text: $draft,
                    axis: .vertical
                )
                .font(.body)
                .lineLimit(1...4)
                .textInputAutocapitalization(.sentences)
                .focused($composerFocused)
                .disabled(atCapacity)
                .submitLabel(.send)
                .accessibilityLabel("New reminder")
                .accessibilityHint(
                    atCapacity
                        ? "Board is full. Complete a reminder or combine lines."
                        : "Adds a reminder to your board and Lock Screen"
                )
                .onSubmit { Task { await addReminder() } }

                Button {
                    Task { await addReminder() }
                } label: {
                    Group {
                        if isAdding {
                            ProgressView()
                                .controlSize(.small)
                                .accessibilityHidden(true)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.body.weight(.bold))
                                .foregroundStyle(canAdd ? Color.white : Color.secondary)
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(width: addVisualSize, height: addVisualSize)
                    .background {
                        Circle()
                            .fill(canAdd ? Color.accentColor : Color(.tertiarySystemFill))
                    }
                    .frame(width: addHitSize, height: addHitSize)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canAdd)
                .accessibilityLabel(isAdding ? "Adding reminder" : "Add reminder")
                .accessibilityHint("Saves the text as a new reminder")
            }
            .padding(.leading, 14)
            .padding(.trailing, 5)
            .padding(.vertical, 5)
            .background {
                composerFieldBackground
            }
            .accessibilityElement(children: .contain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var composerFieldBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        if prefersSolidChrome {
            shape
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay {
                    shape.strokeBorder(Color(.separator), lineWidth: colorSchemeContrast == .increased ? 1 : 0.5)
                }
        } else if #available(iOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(.regular.interactive(), in: shape)
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay {
                    shape.strokeBorder(Color(.separator), lineWidth: 0.5)
                }
        }
    }

    private var addHitSize: CGFloat {
        max(44, addVisualSize + 16)
    }

    private var atCapacity: Bool {
        ReminderBoardLimits.isAtCapacity(reminders.count)
    }

    private var canAdd: Bool {
        !isAdding
            && !atCapacity
            && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func animateBoard(_ updates: () -> Void) {
        if reduceMotion {
            updates()
        } else {
            withAnimation(.easeInOut(duration: 0.2), updates)
        }
    }

    private func presentError(_ message: String) {
        error = message
        errorTick += 1
    }

    private func refresh() async {
        if !hasLoaded {
            isLoading = true
        } else if reminders.isEmpty && error != nil {
            isLoading = true
        }
        do {
            reminders = try await ReminderStore.shared.refresh()
            error = nil
            await ReminderBoardSync.apply(reminders, notify: false)
        } catch {
            reminders = await ReminderStore.shared.cached()
            presentError(error.localizedDescription)
            await ReminderBoardSync.apply(reminders, notify: false)
        }
        isLoading = false
        hasLoaded = true
    }

    private func addReminder() async {
        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canAdd, let userID = auth.session?.user.id else { return }
        if atCapacity {
            presentError(ReminderBoardLimits.postItHint)
            return
        }
        isAdding = true
        draft = ""
        do {
            let updated = try await ReminderStore.shared.create(text: value, userID: userID)
            animateBoard { reminders = updated }
            await ReminderBoardSync.apply(reminders, notify: false)
            composerFocused = true
            hapticTick += 1
            UIAccessibility.post(
                notification: .announcement,
                argument: "Reminder added"
            )
        } catch {
            draft = value
            presentError(error.localizedDescription)
        }
        isAdding = false
    }

    private func markDone(_ reminder: Reminder) async {
        guard !completingIDs.contains(reminder.id) else { return }
        completingIDs.insert(reminder.id)
        do {
            let updated = try await ReminderStore.shared.markDone(id: reminder.id)
            animateBoard { reminders = updated }
            await ReminderBoardSync.apply(reminders, notify: false)
            hapticTick += 1
            UIAccessibility.post(
                notification: .announcement,
                argument: "Completed \(reminder.text)"
            )
        } catch {
            completingIDs.remove(reminder.id)
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
                .foregroundStyle(.red)
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
            .accessibilityLabel("Dismiss")
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
    let reminder: Reminder
    let isCompleting: Bool
    let onComplete: () -> Void

    var body: some View {
        Button(action: onComplete) {
            Label {
                Text(reminder.text)
                    .font(.body)
                    .foregroundStyle(isCompleting ? .secondary : .primary)
                    .strikethrough(isCompleting)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } icon: {
                Image(systemName: isCompleting ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isCompleting ? Color.accentColor : .secondary)
                    .imageScale(.large)
                    .frame(minWidth: 44, minHeight: 44, alignment: .center)
                    .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .disabled(isCompleting)
        .opacity(isCompleting ? 0.55 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reminder.text)
        .accessibilityValue(isCompleting ? "Completing" : "Active")
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
