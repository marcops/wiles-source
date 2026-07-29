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

    var body: some View {
        ScrollView {
            ZStack(alignment: .topLeading) {
                Color(NSColor.controlBackgroundColor).opacity(0.001)
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
            .frame(maxWidth: .infinity, minHeight: 400, alignment: .topLeading)
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
    }
    
    private var tableHeader: some View {
        HStack(spacing: 12) {
            headerColumn(appState.tr(.name), option: .name)
                .frame(maxWidth: .infinity, alignment: .leading)
            headerColumn(appState.tr(.size), option: .size)
                .frame(width: LayoutTokens.columnSizeWidth, alignment: .trailing)
            headerColumn(appState.tr(.dateModified), option: .dateModified)
                .frame(width: LayoutTokens.columnDateWidth, alignment: .trailing)
            headerColumn(appState.tr(.kind), option: .kind)
                .frame(width: LayoutTokens.columnKindWidth, alignment: .trailing)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundColor(.secondary)
        .padding(.horizontal, 22)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
    
    private func headerColumn(_ title: String, option: SortOption) -> some View {
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
        }
        .buttonStyle(.plain)
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

    private func listRow(for item: FileItem) -> some View {
        let isSel = appState.selectedURLs.contains(item.url)
        let isCut = appState.clipboard?.isCut(url: item.url) ?? false
        
        return HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(nsImage: item.icon)
                    .resizable().scaledToFit().frame(width: listIconSize, height: listIconSize)
                Text(item.name)
                    .font(.system(size: 13, weight: isSel ? .semibold : .regular))
                    .lineLimit(1)
                    .foregroundColor(isSel ? .white : .primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(item.formattedSize)
                .font(.system(size: 12))
                .foregroundColor(isSel ? .white.opacity(0.8) : .secondary)
                .frame(width: LayoutTokens.columnSizeWidth, alignment: .trailing)
                
            Text(item.formattedDate)
                .font(.system(size: 12))
                .foregroundColor(isSel ? .white.opacity(0.8) : .secondary)
                .frame(width: LayoutTokens.columnDateWidth, alignment: .trailing)
                
            Text(item.isDirectory ? appState.tr(.folder) : item.fileExtension.uppercased())
                .font(.system(size: 12))
                .foregroundColor(isSel ? .white.opacity(0.8) : .secondary)
                .frame(width: LayoutTokens.columnKindWidth, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, max(4, listIconSize * 0.25))
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
