/// Announces each error presentation once without moving accessibility or keyboard focus.
struct SignInErrorAnnouncementPolicy {
    private var presentedError: String?

    mutating func announcement(for notice: AuthNotice?) -> String? {
        guard case .error(let message) = notice else {
            presentedError = nil
            return nil
        }
        guard message != presentedError else { return nil }
        presentedError = message
        return message
    }
}
