import SwiftUI
import AppKit

struct FileColumnView: View {
    var appState: AppState

    @State private var columns: [ColumnData] = []
    @State private var activeColumnIndex: Int = 0
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        if appState.isSearching && !appState.searchQuery.isEmpty {
            // A search (especially "Whole Mac") has no meaningful drill-down hierarchy — results
            // can come from anywhere under the home folder — so Column view falls back to a
            // single flat results column bound directly to `appState.fileSystem.items`, the exact
            // same data source List/Grid already render from. This is what was missing before:
            // Column view's normal browsing mode never touched `appState.fileSystem.items` at
            // all (see `loadInitialColumns`/`refreshAllColumnsFromDisk` below, which always
            // re-read straight from disk instead), so it silently showed nothing during a search.
            searchResultsColumn
        } else {
            columnBrowser
        }
    }

    private var searchResultsColumn: some View {
        let paginate = appState.fileSystem.items.count > LayoutTokens.paginationThreshold
        return ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 1) {
                ForEach(appState.fileSystem.items) { item in
                    FileColumnRowView(
                        item: item,
                        columnIndex: 0,
                        isSelected: appState.selectedURLs.contains(item.url),
                        appState: appState,
                        onSelect: { appState.handleSelection(for: item) }
                    )
                    .transition(.opacity)
                }
                .animation(paginate ? nil : MotionTokens.smoothEase, value: appState.fileSystem.items.map(\.url))
            }
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity)
        .background(ScrollerAutoHideSetter())
    }

    private var columnBrowser: some View {
        ScrollViewReader { proxy in
            columnBrowserContent(proxy: proxy)
        }
    }

    @ViewBuilder
    private func columnBrowserContent(proxy: ScrollViewProxy) -> some View {
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
        .onChange(of: appState.fileSystem.items) { _, _ in
            // Column view keeps its own local snapshot per column instead of rendering
            // `appState.fileSystem.items` directly (like Grid/List do), so an operation that
            // changes a folder's contents (paste, delete, rename via another view, etc.)
            // otherwise never reaches the visible columns. `fileSystem.items` only ever
            // reflects `navigation.currentURL`, but drilling right in Column view never
            // changes `navigation.currentURL` — so a delete inside a drilled-in column (not
            // the root) previously went unnoticed here entirely. Re-read every open column
            // straight from disk instead of trying to map the single changed folder back to
            // one column index.
            refreshAllColumnsFromDisk()
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

    private func columnView(for column: ColumnData, index: Int) -> some View {
        VStack(spacing: 0) {
            columnHeader(title: columnTitle(for: column))
            columnItemsScrollView(for: column, index: index)
        }
        .frame(width: 220)
    }

    private func columnTitle(for column: ColumnData) -> String {
        column.folderURL.lastPathComponent.isEmpty ? "/" : column.folderURL.lastPathComponent
    }

    private func columnItemsScrollView(for column: ColumnData, index: Int) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            columnItemsList(for: column, index: index)
        }
        .background(ScrollerAutoHideSetter())
    }

    @ViewBuilder
    private func columnItemsList(for column: ColumnData, index: Int) -> some View {
        LazyVStack(spacing: 1) {
            let paginate = column.items.count > LayoutTokens.paginationThreshold
            let visibleItems = paginate ? Array(column.items.prefix(column.visibleLimit)) : column.items

            columnItemRows(visibleItems: visibleItems, paginate: paginate, column: column, index: index)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func columnItemRows(visibleItems: [FileItem], paginate: Bool, column: ColumnData, index: Int) -> some View {
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
            .transition(.opacity)
        }
        .animation(paginate ? nil : MotionTokens.smoothEase, value: visibleItems.map(\.url))
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

    private func refreshAllColumnsFromDisk() {
        let snapshot = columns
        Task {
            for (index, column) in snapshot.enumerated() {
                let items = await FileSystemService.loadDirectoryContents(
                    at: column.folderURL,
                    options: DirectoryLoadOptions(
                        showHidden: appState.preferences.showHiddenFiles,
                        showTags: appState.preferences.showTags,
                        searchQuery: column.folderURL == appState.navigation.currentURL ? appState.searchQuery : "",
                        sortOption: appState.preferences.sortOption,
                        sortAscending: appState.preferences.sortAscending,
                        showOwnerGroup: appState.isColumnVisible(.owner) || appState.isColumnVisible(.group)
                    )
                )
                await MainActor.run {
                    guard index < columns.count, columns[index].folderURL == column.folderURL else { return }
                    columns[index].items = items
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
