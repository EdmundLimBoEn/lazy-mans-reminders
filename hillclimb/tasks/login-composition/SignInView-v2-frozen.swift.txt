import AuthenticationServices
import SwiftUI
import UIKit

struct SignInView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .body) private var signInButtonHeight: CGFloat = 48
    @State private var email = ""
    @State private var password = ""
    @State private var usesPassword = false
    @State private var passwordTask: Task<Void, Never>?
    @State private var pending: PendingSignIn?
    @State private var inboxPulse = 0
    @State private var errorPulse = 0
    @State private var errorAnnouncements = SignInErrorAnnouncementPolicy()
#if DEBUG
    @State private var fixtureNoticeCleared = false
#endif
    @FocusState private var emailFocused: Bool
    @FocusState private var passwordFocused: Bool

#if DEBUG
    // Only explicit sign-in demos permit local editing while blocking external actions.
    private var fixtureVariant: String? {
        HillclimbDemo.mode == .signin ? HillclimbDemo.argument("--hillclimb-signin-variant") : nil
    }
#endif

    private var displayedNotice: AuthNotice? {
#if DEBUG
        if fixtureNoticeCleared { return nil }
        switch fixtureVariant {
        case "inbox": return .checkInbox(email: "you@example.com")
        case "error": return .error("Couldn’t sign in. Check your email and password, or use a sign-in link. If you’re offline, reconnect and try again.")
        default: break
        }
#endif
        return auth.notice
    }

    private var blocksExternalActions: Bool {
#if DEBUG
        HillclimbDemo.mode == .signin
#else
        false
#endif
    }

    private var appearanceFixture: Bool {
#if DEBUG
        HillclimbDemo.mode == .signin && HillclimbDemo.argument("--hillclimb-signin-appearance") == "enabled"
#else
        false
#endif
    }

    private var disablesDemoControls: Bool {
        blocksExternalActions && !appearanceFixture
    }

    private enum PendingSignIn {
        case apple, google, magicLink, password
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notepad")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Your board on this iPhone, the web, and the Lock Screen.")
                            .font(.body)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    providerSection
                    emailSection
                    if case .error(let message) = displayedNotice {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.primary)
                            .symbolRenderingMode(.hierarchical)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.updatesFrequently)
                    }
                    legalFooter
                        .id("signin.legalFooter")
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
#if DEBUG
            .task {
                if appearanceFixture && HillclimbDemo.argument("--hillclimb-signin-scroll") == "bottom" {
                    scroll.scrollTo("signin.legalFooter", anchor: .bottom)
                }
            }
#endif
            .signInTopEdge()
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemBackground))
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                if emailFocused || passwordFocused {
                    scroll.scrollTo("signin.alternateTarget", anchor: .bottom)
                }
            }
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 8) {
                if emailFocused || passwordFocused {
                    HStack {
                        Spacer()
                        Button {
                            emailFocused = false
                            passwordFocused = false
                        } label: {
                            Text("Done")
                                .frame(minWidth: 48, minHeight: 48)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.tint)
                    }
                    .padding(.horizontal, 20)
                    .background(Color(.systemBackground))
                }
            }
        }
#if DEBUG
        .task {
            if fixtureVariant == "password" || fixtureVariant == "password-keyboard" {
                usesPassword = true
            }
            if appearanceFixture && HillclimbDemo.argument("--hillclimb-signin-filled") == "yes" {
                email = "you@example.com"
                if usesPassword { password = "Demo-password" }
            }
            if fixtureVariant == "loading" { pending = .magicLink }
            if fixtureVariant == "keyboard" || fixtureVariant == "password-keyboard" {
                try? await Task.sleep(for: .milliseconds(300))
            }
            if fixtureVariant == "keyboard" { emailFocused = true }
            if fixtureVariant == "password-keyboard" { passwordFocused = true }
        }
#endif
        .environment(\.openURL, OpenURLAction { url in
            guard !blocksExternalActions else { return .discarded }
            return .systemAction(url)
        })
#if DEBUG
        .overlay(alignment: .topLeading) {
            if HillclimbDemo.mode == .signin {
                SignInDensityExport().frame(width: 1, height: 1).allowsHitTesting(false)
            }
        }
