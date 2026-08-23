import AppKit
import SwiftUI

struct TrafficLightRepositioner: NSViewRepresentable {
    /// Shared offset used by the header's one call site — how far the traffic lights are nudged
    /// from their stock position to align with the header row's own padding.
    static let defaultOffset: CGFloat = 6

    var offsetX: CGFloat = defaultOffset
    var offsetY: CGFloat = defaultOffset

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
}
