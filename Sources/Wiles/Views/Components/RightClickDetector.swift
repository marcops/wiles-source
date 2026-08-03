import SwiftUI
import AppKit

struct RightClickDetector: NSViewRepresentable {
    let onRightClick: () -> Void

    func makeNSView(context: Context) -> RightClickNSView {
        let view = RightClickNSView()
        view.onRightClick = onRightClick
        return view
    }

    func updateNSView(_ nsView: RightClickNSView, context: Context) {
        nsView.onRightClick = onRightClick
    }

    class RightClickNSView: NSView {
        var onRightClick: (() -> Void)?

        override func hitTest(_ aPoint: NSPoint) -> NSView? {
            let pointInView = convert(aPoint, from: superview)
            if bounds.contains(pointInView) {
                if let event = NSApp.currentEvent, event.type == .rightMouseDown || event.type == .rightMouseUp {
                    return self
                }
            }
            return nil
        }

        override func rightMouseDown(with event: NSEvent) {
            onRightClick?()
            super.rightMouseDown(with: event)
        }
    }
}
