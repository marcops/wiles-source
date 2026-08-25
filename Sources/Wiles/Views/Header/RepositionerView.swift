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

    /// Purely a passive layout observer — must never intercept clicks meant for whatever's
    /// drawn on top of or behind it, since the default NSView.hitTest claims everything.
    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
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
