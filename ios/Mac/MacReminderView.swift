import AppKit
import AuthenticationServices
import SwiftUI

struct MacReminderView: View {
    @ObservedObject var model: MacReminderModel
    @State private var draft = ""
    @State private var email = ""
    @State private var code = ""
    @State private var password = ""
    @State private var usesPassword = false
    @State private var isPopoverVisible = false
    @FocusState private var addFieldFocused: Bool
    @ScaledMetric(relativeTo: .body) private var appleButtonHeight: CGFloat = 36
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let webBoardURL = URL(string: "https://app.notepads.dev")!
    private let webAccountURL = URL(string: "https://app.notepads.dev/#account-heading")!

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Notepad").font(.headline)
                Spacer()
                if model.isBusy && !reduceMotion { ProgressView().controlSize(.small) }
                Button {
                    Task { await model.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh reminders")
                .accessibilityHint("Checks for changes on your board")
                .keyboardShortcut("r")
                .disabled(model.isBusy || model.isDemo)
            }

            if !model.hasLoaded {
                Text("Loading reminders").foregroundStyle(.secondary)
            } else if model.isSignedIn {
                board
            } else {
                signIn
            }

            if let error = model.errorMessage, !model.isFull || error != ReminderBoardLimits.postItHint {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()
            HStack {
                if model.isSignedIn {
                    Button("Sign Out") { Task { await model.signOut() } }
                        .disabled(model.isBusy)
                }
                Link("Open web board", destination: webBoardURL)
                Spacer()
                Button("Quit Notepad") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .font(.caption)
            if model.isSignedIn {
                Link("Delete account on the web", destination: webAccountURL)
                    .font(.caption)
            }
        }
        .padding(16)
        .frame(width: 380)
        .background {
            MacPopoverVisibility { isPopoverVisible = $0 }
        }
        .task(id: isPopoverVisible) {
            guard isPopoverVisible, !model.isDemo else { return }
            if model.hasBoard { addFieldFocused = true }
            await model.refresh()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
                if model.isSignedIn { await model.refresh(performMaintenance: false) }
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
            if model.hasBoard && model.reminders.isEmpty {
                Label("All Clear", systemImage: "checkmark.circle")
                Text("Nothing on your board. Add a reminder below.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if !model.reminders.isEmpty {
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
                            .accessibilityLabel(reminder.text)
                            .accessibilityHint("Marks this reminder complete")
                            .disabled(model.isBusy)
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
            HStack {
                TextField("New reminder", text: $draft)
                    .focused($addFieldFocused)
                    .onSubmit(addReminder)
                    .disabled(!model.hasBoard)
                Button(action: addReminder) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add reminder")
                .accessibilityHint("Adds this reminder to your board")
                .disabled(model.isBusy || !model.hasBoard || model.addIssue(for: draft) != nil)
            }
            if model.isFull {
                Text(ReminderBoardLimits.postItHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let issue = model.addIssue(for: draft), case .tooLong = issue {
                Text(issue.localizedDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .defaultFocus($addFieldFocused, true)
        .onAppear { addFieldFocused = true }
        .onChange(of: model.hasBoard) { _, hasBoard in
            if hasBoard { addFieldFocused = true }
        }
    }

    private var signIn: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sign In").font(.headline)
            if model.codeEmail != nil {
                Text("Check Your Inbox")
                TextField("Sign-in code", text: $code)
                    .onSubmit { Task { await model.verifyCode(code) } }
                Button("Sign In") { Task { await model.verifyCode(code) } }
                    .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Use a Different Email") {
                    code = ""
                    model.useDifferentEmail()
                }
            } else {
                SignInWithAppleButton(.signIn) { request in
                    model.configureAppleRequest(request)
                } onCompletion: { result in
                    Task { await model.handleAppleSignIn(result) }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: appleButtonHeight)
                Button("Sign In with Google") {
                    let window = NSApp.currentEvent?.window ?? NSApp.keyWindow
                    Task { await model.signInWithGoogle(window: window) }
                }
                Divider()
                TextField("Email address", text: $email)
                    .autocorrectionDisabled()
                if usesPassword {
                    SecureField("Password", text: $password)
                        .onSubmit(signInWithPassword)
                    Button("Sign In with Password", action: signInWithPassword)
                        .disabled(email.isEmpty || password.isEmpty)
                } else {
                    Button("Send Sign-In Code") {
                        Task { await model.sendCode(email: email) }
                    }
                    .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Button(usesPassword ? "Use an Email Code" : "Use an Existing Password") {
                    password = ""
                    usesPassword.toggle()
                }
            }
        }
        .textFieldStyle(.roundedBorder)
        .disabled(model.isBusy)
    }

    private func addReminder() {
        guard model.hasBoard, model.addIssue(for: draft) == nil, !model.isBusy else { return }
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
