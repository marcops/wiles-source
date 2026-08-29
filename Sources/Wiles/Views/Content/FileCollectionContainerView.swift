import SwiftUI

/// Shared scroll/selection/pagination/dataset-replacement scaffolding for both file-collection
/// browsing modes — `FileGridView`'s grid and `FileListView`'s list. Both used to duplicate this
/// entire orchestration (`GeometryReader` → `ScrollViewReader` → `ScrollView` → `ZStack` with a
/// `"top"` anchor + `SelectionRectangleOverlay` → `.coordinateSpace` →
/// `.onPreferenceChange(URLFrameKey.self)` → `.id(appState.navigation.currentURL)`/
/// `.transition(.opacity)` → the same pagination-reset/scroll-to-top/scroll-to-last-moved-selection
/// modifier chain) top to bottom; only the leaf renderer (grid cells vs. list rows) and a handful of
/// genuinely mode-specific knobs actually differ, and those are the parameters below.
struct FileCollectionContainerView<ItemsGroup: View, Overlay: View>: View {
    var appState: AppState
    let coordinateSpaceName: String
    var scrollAxes: Axis.Set = .vertical
    let thumbnailIconSize: CGFloat
    /// List needs its selection rectangle to span the full scroll width even past the last column;
    /// grid has no such need. `nil` (grid's default) omits `SelectionRectangleOverlay`'s `minWidth`
    /// entirely, matching its previous unconstrained behavior exactly.
    var selectionRectMinWidth: ((GeometryProxy) -> CGFloat)?
    let cellFramesProvider: () -> [URL: CGRect]
    let onURLFramesChanged: ([URL: CGRect]) -> Void
    /// Grid-only: it separately tracks each card's measured label width (`LabelWidthKey`) to size
    /// the rename-field overlay. List has no equivalent.
    var onLabelWidthsChanged: (([URL: CGFloat]) -> Void)?
    /// List-only: re-derives its header column widths whenever the available width changes.
    var onGeometryWidthChange: ((CGFloat) -> Void)?
    @ViewBuilder let nonEmptyContent: (GeometryProxy, Binding<Int>) -> ItemsGroup
    @ViewBuilder let overlayContent: () -> Overlay

    @State private var selectionRect: CGRect?
    @State private var visibleLimit: Int = LayoutTokens.paginationThreshold

    var body: some View {
        GeometryReader { geometry in
            scrollArea(geometry: geometry)
        }
    }

    private func scrollArea(geometry: GeometryProxy) -> some View {
        ScrollViewReader { proxy in
            scrollViewReaderContent(geometry: geometry, proxy: proxy)
        }
        .onChange(of: geometry.size.width) { _, newWidth in
            onGeometryWidthChange?(newWidth)
        }
        .onAppear {
            onGeometryWidthChange?(geometry.size.width)
        }
        .background(BackgroundContextMenuLayer(appState: appState))
    }

    private func scrollViewReaderContent(geometry: GeometryProxy, proxy: ScrollViewProxy) -> some View {
        ScrollView(scrollAxes) {
            scrollViewBody(geometry: geometry)
        }
        .resetPaginationAndPrefetchThumbnails(appState: appState, visibleLimit: $visibleLimit, thumbnailIconSize: thumbnailIconSize)
        .scrollToTopOnRenameOrSearchClear(appState: appState, proxy: proxy)
        .scrollToLastMovedSelection(appState: appState, proxy: proxy)
    }

    private func scrollViewBody(geometry: GeometryProxy) -> some View {
        ZStack(alignment: .topLeading) {
            zStackContent(geometry: geometry)
        }
        .coordinateSpace(name: coordinateSpaceName)
        .onPreferenceChange(URLFrameKey.self) { frames in
            onURLFramesChanged(frames)
        }
        .onPreferenceChange(LabelWidthKey.self) { widths in
            onLabelWidthsChanged?(widths)
        }
        .frame(minHeight: geometry.size.height - LayoutTokens.scrollbarReservedThickness, alignment: .topLeading)
        .background(ScrollerAutoHideSetter())
    }

    @ViewBuilder
    private func zStackContent(geometry: GeometryProxy) -> some View {
        Color.clear.frame(height: 1).id("top")

        SelectionRectangleOverlay(
            appState: appState,
            coordinateSpaceName: coordinateSpaceName,
            minWidth: selectionRectMinWidth?(geometry),
            selectionRect: $selectionRect,
            cellFramesProvider: cellFramesProvider)

        Group {
            itemsGroup(geometry: geometry)
        }
        .id(appState.navigation.currentURL)
        .transition(.opacity)

        SelectionRectangleOverlay.rectangleOverlay(selectionRect)

        overlayContent()
    }

    @ViewBuilder
    private func itemsGroup(geometry: GeometryProxy) -> some View {
        if appState.fileSystem.items.isEmpty, !appState.fileSystem.isLoading {
            EmptyDirectoryView(appState: appState)
        } else {
            nonEmptyContent(geometry, $visibleLimit)
        }
    }
}
