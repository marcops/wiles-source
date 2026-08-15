import AppKit
import SwiftUI

/// Forces the enclosing NSScrollView to use overlay-style scrollers, which fade out after
/// inactivity and reappear on scroll/hover — the standard macOS behavior. Needed because some
/// scroll views in this app end up defaulting to the always-visible legacy style.
struct ScrollerAutoHideSetter: NSViewRepresentable {
    func makeNSView(context _: Context) -> ApplierView {
        ApplierView()
    }

    func updateNSView(_ nsView: ApplierView, context _: Context) {
        nsView.applyIfNeeded()
    }

    class ApplierView: NSView {
        override func hitTest(_: NSPoint) -> NSView? {
            nil
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            applyIfNeeded()
        }

        override func layout() {
            super.layout()
            applyIfNeeded()
        }

        func applyIfNeeded() {
            guard let scrollView = nearbyScrollView(), scrollView.scrollerStyle != .overlay else { return }
            scrollView.scrollerStyle = .overlay
            scrollView.autohidesScrollers = true
            // Changing scrollerStyle on an already-instantiated NSScrollView doesn't reliably
            // reconfigure its existing NSScroller instances on its own — re-tiling forces AppKit
            // to rebuild them under the new style so the fade-on-inactivity behavior actually applies.
            scrollView.tile()
            scrollView.flashScrollers()
        }

        /// `.background()` places this view as a *sibling* of the real content (both children of
        /// a shared container), not inside the NSScrollView's own hierarchy — so walking up via
        /// `superview` never finds it. Search the shared container's subtree instead.
        private func nearbyScrollView() -> NSScrollView? {
            guard let container = superview else { return nil }
            return Self.searchScrollView(in: container)
        }

        private static func searchScrollView(in view: NSView) -> NSScrollView? {
            if let scrollView = view as? NSScrollView {
                return scrollView
            }
            for subview in view.subviews {
                if let found = searchScrollView(in: subview) {
                    return found
                }
            }
            return nil
        }
    }
}
