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
            if window != nil {
                if monitor == nil {
                    monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                        guard let self = self, let window = self.window, event.window == window else { return event }
                        let locationInView = self.convert(event.locationInWindow, from: nil)
                        if !self.bounds.contains(locationInView) {
                            DispatchQueue.main.async {
                                self.onOutsideClick?()
                            }
                        }
                        return event
                    }
                }
            } else {
                removeMonitor()
            }
        }

        override func removeFromSuperview() {
            super.removeFromSuperview()
            removeMonitor()
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
