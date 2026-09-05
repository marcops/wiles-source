import AppKit
import SwiftUI

/// Forces the enclosing NSScrollView to use overlay-style scrollers, which fade out after
/// inactivity and reappear on scroll/hover — the standard macOS behavior. Needed because macOS
/// itself, under "Show scroll bars: Automatically based on mouse or trackpad", silently flips a
/// scroll view's `scrollerStyle` to `.legacy` the moment it sees a real mouse wheel event, and
/// never flips it back. A `.legacy` scroller expects the content to shrink and leave room for it;
/// this app's content is always full width, so the legacy-style scrollbar ends up painted behind
/// the opaque content — present per AppKit (`NSScroller.isHidden` stays false throughout), just
/// visually covered. Confirmed live via a debug build that logged scroll-lifecycle notifications.
struct ScrollerAutoHideSetter: NSViewRepresentable {
    func makeNSView(context _: Context) -> ApplierView {
        ApplierView()
    }

    func updateNSView(_ nsView: ApplierView, context _: Context) {
        nsView.keepOverlayStyle()
    }

    class ApplierView: NSView {
        private var hasObservedScrollView = false
        /// The scroll view currently being observed via target-action (not closures): `self` as
        /// observer lets `deinit` remove everything in one `removeObserver(self)` call, sidestepping
        /// the `NSObjectProtocol` token-array Sendable/isolation issues a closure-based
        /// `addObserver(forName:...)` would need to solve for a nonisolated `deinit`.
        private weak var observedScrollView: NSScrollView?

        override func hitTest(_: NSPoint) -> NSView? {
            nil
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            keepOverlayStyle()
        }

        override func layout() {
            super.layout()
            keepOverlayStyle()
        }

        func keepOverlayStyle() {
            guard let scrollView = nearbyScrollView() else { return }
            if scrollView.scrollerStyle != .overlay {
                scrollView.scrollerStyle = .overlay
            }
            observeLiveScrollIfNeeded(on: scrollView)
        }

        /// One-time setup: `autohidesScrollers` only needs setting once, and the live-scroll
        /// notification observers below are what actually re-pin the style promptly *during* a
        /// scroll — `keepOverlayStyle()` above alone only re-checks on the next SwiftUI/AppKit
        /// layout pass, which a pure scroll gesture doesn't necessarily trigger.
        private func observeLiveScrollIfNeeded(on scrollView: NSScrollView) {
            guard !hasObservedScrollView else { return }
            hasObservedScrollView = true
            observedScrollView = scrollView
            scrollView.autohidesScrollers = true
            let center = NotificationCenter.default
            for name in [
                NSScrollView.willStartLiveScrollNotification, NSScrollView.didLiveScrollNotification,
                NSScrollView.didEndLiveScrollNotification
            ] {
                center.addObserver(self, selector: #selector(handleScrollLifecycleNotification), name: name, object: scrollView)
            }
        }

        @objc
        private func handleScrollLifecycleNotification(_: Notification) {
            guard let scrollView = observedScrollView, scrollView.scrollerStyle != .overlay else { return }
            scrollView.scrollerStyle = .overlay
        }

        /// `.background()` does NOT place this view as a sibling of the real `NSScrollView` in the
        /// actual AppKit tree — SwiftUI wraps each `NSViewRepresentable` in its own isolated hosting
        /// view, confirmed live (its `superview` is never the shared container a naive subtree walk
        /// would assume). Search the whole window instead and match by on-screen position:
        /// `.background()` still sizes/positions this view to coincide with the content it's
        /// attached to, so the closest `NSScrollView` on screen is the real one even when the main
        /// content area has its own separate scroll view in the same window.
        private func nearbyScrollView() -> NSScrollView? {
            guard let contentView = window?.contentView else { return nil }
            let candidates = Self.allScrollViews(in: contentView)
            guard !candidates.isEmpty else { return nil }
            let ownFrame = convert(bounds, to: nil)
            return candidates.min { distance(from: $0, to: ownFrame) < distance(from: $1, to: ownFrame) }
        }

        private func distance(from scrollView: NSScrollView, to frame: NSRect) -> CGFloat {
            let scrollFrame = scrollView.convert(scrollView.bounds, to: nil)
            return abs(scrollFrame.midX - frame.midX) + abs(scrollFrame.midY - frame.midY)
        }

        private static func allScrollViews(in view: NSView) -> [NSScrollView] {
            var result: [NSScrollView] = []
            if let scrollView = view as? NSScrollView {
                result.append(scrollView)
            }
            for subview in view.subviews {
                result.append(contentsOf: allScrollViews(in: subview))
            }
            return result
        }
    }
}
