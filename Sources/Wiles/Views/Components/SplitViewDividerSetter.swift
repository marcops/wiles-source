import SwiftUI
import AppKit

struct SplitViewDividerSetter: NSViewRepresentable {
    let position: CGFloat

    func makeNSView(context: Context) -> ApplierView {
        let view = ApplierView()
        view.position = position
        return view
    }

    func updateNSView(_ nsView: ApplierView, context: Context) {
        nsView.position = position
    }

    class ApplierView: NSView {
        var position: CGFloat = 0
        private var hasApplied = false

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            applyIfNeeded()
        }

        override func layout() {
            super.layout()
            applyIfNeeded()
        }

        private func applyIfNeeded() {
            guard !hasApplied, let splitView = enclosingSplitView() else { return }
            hasApplied = true
            splitView.setPosition(position, ofDividerAt: 0)
        }

        private func enclosingSplitView() -> NSSplitView? {
            var view = superview
            while let current = view {
                if let splitView = current as? NSSplitView { return splitView }
                view = current.superview
            }
            return nil
        }
    }
}
