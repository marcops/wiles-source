import SwiftUI
import AppKit

struct ClickOutsideDetector: NSViewRepresentable {
    let onOutsideClick: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = ClickView()
        view.onOutsideClick = onOutsideClick
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let v = nsView as? ClickView {
            v.onOutsideClick = onOutsideClick
        }
    }

    class ClickView: NSView {
        var onOutsideClick: (() -> Void)?
        private var monitor: Any?

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

        private func setupMonitor() {
            guard window != nil, monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let self = self, let myWindow = self.window else { return event }
                let isSameWindow = (event.window == myWindow) || (event.window?.sheetParent == myWindow)
                if isSameWindow || event.window == nil {
                    let locationInView = self.convert(event.locationInWindow, from: nil)
                    if !self.bounds.contains(locationInView) {
                        DispatchQueue.main.async {
                            self.onOutsideClick?()
                        }
                    }
                }
                return event
            }
        }

        private func removeMonitor() {
            if let m = monitor {
                NSEvent.removeMonitor(m)
                monitor = nil
            }
        }
        
        override func hitTest(_ aPoint: NSPoint) -> NSView? {
            return nil
        }
    }
}
