import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FileGridView: View {
    var appState: AppState

    private var iconSize: CGFloat {
        CGFloat(appState.preferences.iconSize) * LayoutTokens.gridIconScaleMultiplier
    }

    private var cardWidth: CGFloat {
        iconSize + LayoutTokens.cardWidthOffset
    }

    private var cardHeight: CGFloat {
        iconSize + LayoutTokens.cardHeightOffset
    }

    /// `maximum` used to be `cardWidth + 24`, letting each column stretch up to 24pt past the card's
    /// own width to fill the row evenly. Since the card content itself stays a fixed `cardWidth`,
    /// that slack just became extra empty margin around the icon — and since how much slack is left
    /// over per row depends on how many columns fit, which changes with `cardWidth`, the visual gap
    /// between icons appeared to grow/shrink as the icon-size slider moved even though `gridSpacing`
    /// itself never changed. Locking `maximum` to `cardWidth` removes the stretch entirely: any
    /// leftover row width becomes trailing margin instead of inflating the gap between icons.
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: cardWidth, maximum: cardWidth), spacing: LayoutTokens.gridSpacing)]
    }

    @Environment(WindowUIState.self)
    private var windowUIState
    @State private var selectionRect: CGRect?
    @State private var visibleLimit: Int = LayoutTokens.paginationThreshold

    var body: some View {
        GeometryReader { geometry in
            gridScrollArea(geometry: geometry)
        }
    }

    private func gridScrollArea(geometry: GeometryProxy) -> some View {
        ScrollViewReader { proxy in
            gridScrollViewReaderContent(geometry: geometry, proxy: proxy)
        }
        .background(BackgroundContextMenuLayer(appState: appState))
        .background(ScrollerAutoHideSetter())
    }

    private func gridScrollViewReaderContent(geometry: GeometryProxy, proxy: ScrollViewProxy) -> some View {
        ScrollView {
            gridScrollViewBody(geometry: geometry)
        }
        .resetPaginationAndPrefetchThumbnails(appState: appState, visibleLimit: $visibleLimit, thumbnailIconSize: iconSize)
        .scrollToTopOnRenameOrSearchClear(appState: appState, proxy: proxy)
        .scrollToLastMovedSelection(appState: appState, proxy: proxy)
        .background(ScrollerAutoHideSetter())
    }

    private func gridScrollViewBody(geometry: GeometryProxy) -> some View {
        ZStack(alignment: .topLeading) {
            gridZStackContent
        }
        .coordinateSpace(name: "gridContainer")
        .onPreferenceChange(URLFrameKey.self) { frames in
            appState.selection.gridCellFrames = frames
        }
        .onPreferenceChange(LabelWidthKey.self) { widths in
            appState.selection.gridLabelWidths = widths
        }
        .frame(minHeight: geometry.size.height - LayoutTokens.scrollbarReservedThickness, alignment: .topLeading)
        .background(ScrollerAutoHideSetter())
    }

    @ViewBuilder private var gridZStackContent: some View {
        Color.clear.frame(height: 1).id("top")

        SelectionRectangleOverlay(
            appState: appState,
            coordinateSpaceName: "gridContainer",
            selectionRect: $selectionRect,
            cellFramesProvider: { appState.selection.gridCellFrames })

        Group {
            gridItemsGroup
        }
        .id(appState.navigation.currentURL)
        .transition(.opacity)

        SelectionRectangleOverlay.rectangleOverlay(selectionRect)

        renameFieldOverlay
    }

    @ViewBuilder private var gridItemsGroup: some View {
        if appState.fileSystem.items.isEmpty, !appState.fileSystem.isLoading {
            EmptyDirectoryView(appState: appState)
        } else {
            gridLazyGrid
        }
    }

    private var gridLazyGrid: some View {
        let paginate = appState.fileSystem.items.count > LayoutTokens.paginationThreshold
        let visibleItems = paginate ? Array(appState.fileSystem.items.prefix(visibleLimit)) : appState.fileSystem.items

        return LazyVGrid(columns: columns, spacing: LayoutTokens.gridSpacing) {
            gridItems(visibleItems: visibleItems, paginate: paginate)
        }
        .padding(16)
    }

    @ViewBuilder
    private func gridItems(visibleItems: [FileItem], paginate: Bool) -> some View {
        ForEach(visibleItems) { item in
            FileGridCardItemView(
                item: item,
                appState: appState,
                iconSize: iconSize,
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                onRightClick: {
                    if !appState.selectedURLs.contains(item.url) {
                        appState.selectedURLs = [item.url]
                    }
                })
                .transition(.opacity)
        }
        .animation(paginate ? nil : MotionTokens.smoothEase, value: visibleItems.map(\.url))
        if paginate, visibleLimit < appState.fileSystem.items.count {
            ProgressView()
                .frame(height: 50)
                .onAppear {
                    visibleLimit = min(appState.fileSystem.items.count, visibleLimit + LayoutTokens.lazyLoadingBatchSize)
                }
        }
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
            let fontSize = max(8.0, min(12.0, Double(iconSize) * 0.22))
            let isSel = appState.selectedURLs.contains(item.url)
            let topInset: CGFloat = 6 + iconSize + 6 // card padding + icon + VStack spacing, matching FileGridCardItemView
            let fieldWidth = appState.selection.gridLabelWidths[renameItem.url] ?? (cardWidth - 12)

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
}
