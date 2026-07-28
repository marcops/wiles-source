import SwiftUI
import AppKit

struct SidebarItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let iconName: String
    let url: URL
}

struct FolderNode: Identifiable, Hashable {
    let id: URL
    let name: String
    let url: URL
    var children: [FolderNode]?
    
    static func buildRootTree() -> FolderNode {
        let root = URL(fileURLWithPath: "/")
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        let children = loadSubfolders(at: root, autoExpandFor: home)
        return FolderNode(id: root, name: "Root (/)", url: root, children: children)
    }
    
    private static func loadSubfolders(at folderURL: URL, autoExpandFor homeURL: URL) -> [FolderNode] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey]
        
        guard let urls = try? fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return []
        }
        
        var nodes: [FolderNode] = []
        for url in urls {
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if !isDir { continue }
            
            let stdURL = url.standardizedFileURL
            let name = stdURL.lastPathComponent
            let isAncestorOrHome = homeURL.path.hasPrefix(stdURL.path)
            
            let children = isAncestorOrHome ? loadSubfolders(at: stdURL, autoExpandFor: homeURL) : nil
            nodes.append(FolderNode(id: stdURL, name: name, url: stdURL, children: children?.isEmpty == true ? nil : children))
        }
        return nodes.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

struct DirectoryTreeNodeView: View {
    let node: FolderNode
    let depth: Int
    var appState: AppState
    
    @State private var isExpanded: Bool
    
    init(node: FolderNode, depth: Int = 0, appState: AppState) {
        self.node = node
        self.depth = depth
        self.appState = appState
        
        let homePath = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        let isAncestorOrHome = homePath.hasPrefix(node.url.path) || node.url.path == "/"
        _isExpanded = State(initialValue: isAncestorOrHome)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let children = node.children, !children.isEmpty {
                DisclosureGroup(isExpanded: $isExpanded) {
                    ForEach(children) { child in
                        DirectoryTreeNodeView(node: child, depth: depth + 1, appState: appState)
                    }
                } label: {
                    rowContent
                }
            } else {
                rowContent
            }
        }
        .padding(.leading, CGFloat(depth) * 12)
    }
    
    private var rowContent: some View {
        let isSel = appState.currentURL.standardizedFileURL == node.url.standardizedFileURL
        return Button(action: { appState.navigateTo(node.url) }) {
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 12))
                    .foregroundColor(isSel ? .white : .accentColor)
                Text(node.name)
                    .font(.system(size: 12, weight: isSel ? .bold : .regular))
                    .foregroundColor(isSel ? .white : .primary)
                Spacer()
            }
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(isSel ? Color.accentColor : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open") { appState.navigateTo(node.url) }
            Button("Copy Path") {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(node.url.path, forType: .string)
            }
            Divider()
            Button("Properties (Cmd+I)") {
                let fileItem = FileItem(url: node.url, icon: NSWorkspace.shared.icon(forFile: node.url.path))
                appState.propertiesItem = fileItem
            }
        }
    }
}

struct SidebarView: View {
    var appState: AppState
    
    var macItems: [SidebarItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let cloudDocs = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        let airDrop = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app/Contents/Applications/AirDrop.app")
        
        var items = [
            SidebarItem(name: "Applications", iconName: "square.grid.3x3.fill", url: URL(fileURLWithPath: "/Applications")),
            SidebarItem(name: "AirDrop", iconName: "dot.radiowaves.left.and.right", url: airDrop)
        ]
        
        if FileManager.default.fileExists(atPath: cloudDocs.path) {
            items.append(SidebarItem(name: "iCloud Drive", iconName: "icloud.fill", url: cloudDocs))
        }
        
        items.append(SidebarItem(name: "Macintosh HD", iconName: "internaldrive.fill", url: URL(fileURLWithPath: "/")))
        return items
    }
    
    var devices: [SidebarItem] {
        return [
            SidebarItem(name: "Macintosh HD", iconName: "internaldrive.fill", url: URL(fileURLWithPath: "/"))
        ]
    }
    
    var recentItems: [SidebarItem] {
        var seen = Set<URL>()
        var items: [SidebarItem] = []
        for url in appState.historyBack.reversed() {
            let std = url.standardizedFileURL
            if !seen.contains(std) && std != appState.currentURL.standardizedFileURL {
                seen.insert(std)
                items.append(sidebarItem(for: std))
                if items.count >= 5 { break }
            }
        }
        return items
    }
    
