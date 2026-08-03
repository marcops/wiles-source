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
                        columnRow(item: item, columnIndex: index, isSelected: appState.selectedURLs.contains(item.url))
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
    
    private func columnRow(item: FileItem, columnIndex: Int, isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            if !item.isDirectory {
                ImageThumbnailView(url: item.url, size: 16, fallback: item.icon)
                    .frame(width: 16, height: 16)
            } else {
                Image(nsImage: item.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            }
            
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
        .background(isSelected ? Color.accentColor : Color.clear)
        .cornerRadius(4)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            selectItem(item: item, columnIndex: columnIndex)
        }
        .contextMenu {
            SharedFileItemContextMenu(item: item, appState: appState)
        }
    }
    
    private func loadInitialColumns() {
        Task {
            let rootItems = await FileSystemService.loadDirectoryContents(
                at: appState.currentURL,
                showHidden: appState.showHiddenFiles,
                showTags: appState.showTags,
                searchQuery: appState.searchQuery,
                sortOption: appState.sortOption,
                sortAscending: appState.sortAscending
            )
            await MainActor.run {
                self.columns = [ColumnData(folderURL: appState.currentURL, items: rootItems, selectedURL: nil)]
                self.activeColumnIndex = 0
            }
        }
    }
    
    /// Reacts to the right-arrow key by drilling into the selected item's column, then selecting its first item.
    private func drillRightFromSelection() {
        guard let selectedURL = appState.selectedURLs.first else { return }
        for (index, column) in columns.enumerated() {
            if let item = column.items.first(where: { $0.url == selectedURL }) {
                selectItem(item: item, columnIndex: index, autoSelectFirst: true)
                return
            }
        }
    }

    /// Reacts to up/down keys by moving selection within the column that actually contains it,
    /// instead of the root-level `appState.items`, which is wrong once the user has drilled into a sub-column.
    private func moveVerticalSelection(by offset: Int) {
        guard let selectedURL = appState.selectedURLs.first,
              let columnIndex = columns.firstIndex(where: { $0.items.contains { $0.url == selectedURL } }) else { return }
        let items = columns[columnIndex].items
        guard let currentIndex = items.firstIndex(where: { $0.url == selectedURL }) else { return }
        let newIndex = max(0, min(items.count - 1, currentIndex + offset))
        selectItem(item: items[newIndex], columnIndex: columnIndex)
    }

    /// Reacts to the left-arrow key by shifting focus back one column, keeping the drilled-in
    /// trail intact (unlike `goUp()`, which would reset the whole browser to a new root).
    private func moveLeftFromSelection() {
        guard let selectedURL = appState.selectedURLs.first,
              let columnIndex = columns.firstIndex(where: { $0.items.contains { $0.url == selectedURL } }),
              columnIndex > 0 else { return }
        let parentColumnIndex = columnIndex - 1
        guard let parentItem = columns[parentColumnIndex].items.first(where: { $0.url == columns[columnIndex].folderURL }) else { return }
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
                showHidden: appState.showHiddenFiles,
                showTags: appState.showTags,
                searchQuery: "",
                sortOption: appState.sortOption,
                sortAscending: appState.sortAscending
            )
            await MainActor.run {
                // Guard against a stale task: if selection moved on again before this load
                // finished, discard this result instead of appending a stray column and
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
