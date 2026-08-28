import AppKit
import SwiftUI

/// Drag source for a multi-selection: starts an AppKit dragging session that carries one
/// `NSDraggingItem` per selected file, so a drop target (Finder, another app, a folder row)
/// receives every selected file instead of only the grabbed row — which a single SwiftUI
/// `NSItemProvider` cannot do.
///
/// The view is transparent to hit-testing unless `isActive` is true (the grabbed row is part of a
/// selection of 2+). When active it claims only left-mouse events, so right-click / context menu,
/// hover, and spring-loaded-folder drops still reach the SwiftUI layer. A left click that never
/// becomes a drag is forwarded via `onClick` / `onDoubleClick` so tap and double-tap keep working.
/// Accessibility stays on the SwiftUI row; this is an invisible interaction shim (like
/// `RightClickDetector`).
struct MultiFileDragView: NSViewRepresentable {
    let isActive: Bool
    let draggedURLs: [URL]
    let dragImage: NSImage
    var onClick: () -> Void
    var onDoubleClick: () -> Void

    func makeNSView(context _: Context) -> DragSourceView {
        let view = DragSourceView()
        apply(to: view)
        return view
    }

    func updateNSView(_ nsView: DragSourceView, context _: Context) {
        apply(to: nsView)
    }

    private func apply(to view: DragSourceView) {
        view.isActive = isActive
        view.draggedURLs = draggedURLs
        view.dragImage = dragImage
        view.onClick = onClick
        view.onDoubleClick = onDoubleClick
    }

    final class DragSourceView: NSView, NSDraggingSource {
        /// Pointer travel (points) before a mouse-down turns into a drag rather than a click.
        private static let dragSlop: CGFloat = 4
        /// Side length of the drag thumbnail drawn per file.
        private static let dragImageSide: CGFloat = 32
        /// Per-file offset so multiple thumbnails read as a stack.
        private static let stackOffset: CGFloat = 4

        var isActive = false
        var draggedURLs: [URL] = []
        var dragImage = NSImage()
        var onClick: (() -> Void)?
        var onDoubleClick: (() -> Void)?

        private var mouseDownPoint: NSPoint = .zero
        private var didStartDrag = false

        override func hitTest(_ point: NSPoint) -> NSView? {
            // Claim only the initial left mouse-down; AppKit then routes the whole drag/up
            // sequence here. Right-click, hover and drop-targeting never match, so they pass through.
            shouldClaimMouseDown(at: point) ? self : nil
        }

        private func shouldClaimMouseDown(at point: NSPoint) -> Bool {
            guard isActive, NSApp.currentEvent?.type == .leftMouseDown else { return false }
            return bounds.contains(convert(point, from: superview))
        }

        override func mouseDown(with event: NSEvent) {
            mouseDownPoint = convert(event.locationInWindow, from: nil)
            didStartDrag = false
        }

        override func mouseDragged(with event: NSEvent) {
            guard isActive, !didStartDrag, movedPastSlop(event) else { return }
            didStartDrag = true
            beginDrag(with: event)
        }

        override func mouseUp(with event: NSEvent) {
            guard !didStartDrag else { return }
            if event.clickCount >= 2 {
                onDoubleClick?()
            } else {
                onClick?()
            }
        }

        private func movedPastSlop(_ event: NSEvent) -> Bool {
            let current = convert(event.locationInWindow, from: nil)
            return abs(current.x - mouseDownPoint.x) > Self.dragSlop
                || abs(current.y - mouseDownPoint.y) > Self.dragSlop
        }

        private func beginDrag(with event: NSEvent) {
            guard !draggedURLs.isEmpty else { return }
            let origin = convert(event.locationInWindow, from: nil)
            let items = draggedURLs.enumerated().map { index, url -> NSDraggingItem in
                let item = NSDraggingItem(pasteboardWriter: url as NSURL)
                let offset = Self.stackOffset * CGFloat(index)
                let frame = NSRect(
                    x: origin.x + offset, y: origin.y - offset,
                    width: Self.dragImageSide, height: Self.dragImageSide)
                item.setDraggingFrame(frame, contents: dragImage)
                return item
            }
            beginDraggingSession(with: items, event: event, source: self)
        }

        func draggingSession(
            _: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
            context == .withinApplication ? [.move, .copy] : [.copy]
        }
    }
}
