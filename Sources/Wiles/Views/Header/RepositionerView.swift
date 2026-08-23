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
        guard let window,
              let closeBtn = window.standardWindowButton(.closeButton),
              let superview = closeBtn.superview else { return }

        let buttons = [
            window.standardWindowButton(.closeButton),
            window.standardWindowButton(.miniaturizeButton),
            window.standardWindowButton(.zoomButton)
        ]

        for btn in buttons {
            guard let button = btn, let buttonSuperview = button.superview else { continue }
            let key = BaselineKey(button: ObjectIdentifier(button), superview: ObjectIdentifier(buttonSuperview))
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
