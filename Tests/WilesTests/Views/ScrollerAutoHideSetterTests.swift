import AppKit
@testable import Wiles

/// Regression test for the sidebar/main-content scrollbar bug: macOS itself (not app code) flips a
/// live scroll view's `scrollerStyle` to `.legacy` on a real mouse wheel event, under "Show scroll
/// bars: Automatically based on mouse or trackpad", and never flips it back on its own. Confirmed
/// live via a debug build that logged `NSScrollView`/`NSScroller` state through the scroll — the
/// scroller stayed `isHidden == false` throughout, it was simply painted behind this app's
/// always-full-width content once in `.legacy` style. This doesn't simulate the real mouse-wheel
/// HID trigger (not reliably simulatable in XCTest) — it tests the fix's own logic directly: given
/// the style has already drifted to `.legacy`, does `keepOverlayStyle()` force it back?
@MainActor
public struct ScrollerAutoHideSetterTests {
    public static func run() {
        testKeepOverlayStyleRevertsLegacyStyleBackToOverlay()
        testKeepOverlayStyleFindsScrollViewAmongMultipleInTheSameWindow()
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }

    /// Builds a scroll view + sibling `ApplierView` inside a shared container, matching
    /// `.background()`'s real on-screen layout (both occupy the same frame) even though SwiftUI
    /// wraps the representable in its own isolated hosting view in the real app.
    private static func makeSidebarLikeScrollSetup(overflowing: Bool) -> (window: NSWindow, scrollView: NSScrollView, applier: ScrollerAutoHideSetter.ApplierView) {
        let frame = NSRect(x: 0, y: 0, width: 200, height: 400)
        let container = NSView(frame: frame)

        let scrollView = NSScrollView(frame: frame)
        let documentHeight: CGFloat = overflowing ? 800 : 200
        scrollView.documentView = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: documentHeight))
        scrollView.hasVerticalScroller = true
        container.addSubview(scrollView)

        let applier = ScrollerAutoHideSetter.ApplierView(frame: frame)
        container.addSubview(applier)

        let window = NSWindow(contentRect: frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = container
        return (window, scrollView, applier)
    }

    private static func testKeepOverlayStyleRevertsLegacyStyleBackToOverlay() {
        let (_, scrollView, applier) = makeSidebarLikeScrollSetup(overflowing: true)
        // Simulates what AppKit does on a real mouse wheel event — see this file's header comment.
        scrollView.scrollerStyle = .legacy

        applier.keepOverlayStyle()

        report(
            "Views/ScrollerAutoHideSetter",
            "POS: keepOverlayStyle() forces a scroll view's style back to .overlay after it drifted to .legacy",
            result: scrollView.scrollerStyle == .overlay)
    }

    /// The real bug behind this whole regression: `.background()` does not place `ApplierView` as a
    /// literal sibling of the real `NSScrollView` in the AppKit tree, so the lookup has to search the
    /// whole window and match by position — confirm it still finds the RIGHT one when the window
    /// (like the real app's, sidebar + main content) has more than one scroll view.
    private static func testKeepOverlayStyleFindsScrollViewAmongMultipleInTheSameWindow() {
        let (window, sidebarScrollView, applier) = makeSidebarLikeScrollSetup(overflowing: true)
        let unrelatedScrollView = NSScrollView(frame: NSRect(x: 300, y: 0, width: 200, height: 400))
        unrelatedScrollView.documentView = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 800))
        unrelatedScrollView.hasVerticalScroller = true
        unrelatedScrollView.scrollerStyle = .legacy
        window.contentView?.addSubview(unrelatedScrollView)

        sidebarScrollView.scrollerStyle = .legacy
        applier.keepOverlayStyle()

        report(
            "Views/ScrollerAutoHideSetter",
            "POS: keepOverlayStyle() fixes the nearby (same-position) scroll view, not an unrelated one elsewhere in the window",
            result: sidebarScrollView.scrollerStyle == .overlay)
        report(
            "Views/ScrollerAutoHideSetter",
            "NEG: keepOverlayStyle() leaves an unrelated scroll view elsewhere in the window untouched",
            result: unrelatedScrollView.scrollerStyle == .legacy)
    }
}
