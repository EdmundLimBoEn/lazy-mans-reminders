import Foundation

struct ReminderDraft {
    private(set) var text = ""
    private var submittedText: String?
    private var editedDuringSubmission = false

    var isSubmitting: Bool { submittedText != nil }

    var canSubmit: Bool {
        !isSubmitting && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    mutating func edit(_ text: String) {
        self.text = text
        if isSubmitting {
            editedDuringSubmission = true
        }
    }

    mutating func beginSubmission() -> String? {
        guard canSubmit else { return nil }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        submittedText = value
        editedDuringSubmission = false
        text = ""
        return value
    }

    mutating func finishSubmission(succeeded: Bool) {
        guard let submittedText else { return }
        if !succeeded && !editedDuringSubmission {
            text = submittedText
        }
        self.submittedText = nil
        editedDuringSubmission = false
    }
}
