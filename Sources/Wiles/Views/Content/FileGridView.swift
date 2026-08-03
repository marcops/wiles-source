import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct CellFrameKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: [URL: CGRect] = [:]
    static func reduce(value: inout [URL: CGRect], nextValue: () -> [URL: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

struct FileGridView: View {
    var appState: AppState
    
    private var iconSize: CGFloat { CGFloat(appState.iconSize) * LayoutTokens.gridIconScaleMultiplier }
    private var cardWidth: CGFloat { iconSize + LayoutTokens.cardWidthOffset }
    private var cardHeight: CGFloat { iconSize + LayoutTokens.cardHeightOffset }
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: cardWidth, maximum: cardWidth + 24), spacing: LayoutTokens.gridSpacing)]
    }
    
    @State private var cellFrames: [URL: CGRect] = [:]
    @State private var selectionRect: CGRect? = nil
    @State private var dragStartPoint: CGPoint? = nil

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    Color(NSColor.controlBackgroundColor).opacity(0.001)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 2, coordinateSpace: .named("gridContainer"))
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
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(appState.items) { item in
                                gridCard(for: item)
                            }
                        }
                        .padding(20)
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
                .coordinateSpace(name: "gridContainer")
                .onPreferenceChange(CellFrameKey.self) { frames in
                    self.cellFrames = frames
                    appState.gridCellFrames = frames
                }
                .frame(maxWidth: .infinity, minHeight: geometry.size.height, maxHeight: .infinity, alignment: .topLeading)
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
    
    @ViewBuilder
    private func gridCardImage(for item: FileItem) -> some View {
        if !item.isDirectory,
           iconSize >= LayoutTokens.thumbnailMinimumIconSize,
           ThumbnailService.isImage(fileExtension: item.fileExtension) {
            ImageThumbnailView(url: item.url, size: iconSize, fallback: item.icon)
        } else {
            Image(nsImage: item.icon).resizable().scaledToFit()
        }
    }

    private func gridCard(for item: FileItem) -> some View {
        let isSel = appState.selectedURLs.contains(item.url)
        let isCut = appState.clipboard?.isCut(url: item.url) ?? false
        
        return VStack(spacing: 6) {
            gridCardImage(for: item)
                .frame(width: iconSize, height: iconSize)
            Text(item.name)
                .font(.system(size: max(10, min(14, iconSize * 0.22)), weight: isSel ? .semibold : .regular))
                .lineLimit(2).multilineTextAlignment(.center)
                .foregroundColor(isSel ? .white : .primary)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(isSel ? Color.accentColor : Color.clear).cornerRadius(4)
            
            if appState.showTags && !item.tags.isEmpty {
                HStack(spacing: -2) {
                    ForEach(item.tags, id: \.self) { tag in
                        Circle()
                            .fill(colorForTag(tag))
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(Color(NSColor.windowBackgroundColor), lineWidth: 1))
                    }
                }
            }
        }
        .frame(width: cardWidth, height: cardHeight).padding(6)
        .background(isSel ? Color.accentColor.opacity(0.15) : Color.clear).cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSel ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .opacity(isCut ? 0.5 : 1.0)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: CellFrameKey.self, value: [item.url: geo.frame(in: .named("gridContainer"))])
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
