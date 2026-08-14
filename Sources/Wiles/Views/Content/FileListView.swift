import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct FileListView: View {
    var appState: AppState

    @Environment(WindowUIState.self)
    private var windowUIState
    @State private var selectionRect: CGRect?
    @State private var lastWindowWidth: CGFloat?
    @State private var hoveredURL: URL?
    @State private var dropTargetedURL: URL?
    @State private var visibleLimit: Int = LayoutTokens.paginationThreshold

    var body: some View {
        GeometryReader { geometry in
            listScrollArea(geometry: geometry)
        }
    }

    @ViewBuilder
    private func listScrollArea(geometry: GeometryProxy) -> some View {
        ScrollViewReader { proxy in
            listScrollViewReaderContent(geometry: geometry, proxy: proxy)
        }
        .onChange(of: geometry.size.width) { _, newWidth in
            FileListHeaderView.adjustNameColumnWidth(for: newWidth, appState: appState)
            lastWindowWidth = newWidth
        }
        .onAppear {
            lastWindowWidth = geometry.size.width
            FileListHeaderView.adjustNameColumnWidth(for: geometry.size.width, appState: appState)
        }
        .background(BackgroundContextMenuLayer(appState: appState))
    }

    @ViewBuilder
    private func listScrollViewReaderContent(geometry: GeometryProxy, proxy: ScrollViewProxy) -> some View {
        ScrollView([.horizontal, .vertical]) {
            listScrollViewBody(geometry: geometry)
        }
        .resetPaginationAndPrefetchThumbnails(appState: appState, visibleLimit: $visibleLimit, thumbnailIconSize: 36)
        .scrollToTopOnRenameOrSearchClear(appState: appState, proxy: proxy)
        .scrollToLastMovedSelection(appState: appState, proxy: proxy)
        .background(ScrollerAutoHideSetter())
    }

    @ViewBuilder
    private func listScrollViewBody(geometry: GeometryProxy) -> some View {
        ZStack(alignment: .topLeading) {
            listZStackContent(geometry: geometry)
        }
        .coordinateSpace(name: "listContainer")
        .onPreferenceChange(URLFrameKey.self) { frames in
            appState.selection.listCellFrames = frames
        }
        .frame(minHeight: geometry.size.height - LayoutTokens.scrollbarReservedThickness, alignment: .topLeading)
        .background(ScrollerAutoHideSetter())
    }

    @ViewBuilder
    private func listZStackContent(geometry: GeometryProxy) -> some View {
        Color.clear.frame(height: 1).id("top")
        SelectionRectangleOverlay(
            appState: appState,
            coordinateSpaceName: "listContainer",
            minWidth: geometry.size.width - LayoutTokens.scrollbarReservedThickness,
            selectionRect: $selectionRect,
            cellFramesProvider: { appState.selection.listCellFrames }
        )

        Group {
            listItemsGroup(geometry: geometry)
        }
        .id(appState.navigation.currentURL)
        .transition(.opacity)

        SelectionRectangleOverlay.rectangleOverlay(selectionRect)
    }

    @ViewBuilder
    private func listItemsGroup(geometry: GeometryProxy) -> some View {
        if appState.fileSystem.items.isEmpty && !appState.fileSystem.isLoading {
            EmptyDirectoryView(appState: appState)
        } else {
            listVStackContent
                .frame(width: max(geometry.size.width, FileListHeaderView.totalColumnsWidth(appState)), alignment: .leading)
        }
    }

    private var listVStackContent: some View {
        VStack(spacing: 0) {
            FileListHeaderView(appState: appState)
            listLazyVStack
        }
    }

    private var listLazyVStack: some View {
        let paginate = appState.fileSystem.items.count > LayoutTokens.paginationThreshold
        let visibleItems = paginate ? Array(appState.fileSystem.items.prefix(visibleLimit)) : appState.fileSystem.items

        return LazyVStack(spacing: 2) {
            listRows(visibleItems: visibleItems, paginate: paginate)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private func listRows(visibleItems: [FileItem], paginate: Bool) -> some View {
        ForEach(visibleItems) { item in
            listRow(for: item)
                .transition(.opacity)
        }
        .animation(paginate ? nil : MotionTokens.smoothEase, value: visibleItems.map(\.url))
        if paginate && visibleLimit < appState.fileSystem.items.count {
            ProgressView()
                .frame(height: 30)
                .onAppear {
                    visibleLimit = min(appState.fileSystem.items.count, visibleLimit + LayoutTokens.lazyLoadingBatchSize)
                }
        }
    }

    private var listIconSize: CGFloat {
        max(LayoutTokens.listIconMinSize, min(LayoutTokens.listIconMaxSize, CGFloat(appState.preferences.iconSize) * LayoutTokens.listIconScaleMultiplier))
    }

    private func dynamicColumnText(_ col: ListColumn, for item: FileItem) -> String? {
        switch col {
        case .size: return item.formattedSize
        case .dateModified: return item.formattedDate
        case .dateCreated: return item.formattedDateCreated
        case .dateAccessed: return item.formattedDateAccessed
        case .kind: return item.isDirectory ? appState.tr(.folder) : item.fileExtension.uppercased()
        case .owner: return item.ownerName
        case .group: return item.groupName
        case .name: return nil
        }
    }

    @ViewBuilder
    private func dynamicColumn(_ col: ListColumn, for item: FileItem, isSel: Bool) -> some View {
        if let text = dynamicColumnText(col, for: item) {
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(isSel ? .white.opacity(0.8) : .secondary)
                .padding(.trailing, 4)
                .frame(width: appState.columnWidth(for: col), alignment: .trailing)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func nameCell(for item: FileItem, isSel: Bool) -> some View {
        HStack(alignment: .center, spacing: 8) {
            FileItemIconView(item: item, size: listIconSize, isOpenTargeted: dropTargetedURL == item.url)
            ICloudStatusBadgeView(item: item)
            nameOrRenameField(for: item, isSel: isSel)
            tagsIndicator(for: item)
        }
        .frame(width: appState.columnWidth(for: .name), alignment: .leading)
    }

    @ViewBuilder
    private func nameOrRenameField(for item: FileItem, isSel: Bool) -> some View {
        if windowUIState.renameItem?.url == item.url {
            InlineRenameField(item: item, appState: appState, windowUIState: windowUIState, font: .system(size: 13, weight: isSel ? .semibold : .regular))
        } else {
            SelectionAwareNameText(
                name: item.name,
                isSelected: isSel,
                font: .system(size: 13, weight: isSel ? .semibold : .regular),
                nsFont: .systemFont(ofSize: 13, weight: isSel ? .semibold : .regular),
                color: isSel ? .white : .primary,
                collapsedLineLimit: 1,
                middleTruncate: appState.preferences.middleTruncateNames
            )
        }
    }

    @ViewBuilder
    private func tagsIndicator(for item: FileItem) -> some View {
        if appState.preferences.showTags && !item.tags.isEmpty {
            HStack(alignment: .center, spacing: -2) {
                ForEach(item.tags, id: \.self) { tag in
                    Circle()
                        .fill(colorForTag(tag))
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(Color(NSColor.windowBackgroundColor), lineWidth: 1))
                }
            }
            .offset(y: appState.isCompactMode ? 1 : 0)
        }
    }

    private func listRow(for item: FileItem) -> some View {
        let isSel = appState.selectedURLs.contains(item.url)
        let isCut = appState.clipboard?.isCut(url: item.url) ?? false

        return HStack(spacing: 0) {
            nameCell(for: item, isSel: isSel)

            ForEach(FileListHeaderView.visibleColumns(appState), id: \.self) { col in
                if col != .name {
                    dynamicColumn(col, for: item, isSel: isSel)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, appState.isCompactMode ? 2 : max(4, listIconSize * 0.25))
        .hoverHighlight(isSelected: isSel, cornerRadius: 6)
        .opacity(isCut ? 0.5 : 1.0)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: URLFrameKey.self, value: [item.url: geo.frame(in: .named("listContainer"))])
            }
        )
        .contentShape(Rectangle())
        .accessibilityLabel(item.name)
        .accessibilityHint(item.isDirectory ? appState.tr(.folder) : appState.tr(.open))
        .accessibilityAddTraits(isSel ? [.isButton, .isSelected] : [.isButton])
        .accessibilityValue(item.formattedSize)
        .fileItemInteractions(
            item: item,
            appState: appState,
            onTargetedChanged: { targeted in dropTargetedURL = targeted ? item.url : nil }
        )
    }
}
