import SwiftUI

/// Shared policies for the app and its bounded system surfaces.
enum ReminderAccessibility {
    static func usesSolidBackground(reduceTransparency: Bool, increasedContrast: Bool) -> Bool {
        reduceTransparency || increasedContrast
    }

    static func allowsAnimation(reduceMotion: Bool) -> Bool {
        !reduceMotion
    }

    static func completionSymbol(isCompleting: Bool) -> String {
        isCompleting ? "checkmark.circle.fill" : "circle"
    }

    static func completionValue(isCompleting: Bool) -> String {
        isCompleting ? "Completing" : "Active"
    }

    static func progressValue(isBusy: Bool) -> String {
        isBusy ? "In progress" : ""
    }

    static func completionAnnouncement(text: String, boardIsEmpty: Bool) -> String {
        let completed = "Completed \(text)"
        // One announcement preserves the order without interrupting the reminder text.
        return boardIsEmpty ? completed + "\n" + ReminderActivityPresentation.boardClearMessage : completed
    }
}

/// Retain a visible busy indicator without ongoing spinning under Reduce Motion.
struct AccessibleProgressView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let title: String?

    init(_ title: String? = nil) { self.title = title }

    var body: some View {
        if ReminderAccessibility.allowsAnimation(reduceMotion: reduceMotion) {
            if let title { ProgressView(title) } else { ProgressView() }
        } else if let title {
            Label(title, systemImage: "hourglass")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(title)
        } else {
            Image(systemName: "hourglass")
                .accessibilityLabel("In progress")
        }
    }
}
