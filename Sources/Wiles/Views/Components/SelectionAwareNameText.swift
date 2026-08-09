import SwiftUI

/// A file/folder name label that stays truncated normally, but un-truncates in place (no tooltip)
/// after the item has been selected continuously for a short delay — matches selecting an item and
/// pausing on it, without popping open on every quick click-through.
///
/// Finder-style middle-ellipsis truncation (equal characters kept from the start and end) instead
/// of the default end-only truncation:
/// - Single-line (`collapsedLineLimit == 1`, List/Column): SwiftUI's native `.truncationMode(.middle)`
///   already does exactly this, using the real layout engine — no width math needed at all.
/// - Multi-line (`collapsedLineLimit > 1`, Grid's 2-line wrap): macOS `Text` doesn't support
///   `.truncationMode(.middle)` across multiple lines, so `FinderStyleTruncationService`
///   pre-computes an equivalent truncated string against the caller-supplied `availableWidth`.
struct SelectionAwareNameText: View {
    let name: String
    let isSelected: Bool
    let font: Font
    let nsFont: NSFont
    let color: Color
    let collapsedLineLimit: Int
    /// Only consulted for the multi-line (Grid) case — ignored for single-line labels, which rely
    /// on native `.truncationMode(.middle)` instead.
    var availableWidth: CGFloat = 0
    var alignment: TextAlignment = .leading
    var middleTruncate: Bool = true

    @State private var showFull = false

    private var displayName: String {
        guard middleTruncate, !(isSelected && showFull), collapsedLineLimit > 1 else { return name }
        return FinderStyleTruncationService.truncatedMiddle(name, font: nsFont, maxWidth: availableWidth, maxLines: collapsedLineLimit)
    }

    var body: some View {
        Text(displayName)
            .font(font)
            .lineLimit(isSelected && showFull ? nil : collapsedLineLimit)
            .truncationMode(middleTruncate ? .middle : .tail)
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
