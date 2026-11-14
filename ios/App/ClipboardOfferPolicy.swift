import Foundation

/// Metadata only: deciding to offer a paste must never read clipboard contents.
enum ClipboardOfferPolicy {
    static let storageKey = "clipboardOfferLastHandledChangeCount"

    struct Snapshot: Equatable {
        var hasStrings = false
        var changeCount = -1
    }

    static func shouldShow(
        snapshot: Snapshot,
        lastHandledChangeCount: Int,
        isActive: Bool,
        isSessionReady: Bool,
        hasLoaded: Bool,
        isLoading: Bool,
        hasError: Bool,
        isAtCapacity: Bool,
        isBusy: Bool
    ) -> Bool {
        snapshot.hasStrings && snapshot.changeCount > lastHandledChangeCount
            && isActive && isSessionReady && hasLoaded && !isLoading
            && !hasError && !isAtCapacity && !isBusy
    }

    /// Called only with the payload delivered by the user's PasteButton gesture.
    /// A paste creates at most one reminder, even if the clipboard has many items.
    static func reminderText(from strings: [String]) -> String? {
        guard let first = strings.first else { return nil }
        let trimmed = first.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
