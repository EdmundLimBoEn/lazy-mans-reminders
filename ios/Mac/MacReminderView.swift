import AppKit
import SwiftUI

struct MacReminderView: View {
    @ObservedObject var model: MacReminderModel
    @State private var draft = ""
    @State private var email = ""
    @State private var code = ""
    @State private var password = ""
    @State private var usesPassword = false

    private var canAdd: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && draft.unicodeScalars.count <= 500
            && !ReminderBoardLimits.isAtCapacity(model.reminders.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Notepad").font(.headline)
                Spacer()
                if model.isBusy { ProgressView().controlSize(.small) }
                Button {
                    Task { await model.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Try Again")
                .keyboardShortcut("r")
                .disabled(model.isBusy || model.isDemo)
            }

            if !model.hasLoaded {
                ProgressView("Loading reminders")
            } else if model.isSignedIn {
                board
            } else {
                signIn
            }

            if let error = model.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()
            HStack {
                if model.isSignedIn && !model.isDemo {
                    Button("Sign Out") { Task { await model.signOut() } }
                        .disabled(model.isBusy)
                }
                Spacer()
                // No existing iOS quit label; Edmund supplies this copy.
                Button("[PLACEHOLDER - Edmund to write]") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .font(.caption)
        }
        .padding(16)
        .frame(width: 380)
        .tint(.blue)
        .task {
            await model.refresh()
            guard !model.isDemo else { return }
            // Refresh on presentation and periodically while the view task lives.
            // Realtime subscription/reconnect behavior is a separate release task.
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
                if model.isSignedIn { await model.refresh() }
            }
        }
        .onChange(of: model.isSignedIn) { _, _ in
            draft = ""
            password = ""
            code = ""
        }
        .onDisappear { password = ""; code = "" }
    }

    private var board: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.reminders.isEmpty {
                Label("All Clear", systemImage: "checkmark.circle")
                Text("Nothing on your board. Add a reminder below.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(model.reminders) { reminder in
                            Button {
                                Task { await model.complete(reminder) }
                            } label: {
                                Label(reminder.text, systemImage: "circle")
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 6)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Marks this reminder complete")
                            .disabled(model.isBusy)
                        }
                    }
                }
                .frame(height: 260)
            }
            HStack {
                TextField("New reminder", text: $draft)
                    .onSubmit(addReminder)
                    .disabled(model.isBusy)
                Button(action: addReminder) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add reminder")
                .disabled(model.isBusy || !canAdd)
            }
            if ReminderBoardLimits.isAtCapacity(model.reminders.count) {
                Text(ReminderBoardLimits.postItHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if draft.unicodeScalars.count > 500 {
                Text("Keep each reminder to 500 characters.").font(.footnote)
            }
        }
    }

    private var signIn: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sign In").font(.headline)
            if model.codeEmail != nil {
                Text("Check Your Inbox")
                TextField("[PLACEHOLDER - Edmund to write]", text: $code)
                    .onSubmit { Task { await model.verifyCode(code) } }
                Button("Sign In") { Task { await model.verifyCode(code) } }
                    .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Use a Different Email") {
                    code = ""
                    model.useDifferentEmail()
                }
            } else {
                TextField("you@example.com", text: $email)
                    .accessibilityLabel("Email address")
                    .autocorrectionDisabled()
                if usesPassword {
                    SecureField("Password", text: $password)
                        .onSubmit(signInWithPassword)
                    Button("Sign In with Password", action: signInWithPassword)
                        .disabled(email.isEmpty || password.isEmpty)
                } else {
                    Button("[PLACEHOLDER - Edmund to write]") {
                        Task { await model.sendCode(email: email) }
                    }
                    .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Button(usesPassword ? "[PLACEHOLDER - Edmund to write]" : "Use an Existing Password") {
                    password = ""
                    usesPassword.toggle()
                }
            }
        }
        .textFieldStyle(.roundedBorder)
        .disabled(model.isBusy)
    }

    private func addReminder() {
        guard canAdd, !model.isBusy else { return }
        let submitted = draft
        Task {
            if await model.add(submitted), draft == submitted { draft = "" }
        }
    }

    private func signInWithPassword() {
        guard !model.isBusy, !email.isEmpty, !password.isEmpty else { return }
        let submitted = password
        password = ""
        Task { await model.signIn(email: email, password: submitted) }
    }
}
