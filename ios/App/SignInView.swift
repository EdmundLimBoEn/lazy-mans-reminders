import AuthenticationServices
import SwiftUI
import UIKit

struct SignInView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .body) private var signInButtonHeight: CGFloat = 44
    @State private var email = ""
    @State private var password = ""
    @State private var usesPassword = false
    @State private var passwordTask: Task<Void, Never>?
    @State private var pending: PendingSignIn?
    @State private var inboxPulse = 0
    @State private var errorPulse = 0
    @FocusState private var emailFocused: Bool
    @FocusState private var passwordFocused: Bool

#if DEBUG
    // Read-only demo variants retain HillclimbRoot's network-control hit-testing block.
    private var fixtureVariant: String? {
        HillclimbDemo.mode == .signin ? HillclimbDemo.argument("--hillclimb-signin-variant") : nil
    }
#endif

    private var displayedNotice: AuthNotice? {
#if DEBUG
        switch fixtureVariant {
        case "inbox": return .checkInbox(email: "you@example.com")
        case "error": return .error("Couldn’t sign in. Check your email and password, or use a sign-in link. If you’re offline, reconnect and try again.")
        default: break
        }
#endif
        return auth.notice
    }

    private enum PendingSignIn {
        case apple, google, magicLink, password
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notepad")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("Your board on this iPhone, the web, and the Lock Screen.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    providerSection
                    emailSection
                    if case .error(let message) = displayedNotice {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .symbolRenderingMode(.hierarchical)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.updatesFrequently)
                    }
                    legalFooter
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemBackground))
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        emailFocused = false
                        passwordFocused = false
                    }
                }
            }
        }
#if DEBUG
        .task {
            if fixtureVariant == "password" || fixtureVariant == "password-keyboard" {
                usesPassword = true
            }
            if fixtureVariant == "keyboard" || fixtureVariant == "password-keyboard" {
                try? await Task.sleep(for: .milliseconds(300))
            }
            if fixtureVariant == "keyboard" { emailFocused = true }
            if fixtureVariant == "password-keyboard" { passwordFocused = true }
        }
