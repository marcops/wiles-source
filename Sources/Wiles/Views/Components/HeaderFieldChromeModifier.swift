import SwiftUI

/// Shared chrome for the header row's inline text fields (search field, path text field) —
/// keeps their styling identical since they occupy the same slot in the same row.
public struct HeaderFieldChromeModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Color(NSColor.controlBackgroundColor)).cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor.opacity(0.6), lineWidth: 1.5))
    }
}

public extension View {
    func headerFieldChrome() -> some View {
        modifier(HeaderFieldChromeModifier())
    }
}
