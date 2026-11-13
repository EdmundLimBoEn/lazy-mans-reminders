import SwiftUI
#if DEBUG
import AppKit
#endif

@main
@MainActor
struct NotepadMacApp: App {
    @StateObject private var model = MacReminderModel()
#if DEBUG
    @NSApplicationDelegateAdaptor(MacSnapshotDelegate.self) private var snapshotDelegate
#endif

    var body: some Scene {
        MenuBarExtra("Notepad", systemImage: "note.text") {
            MacReminderView(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}

#if DEBUG
@MainActor
private final class MacSnapshotDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-demo"),
              let index = arguments.firstIndex(of: "-snapshot") else { return }
        defer { NSApplication.shared.terminate(nil) }
        guard arguments.indices.contains(index + 1),
              arguments[index + 1].hasPrefix("/"),
              arguments[index + 1].lowercased().hasSuffix(".png") else {
            NSLog("Snapshot requires an absolute PNG path after -snapshot")
            return
        }

        let destination = URL(fileURLWithPath: arguments[index + 1])
        let model = MacReminderModel()
        for scheme in [ColorScheme.light, .dark] {
            let url = scheme == .light ? destination : URL(fileURLWithPath:
                destination.deletingPathExtension().path + "-dark.png")
            // Resolve AppKit's dynamic colors as well as SwiftUI's environment.
            let appearance = NSAppearance(named: scheme == .light ? .aqua : .darkAqua)!
            appearance.performAsCurrentDrawingAppearance {
                let content = MacReminderView(model: model)
                    .frame(width: 380, height: 420)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .environment(\.colorScheme, scheme)
                let renderer = ImageRenderer(content: content)
                renderer.scale = 2
                guard let image = renderer.cgImage,
                      let png = NSBitmapImageRep(cgImage: image)
                        .representation(using: .png, properties: [:]) else {
                    NSLog("Could not render snapshot: %@", url.path)
                    return
                }
                do {
                    try png.write(to: url, options: .atomic)
                } catch {
                    NSLog("Could not write snapshot: %@", error.localizedDescription)
                }
            }
        }
    }
}
#endif
