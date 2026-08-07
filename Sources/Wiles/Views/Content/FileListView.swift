import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ListCellFrameKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: [URL: CGRect] = [:]
    static func reduce(value: inout [URL: CGRect], nextValue: () -> [URL: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

struct FileListView: View {
    var appState: AppState

    @State private var selectionRect: CGRect?
    @State private var lastWindowWidth: CGFloat?
    @State private var hoveredURL: URL?
    @State private var dropTargetedURL: URL?
    @State private var visibleLimit: Int = LayoutTokens.paginationThreshold

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    ZStack(alignment: .topLeading) {
                            Color.clear.frame(height: 1).id("top")
                            SelectionRectangleOverlay(
                                appState: appState,
                                coordinateSpaceName: "listContainer",
                                minWidth: geometry.size.width - LayoutTokens.scrollbarReservedThickness,
                                selectionRect: $selectionRect
                            )

                        Group {
                            if appState.fileSystem.items.isEmpty && !appState.fileSystem.isLoading {
                                emptyStateView
                            } else {
                                VStack(spacing: 0) {
                                    FileListHeaderView(appState: appState)

                                    LazyVStack(spacing: 2) {
                                        let paginate = appState.fileSystem.items.count > LayoutTokens.paginationThreshold
                                        let visibleItems = paginate ? Array(appState.fileSystem.items.prefix(visibleLimit)) : appState.fileSystem.items

                                        ForEach(visibleItems) { item in
                                            listRow(for: item)
                                        }
                                        if paginate && visibleLimit < appState.fileSystem.items.count {
                                            ProgressView()
                                                .frame(height: 30)
                                                .onAppear {
                                                    visibleLimit = min(appState.fileSystem.items.count, visibleLimit + LayoutTokens.lazyLoadingBatchSize)
                                                }
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.bottom, 10)
                                    .onAppear {
                                        if appState.fileSystem.items.count > 500 {
                                            ThumbnailService.shared.prefetchThumbnails(for: appState.fileSystem.items, size: 36)
                                        }
                                    }
                                }
                                .frame(width: max(geometry.size.width, FileListHeaderView.totalColumnsWidth(appState)), alignment: .leading)
                            }
                        }
                        .id(appState.navigation.currentURL)
                        .transition(.opacity)

                        SelectionRectangleOverlay.rectangleOverlay(selectionRect)
                    }
                .coordinateSpace(name: "listContainer")
                .onPreferenceChange(ListCellFrameKey.self) { frames in
                    appState.selection.listCellFrames = frames
                }
                .frame(minHeight: geometry.size.height - LayoutTokens.scrollbarReservedThickness, alignment: .topLeading)
                .background(ScrollerAutoHideSetter())
                }
            .onChange(of: appState.navigation.currentURL) { _, _ in
                visibleLimit = LayoutTokens.paginationThreshold
            }
            .onChange(of: appState.fileSystem.items) { _, newItems in
                if newItems.count > 500 {
                    ThumbnailService.shared.prefetchThumbnails(for: newItems, size: 36)
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
            .onChange(of: geometry.size.width) { _, newWidth in
                FileListHeaderView.adjustNameColumnWidth(for: newWidth, appState: appState)
                lastWindowWidth = newWidth
            }
            .onAppear {
                lastWindowWidth = geometry.size.width
                FileListHeaderView.adjustNameColumnWidth(for: geometry.size.width, appState: appState)
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
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 80)
            Image(systemName: appState.isSearching ? "magnifyingglass" : "folder")
                .font(.system(size: 48)).foregroundColor(.secondary.opacity(0.5))
            Text(appState.isSearching ? appState.tr(.noResultsFound) : appState.tr(.folderIsEmpty))
                .font(.system(size: 16, weight: .medium)).foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 300)
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
            SelectionAwareNameText(
                name: item.name,
                isSelected: isSel,
                font: .system(size: 13, weight: isSel ? .semibold : .regular),
                color: isSel ? .white : .primary,
                collapsedLineLimit: 1
            )

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
        .frame(width: appState.columnWidth(for: .name), alignment: .leading)
    }

    private func dragProvider(for item: FileItem) -> NSItemProvider {
        if !appState.selectedURLs.contains(item.url) {
            appState.selectedURLs = [item.url]
        }
        let provider = NSItemProvider()
        for fileURL in appState.selectedURLs {
            provider.registerObject(fileURL as NSURL, visibility: .all)
        }
        return provider
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
                Color.clear.preference(key: ListCellFrameKey.self, value: [item.url: geo.frame(in: .named("listContainer"))])
            }
        )
        .contentShape(Rectangle())
        .accessibilityLabel(item.name)
        .accessibilityHint(item.isDirectory ? appState.tr(.folder) : appState.tr(.open))
        .accessibilityAddTraits(isSel ? [.isButton, .isSelected] : [.isButton])
        .accessibilityValue(item.formattedSize)
        .rowInteractions(item: item, appState: appState, dragProvider: { dragProvider(for: item) }, onTargetedChanged: { targeted in
            dropTargetedURL = targeted ? item.url : nil
        })
    }
}

private struct FileRowInteractionsModifier: ViewModifier {
    let item: FileItem
    var appState: AppState
    let dragProvider: () -> NSItemProvider
    var onTargetedChanged: (Bool) -> Void = { _ in }

    func body(content: Content) -> some View {
        content
            .onTapGesture(count: 2) {
                appState.navigateTo(item.url)
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    appState.handleSelection(for: item)
                }
            )
            .onDrag(dragProvider)
            .springLoadedFolder(folderURL: item.url, isDirectory: item.isDirectory, appState: appState, onTargetedChanged: onTargetedChanged)
            .overlay(
                RightClickDetector {
                    if !appState.selectedURLs.contains(item.url) {
                        appState.selectedURLs = [item.url]
                    }
                }
            )
            .fileItemContextMenu(for: item, appState: appState)
    }
}

private extension View {
    func rowInteractions(
        item: FileItem,
        appState: AppState,
        dragProvider: @escaping () -> NSItemProvider,
        onTargetedChanged: @escaping (Bool) -> Void = { _ in }
    ) -> some View {
        modifier(FileRowInteractionsModifier(item: item, appState: appState, dragProvider: dragProvider, onTargetedChanged: onTargetedChanged))
    }
}
