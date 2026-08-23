import AppKit
import SwiftUI

struct ClickOutsideDetector: NSViewRepresentable {
    let onOutsideClick: () -> Void

    func makeNSView(context _: Context) -> NSView {
        let view = ClickView()
        view.onOutsideClick = onOutsideClick
        return view
    }

    func updateNSView(_ nsView: NSView, context _: Context) {
        if let clickView = nsView as? ClickView {
            clickView.onOutsideClick = onOutsideClick
        }
    }

    class ClickView: NSView {
        var onOutsideClick: (() -> Void)?
        private nonisolated(unsafe) var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            setupMonitor()
        }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            super.viewWillMove(toWindow: newWindow)
            if newWindow == nil {
                removeMonitor()
            }
        }

        override func removeFromSuperview() {
            super.removeFromSuperview()
            removeMonitor()
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        private func setupMonitor() {
            guard window != nil, monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let self, let myWindow = window else { return event }
                let isSameWindow = (event.window == myWindow) || (event.window?.sheetParent == myWindow)
                if isSameWindow || event.window == nil {
                    let locationInView = convert(event.locationInWindow, from: nil)
                    if !bounds.contains(locationInView) {
                        DispatchQueue.main.async {
                            self.onOutsideClick?()
                        }
                    }
                }
                return event
            }
        }

        private func removeMonitor() {
            if let existingMonitor = monitor {
                NSEvent.removeMonitor(existingMonitor)
                monitor = nil
            }
        }

        override func hitTest(_: NSPoint) -> NSView? {
            nil
        }
    }
}
