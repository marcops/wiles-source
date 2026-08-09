import SwiftUI
import AppKit

struct FileColumnView: View {
    var appState: AppState

    @State private var columns: [ColumnData] = []
    @State private var activeColumnIndex: Int = 0
    @State private var loadTask: Task<Void, Never>?

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
            .onChange(of: appState.navigation.currentURL) { _, _ in loadInitialColumns() }
            .onChange(of: appState.fileSystem.items) { _, newItems in
                // Column view keeps its own local snapshot per column instead of rendering
                // `appState.fileSystem.items` directly (like Grid/List do), so an operation that
                // changes the current folder's contents without changing `currentURL` (paste,
                // delete, rename via another view, etc.) otherwise never reaches the visible
                // column. `fileSystem.items` always tracks `navigation.currentURL`, so refresh
                // whichever local column corresponds to that folder.
                guard let index = columns.firstIndex(where: { $0.folderURL == appState.navigation.currentURL }) else { return }
                columns[index].items = newItems
            }
            .onChange(of: columns.count) { _, newCount in
                if newCount > 0 {
                    proxy.scrollTo(newCount - 1, anchor: .trailing)
                }
            }
            .onChange(of: appState.selection.columnViewDrillRightTrigger) { _, _ in
                drillRightFromSelection()
            }
            .onChange(of: appState.selection.columnViewVerticalTrigger) { _, _ in
                moveVerticalSelection(by: appState.selection.columnViewVerticalDirection)
            }
            .onChange(of: appState.selection.columnViewMoveLeftTrigger) { _, _ in
                moveLeftFromSelection()
            }
        }
    }

    private func columnView(for column: ColumnData, index: Int) -> some View {
        return VStack(spacing: 0) {
            columnHeader(title: column.folderURL.lastPathComponent.isEmpty ? "/" : column.folderURL.lastPathComponent)

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 1) {
                    let paginate = column.items.count > LayoutTokens.paginationThreshold
                    let visibleItems = paginate ? Array(column.items.prefix(column.visibleLimit)) : column.items

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
                    if paginate && column.visibleLimit < column.items.count {
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
        loadTask?.cancel()
        let targetURL = appState.navigation.currentURL
        loadTask = Task {
            let rootItems = await FileSystemService.loadDirectoryContents(
                at: targetURL,
                options: DirectoryLoadOptions(
                    showHidden: appState.preferences.showHiddenFiles,
                    showTags: appState.preferences.showTags,
                    searchQuery: appState.searchQuery,
                    sortOption: appState.preferences.sortOption,
                    sortAscending: appState.preferences.sortAscending,
                    showOwnerGroup: appState.isColumnVisible(.owner) || appState.isColumnVisible(.group)
                )
            )
            await MainActor.run {
                guard appState.navigation.currentURL == targetURL else { return }
                self.columns = [ColumnData(folderURL: targetURL, items: rootItems, selectedURL: nil)]
                self.activeColumnIndex = 0
                self.appState.selectedURLs.removeAll()
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

        guard let currentIndex = col.items.firstIndex(where: { $0.url == col.selectedURL }) else {
            let startIndex = offset >= 0 ? 0 : col.items.count - 1
            selectItem(item: col.items[startIndex], columnIndex: activeColumnIndex)
            return
        }
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
                    showHidden: appState.preferences.showHiddenFiles,
                    showTags: appState.preferences.showTags,
                    searchQuery: "",
                    sortOption: appState.preferences.sortOption,
                    sortAscending: appState.preferences.sortAscending,
                    showOwnerGroup: appState.isColumnVisible(.owner) || appState.isColumnVisible(.group)
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
