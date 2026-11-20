import SwiftUI
#if DEBUG
import AppKit
import Darwin
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
        guard arguments.indices.contains(index + 1),
              arguments[index + 1].hasPrefix("/"),
              arguments[index + 1].lowercased().hasSuffix(".png") else {
            NSLog("Snapshot requires an absolute PNG path after -snapshot")
            exit(EXIT_FAILURE)
        }

        let destination = URL(fileURLWithPath: arguments[index + 1])
        let stem = destination.deletingPathExtension().path
        Task {
            do {
                try await renderSnapshot(.board, scheme: .light, destination: destination)
                try await renderSnapshot(.board, scheme: .dark, destination: URL(fileURLWithPath: stem + "-dark.png"))
                try await renderSnapshot(.signedOut, scheme: .light, destination: URL(fileURLWithPath: stem + "-signed-out.png"))
                try await renderSnapshot(.full, scheme: .light, destination: URL(fileURLWithPath: stem + "-full.png"))
                NSApplication.shared.terminate(nil)
            } catch {
                NSLog("Snapshot failed: %@", error.localizedDescription)
                exit(EXIT_FAILURE)
            }
        }
    }

    private func renderSnapshot(
        _ state: MacDemoBoard.State, scheme: ColorScheme, destination: URL
    ) async throws {
        let model = MacReminderModel(demo: state)
        let content = MacReminderView(model: model)
            .frame(width: 380, height: 420)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .environment(\.colorScheme, scheme)
        let hostingView = NSHostingView(rootView: content)
        let appearance = NSAppearance(named: scheme == .light ? .aqua : .darkAqua)!
        hostingView.appearance = appearance
        let window = NSWindow(
            contentRect: NSRect(x: -10000, y: 0, width: 380, height: 420),
            styleMask: .borderless, backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = appearance
        window.contentView = hostingView
        window.orderFrontRegardless()
        defer { window.close() }

        // Give SwiftUI time to lay out rows and native controls.
        try await Task.sleep(for: .seconds(1))
        var png: Data?
        appearance.performAsCurrentDrawingAppearance {
            hostingView.layoutSubtreeIfNeeded()
            hostingView.displayIfNeeded()
            let bounds = hostingView.bounds
            // Export at 2x even on a 1x runner display.
            guard let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: Int(bounds.width * 2), pixelsHigh: Int(bounds.height * 2),
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
            ) else { return }
            bitmap.size = bounds.size
            hostingView.cacheDisplay(in: bounds, to: bitmap)
            png = bitmap.representation(using: .png, properties: [:])
        }
        guard let png else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSURLErrorKey: destination])
        }
        try png.write(to: destination, options: .atomic)
    }
}
#endif
