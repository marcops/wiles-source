import AppKit
import SwiftUI

/// Attach to dead space in the header/toolbar strip so double-clicking there zooms the window
/// (fills the screen without entering native Fullscreen), matching standard macOS title-bar
/// double-click behavior. Uses SwiftUI's own gesture/hit-testing system rather than a raw AppKit
/// NSView, since a background NSViewRepresentable sits as a *sibling* of the foreground content
/// in the view hierarchy (not behind it in a way plain NSView hit-testing resolves reliably) —
/// `.contentShape` + `.onTapGesture` correctly falls through empty space while still letting
/// real buttons drawn in front handle their own single clicks first.
struct DoubleClickZoomModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    NSApp.keyWindow?.zoom(nil)
                })
    }
}

extension View {
    func doubleClickToZoom() -> some View {
        modifier(DoubleClickZoomModifier())
    }
}
