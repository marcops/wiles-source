import AppKit
import SwiftUI

struct TrafficLightRepositioner: NSViewRepresentable {
    var offsetX: CGFloat = 0
    let offsetY: CGFloat

    func makeNSView(context _: Context) -> NSView {
        let view = RepositionerView()
        view.offsetX = offsetX
        view.offsetY = offsetY
        return view
    }

    func updateNSView(_ nsView: NSView, context _: Context) {
        if let view = nsView as? RepositionerView {
            view.offsetX = offsetX
            view.offsetY = offsetY
        }
    }

    class RepositionerView: NSView {
        var offsetX: CGFloat = 0
        var offsetY: CGFloat = 6
        private var baseOrigins: [ObjectIdentifier: CGFloat] = [:]

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
                guard let button = btn else { continue }
                let key = ObjectIdentifier(button)
                // AppKit re-centers these buttons on every window layout pass, so the stock
                // x-position (before our offset) has to be captured once and reused — otherwise
                // offsetX compounds further right on every subsequent `layout()` call.
                let baseX = baseOrigins[key] ?? button.frame.origin.x
                baseOrigins[key] = baseX

                var buttonFrame = button.frame
                buttonFrame.origin.x = baseX + offsetX
                buttonFrame.origin.y = (superview.bounds.height - buttonFrame.height) / 2 - offsetY
                button.setFrameOrigin(buttonFrame.origin)
            }
        }
    }
}
