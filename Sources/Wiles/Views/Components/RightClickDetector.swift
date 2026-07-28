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

        override func rightMouseDown(with event: NSEvent) {
            onRightClick?()
            super.rightMouseDown(with: event)
        }
        
        override func hitTest(_ aPoint: NSPoint) -> NSView? {
            guard let event = NSApp.currentEvent else { return nil }
            if event.type == .rightMouseDown || event.type == .rightMouseUp {
                return super.hitTest(aPoint)
            }
            return nil
        }
    }
}
