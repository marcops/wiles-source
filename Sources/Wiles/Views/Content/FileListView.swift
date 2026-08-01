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
    @State private var selectionRect: CGRect? = nil
    @State private var dragStartPoint: CGPoint? = nil
    @State private var lastWindowWidth: CGFloat? = nil

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical) {
                ScrollView(.horizontal) {
                ZStack(alignment: .topLeading) {
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
                                        for (url, frame) in cellFrames {
                                            if frame.intersects(rect) {
                                                matched.insert(url)
                                            }
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

                        if appState.items.isEmpty && !appState.isLoading {
                            emptyStateView
                        } else {
                            VStack(spacing: 0) {
                                tableHeader
                                
                                LazyVStack(spacing: 2) {
                                    ForEach(appState.items) { item in
                                        listRow(for: item)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.bottom, 10)
                            }
                            .frame(width: max(geometry.size.width, totalColumnsWidth), alignment: .leading)
                        }

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
            .background(ScrollerAutoHideSetter())
            .onChange(of: geometry.size.width) { oldWidth, newWidth in
                if let last = lastWindowWidth {
                    let diff = newWidth - last
                    if diff != 0 {
                        let currentName = appState.columnWidth(for: .name)
                        let newName = max(100, currentName + diff)
                        appState.setColumnWidth(.name, width: newName)
                    }
                }
                lastWindowWidth = newWidth
            }
            .onAppear {
                lastWindowWidth = geometry.size.width
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
            ForEach(Array(visibleColumns.enumerated()), id: \.element) { index, col in
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
        Button(action: {
            if appState.sortOption == option {
                appState.sortAscending.toggle()
            } else {
                appState.sortOption = option
                appState.sortAscending = true
            }
            appState.refreshCurrentDirectory()
        }) {
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

    @ViewBuilder
    private var columnVisibilityMenu: some View {
        ForEach(ListColumn.allCases.filter { !$0.isAlwaysVisible }, id: \.self) { col in
            Button(action: { appState.toggleColumnVisibility(col) }) {
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

    
    @ViewBuilder
    private func dynamicColumn(_ col: ListColumn, for item: FileItem, isSel: Bool) -> some View {
        let width = appState.columnWidth(for: col)
        switch col {
        case .size:
            Text(item.formattedSize)
                .font(.system(size: 12))
                .foregroundColor(isSel ? .white.opacity(0.8) : .secondary)
                .padding(.trailing, 4)
                .frame(width: width, alignment: .trailing)
        case .dateModified:
            Text(item.formattedDate)
                .font(.system(size: 12))
                .foregroundColor(isSel ? .white.opacity(0.8) : .secondary)
                .padding(.trailing, 4)
                .frame(width: width, alignment: .trailing)
        case .dateCreated:
            Text(item.formattedDateCreated)
                .font(.system(size: 12))
                .foregroundColor(isSel ? .white.opacity(0.8) : .secondary)
                .padding(.trailing, 4)
                .frame(width: width, alignment: .trailing)
        case .dateAccessed:
            Text(item.formattedDateAccessed)
                .font(.system(size: 12))
                .foregroundColor(isSel ? .white.opacity(0.8) : .secondary)
                .padding(.trailing, 4)
                .frame(width: width, alignment: .trailing)
        case .kind:
            Text(item.isDirectory ? appState.tr(.folder) : item.fileExtension.uppercased())
                .font(.system(size: 12))
                .foregroundColor(isSel ? .white.opacity(0.8) : .secondary)
                .padding(.trailing, 4)
                .frame(width: width, alignment: .trailing)
        case .owner:
            Text(item.ownerName)
                .font(.system(size: 12))
                .foregroundColor(isSel ? .white.opacity(0.8) : .secondary)
                .padding(.trailing, 4)
                .frame(width: width, alignment: .trailing)
        case .group:
            Text(item.groupName)
                .font(.system(size: 12))
                .foregroundColor(isSel ? .white.opacity(0.8) : .secondary)
                .padding(.trailing, 4)
                .frame(width: width, alignment: .trailing)
        case .name:
            EmptyView()
        }
    }

    private func listRow(for item: FileItem) -> some View {
        let isSel = appState.selectedURLs.contains(item.url)
        let isCut = appState.clipboard?.isCut(url: item.url) ?? false

        return HStack(spacing: 0) {
            // Name (always visible)
            HStack(alignment: .center, spacing: 8) {
                Image(nsImage: item.icon)
                    .resizable().scaledToFit().frame(width: listIconSize, height: listIconSize)
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

            // Dynamic fixed-width columns
            ForEach(visibleColumns, id: \.self) { col in
                if col != .name {
                    dynamicColumn(col, for: item, isSel: isSel)
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, appState.isCompactMode ? 2 : max(4, listIconSize * 0.25))
        .background(isSel ? Color.accentColor : Color.clear)
        .cornerRadius(6)
        .opacity(isCut ? 0.5 : 1.0)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: ListCellFrameKey.self, value: [item.url: geo.frame(in: .named("listContainer"))])
            }
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            appState.navigateTo(item.url)
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                appState.handleSelection(for: item)
            }
        )
        .onDrag {
            if !appState.selectedURLs.contains(item.url) {
                appState.selectedURLs = [item.url]
            }
            let urls = Array(appState.selectedURLs)
            let provider = NSItemProvider()
            for u in urls {
                provider.registerObject(u as NSURL, visibility: .all)
            }
            return provider
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            if item.isDirectory {
                appState.handleDrop(providers: providers, targetFolder: item.url)
                return true
            }
            return false
        }
        .overlay(
            RightClickDetector {
                if !appState.selectedURLs.contains(item.url) {
                    appState.selectedURLs = [item.url]
                }
            }
        )
        .contextMenu { SharedFileItemContextMenu(item: item, appState: appState) }
    }
}
