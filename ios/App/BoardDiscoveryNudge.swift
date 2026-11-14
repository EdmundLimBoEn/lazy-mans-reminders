import Foundation

/// Installation-wide history, intentionally separate from account/board contents.
enum BoardDiscoveryNudge: String, CaseIterable {
    case web
    case agent

    static let successfulAdditionCountKey = "boardNudgeSuccessfulAdditionCount"

    var shownKey: String {
        switch self {
        case .web: return "boardWebNudgeShown"
        case .agent: return "boardAgentNudgeShown"
        }
    }

    var dismissedKey: String {
        switch self {
        case .web: return "boardWebNudgeDismissed"
        case .agent: return "boardAgentNudgeDismissed"
        }
    }

    /// Call only after the server confirms creation, never on submit or refresh.
    static func recordSuccessfulAddition(in defaults: UserDefaults = .standard) {
        let count = defaults.integer(forKey: successfulAdditionCountKey)
        defaults.set(count + 1, forKey: successfulAdditionCountKey)
    }
}

/// Snapshot eligibility at the start of a visit (board appearance or return
/// from background). Dismissing the setup tip or adding a reminder cannot
/// unlock a nudge mid-visit. A visit has at most one candidate, even on dismissal.
struct BoardNudgeVisit {
    let candidate: BoardDiscoveryNudge?

    init(
        setupTipDismissed: Bool,
        successfulAdditionCount: Int,
        webShown: Bool,
        webDismissed: Bool,
        agentShown: Bool,
        agentDismissed: Bool
    ) {
        if successfulAdditionCount > 0 && !agentShown && !agentDismissed {
            candidate = .agent
        } else if setupTipDismissed && !webShown && !webDismissed {
            candidate = .web
        } else {
            candidate = nil
        }
    }

    struct Visibility {
        var hasLoaded = false
        var isLoading = false
        var hasError = false
        var isBoardEmpty = false
        var isEditing = false
        var isKeyboardVisible = false
        var isPresentingConsent = false
        var isAccountPresented = false
        var isActive = true
        var isShowingSetupTip = false
    }

    func shouldShow(_ visibility: Visibility, isDismissed: Bool) -> Bool {
        guard let candidate, !isDismissed,
              visibility.hasLoaded, !visibility.isLoading, !visibility.hasError,
              !visibility.isEditing, !visibility.isKeyboardVisible,
              !visibility.isPresentingConsent, !visibility.isAccountPresented,
              visibility.isActive, !visibility.isShowingSetupTip else { return false }
        return candidate == .agent || visibility.isBoardEmpty
    }
}