#endif
        .allowsHitTesting(!appearanceFixture)
        .onChange(of: displayedNotice, initial: true) { _, notice in
            if let message = errorAnnouncements.announcement(for: notice) {
                UIAccessibility.post(notification: .announcement, argument: message)
            }
        }
        .sensoryFeedback(.success, trigger: inboxPulse)
        .sensoryFeedback(.error, trigger: errorPulse)
        .onChange(of: email) { _, _ in
            if case .error = displayedNotice {
                clearNotice()
            }
        }
        .onChange(of: password) { _, value in
            if !value.isEmpty, case .error = displayedNotice {
                clearNotice()
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

    private var submitIsDisabled: Bool {
        disablesDemoControls || !emailIsPlausible || busy || (usesPassword && password.isEmpty)
    }

    private var providerSection: some View {
        SignInSection {
            SignInWithAppleButton(.signIn) { request in
                guard !blocksExternalActions else { return }
                pending = .apple
                auth.configureAppleRequest(request)
            } onCompletion: { result in
                guard !blocksExternalActions else { return }
                Task {
                    await auth.handleAppleSignIn(result)
                    if auth.session == nil {
                        pending = nil
                    }
                }
            }
            .signInWithAppleFill(SignInAppleFill.fill(for: colorScheme))
            .accessibilityIdentifier("signin.apple")
            .frame(maxWidth: .infinity)
            .frame(height: max(44, signInButtonHeight))
            .disabled(busy || disablesDemoControls)

            Button {
                guard !blocksExternalActions else { return }
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
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: max(44, signInButtonHeight))
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary, lineWidth: 1))
            .disabled(busy || disablesDemoControls)
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
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Use a Different Email") {
                    clearNotice()
                    pending = nil
                    emailFocused = true
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            }
        } else {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                        .modifier(SignInDensityProbe(key: "emailHeading"))
                    Text("Use the same address as the web board.")
                        .font(.footnote)
                        .foregroundStyle(.primary.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                        .modifier(SignInDensityProbe(key: "emailHelper"))
                    emailField
                        .modifier(SignInDensityProbe(key: "emailField"))
                    if !normalizedEmail.isEmpty && !emailIsPlausible {
                        Text("Enter a valid email address.")
                            .font(.footnote)
                            .foregroundStyle(.primary)
                            .accessibilityAddTraits(.updatesFrequently)
                    }
                }
                .modifier(SignInDensityProbe(key: "emailGroup"))
                if usesPassword {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.headline)
                            .accessibilityHidden(true)
                            .modifier(SignInDensityProbe(key: "passwordHeading"))
                        passwordField
                            .modifier(SignInDensityProbe(key: "passwordField"))
                        Text("For an existing account with a password. You can also use a sign-in link.")
                            .font(.footnote)
                            .foregroundStyle(.primary.opacity(0.75))
                            .fixedSize(horizontal: false, vertical: true)
                            .modifier(SignInDensityProbe(key: "passwordHelper"))
                    }
                    .modifier(SignInDensityProbe(key: "passwordGroup"))
                }
                VStack(alignment: .leading, spacing: 8) {
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
                        .foregroundColor(colorScheme == .dark && !submitIsDisabled ? Color(.systemBackground) : nil)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .disabled(submitIsDisabled)
                    Button {
                        usesPassword.toggle()
                        password = ""
                        passwordFocused = false
                        clearNotice()
                    } label: {
                        Text(usesPassword ? "Use a Sign-In Link Instead" : "Use an Existing Password")
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .disabled(busy)
                    .id("signin.alternateTarget")
                }
                .modifier(SignInDensityProbe(key: "actionGroup"))
            }
        }
    }

    private var emailField: some View {
        HStack(spacing: 0) {
            TextField("you@example.com", text: $email, prompt: Text(verbatim: "you@example.com").foregroundColor(Color(.secondaryLabel)))
                .textContentType(usesPassword ? .username : .emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body)
                .frame(minHeight: 48)
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
        .frame(minHeight: 48)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { if !busy { emailFocused = true } }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("signin.emailTarget")
        .id("signin.emailTarget")
    }

    private var passwordField: some View {
        VStack(spacing: 0) {
            SecureField("Password", text: $password)
                .frame(minHeight: 48)
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
        .frame(minHeight: 48)
        .contentShape(Rectangle())
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture { if !busy { passwordFocused = true } }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("signin.passwordTarget")
        .id("signin.passwordTarget")
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
        .disabled(disablesDemoControls)
        .tint(.primary)
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

    private func clearNotice() {
#if DEBUG
        if blocksExternalActions { fixtureNoticeCleared = true }
#endif
        auth.clearNotice()
    }

    private func startPasswordSignIn() {
        guard !blocksExternalActions, !busy,
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
        guard !blocksExternalActions, SignInEmail.isPlausible(value), !busy else { return }
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
    func signInTopEdge() -> some View {
        if #available(iOS 26.0, *) {
            scrollEdgeEffectStyle(.hard, for: .top)
        } else {
            self
        }
    }

    @ViewBuilder
    func signInWithAppleFill(_ fill: SignInAppleFill) -> some View {
        switch fill {
        case .whiteOutline:
            signInWithAppleButtonStyle(.whiteOutline)
        }
    }
}

private struct SignInDensityProbe: ViewModifier {
    let key: String
    func body(content: Content) -> some View {
        #if DEBUG
            if HillclimbDemo.mode == .signin {
                content.background(
                    GeometryReader { geometry in
                        Color.clear.onAppear { SignInDensityFrames.values[key] = geometry.frame(in: .global) }
                            .onChange(of: geometry.frame(in: .global)) { _, frame in
                                SignInDensityFrames.values[key] = frame
                            }
                    })
            } else {
                content
            }
        #else
            content
        #endif
    }
}
#if DEBUG
    @MainActor private enum SignInDensityFrames {
        static var values: [String: CGRect] = [:]
    }
    private struct SignInDensityExport: UIViewRepresentable {
        func makeUIView(context: Context) -> ExportView { ExportView() }
        func updateUIView(_ uiView: ExportView, context: Context) {}
        final class ExportView: UIView {
            override init(frame: CGRect) {
                super.init(frame: frame)
                isAccessibilityElement = true
                accessibilityIdentifier = "signin.densityFrames"
            }
            required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
            override var accessibilityValue: String? {
                get {
                    let frames = SignInDensityFrames.values.mapValues {
                        [$0.minX, $0.minY, $0.width, $0.height]
                    }
                    guard
                        let data = try? JSONSerialization.data(withJSONObject: frames, options: [.sortedKeys])
                    else { return nil }
                    return String(data: data, encoding: .utf8)
                }
                set {}
            }
        }
    }
#endif
