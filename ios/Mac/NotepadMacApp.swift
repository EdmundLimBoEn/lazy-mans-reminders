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
        guard arguments.indices.contains(index + 1),
              arguments[index + 1].hasPrefix("/"),
              arguments[index + 1].lowercased().hasSuffix(".png") else {
            NSLog("Snapshot requires an absolute PNG path after -snapshot")
            NSApplication.shared.terminate(nil)
            return
        }

        let destination = URL(fileURLWithPath: arguments[index + 1])
        let demoModel = MacReminderModel()
        renderSnapshot(model: demoModel, scheme: .light, destination: destination) {
            let darkDestination = URL(fileURLWithPath:
                destination.deletingPathExtension().path + "-dark.png")
            self.renderSnapshot(model: demoModel, scheme: .dark, destination: darkDestination) {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func renderSnapshot(
        model: MacReminderModel, scheme: ColorScheme, destination: URL,
        completion: @escaping @MainActor () -> Void
    ) {
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
        hostingView.layoutSubtreeIfNeeded()
        hostingView.displayIfNeeded()

        waitForModel(model, attemptsRemaining: 50) { loaded in
            guard loaded else {
                NSLog("Snapshot model did not load: %@", destination.path)
                window.close()
                completion()
                return
            }
            // Let SwiftUI populate rows and AppKit controls on the main run loop.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                defer {
                    window.close()
                    completion()
                }
                appearance.performAsCurrentDrawingAppearance {
                    hostingView.layoutSubtreeIfNeeded()
                    hostingView.displayIfNeeded()
                    let bounds = hostingView.bounds
                    guard var bitmap = hostingView.bitmapImageRepForCachingDisplay(in: bounds) else {
                        NSLog("Could not render snapshot: %@", destination.path)
                        return
                    }
                    // Offscreen windows may inherit a 1x display; always export at 2x.
                    let pixelsWide = Int(bounds.width * 2)
                    let pixelsHigh = Int(bounds.height * 2)
                    if bitmap.pixelsWide != pixelsWide || bitmap.pixelsHigh != pixelsHigh {
                        guard let scaledBitmap = NSBitmapImageRep(
                            bitmapDataPlanes: nil, pixelsWide: pixelsWide, pixelsHigh: pixelsHigh,
                            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                            isPlanar: false, colorSpaceName: .deviceRGB,
                            bytesPerRow: 0, bitsPerPixel: 0
                        ) else {
                            NSLog("Could not allocate snapshot bitmap: %@", destination.path)
                            return
                        }
                        bitmap = scaledBitmap
                    }
                    bitmap.size = bounds.size
                    hostingView.cacheDisplay(in: bounds, to: bitmap)
                    guard let png = bitmap.representation(using: .png, properties: [:]) else {
                        NSLog("Could not encode snapshot: %@", destination.path)
                        return
                    }
                    do {
                        try png.write(to: destination, options: .atomic)
                    } catch {
                        NSLog("Could not write snapshot: %@", error.localizedDescription)
                    }
                }
            }
        }
    }

    private func waitForModel(
        _ model: MacReminderModel, attemptsRemaining: Int,
        completion: @escaping @MainActor (Bool) -> Void
    ) {
        guard !model.hasLoaded else {
            completion(true)
            return
        }
        guard attemptsRemaining > 0 else {
            completion(false)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.waitForModel(model, attemptsRemaining: attemptsRemaining - 1, completion: completion)
        }
    }
}
#endif
