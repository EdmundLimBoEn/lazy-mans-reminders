import SwiftUI
import UIKit

struct RoutineListView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model = RoutineListModel()
    @State private var showAccount = false
    @State private var editor: Editor?
    @State private var pendingDelete: Routine?

    private struct Editor: Identifiable {
        let id = UUID()
        let routine: Routine?
    }

    var body: some View {
        NavigationStack {
            List {
                if let error = model.error {
                    BoardErrorBanner(message: error) { model.error = nil }
                        .listRowInsets(EdgeInsets())
                }
                if model.isLoading && !model.hasLoaded && model.routines.isEmpty {
                    AccessibleProgressView("Loading routines…")
                } else if model.showsEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("No routines yet.").font(.headline)
                        Text("When due, the reminder returns to your board and sends a push to your registered iPhone. Completing it keeps the routine running.")
                            .foregroundStyle(.secondary)
                        addButton
                    }
                    .fixedSize(horizontal: false, vertical: true)
                } else if model.routines.isEmpty && model.loadFailed {
                    Button("Try Again") { Task { await refresh() } }
                        .frame(minHeight: 44)
                        .disabled(model.isLoading)
                }
                ForEach(model.routines) { routine in
                    row(routine)
                }
            }
            .listStyle(.insetGrouped)
            .tint(.primary)
            .navigationTitle("Routine reminders")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { addButton }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAccount = true } label: {
                        Label("Account", systemImage: "person.crop.circle")
                    }
                    .accessibilityHint("Sign out, privacy, and delete account")
                    .disabled(model.isBusy)
                }
            }
            .refreshable { await refresh() }
            .task(id: scenePhase == .active && auth.isSharedSessionReady) {
                guard scenePhase == .active, auth.isSharedSessionReady else { return }
                await refresh()
            }
            .sheet(isPresented: $showAccount) {
                AccountView()
                    .environmentObject(auth)
                    .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationContentInteraction(.scrolls)
            }
            .sheet(item: $editor) { editor in
                RoutineEditorView(routine: editor.routine) { draft in
                    guard let userID = auth.session?.user.id else { throw RoutineListError.signedOut }
                    try await model.save(draft, userID: userID)
                }
            }
            .alert("Delete routine?", isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ), presenting: pendingDelete) { routine in
                // Neutral styling matches the rest of this screen; the explicit alert confirms intent.
                Button("Delete routine") { change(routine, delete: true) }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("Future reminders will stop. The current board reminder stays.")
            }
            .onChange(of: model.error) { _, message in
                if let message { UIAccessibility.post(notification: .announcement, argument: message) }
            }
        }
    }

    private var addButton: some View {
        Button { editor = Editor(routine: nil) } label: {
            Label("Add routine", systemImage: "plus")
                .frame(minHeight: 44)
        }
        .disabled(model.isBusy || !auth.isSharedSessionReady)
    }

    private func row(_ routine: Routine) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Text(routine.text).font(.headline)
                Text(RoutineSchedule.summary(routine)).font(.subheadline).foregroundStyle(.secondary)
                Text(RoutineSchedule.status(routine)).font(.subheadline)
            }
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(routine.text). \(RoutineSchedule.summary(routine)). \(RoutineSchedule.status(routine))")
            .accessibilityAction(named: "Edit") { edit(routine) }
            .accessibilityAction(named: Text(routine.enabled ? "Pause" : "Resume")) { change(routine) }
            .accessibilityAction(named: "Delete routine") { confirmDelete(routine) }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 20) { actions(routine) }
                VStack(alignment: .leading, spacing: 4) { actions(routine) }
            }
            .buttonStyle(.borderless)
            .disabled(model.isBusy)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func actions(_ routine: Routine) -> some View {
        Button("Edit") { edit(routine) }.frame(minWidth: 44, minHeight: 44)
        Button(routine.enabled ? "Pause" : "Resume") { change(routine) }.frame(minWidth: 44, minHeight: 44)
        Button("Delete routine") { confirmDelete(routine) }.frame(minWidth: 44, minHeight: 44)
    }

    private func edit(_ routine: Routine) {
        guard !model.isBusy else { return }
        editor = Editor(routine: routine)
    }

    private func confirmDelete(_ routine: Routine) {
        guard !model.isBusy else { return }
        pendingDelete = routine
    }

    private func change(_ routine: Routine, delete: Bool = false) {
        guard !model.isBusy, let userID = auth.session?.user.id else { return }
        Task { await model.change(routine, delete: delete, userID: userID) }
    }

    private func refresh() async {
        guard auth.isSharedSessionReady, let userID = auth.session?.user.id else { return }
        await model.refresh(userID: userID)
    }
}

private enum RoutineListError: LocalizedError {
    case signedOut
    var errorDescription: String? { "Sign in to Notepad on this iPhone first." }
}
