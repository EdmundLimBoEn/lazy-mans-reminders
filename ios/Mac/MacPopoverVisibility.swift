import AppKit
import SwiftUI

/// MenuBarExtra can keep its SwiftUI view mounted while its window is hidden.
struct MacPopoverVisibility: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> WindowObserver {
        let view = WindowObserver()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ view: WindowObserver, context: Context) {
        view.onChange = onChange
    }

    final class WindowObserver: NSView {
        var onChange: ((Bool) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            let center = NotificationCenter.default
            center.removeObserver(self)
            if let window {
                center.addObserver(
                    self, selector: #selector(visibilityChanged(_:)),
                    name: NSWindow.didChangeOcclusionStateNotification, object: window
                )
            }
            // Avoid updating SwiftUI state during AppKit's layout pass.
            Task { [weak self] in self?.reportVisibility() }
        }

        @objc private func visibilityChanged(_ notification: Notification) {
            Task { [weak self] in self?.reportVisibility() }
        }

        private func reportVisibility() {
            onChange?(window?.occlusionState.contains(.visible) == true)
        }
    }
}
