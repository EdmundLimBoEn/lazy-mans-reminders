import SwiftUI

@main
@MainActor
struct NotepadMacApp: App {
    @StateObject private var model = MacReminderModel()

    var body: some Scene {
        MenuBarExtra("Notepad", systemImage: "note.text") {
            MacReminderView(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}
