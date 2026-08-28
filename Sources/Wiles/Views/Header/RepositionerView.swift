import AppKit

/// Repositions the standard traffic-light window buttons by a fixed offset. Backs
/// `TrafficLightRepositioner`.
final class RepositionerView: NSView {
    var offsetX: CGFloat = 0
    var offsetY: CGFloat = 6

    /// Keyed by (button identity, its *current* superview identity) rather than just the
    /// button, so re-parenting into a different superview (full screen, or a torn-down and
    /// rebuilt `RepositionerView`) captures a fresh baseline instead of compounding the old
    /// offset. Static + process-wide so it survives this `NSView` itself being recreated.
    private struct BaselineKey: Hashable {
        let button: ObjectIdentifier
        let superview: ObjectIdentifier
    }

    /// What we last actually wrote to `button.frame.origin.x`, so `reposition()` can tell "AppKit
    /// left the button exactly where I put it" apart from "AppKit reset it to native this pass" —
    /// see `reposition()`.
    private static var lastAppliedX: [BaselineKey: CGFloat] = [:]

    /// `lastAppliedX` keys are (button, superview) identities that are never individually removed —
    /// each opened window adds ~3. A missing baseline is a handled case (`reposition()` recaptures
    /// it next pass), so once the map is clearly larger than any plausible live window count, drop
    /// it wholesale rather than letting it grow unbounded across a long multi-window session.
    private static let maxBaselineEntries = 90

    /// Purely a passive layout observer — must never intercept clicks meant for whatever's
    /// drawn on top of or behind it, since the default NSView.hitTest claims everything.
    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Registered once, ever, per instance — observing `object: nil` (any window) sidesteps
    /// needing to swap the observed object if this view is ever re-parented to a different
    /// window, which would otherwise mean removing the old registration outside `deinit`.
    private var didRegisterResizeObservers = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if !didRegisterResizeObservers {
            didRegisterResizeObservers = true
            // `layout()` only fires when *this* view's own layout is invalidated, but AppKit can
            // reset the traffic-light buttons to their native position as part of a window resize
            // without ever touching this view's layout (e.g. the sidebar collapsing/peeking
            // reflows content without resizing the window itself, yet a live window resize's own
            // button re-layout can land on a tick where this view doesn't relayout). Listening to
            // the window directly guarantees a correction fires for every resize regardless of
            // which subview AppKit decided needed relayout. `reposition()` itself resolves
            // buttons from `self.window`, so it's harmless if this fires for some other window.
            for name: Notification.Name in [
                NSWindow.didResizeNotification, NSWindow.willStartLiveResizeNotification, NSWindow.didEndLiveResizeNotification
            ] {
                NotificationCenter.default.addObserver(self, selector: #selector(handleWindowResize), name: name, object: nil)
            }
        }
        reposition()
    }

    @objc
    private func handleWindowResize() {
        reposition()
    }

    override func layout() {
        super.layout()
        reposition()
    }

    private func reposition() {
        guard let window else { return }

        let buttons = [
            window.standardWindowButton(.closeButton),
            window.standardWindowButton(.miniaturizeButton),
            window.standardWindowButton(.zoomButton)
        ]

        // During live resize AppKit can momentarily tear down and rebuild the title bar's
        // button hierarchy, so any one button's superview can be transiently unavailable. Only
        // three-out-of-three resolving is allowed to move anything — repositioning a subset
        // would leave that pass's untouched button(s) at AppKit's native position while the
        // rest sit at our offset, which reads as the buttons swapping places until the next
        // `layout()` call catches up.
        let resolved = buttons.compactMap { btn -> (button: NSButton, superview: NSView)? in
            guard let button = btn, let superview = button.superview else { return nil }
            return (button, superview)
        }
        guard resolved.count == buttons.count else { return }

        if Self.lastAppliedX.count > Self.maxBaselineEntries {
            Self.lastAppliedX.removeAll(keepingCapacity: true)
        }

        for (button, superview) in resolved {
            let key = BaselineKey(button: ObjectIdentifier(button), superview: ObjectIdentifier(superview))
            let currentX = button.frame.origin.x

            // AppKit only *occasionally* resets these buttons back to their native x (most layout
            // passes leave whatever we last set alone) — most visibly during live resize, where a
            // reset briefly shows the buttons at their native position until our next pass corrects
            // it. A one-time "capture baseline on first sight" cache can permanently latch onto a
            // stale/transient value from exactly one of those reset moments and never let go. So
            // instead: if the button is still sitting where we last put it, its native x hasn't
            // changed under us — reuse the known baseline. If it isn't (AppKit just reset it this
            // pass), that reset value *is* the fresh native x — rebaseline from it immediately
            // rather than trusting a cached one, so a bad snapshot self-heals on the very next pass.
            let lastApplied = Self.lastAppliedX[key]
            let baseX: CGFloat = if let lastApplied, abs(currentX - lastApplied) < 0.5 {
                lastApplied - offsetX
            } else {
                currentX
            }

            var buttonFrame = button.frame
            buttonFrame.origin.x = baseX + offsetX
            buttonFrame.origin.y = (superview.bounds.height - buttonFrame.height) / 2 - offsetY
            button.setFrameOrigin(buttonFrame.origin)
            Self.lastAppliedX[key] = buttonFrame.origin.x
        }
    }
}
