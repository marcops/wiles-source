import SwiftUI

/// Shared translucent-panel background: an `NSVisualEffectView` material layer with a
/// window-background tint on top, at a caller-supplied opacity.
private struct TranslucentBackgroundModifier: ViewModifier {
    let material: NSVisualEffectView.Material
    let opacity: Double
    var ignoresSafeArea: Bool = false

    private var backgroundLayer: some View {
        ZStack {
            TranslucentVisualEffectView(material: material)
            Color(NSColor.windowBackgroundColor)
                .opacity(opacity)
        }
    }

    func body(content: Content) -> some View {
        content.background {
            if ignoresSafeArea {
                backgroundLayer.ignoresSafeArea()
            } else {
                backgroundLayer
            }
        }
    }
}

extension View {
    func translucentBackground(material: NSVisualEffectView.Material, opacity: Double, ignoresSafeArea: Bool = false) -> some View {
        modifier(TranslucentBackgroundModifier(material: material, opacity: opacity, ignoresSafeArea: ignoresSafeArea))
    }
}
