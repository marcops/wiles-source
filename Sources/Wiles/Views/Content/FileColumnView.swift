import SwiftUI
import AppKit

struct ColumnData: Identifiable {
    let id = UUID()
    let folderURL: URL
    var items: [FileItem]
    var selectedURL: URL?
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
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
            .onAppear { loadInitialColumns() }
            .onChange(of: appState.currentURL) { _, _ in loadInitialColumns() }
            .onChange(of: columns.count) { _, newCount in
                if newCount > 0 {
                    proxy.scrollTo(newCount - 1, anchor: .trailing)
                }
            }
        }
    }
    
    private func columnView(for column: ColumnData, index: Int) -> some View {
        VStack(spacing: 0) {
            columnHeader(title: column.folderURL.lastPathComponent.isEmpty ? "/" : column.folderURL.lastPathComponent)
            
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 1) {
                    ForEach(column.items) { item in
                        columnRow(item: item, columnIndex: index, isSelected: item.url == column.selectedURL)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(width: 220)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.4))
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
        .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
    }
    
    private func columnRow(item: FileItem, columnIndex: Int, isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            Image(nsImage: item.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
            
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
    
    private func selectItem(item: FileItem, columnIndex: Int) {
        appState.selectedURLs = [item.url]
        columns[columnIndex].selectedURL = item.url
        
        // Truncate sub-columns after this column
        if columnIndex + 1 < columns.count {
            columns.removeSubrange((columnIndex + 1)...)
        }
        
        if item.isDirectory {
            Task {
                let subItems = await FileSystemService.loadDirectoryContents(
                    at: item.url,
                    showHidden: appState.showHiddenFiles,
                    searchQuery: "",
                    sortOption: appState.sortOption,
                    sortAscending: appState.sortAscending
                )
                await MainActor.run {
                    self.columns.append(ColumnData(folderURL: item.url, items: subItems, selectedURL: nil))
                    self.activeColumnIndex = columnIndex + 1
                }
            }
        }
    }
}