    var rootFolderNode: FolderNode {
        FolderNode.buildRootTree()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if appState.showFavorites && !appState.favoriteURLs.isEmpty {
                        sectionView(title: "FAVORITES", items: appState.favoriteURLs.map { sidebarItem(for: $0) }, isFavoritesSection: true)
                        Divider().padding(.horizontal, 12)
                    }
                    
                    if appState.showMacSection {
                        sectionView(title: "MAC", items: macItems, isFavoritesSection: false)
                        Divider().padding(.horizontal, 12)
                        
                        if appState.showRecents && !recentItems.isEmpty {
                            sectionView(title: "RECENTS", items: recentItems, isFavoritesSection: false)
                            Divider().padding(.horizontal, 12)
                        }
                    }
                    
                    if appState.sidebarMode == .places {
                        sectionView(title: "DEVICES", items: devices, isFavoritesSection: false)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("DIRECTORY TREE").font(.system(size: 11, weight: .bold)).foregroundColor(.secondary).padding(.horizontal, 12)
                            DirectoryTreeNodeView(node: rootFolderNode, depth: 0, appState: appState)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
        .frame(minWidth: 160, idealWidth: 180)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.85))
    }
    
    private func sidebarItem(for url: URL) -> SidebarItem {
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        let std = url.standardizedFileURL
        let path = std.path
        
        let icon: String
        let name: String
        
        if path == home.path {
            name = "Home"; icon = "house.fill"
        } else if path == home.appendingPathComponent("Desktop").path {
            name = "Desktop"; icon = "desktopcomputer"
        } else if path == home.appendingPathComponent("Documents").path {
            name = "Documents"; icon = "doc.fill"
        } else if path == home.appendingPathComponent("Downloads").path {
            name = "Downloads"; icon = "arrow.down.circle.fill"
        } else if path == "/Applications" {
            name = "Applications"; icon = "square.grid.3x3.fill"
        } else if path == home.appendingPathComponent("Music").path {
            name = "Music"; icon = "music.note"
        } else if path == home.appendingPathComponent("Pictures").path {
            name = "Pictures"; icon = "photo.fill"
        } else if path == home.appendingPathComponent("Movies").path {
            name = "Movies"; icon = "film.fill"
        } else if path == home.appendingPathComponent(".Trash").path {
            name = "Trash"; icon = "trash.fill"
        } else {
            name = std.lastPathComponent
            icon = "folder.fill"
        }
        return SidebarItem(name: name, iconName: icon, url: std)
    }
    
    private func sectionView(title: String, items: [SidebarItem], isFavoritesSection: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 11, weight: .bold)).foregroundColor(.secondary).padding(.horizontal, 12)
            ForEach(items) { item in
                sidebarRow(for: item, isFavoritesSection: isFavoritesSection)
            }
        }
    }
    
    private func sidebarRow(for item: SidebarItem, isFavoritesSection: Bool = false) -> some View {
        let isSel = appState.currentURL.standardizedFileURL == item.url.standardizedFileURL
        return Button(action: { appState.navigateTo(item.url) }) {
            HStack(spacing: 10) {
                Image(systemName: item.iconName)
                    .font(.system(size: 14)).foregroundColor(isSel ? .white : .accentColor).frame(width: 20)
                Text(item.name)
                    .font(.system(size: 13, weight: isSel ? .medium : .regular))
                    .foregroundColor(isSel ? .white : .primary)
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(isSel ? Color.accentColor : Color.clear).cornerRadius(6)
        }
        .buttonStyle(.plain).padding(.horizontal, 8)
        .contextMenu {
            Button("Open") { appState.navigateTo(item.url) }
            Button("Copy Path") {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(item.url.path, forType: .string)
            }
            Divider()
            if isFavoritesSection || appState.isFavorite(item.url) {
                Button("Remove from Favorites") {
                    appState.removeFavorite(item.url)
                }
            } else {
                Button("Add to Favorites") {
                    appState.addFavorite(item.url)
                }
            }
            Divider()
            Button("Properties (Cmd+I)") {
                let fileItem = FileItem(url: item.url, icon: NSWorkspace.shared.icon(forFile: item.url.path))
                appState.propertiesItem = fileItem
            }
        }
    }
}
