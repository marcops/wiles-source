import Quartz
import SwiftUI

/// Inline (embedded, not a popup panel) native QuickLook preview — renders anything the system
/// has a QuickLook generator for (HTML, PDF, images, video, code, Office docs, ...), same engine
/// as the spacebar full preview, just embedded in a view instead of its own window.
struct QLPreviewInlineView: NSViewRepresentable {
    let url: URL

    func makeNSView(context _: Context) -> QLPreviewView {
        guard let view = QLPreviewView(frame: .zero, style: .normal) else {
            preconditionFailure("QLPreviewView failed to initialize")
        }
        view.autostarts = true
        return view
    }

    func updateNSView(_ nsView: QLPreviewView, context _: Context) {
        if (nsView.previewItem as? URL) != url {
            nsView.previewItem = url as NSURL
        }
    }
}
