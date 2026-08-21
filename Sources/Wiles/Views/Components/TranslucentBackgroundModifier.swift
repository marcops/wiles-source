import SwiftUI

/// Shared translucent-panel background: an `NSVisualEffectView` material layer with a
/// window-background tint on top, at a caller-supplied opacity.
private struct TranslucentBackgroundModifier: ViewModifier {
    let material: NSVisualEffectView.Material
    let opacity: Double

    func body(content: Content) -> some View {
        content.background(
            ZStack {
                TranslucentVisualEffectView(material: material)
                Color(NSColor.windowBackgroundColor)
                    .opacity(opacity)
            })
    }
}

extension View {
    func translucentBackground(material: NSVisualEffectView.Material, opacity: Double) -> some View {
        modifier(TranslucentBackgroundModifier(material: material, opacity: opacity))
    }
}
