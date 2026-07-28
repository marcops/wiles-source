import SwiftUI
import AppKit

struct FileGridView: View {
    var appState: AppState
    let columns = [GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 16)]
    
    var body: some View {
        ScrollView {
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
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .onTapGesture { appState.selectedURLs.removeAll() }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 80)
            Image(systemName: appState.isSearching ? "magnifyingglass" : "folder")
                .font(.system(size: 48)).foregroundColor(.secondary.opacity(0.5))
            Text(appState.isSearching ? "No Results Found" : "Folder is Empty")
                .font(.system(size: 16, weight: .medium)).foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
    
    private func gridCard(for item: FileItem) -> some View {
        let isSel = appState.selectedURLs.contains(item.url)
        let isCut = appState.clipboard?.isCut(url: item.url) ?? false
        
        return VStack(spacing: 8) {
            Image(nsImage: item.icon)
                .resizable().scaledToFit().frame(width: 54, height: 54)
            Text(item.name)
                .font(.system(size: 12, weight: isSel ? .semibold : .regular))
                .lineLimit(2).multilineTextAlignment(.center)
                .foregroundColor(isSel ? .white : .primary)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(isSel ? Color.accentColor : Color.clear).cornerRadius(4)
        }
        .frame(width: 100, height: 105).padding(8)
        .background(isSel ? Color.accentColor.opacity(0.15) : Color.clear).cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSel ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .opacity(isCut ? 0.5 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { appState.navigateTo(item.url) }
        .onTapGesture(count: 1) { handleSelection(for: item) }
        .overlay(
            RightClickDetector {
                if !appState.selectedURLs.contains(item.url) {
                    appState.selectedURLs = [item.url]
                }
            }
        )
        .contextMenu { itemContextMenu(for: item) }
    }
    
    private func handleSelection(for item: FileItem) {
        if NSEvent.modifierFlags.contains(.command) {
            if appState.selectedURLs.contains(item.url) { appState.selectedURLs.remove(item.url) }
            else { appState.selectedURLs.insert(item.url) }
        } else {
            appState.selectedURLs = [item.url]
        }
    }
    
    @ViewBuilder
    private func itemContextMenu(for item: FileItem) -> some View {
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
