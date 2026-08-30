import SwiftUI

/// A file/folder name label that un-truncates in place after being selected and left alone for a
/// short delay. Single-line (List) relies on native `.truncationMode(.middle)`; multi-line (Grid)
/// uses `FinderStyleTruncationService`'s pre-broken lines instead, since `Text` won't reliably
/// wrap an unbroken filename on its own.
struct SelectionAwareNameText: View {
    let name: String
    let isSelected: Bool
    let font: Font
    let nsFont: NSFont
    let color: Color
    let collapsedLineLimit: Int
    /// Only consulted for the multi-line (Grid) case.
    var availableWidth: CGFloat = 0
    var alignment: TextAlignment = .leading
    var middleTruncate: Bool = true
    /// Tag dots shown inline before the first line — empty for callers showing tags separately.
    var tags: [String] = []
    /// Grid disables this — it renders the reveal as its own grid-level overlay instead.
    var revealsOnSelect: Bool = true

    @State private var showFull = false

    private var isRevealingFull: Bool {
        revealsOnSelect && isSelected && showFull
    }

    private var displayName: String {
        guard middleTruncate, !isRevealingFull, collapsedLineLimit > 1 else { return name }
        return FinderStyleTruncationService.truncatedMiddle(name, font: nsFont, maxWidth: availableWidth, maxLines: collapsedLineLimit)
    }

    private var horizontalAlignment: HorizontalAlignment {
        switch alignment {
        case .leading: .leading
        case .trailing: .trailing
        case .center: .center
        @unknown default: .center
        }
    }

    var body: some View {
        Group {
            if collapsedLineLimit > 1 {
                multilineBody
            } else {
                Text(displayName)
                    .font(font)
                    .lineLimit(collapsedLineLimit)
                    .truncationMode(middleTruncate ? .middle : .tail)
                    .multilineTextAlignment(alignment)
                    .foregroundColor(color)
            }
        }
        .task(id: isSelected) {
            showFull = false
            guard revealsOnSelect, isSelected else { return }
            try? await Task.sleep(for: AsyncDelayTokens.nameRevealDelay)
            guard !Task.isCancelled else { return }
            showFull = true
        }
    }

    /// One independent single-line `Text` per pre-broken line, instead of one multi-line `Text`.
    private var multilineBody: some View {
        let lines = isRevealingFull
            ? FinderStyleTruncationService.wrappedLines(name, font: nsFont, maxWidth: availableWidth)
            : displayName.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        return VStack(alignment: horizontalAlignment, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                HStack(spacing: 3) {
                    if index == 0, !tags.isEmpty {
                        TagsIndicatorView(tags: tags, dotSize: nsFont.capHeight)
                    }
                    // Natural width + clip, not .lineLimit(1), so Text can't add its own "…" on top of ours.
                    Text(line)
                        .font(font)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundColor(color)
                }
            }
        }
        .clipped()
    }
}
