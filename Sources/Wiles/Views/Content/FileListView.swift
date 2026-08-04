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

    @State private var cellFrames: [URL: CGRect] = [:]
    @State private var selectionRect: CGRect?
    @State private var dragStartPoint: CGPoint?
    @State private var lastWindowWidth: CGFloat?
    @State private var visibleLimit: Int = LayoutTokens.lazyLoadingBatchSize
    @State private var hoveredURL: URL?

    var body: some View {
        let visibleItems = Array(appState.items.prefix(visibleLimit))
        return GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    ScrollView(.horizontal) {
                    ZStack(alignment: .topLeading) {
                            Color.clear.frame(height: 1).id("top")
                            Color(NSColor.controlBackgroundColor).opacity(0.001)
                            .frame(minWidth: geometry.size.width - LayoutTokens.scrollbarReservedThickness)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 2, coordinateSpace: .named("listContainer"))
                                    .onChanged { gesture in
                                        let start = dragStartPoint ?? gesture.startLocation
                                        if dragStartPoint == nil { dragStartPoint = start }

                                        let minX = min(start.x, gesture.location.x)
                                        let minY = min(start.y, gesture.location.y)
                                        let maxX = max(start.x, gesture.location.x)
                                        let maxY = max(start.y, gesture.location.y)
                                        let rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

                                        self.selectionRect = rect

                                        var matched = Set<URL>()
                                        for (url, frame) in cellFrames where frame.intersects(rect) {
                                            matched.insert(url)
                                        }
                                        if NSEvent.modifierFlags.contains(.command) {
                                            appState.selectedURLs.formUnion(matched)
                                        } else {
                                            appState.selectedURLs = matched
                                        }
                                    }
                                    .onEnded { _ in
                                        selectionRect = nil
                                        dragStartPoint = nil
                                    }
                            )
                            .onTapGesture {
                                appState.selectedURLs.removeAll()
                            }
                            .overlay(
                                RightClickDetector {
                                    appState.selectedURLs.removeAll()
                                }
                            )
                            .contextMenu {
                                SharedBackgroundContextMenu(appState: appState)
                            }

                        Group {
                            if appState.items.isEmpty && !appState.isLoading {
                                emptyStateView
                            } else {
                                VStack(spacing: 0) {
                                    tableHeader
    
                                    LazyVStack(spacing: 2) {
                                        ForEach(visibleItems) { item in
                                            listRow(for: item)
                                        }
                                        if visibleLimit < appState.items.count {
                                            ProgressView()
                                                .frame(height: 30)
                                                .onAppear {
                                                    visibleLimit = min(appState.items.count, visibleLimit + LayoutTokens.lazyLoadingBatchSize)
                                                    let nextBatch = Array(appState.items.prefix(min(appState.items.count, visibleLimit + LayoutTokens.lazyLoadingBatchSize)))
                                                    ThumbnailService.shared.prefetchThumbnails(for: nextBatch, size: 36)
                                                }
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.bottom, 10)
                                }
                                .frame(width: max(geometry.size.width, totalColumnsWidth), alignment: .leading)
                            }
                        }
                        .id(appState.currentURL)
                        .transition(.opacity)

                        if let rect = selectionRect {
                            Rectangle()
                                .fill(Color.accentColor.opacity(0.15))
                                .overlay(Rectangle().stroke(Color.accentColor, lineWidth: 1.5))
                                .frame(width: rect.width, height: rect.height)
                                .offset(x: rect.minX, y: rect.minY)
                                .allowsHitTesting(false)
                        }
                    }
                .coordinateSpace(name: "listContainer")
                .onPreferenceChange(ListCellFrameKey.self) { frames in
                    self.cellFrames = frames
                }
                .frame(minHeight: geometry.size.height - LayoutTokens.scrollbarReservedThickness, alignment: .topLeading)
                .background(ScrollerAutoHideSetter())
                }
            }
            .onChange(of: appState.items) { _, _ in
                visibleLimit = LayoutTokens.lazyLoadingBatchSize
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
                adjustNameColumnWidth(for: newWidth)
                lastWindowWidth = newWidth
            }
            .onAppear {
                lastWindowWidth = geometry.size.width
                adjustNameColumnWidth(for: geometry.size.width)
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

    private var tableHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(visibleColumns.enumerated()), id: \.element) { _, col in
                headerCell(columnTitle(col), option: sortOption(for: col), isLeading: col == .name)
                    .frame(width: appState.columnWidth(for: col), alignment: col == .name ? .leading : .trailing)
                    .overlay(alignment: .trailing) {
                        ColumnResizeHandle(column: col, appState: appState)
                            .offset(x: 4)
                    }
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundColor(.secondary)
        .padding(.horizontal, 22)
        .frame(height: 30)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.08))
        .clipped()
        .contextMenu { columnVisibilityMenu }
    }

    /// Columns currently set to visible, in canonical order.
    private var visibleColumns: [ListColumn] {
        ListColumn.allCases.filter { appState.isColumnVisible($0) }
    }

    private var totalColumnsWidth: CGFloat {
        visibleColumns.map { appState.columnWidth(for: $0) }.reduce(0, +) + 44
    }

    private func adjustNameColumnWidth(for containerWidth: CGFloat) {
        let otherWidths = visibleColumns.filter { $0 != .name }.map { appState.columnWidth(for: $0) }.reduce(0, +) + 44
        let targetNameWidth = max(LayoutTokens.columnMinWidth, containerWidth - otherWidths)
        if abs(appState.columnWidth(for: .name) - targetNameWidth) > 1 {
            appState.setColumnWidth(.name, width: targetNameWidth)
        }
    }

    private func columnTitle(_ col: ListColumn) -> String {
        switch col {
        case .name:         return appState.tr(.name)
        case .size:         return appState.tr(.size)
        case .dateModified: return appState.tr(.dateModified)
        case .dateCreated:  return appState.tr(.created)
        case .dateAccessed: return appState.tr(.lastOpened)
        case .kind:         return appState.tr(.kind)
        case .owner:        return appState.tr(.owner)
        case .group:        return appState.tr(.group)
        }
    }

    private func headerCell(_ title: String, option: SortOption, isLeading: Bool) -> some View {
        Button {
            if appState.sortOption == option {
                appState.sortAscending.toggle()
            } else {
                appState.sortOption = option
                appState.sortAscending = true
            }
            appState.refreshCurrentDirectory()
        } label: {
            HStack(spacing: 4) {
                Text(title)
                if appState.sortOption == option {
                    Image(systemName: appState.sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
            }
            .padding(.trailing, isLeading ? 0 : 4)
        }
        .buttonStyle(.plain)
    }

    private func sortOption(for col: ListColumn) -> SortOption {
        switch col {
        case .name:         return .name
        case .size:         return .size
        case .dateModified: return .dateModified
        case .dateCreated:  return .dateCreated
        case .dateAccessed: return .dateAccessed
        case .kind:         return .kind
        case .owner:        return .owner
        case .group:        return .group
        }
    }

    @ViewBuilder private var columnVisibilityMenu: some View {
        ForEach(ListColumn.allCases.filter { !$0.isAlwaysVisible }, id: \.self) { col in
            Button { appState.toggleColumnVisibility(col) } label: {
                HStack {
                    Text(columnTitle(col))
                    Spacer()
                    if appState.isColumnVisible(col) {
                        Image(systemName: "checkmark")
                    }
                }
            }
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
        max(LayoutTokens.listIconMinSize, min(LayoutTokens.listIconMaxSize, CGFloat(appState.iconSize) * LayoutTokens.listIconScaleMultiplier))
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
            FileItemIconView(item: item, size: listIconSize)
            ICloudStatusBadgeView(item: item)
            Text(item.name)
                .font(.system(size: 13, weight: isSel ? .semibold : .regular))
                .lineLimit(1)
                .foregroundColor(isSel ? .white : .primary)

            if appState.showTags && !item.tags.isEmpty {
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

            ForEach(visibleColumns, id: \.self) { col in
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
        .rowInteractions(item: item, appState: appState, dragProvider: { dragProvider(for: item) })
    }
}

private struct FileRowInteractionsModifier: ViewModifier {
    let item: FileItem
    var appState: AppState
    let dragProvider: () -> NSItemProvider

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
            .springLoadedFolder(folderURL: item.url, isDirectory: item.isDirectory, appState: appState)
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
    func rowInteractions(item: FileItem, appState: AppState, dragProvider: @escaping () -> NSItemProvider) -> some View {
        modifier(FileRowInteractionsModifier(item: item, appState: appState, dragProvider: dragProvider))
    }
}
