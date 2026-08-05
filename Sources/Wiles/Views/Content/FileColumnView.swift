import SwiftUI
import AppKit

struct ColumnData: Identifiable {
    let id = UUID()
    let folderURL: URL
    var items: [FileItem]
    var selectedURL: URL?
    var visibleLimit: Int = LayoutTokens.lazyLoadingBatchSize
}

struct FileColumnView: View {
    var appState: AppState

    @State private var columns: [ColumnData] = []
    @State private var activeColumnIndex: Int = 0

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 0) {
                    ForEach(Array(columns.enumerated()), id: \.element.id) { index, column in
                        columnView(for: column, index: index)
                            .id(index)
                        Divider()
                    }
                }
            }
            .background(ScrollerAutoHideSetter())
            .onAppear { loadInitialColumns() }
            .onChange(of: appState.currentURL) { _, _ in loadInitialColumns() }
            .onChange(of: columns.count) { _, newCount in
                if newCount > 0 {
                    proxy.scrollTo(newCount - 1, anchor: .trailing)
                }
            }
            .onChange(of: appState.columnViewDrillRightTrigger) { _, _ in
                drillRightFromSelection()
            }
            .onChange(of: appState.columnViewVerticalTrigger) { _, _ in
                moveVerticalSelection(by: appState.columnViewVerticalDirection)
            }
            .onChange(of: appState.columnViewMoveLeftTrigger) { _, _ in
                moveLeftFromSelection()
            }
        }
    }

    private func columnView(for column: ColumnData, index: Int) -> some View {
        let visibleItems = Array(column.items.prefix(column.visibleLimit))
        return VStack(spacing: 0) {
            columnHeader(title: column.folderURL.lastPathComponent.isEmpty ? "/" : column.folderURL.lastPathComponent)

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 1) {
                    ForEach(visibleItems) { item in
                        FileColumnRowView(
                            item: item,
                            columnIndex: index,
                            isSelected: appState.selectedURLs.contains(item.url),
                            appState: appState,
                            onSelect: {
                                selectItem(item: item, columnIndex: index)
                            }
                        )
                    }
                    if column.visibleLimit < column.items.count {
                        ProgressView()
                            .frame(height: 25)
                            .onAppear {
                                var col = column
                                col.visibleLimit = min(col.items.count, col.visibleLimit + LayoutTokens.lazyLoadingBatchSize)
                                columns[index] = col
                            }
                    }
                }
                .padding(.vertical, 4)
            }
            .background(ScrollerAutoHideSetter())
        }
        .frame(width: 220)
    }

    private func columnHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.08))
    }

    private func loadInitialColumns() {
        Task {
            let rootItems = await FileSystemService.loadDirectoryContents(
                at: appState.currentURL,
                options: DirectoryLoadOptions(
                    showHidden: appState.showHiddenFiles,
                    showTags: appState.showTags,
                    searchQuery: appState.searchQuery,
                    sortOption: appState.sortOption,
                    sortAscending: appState.sortAscending
                )
            )
            await MainActor.run {
                self.columns = [ColumnData(folderURL: appState.currentURL, items: rootItems, selectedURL: nil)]
                self.activeColumnIndex = 0
                if let first = rootItems.first {
                    self.selectItem(item: first, columnIndex: 0, autoSelectFirst: true)
                }
            }
        }
    }

    private func drillRightFromSelection() {
        guard activeColumnIndex < columns.count else { return }
        let col = columns[activeColumnIndex]
        guard let selURL = col.selectedURL,
              let item = col.items.first(where: { $0.url == selURL }) else { return }

        if item.isDirectory {
            selectItem(item: item, columnIndex: activeColumnIndex, autoSelectFirst: true)
        }
    }

    private func moveVerticalSelection(by offset: Int) {
        guard activeColumnIndex < columns.count else { return }
        let col = columns[activeColumnIndex]
        guard !col.items.isEmpty else { return }

        let currentIndex = col.items.firstIndex(where: { $0.url == col.selectedURL }) ?? 0
        let targetIndex = max(0, min(col.items.count - 1, currentIndex + offset))
        let targetItem = col.items[targetIndex]

        selectItem(item: targetItem, columnIndex: activeColumnIndex)
    }

    private func moveLeftFromSelection() {
        guard activeColumnIndex > 0 else { return }
        let parentColumnIndex = activeColumnIndex - 1
        let parentCol = columns[parentColumnIndex]
        guard let parentItem = parentCol.items.first(where: { $0.url == parentCol.selectedURL }) else { return }

        appState.selectedURLs = [parentItem.url]
        columns[parentColumnIndex].selectedURL = parentItem.url
        activeColumnIndex = parentColumnIndex
    }

    private func selectItem(item: FileItem, columnIndex: Int, autoSelectFirst: Bool = false) {
        appState.selectedURLs = [item.url]
        columns[columnIndex].selectedURL = item.url

        guard item.isDirectory else {
            truncateColumns(after: columnIndex)
            return
        }

        Task {
            let subItems = await FileSystemService.loadDirectoryContents(
                at: item.url,
                options: DirectoryLoadOptions(
                    showHidden: appState.showHiddenFiles,
                    showTags: appState.showTags,
                    searchQuery: "",
                    sortOption: appState.sortOption,
                    sortAscending: appState.sortAscending
                )
            )
            await MainActor.run {
                // Verify the user hasn't changed selection while loading before
                // clobbering the newer selection. The old preview column, if any, stays
                // visible until here so navigating quickly doesn't flicker it away and back.
                guard columnIndex < self.columns.count,
                      self.columns[columnIndex].selectedURL == item.url else { return }
                let firstURL = autoSelectFirst ? subItems.first?.url : nil
                self.truncateColumns(after: columnIndex)
                self.columns.append(ColumnData(folderURL: item.url, items: subItems, selectedURL: firstURL))
                self.activeColumnIndex = columnIndex + 1
                if let firstURL {
                    self.appState.selectedURLs = [firstURL]
                }
            }
        }
    }

    private func truncateColumns(after columnIndex: Int) {
        if columnIndex + 1 < columns.count {
            columns.removeSubrange((columnIndex + 1)...)
        }
    }
}

struct FileColumnRowView: View {
    let item: FileItem
    let columnIndex: Int
    let isSelected: Bool
    var appState: AppState
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            FileItemIconView(item: item, size: 16)
            ICloudStatusBadgeView(item: item)

            Text(item.name)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)
                .foregroundColor(isSelected ? .white : .primary)

            Spacer()

            if item.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary.opacity(0.5))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .hoverHighlight(isSelected: isSelected, cornerRadius: 4)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .accessibilityLabel(item.name)
        .accessibilityHint(item.isDirectory ? appState.tr(.folder) : appState.tr(.open))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
        .accessibilityValue(item.formattedSize)
        .onTapGesture {
            onSelect()
        }
        .springLoadedFolder(folderURL: item.url, isDirectory: item.isDirectory, appState: appState)
        .fileItemInteractions(item: item, appState: appState)
    }
}
