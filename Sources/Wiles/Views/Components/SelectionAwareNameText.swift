import SwiftUI

/// A file/folder name label that stays truncated normally, but un-truncates in place (no tooltip)
/// after the item has been selected continuously for a short delay — matches selecting an item and
/// pausing on it, without popping open on every quick click-through.
struct SelectionAwareNameText: View {
    let name: String
    let isSelected: Bool
    let font: Font
    let color: Color
    let collapsedLineLimit: Int
    var alignment: TextAlignment = .leading

    @State private var showFull = false

    var body: some View {
        Text(name)
            .font(font)
            .lineLimit(isSelected && showFull ? nil : collapsedLineLimit)
            .multilineTextAlignment(alignment)
            .foregroundColor(color)
            .task(id: isSelected) {
                showFull = false
                guard isSelected else { return }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled else { return }
                showFull = true
            }
    }
}
