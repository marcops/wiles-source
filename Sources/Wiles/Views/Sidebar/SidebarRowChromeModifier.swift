import SwiftUI

/// Shared row chrome for sidebar rows (favorites/places rows, tag rows, smart folder rows) —
/// one padding, corner radius, and selected/hover/drag-target background so they can't drift.
struct SidebarRowChromeModifier: ViewModifier {
    let isSelected: Bool
    var isDragTargeted: Bool = false
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(
                isDragTargeted ? Color.accentColor.opacity(0.25) :
                    (isSelected ? Color.accentColor.opacity(0.18) :
                        (isHovered ? Color.primary.opacity(0.06) : Color.clear)))
            .cornerRadius(8)
            .scaleEffect(isDragTargeted ? 1.02 : 1.0)
            .animation(MotionTokens.snappySpring, value: isDragTargeted)
            .animation(MotionTokens.quickEase, value: isHovered)
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
    }
}

extension View {
    func sidebarRowChrome(isSelected: Bool, isDragTargeted: Bool = false) -> some View {
        modifier(SidebarRowChromeModifier(isSelected: isSelected, isDragTargeted: isDragTargeted))
    }
}
