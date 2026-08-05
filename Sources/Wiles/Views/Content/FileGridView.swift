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
    @State private var selectionRect: CGRect?
    @State private var dragStartPoint: CGPoint?

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        Color.clear.frame(height: 1).id("top")

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

                                    let selected = cellFrames.compactMap { (url, frame) -> URL? in
                                        frame.intersects(rect) ? url : nil
                                    }
                                    appState.selectedURLs = Set(selected)
                                }
                                .onEnded { _ in
                                    self.selectionRect = nil
                                    self.dragStartPoint = nil
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
                                EmptyDirectoryView(appState: appState)
                            } else {
                                LazyVGrid(columns: columns, spacing: LayoutTokens.gridSpacing) {
                                    ForEach(appState.items) { item in
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
                                    }
                                }
                                .padding(16)
                                .onAppear {
                                    if appState.items.count > 500 {
                                        ThumbnailService.shared.prefetchThumbnails(for: appState.items, size: iconSize)
                                    }
                                }
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
                    .coordinateSpace(name: "gridContainer")
                    .onPreferenceChange(CellFrameKey.self) { frames in
                        self.cellFrames = frames
                        appState.gridCellFrames = frames
                    }
                    .frame(minHeight: geometry.size.height - LayoutTokens.scrollbarReservedThickness, alignment: .topLeading)
                    .background(ScrollerAutoHideSetter())
                }
                .onChange(of: appState.items) { _, newItems in
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

struct FileGridCardItemView: View {
    let item: FileItem
    var appState: AppState
    let iconSize: CGFloat
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let onRightClick: () -> Void

    @State private var isDropTargeted = false

    var body: some View {
        let isSel = appState.selectedURLs.contains(item.url)
        let isCut = appState.clipboard?.isCut(url: item.url) ?? false

        return mainContent(isSel: isSel, isCut: isCut)
            .springLoadedFolder(folderURL: item.url, isDirectory: item.isDirectory, appState: appState) { targeted in
                withAnimation(MotionTokens.quickEase) { isDropTargeted = targeted }
            }
            .fileItemInteractions(item: item, appState: appState, onRightClick: onRightClick)
    }

    private func mainContent(isSel: Bool, isCut: Bool) -> some View {
        let borderStroke = isDropTargeted ? Color.accentColor : (isSel ? Color.accentColor : Color.clear)
        let strokeWidth: CGFloat = isDropTargeted ? 3 : 2

        return cardVStack(isSel: isSel)
            .frame(width: cardWidth, height: cardHeight)
            .padding(6)
            .hoverHighlight(isSelected: isSel, selectedBackground: Color.accentColor.opacity(0.18), cornerRadius: 10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(borderStroke, lineWidth: strokeWidth))
            .opacity(isCut ? 0.5 : 1.0)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: CellFrameKey.self, value: [item.url: geo.frame(in: .named("gridContainer"))])
                }
            )
            .contentShape(Rectangle())
            .help(item.name)
            .accessibilityLabel(item.name)
            .accessibilityHint(item.isDirectory ? appState.tr(.folder) : appState.tr(.open))
            .accessibilityAddTraits(isSel ? [.isButton, .isSelected] : [.isButton])
            .accessibilityValue(item.formattedSize)
            .onTapGesture(count: 2) { appState.navigateTo(item.url) }
            .simultaneousGesture(TapGesture().onEnded { appState.handleSelection(for: item) })
    }

    private func cardVStack(isSel: Bool) -> some View {
        VStack(spacing: 6) {
            FileItemIconView(item: item, size: iconSize)
                .overlay(ICloudStatusBadgeView(item: item).padding(2), alignment: .topTrailing)
            cardLabel(isSel: isSel)
            if appState.showTags && !item.tags.isEmpty {
                tagsView
            }
        }
    }

    private func cardLabel(isSel: Bool) -> some View {
        let fontSize = max(10.0, min(14.0, Double(iconSize) * 0.22))
        let fontWeight: Font.Weight = isSel ? .semibold : .regular
        return Text(item.name)
            .font(.system(size: fontSize, weight: fontWeight))
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .foregroundColor(isSel ? .white : .primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isSel ? Color.accentColor : Color.clear)
            .cornerRadius(4)
    }

    private var tagsView: some View {
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
