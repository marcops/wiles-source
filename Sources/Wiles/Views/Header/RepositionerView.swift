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

    private static var baseOrigins: [BaselineKey: CGFloat] = [:]

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
            // AppKit re-centers these buttons on every window layout pass, so the stock
            // x-position (before our offset) has to be captured once per superview and reused —
            // otherwise offsetX compounds further right on every subsequent `layout()` call.
            let baseX = Self.baseOrigins[key] ?? button.frame.origin.x
            Self.baseOrigins[key] = baseX

            var buttonFrame = button.frame
            buttonFrame.origin.x = baseX + offsetX
            buttonFrame.origin.y = (superview.bounds.height - buttonFrame.height) / 2 - offsetY
            button.setFrameOrigin(buttonFrame.origin)
        }
    }
}
