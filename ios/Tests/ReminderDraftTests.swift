import XCTest
@testable import LazyMansReminders

final class ReminderDraftTests: XCTestCase {
    func testFailureRestoresSubmittedTextWhenComposerWasNotEdited() {
        var draft = ReminderDraft()
        draft.edit("  Buy milk\n")

        XCTAssertEqual(draft.beginSubmission(), "Buy milk")
        XCTAssertEqual(draft.text, "")
        XCTAssertTrue(draft.isSubmitting)
        XCTAssertFalse(draft.canSubmit)

        draft.finishSubmission(succeeded: false)

        XCTAssertEqual(draft.text, "Buy milk")
        XCTAssertFalse(draft.isSubmitting)
        XCTAssertTrue(draft.canSubmit)
    }

    func testFailurePreservesNewDraftTypedDuringSubmission() {
        var draft = ReminderDraft()
        draft.edit("Buy milk")
        _ = draft.beginSubmission()
        draft.edit("  Call Mum\n")
        XCTAssertFalse(draft.canSubmit)

        draft.finishSubmission(succeeded: false)

        XCTAssertEqual(draft.text, "  Call Mum\n")
        XCTAssertTrue(draft.canSubmit)
    }

    func testFailurePreservesIntentionalClearAfterTyping() {
        var draft = ReminderDraft()
        draft.edit("Buy milk")
        _ = draft.beginSubmission()
        draft.edit("Call Mum")
        draft.edit("")

        draft.finishSubmission(succeeded: false)

        XCTAssertEqual(draft.text, "")
        XCTAssertFalse(draft.canSubmit)
        XCTAssertFalse(draft.isSubmitting)
    }

    func testSuccessPreservesNewDraftTypedDuringSubmission() {
        var draft = ReminderDraft()
        draft.edit("Buy milk")
        _ = draft.beginSubmission()
        draft.edit("Call Mum")

        draft.finishSubmission(succeeded: true)

        XCTAssertEqual(draft.text, "Call Mum")
        XCTAssertFalse(draft.isSubmitting)
        XCTAssertTrue(draft.canSubmit)
    }

    func testSuccessLeavesUneditedComposerEmpty() {
        var draft = ReminderDraft()
        draft.edit("Buy milk")
        _ = draft.beginSubmission()

        draft.finishSubmission(succeeded: true)

        XCTAssertEqual(draft.text, "")
        XCTAssertFalse(draft.canSubmit)
        XCTAssertFalse(draft.isSubmitting)
    }

    func testEmptyAndWhitespaceDraftsCannotSubmit() {
        var draft = ReminderDraft()
        XCTAssertNil(draft.beginSubmission())
        draft.edit(" \n\t ")

        XCTAssertFalse(draft.canSubmit)
        XCTAssertNil(draft.beginSubmission())
        XCTAssertFalse(draft.isSubmitting)
        XCTAssertEqual(draft.text, " \n\t ")
    }

    func testRepeatedSubmissionCannotReplacePendingReminderOrNewDraft() {
        var draft = ReminderDraft()
        draft.edit("Buy milk")
        _ = draft.beginSubmission()
        draft.edit("Call Mum")

        XCTAssertNil(draft.beginSubmission())
        draft.finishSubmission(succeeded: false)

        XCTAssertEqual(draft.beginSubmission(), "Call Mum")
        draft.finishSubmission(succeeded: false)
        XCTAssertEqual(draft.text, "Call Mum")
    }

    func testEditsFromPreviousSubmissionDoNotSuppressLaterRestoration() {
        var draft = ReminderDraft()
        draft.edit("Buy milk")
        _ = draft.beginSubmission()
        draft.edit("Call Mum")
        draft.finishSubmission(succeeded: true)
        XCTAssertEqual(draft.beginSubmission(), "Call Mum")

        draft.finishSubmission(succeeded: false)

        XCTAssertEqual(draft.text, "Call Mum")
        XCTAssertTrue(draft.canSubmit)
    }
}
