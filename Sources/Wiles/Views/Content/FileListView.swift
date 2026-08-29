import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FileListView: View {
    var appState: AppState

    @Environment(WindowUIState.self)
    private var windowUIState
    @State private var lastWindowWidth: CGFloat?
    @State private var hoveredURL: URL?
    @State private var dropTargetedURL: URL?

    var body: some View {
        FileCollectionContainerView(
            appState: appState,
            coordinateSpaceName: "listContainer",
            scrollAxes: [.horizontal, .vertical],
            thumbnailIconSize: 36,
            selectionRectMinWidth: { geometry in geometry.size.width - LayoutTokens.scrollbarReservedThickness },
            cellFramesProvider: { appState.selection.listCellFrames },
            onURLFramesChanged: { frames in appState.selection.listCellFrames = frames },
            onGeometryWidthChange: { newWidth in
                FileListHeaderView.adjustNameColumnWidth(for: newWidth, appState: appState)
                lastWindowWidth = newWidth
            },
            nonEmptyContent: { geometry, visibleLimit in
                listVStackContent(visibleLimit: visibleLimit)
                    .frame(width: max(geometry.size.width, FileListHeaderView.totalColumnsWidth(appState)), alignment: .leading)
            },
            overlayContent: { EmptyView() })
    }

    private func listVStackContent(visibleLimit: Binding<Int>) -> some View {
        VStack(spacing: 0) {
            FileListHeaderView(appState: appState)
            listLazyVStack(visibleLimit: visibleLimit)
        }
    }

    private func listLazyVStack(visibleLimit: Binding<Int>) -> some View {
        LazyVStack(spacing: 2) {
            PaginatedItemsSection(
                items: appState.fileSystem.items,
                visibleLimit: visibleLimit,
                progressViewHeight: 30) { item in
                    listRow(for: item)
                }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }

    private var listIconSize: CGFloat {
        max(LayoutTokens.listIconMinSize, min(LayoutTokens.listIconMaxSize, CGFloat(appState.preferences.view.iconSize) * LayoutTokens.listIconScaleMultiplier))
    }

    private func dynamicColumnText(_ col: ListColumn, for item: FileItem) -> String? {
        switch col {
        case .size: item.formattedSize
        case .dateModified: item.formattedDate(language: appState.preferences.appearance.appLanguage)
        case .dateCreated: item.formattedDateCreated(language: appState.preferences.appearance.appLanguage)
        case .dateAccessed: item.formattedDateAccessed(language: appState.preferences.appearance.appLanguage)
        case .kind: if item.isDirectory {
                appState.tr(.folder)
            } else {
                item.fileExtension.uppercased()
            }
        case .owner: item.ownerName
        case .group: item.groupName
        case .name: nil
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
        }
    }

    private func nameCell(for item: FileItem, isSel: Bool) -> some View {
        HStack(alignment: .center, spacing: 8) {
            FileItemIconView(item: item, size: listIconSize, isOpenTargeted: dropTargetedURL == item.url)
            ICloudStatusBadgeView(item: item, appState: appState)
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
                middleTruncate: appState.preferences.view.middleTruncateNames)
        }
    }

    @ViewBuilder
    private func tagsIndicator(for item: FileItem) -> some View {
        if appState.preferences.sidebar.showTags, !item.tags.isEmpty {
            TagsIndicatorView(tags: item.tags)
                .offset(y: appState.preferences.view.isCompactMode ? 1 : 0)
        }
    }

    private func listRow(for item: FileItem) -> some View {
        let isSel = appState.selection.selectedURLs.contains(item.url)
        let isCut = appState.transient.clipboard?.isCut(url: item.url) ?? false

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
        .padding(.vertical, appState.preferences.view.isCompactMode ? 2 : max(4, listIconSize * 0.25))
        .hoverHighlight(isSelected: isSel, cornerRadius: 6)
        .opacity(isCut ? 0.5 : 1.0)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: URLFrameKey.self, value: [item.url: geo.frame(in: .named("listContainer"))])
            })
        .contentShape(Rectangle())
        .accessibilityLabel(item.name)
        .accessibilityHint(item.isDirectory ? appState.tr(.folder) : appState.tr(.open))
        .accessibilityAddTraits(isSel ? [.isButton, .isSelected] : [.isButton])
        .accessibilityValue(item.formattedSize)
        .fileItemInteractions(
            item: item,
            appState: appState,
            onTargetedChanged: { targeted in dropTargetedURL = targeted ? item.url : nil })
        .fileMetadataTooltip(item, language: appState.preferences.appearance.appLanguage)
    }
}
