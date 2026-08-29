import SwiftUI

public struct HoverItemHighlightModifier: ViewModifier {
    let isSelected: Bool
    let normalBackground: Color
    let hoverBackground: Color
    let selectedBackground: Color
    let cornerRadius: CGFloat

    /// Subtle 1% grow on hover — enough to register as feedback without visibly reflowing the row.
    private static let hoverScale: CGFloat = 1.01

    @State private var isHovered: Bool = false

    public init(
        isSelected: Bool,
        normalBackground: Color = .clear,
        hoverBackground: Color = Color.accentColor.opacity(0.12),
        selectedBackground: Color = Color.accentColor,
        cornerRadius: CGFloat = 4) {
        self.isSelected = isSelected
        self.normalBackground = normalBackground
        self.hoverBackground = hoverBackground
        self.selectedBackground = selectedBackground
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        content
            .background(
                isSelected ? selectedBackground : (isHovered ? hoverBackground : normalBackground))
            .cornerRadius(cornerRadius)
            .scaleEffect(isHovered ? Self.hoverScale : 1.0)
            .animation(MotionTokens.quickEase, value: isHovered)
            .onHover { isHovered = $0 }
    }
}

public extension View {
    func hoverHighlight(
        isSelected: Bool,
        normalBackground: Color = .clear,
        hoverBackground: Color = Color.accentColor.opacity(0.12),
        selectedBackground: Color = Color.accentColor,
        cornerRadius: CGFloat = 4) -> some View {
        modifier(
            HoverItemHighlightModifier(
                isSelected: isSelected,
                normalBackground: normalBackground,
                hoverBackground: hoverBackground,
                selectedBackground: selectedBackground,
                cornerRadius: cornerRadius))
    }
}