#endif
        .sensoryFeedback(.success, trigger: inboxPulse)
        .sensoryFeedback(.error, trigger: errorPulse)
        .onChange(of: email) { _, _ in
            if case .error = auth.notice {
                auth.clearNotice()
            }
        }
        .onChange(of: password) { _, value in
            if !value.isEmpty, case .error = auth.notice {
                auth.clearNotice()
            }
        }
        .onDisappear {
            passwordTask?.cancel()
            passwordTask = nil
            password = ""
        }
        .onChange(of: auth.notice) { _, notice in
            if case .checkInbox = notice {
                pending = nil
                emailFocused = false
                inboxPulse += 1
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "Check your inbox for the sign-in link"
                )
            } else if case .error = notice {
                pending = nil
                errorPulse += 1
            }
        }
    }

    private var busy: Bool {
        pending != nil || auth.isAuthenticating
    }

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var emailIsPlausible: Bool {
        SignInEmail.isPlausible(normalizedEmail)
    }

    private var providerSection: some View {
        SignInSection {
            SignInWithAppleButton(.signIn) { request in
                pending = .apple
                auth.configureAppleRequest(request)
            } onCompletion: { result in
                Task {
                    await auth.handleAppleSignIn(result)
                    if auth.session == nil {
                        pending = nil
                    }
                }
            }
            .signInWithAppleFill(SignInAppleFill.fill(for: colorScheme))
            .frame(maxWidth: .infinity)
            .frame(height: max(44, signInButtonHeight))
            .disabled(busy)

            Button {
                pending = .google
                Task {
                    await auth.signInWithGoogle()
                    pending = nil
                }
            } label: {
                signInButtonLabel(
                    title: "Sign in with Google",
                    showsProgress: pending == .google
                )
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .frame(minHeight: max(44, signInButtonHeight))
            .disabled(busy)
            .accessibilityHint("Opens Google sign-in in a secure browser sheet")
        }
    }

    @ViewBuilder
    private var emailSection: some View {
        if case .checkInbox(let sentTo) = displayedNotice {
            SignInSection {
                Label("Check Your Inbox", systemImage: "envelope.badge")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityAddTraits(.updatesFrequently)
                Text("We sent a sign-in link to \(sentTo).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Use a Different Email") {
                    auth.clearNotice()
                    pending = nil
                    emailFocused = true
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            }
        } else {
            SignInSection {
                Text("Email")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text("Use the same address as the web board.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                emailField
                if !normalizedEmail.isEmpty && !emailIsPlausible {
                    Text("Enter a valid email address.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityAddTraits(.updatesFrequently)
                }
                if usesPassword {
                    passwordField
                    Text("For an existing account with a password. You can also use a sign-in link.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button {
                    if usesPassword {
                        startPasswordSignIn()
                    } else {
                        Task { await sendMagicLink() }
                    }
                } label: {
                    signInButtonLabel(
                        title: usesPassword ? "Sign In with Password" : "Send Sign-In Link",
                        showsProgress: pending == .magicLink || pending == .password
                    )
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .disabled(!emailIsPlausible || busy || (usesPassword && password.isEmpty))
                Button {
                    usesPassword.toggle()
                    password = ""
                    passwordFocused = false
                    auth.clearNotice()
                } label: {
                    Text(usesPassword ? "Use a Sign-In Link Instead" : "Use an Existing Password")
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .controlSize(.large)
                .frame(maxWidth: .infinity, minHeight: 44)
                .disabled(busy)
            }
        }
    }

    private var emailField: some View {
        HStack(spacing: 0) {
            TextField("you@example.com", text: $email)
                .textContentType(usesPassword ? .username : .emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .focused($emailFocused)
                .submitLabel(usesPassword ? .next : .send)
                .accessibilityLabel("Email address")
                .onSubmit {
                    if usesPassword {
                        passwordFocused = true
                    } else {
                        Task { await sendMagicLink() }
                    }
                }
                .disabled(busy)

            if !email.isEmpty {
                Button {
                    email = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(busy)
                .accessibilityLabel("Clear text")
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, email.isEmpty ? 12 : 0)
        .frame(minHeight: 44)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { if !busy { emailFocused = true } }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("signin.emailTarget")
    }

    private var passwordField: some View {
        VStack(spacing: 0) {
            SecureField("Password", text: $password)
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .privacySensitive()
                .focused($passwordFocused)
                .submitLabel(.go)
                .accessibilityLabel("Password")
                .onSubmit { startPasswordSignIn() }
                .disabled(busy)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture { if !busy { passwordFocused = true } }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("signin.passwordTarget")
    }

    private var legalFooter: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                Link("Privacy", destination: LMRWeb.privacy)
                    .frame(minHeight: 44)
                Text("·")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
                Link("Terms", destination: LMRWeb.terms)
                    .frame(minHeight: 44)
                Text("·")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
                Link("Support", destination: LMRWeb.support)
                    .frame(minHeight: 44)
            }
            VStack(spacing: 0) {
                Link("Privacy", destination: LMRWeb.privacy)
                    .frame(minHeight: 44)
                Link("Terms", destination: LMRWeb.terms)
                    .frame(minHeight: 44)
                Link("Support", destination: LMRWeb.support)
                    .frame(minHeight: 44)
            }
        }
        .font(.footnote)
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private func signInButtonLabel(title: String, showsProgress: Bool) -> some View {
        ZStack {
            Text(title)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
                .opacity(showsProgress ? 0 : 1)
            if showsProgress {
                ProgressView()
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 22)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(showsProgress ? "\(title), in progress" : title)
    }

    private func startPasswordSignIn() {
        guard !busy,
              let credentials = PasswordSignInCredentials(email: email, password: password)
        else { return }
        emailFocused = false
        passwordFocused = false
        pending = .password
        passwordTask = Task {
            await auth.signInWithPassword(email: credentials.email, password: credentials.password)
            password = ""
            pending = nil
            passwordTask = nil
        }
    }

    private func sendMagicLink() async {
        let value = normalizedEmail
        guard SignInEmail.isPlausible(value), !busy else { return }
        pending = .magicLink
        await auth.sendMagicLink(to: value)
        pending = nil
    }
}

private struct SignInSection<Content: View>: View {
    var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension View {
    @ViewBuilder
    func signInWithAppleFill(_ fill: SignInAppleFill) -> some View {
        switch fill {
        case .black:
            signInWithAppleButtonStyle(.black)
        case .whiteOutline:
            signInWithAppleButtonStyle(.whiteOutline)
        }
    }
}
