import GitBeacon
import Quartz
import SwiftUI

/// Inline (embedded, not a popup panel) native QuickLook preview — renders anything the system
/// has a QuickLook generator for (HTML, PDF, images, video, code, Office docs, ...), same engine
/// as the spacebar full preview, just embedded in a view instead of its own window.
struct QLPreviewInlineView: NSViewRepresentable {
    let url: URL
    var appState: AppState

    func makeNSView(context _: Context) -> NSView {
        guard let view = QLPreviewView(frame: .zero, style: .normal) else {
            // Under memory pressure (or other rare AppKit failures), `QLPreviewView`'s
            // designated initializer can return nil. This is a non-essential inline preview —
            // degrade to a fallback view instead of crashing the whole app over it, while still
            // surfacing the failure through error reporting.
            ErrorReporter.report(
                NSError(domain: "QLPreviewInlineView", code: 1, userInfo: [NSLocalizedDescriptionKey: "QLPreviewView failed to initialize."]),
                context: "Creating inline QuickLook preview")
            return NSHostingView(rootView: QLPreviewUnavailableView(appState: appState))
        }
        view.autostarts = true
        return view
    }

    func updateNSView(_ nsView: NSView, context _: Context) {
        guard let previewView = nsView as? QLPreviewView else { return }
        if (previewView.previewItem as? URL) != url {
            previewView.previewItem = url as NSURL
        }
    }
}
