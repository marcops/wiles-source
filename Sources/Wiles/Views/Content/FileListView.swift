import SwiftUI
import AppKit

struct FileListView: View {
    var appState: AppState
    
    var body: some View {
        @Bindable var appState = appState
        return Table(appState.items, selection: $appState.selectedURLs, sortOrder: sortOrderBinding) {
            TableColumn("Name", value: \.name) { item in
                nameCell(for: item)
            }
            TableColumn("Size", value: \.size) { item in
                Text(item.formattedSize).font(.system(size: 12)).foregroundColor(.secondary)
            }
            TableColumn("Date Modified", value: \.dateModified) { item in
                Text(item.formattedDate).font(.system(size: 12)).foregroundColor(.secondary)
            }
            TableColumn("Kind", value: \.fileExtension) { item in
                Text(item.isDirectory ? "Folder" : item.fileExtension.uppercased()).font(.system(size: 12)).foregroundColor(.secondary)
            }
        }
        .tableStyle(.inset)
        .contextMenu(forSelectionType: URL.self) { urls in
            if let first = urls.first, let item = appState.items.first(where: { $0.url == first }) {
                listContextMenu(for: item)
            }
        } primaryAction: { urls in
            if let first = urls.first { appState.navigateTo(first) }
        }
    }
    
    private func nameCell(for item: FileItem) -> some View {
        HStack(spacing: 8) {
            Image(nsImage: item.icon).resizable().frame(width: 18, height: 18)
            Text(item.name).font(.system(size: 13))
        }
        .opacity(appState.clipboard?.isCut(url: item.url) == true ? 0.5 : 1.0)
        .overlay(RightClickDetector {
            if !appState.selectedURLs.contains(item.url) {
                appState.selectedURLs = [item.url]
            }
        })
    }
    
    private var sortOrderBinding: Binding<[KeyPathComparator<FileItem>]> {
        Binding(
            get: { [currentComparator] },
            set: { newOrder in
                guard let comp = newOrder.first else { return }
                updateSort(from: comp)
            }
        )
    }
    
    private var currentComparator: KeyPathComparator<FileItem> {
        let order: SortOrder = appState.sortAscending ? .forward : .reverse
        switch appState.sortOption {
        case .name: return KeyPathComparator(\FileItem.name, order: order)
        case .dateModified: return KeyPathComparator(\FileItem.dateModified, order: order)
        case .size: return KeyPathComparator(\FileItem.size, order: order)
        case .kind: return KeyPathComparator(\FileItem.fileExtension, order: order)
        }
    }
    
    private func updateSort(from comp: KeyPathComparator<FileItem>) {
        let newAsc = (comp.order == .forward)
        let newOpt: SortOption
        
        switch comp.keyPath {
        case \FileItem.name as PartialKeyPath<FileItem>: newOpt = .name
        case \FileItem.dateModified as PartialKeyPath<FileItem>: newOpt = .dateModified
        case \FileItem.size as PartialKeyPath<FileItem>: newOpt = .size
        default: newOpt = .kind
        }
        
        if newOpt != appState.sortOption || newAsc != appState.sortAscending {
            appState.sortOption = newOpt
            appState.sortAscending = newAsc
            appState.refreshCurrentDirectory()
        }
    }
    
    @ViewBuilder
    private func listContextMenu(for item: FileItem) -> some View {
        Group {
            Button("Open") { appState.navigateTo(item.url) }
            Button("Quick Look (Space)") { appState.quickLookURL = item.url }
            Divider()
            if item.isDirectory {
                if appState.isFavorite(item.url) {
                    Button("Remove from Favorites") { appState.removeFavorite(item.url) }
                } else {
                    Button("Add to Favorites") { appState.addFavorite(item.url) }
                }
                Divider()
            }
            Button("Cut (Cmd+X)") { appState.selectedURLs = [item.url]; appState.cutSelected() }
            Button("Copy (Cmd+C)") { appState.selectedURLs = [item.url]; appState.copySelected() }
            Button("Paste Here (Cmd+V)") { appState.pasteToCurrentDirectory() }
            if !item.isDirectory {
                Button("Copy Content (#10)") { appState.selectedURLs = [item.url]; appState.copyContentOfSelected() }
            }
            Divider()
            Button("Move to Trash", role: .destructive) { appState.selectedURLs = [item.url]; appState.deleteSelected() }
            Divider()
            Button("Properties (Cmd+I)") {
                appState.selectedURLs = [item.url]
                appState.propertiesItem = item
            }
        }
        .onAppear {
            if !appState.selectedURLs.contains(item.url) {
                appState.selectedURLs = [item.url]
            }
        }
    }
}
