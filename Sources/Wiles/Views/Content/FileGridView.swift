import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FileGridView: View {
    private static let gridIconScaleMultiplier: CGFloat = 1.25
    private static let cardWidthOffset: CGFloat = 20.0
    private static let gridSpacing: CGFloat = 20.0

    var appState: AppState

    private var iconSize: CGFloat {
        CGFloat(appState.preferences.iconSize) * Self.gridIconScaleMultiplier
    }

    private var cardWidth: CGFloat {
        iconSize + Self.cardWidthOffset
    }

    /// Icon + spacing + a genuine 2-line label, so a wrapped second line isn't clipped.
    private var cardHeight: CGFloat {
        iconSize + LayoutTokens.gridCardVStackSpacing + LayoutTokens.gridCardTwoLineLabelHeight(forIconSize: iconSize)
    }

    /// `maximum` used to be `cardWidth + 24`, letting each column stretch up to 24pt past the card's
    /// own width to fill the row evenly. Since the card content itself stays a fixed `cardWidth`,
    /// that slack just became extra empty margin around the icon — and since how much slack is left
    /// over per row depends on how many columns fit, which changes with `cardWidth`, the visual gap
    /// between icons appeared to grow/shrink as the icon-size slider moved even though `gridSpacing`
    /// itself never changed. Locking `maximum` to `cardWidth` removes the stretch entirely: any
    /// leftover row width becomes trailing margin instead of inflating the gap between icons.
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: cardWidth, maximum: cardWidth), spacing: Self.gridSpacing)]
    }

    @Environment(WindowUIState.self)
    private var windowUIState

    var body: some View {
        FileCollectionContainerView(
            appState: appState,
            coordinateSpaceName: "gridContainer",
            thumbnailIconSize: iconSize,
            cellFramesProvider: { appState.selection.gridCellFrames },
            onURLFramesChanged: { frames in appState.selection.gridCellFrames = frames },
            onLabelWidthsChanged: { widths in appState.selection.gridLabelWidths = widths },
            nonEmptyContent: { _, visibleLimit in
                gridLazyGrid(visibleLimit: visibleLimit)
            },
            overlayContent: {
                renameFieldOverlay
                revealFieldOverlay
            })
    }

    private func gridLazyGrid(visibleLimit: Binding<Int>) -> some View {
        LazyVGrid(columns: columns, spacing: Self.gridSpacing) {
            PaginatedItemsSection(
                items: appState.fileSystem.items,
                visibleLimit: visibleLimit,
                progressViewHeight: 50) { item in
                    FileGridCardItemView(
                        item: item,
                        appState: appState,
                        iconSize: iconSize,
                        cardWidth: cardWidth,
                        cardHeight: cardHeight,
                        onRightClick: {
                            if !appState.selection.selectedURLs.contains(item.url) {
                                appState.selection.selectedURLs = [item.url]
                            }
                        })
                }
        }
        .padding(16)
    }

    /// Renders the active rename field as a grid-level overlay instead of inside its card's own
    /// `LazyVGrid` cell — a `LazyVGrid` clips each cell to its allocated row height, so a field that
    /// needs to grow taller than a normal 2-line label has nowhere to actually show that growth if
    /// it lives inside the cell. Positioned using the same `URLFrameKey` frame tracking the grid
    /// already maintains for marquee-selection hit testing, so it lines up exactly over the
    /// invisible placeholder `FileGridCardItemView` leaves in the label's normal spot. Sized to the
    /// label's own last-measured width (`LabelWidthKey`) instead of always spanning the full card,
    /// so it starts out matching the collapsed label exactly and grows from there.
    @ViewBuilder private var renameFieldOverlay: some View {
        if let renameItem = windowUIState.renameItem,
           let item = appState.fileSystem.items.first(where: { $0.url == renameItem.url }),
           let cellFrame = appState.selection.gridCellFrames[renameItem.url] {
            let fontSize = LayoutTokens.gridCardLabelFontSize(forIconSize: iconSize)
            let isSel = appState.selection.selectedURLs.contains(item.url)
            // card padding + icon + VStack spacing, matching FileGridCardItemView
            let topInset: CGFloat = LayoutTokens.gridCardPadding + iconSize + LayoutTokens.gridCardVStackSpacing
            let fieldWidth = appState.selection.gridLabelWidths[renameItem.url] ?? (cardWidth - LayoutTokens.gridCardLabelHorizontalInset)

            InlineRenameField(
                item: item,
                appState: appState,
                windowUIState: windowUIState,
                font: .system(size: fontSize, weight: isSel ? .semibold : .regular),
                alignment: .center)
                .frame(width: fieldWidth, alignment: .top)
                .offset(x: cellFrame.midX - fieldWidth / 2, y: cellFrame.minY + topInset)
                .zIndex(10)
        }
    }

    /// Fully-revealed name, same clipped-cell reason and positioning as `renameFieldOverlay`.
    @ViewBuilder private var revealFieldOverlay: some View {
        if let revealURL = appState.selection.revealingFullNameURL,
           let item = appState.fileSystem.items.first(where: { $0.url == revealURL }),
           let cellFrame = appState.selection.gridCellFrames[revealURL] {
            let fontSize = LayoutTokens.gridCardLabelFontSize(forIconSize: iconSize)
            let nsFont = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
            let topInset: CGFloat = LayoutTokens.gridCardPadding + iconSize + LayoutTokens.gridCardVStackSpacing
            let textAvailableWidth = cardWidth - LayoutTokens.gridCardLabelHorizontalInset
            let lines = FinderStyleTruncationService.wrappedLines(item.name, font: nsFont, maxWidth: textAvailableWidth)

            VStack(spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    // Natural width + clip, not .lineLimit(1) — see SelectionAwareNameText.multilineBody.
                    Text(line)
                        .font(.system(size: fontSize, weight: .semibold))
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundColor(.white)
                }
            }
            .frame(width: textAvailableWidth)
            .clipped()
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentColor)
            .cornerRadius(4)
            // Center on cardWidth (the pill's true post-padding width), not the narrower text width.
            .offset(x: cellFrame.midX - cardWidth / 2, y: cellFrame.minY + topInset)
            .zIndex(10)
            .allowsHitTesting(false)
        }
    }
}
