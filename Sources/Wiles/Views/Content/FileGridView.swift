import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct FileGridView: View {
    var appState: AppState

    private var iconSize: CGFloat { CGFloat(appState.preferences.iconSize) * LayoutTokens.gridIconScaleMultiplier }
    private var cardWidth: CGFloat { iconSize + LayoutTokens.cardWidthOffset }
    private var cardHeight: CGFloat { iconSize + LayoutTokens.cardHeightOffset }
    // `maximum` used to be `cardWidth + 24`, letting each column stretch up to 24pt past the card's
    // own width to fill the row evenly. Since the card content itself stays a fixed `cardWidth`,
    // that slack just became extra empty margin around the icon — and since how much slack is left
    // over per row depends on how many columns fit, which changes with `cardWidth`, the visual gap
    // between icons appeared to grow/shrink as the icon-size slider moved even though `gridSpacing`
    // itself never changed. Locking `maximum` to `cardWidth` removes the stretch entirely: any
    // leftover row width becomes trailing margin instead of inflating the gap between icons.
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: cardWidth, maximum: cardWidth), spacing: LayoutTokens.gridSpacing)]
    }

    @State private var selectionRect: CGRect?
    @State private var visibleLimit: Int = LayoutTokens.paginationThreshold

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        Color.clear.frame(height: 1).id("top")

                        SelectionRectangleOverlay(
                            appState: appState,
                            coordinateSpaceName: "gridContainer",
                            selectionRect: $selectionRect
                        )

                        Group {
                            if appState.fileSystem.items.isEmpty && !appState.fileSystem.isLoading {
                                EmptyDirectoryView(appState: appState)
                            } else {
                                let paginate = appState.fileSystem.items.count > LayoutTokens.paginationThreshold
                                let visibleItems = paginate ? Array(appState.fileSystem.items.prefix(visibleLimit)) : appState.fileSystem.items

                                LazyVGrid(columns: columns, spacing: LayoutTokens.gridSpacing) {
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
                                            }
                                        )
                                        .transition(.opacity)
                                    }
                                    .animation(paginate ? nil : MotionTokens.smoothEase, value: visibleItems.map(\.url))
                                    if paginate && visibleLimit < appState.fileSystem.items.count {
                                        ProgressView()
                                            .frame(height: 50)
                                            .onAppear {
                                                visibleLimit = min(appState.fileSystem.items.count, visibleLimit + LayoutTokens.lazyLoadingBatchSize)
                                            }
                                    }
                                }
                                .padding(16)
                                .onAppear {
                                    if appState.fileSystem.items.count > 500 {
                                        ThumbnailService.shared.prefetchThumbnails(for: appState.fileSystem.items, size: iconSize)
                                    }
                                }
                            }
                        }
                        .id(appState.navigation.currentURL)
                        .transition(.opacity)

                        SelectionRectangleOverlay.rectangleOverlay(selectionRect)
                    }
                    .coordinateSpace(name: "gridContainer")
                    .onPreferenceChange(CellFrameKey.self) { frames in
                        appState.selection.gridCellFrames = frames
                    }
                    .frame(minHeight: geometry.size.height - LayoutTokens.scrollbarReservedThickness, alignment: .topLeading)
                    .background(ScrollerAutoHideSetter())
                }
                .onChange(of: appState.navigation.currentURL) { _, _ in
                    visibleLimit = LayoutTokens.paginationThreshold
                }
                .onChange(of: appState.fileSystem.items) { _, newItems in
                    if newItems.count > 500 {
                        ThumbnailService.shared.prefetchThumbnails(for: newItems, size: iconSize)
                    }
                }
                .onChange(of: appState.searchQuery) { _, newValue in
                    if newValue.isEmpty {
                        withAnimation(MotionTokens.mediumEase) {
                            proxy.scrollTo("top", anchor: .top)
                        }
                    }
                }
                .background(ScrollerAutoHideSetter())
            }
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .overlay(
                        RightClickDetector {
                            appState.selectedURLs.removeAll()
                        }
                    )
                    .contextMenu {
                        SharedBackgroundContextMenu(appState: appState)
                    }
            )
            .background(ScrollerAutoHideSetter())
        }
    }
}
