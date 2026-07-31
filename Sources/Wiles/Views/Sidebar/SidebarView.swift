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
    
    init(node: FolderNode, depth: Int = 0, appState: AppState) {
        self.node = node
        self.depth = depth
        self.appState = appState
    }
    
    private var isExpandedBinding: Binding<Bool> {
        Binding(
            get: { appState.expandedTreePaths.contains(node.url.path) },
            set: { newValue in
                if newValue {
                    appState.expandedTreePaths.insert(node.url.path)
                } else {
                    appState.expandedTreePaths.remove(node.url.path)
                }
            }
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let children = node.children, !children.isEmpty {
                DisclosureGroup(isExpanded: isExpandedBinding) {
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
            Button(appState.tr(.open)) { appState.navigateTo(node.url) }
            Button(appState.tr(.copyPath)) {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(node.url.path, forType: .string)
            }
            Divider()
            Button("\(appState.tr(.properties)) (Cmd+I)") {
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
            SidebarItem(name: appState.tr(.applications), iconName: "square.grid.3x3.fill", url: URL(fileURLWithPath: "/Applications")),
            SidebarItem(name: appState.tr(.airDrop), iconName: "dot.radiowaves.left.and.right", url: airDrop)
        ]
        
        if FileManager.default.fileExists(atPath: cloudDocs.path) {
            items.append(SidebarItem(name: appState.tr(.iCloudDrive), iconName: "icloud.fill", url: cloudDocs))
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
                if items.count >= LayoutTokens.maxRecentItemsCount { break }
            }
        }
        return items
    }
    
    var rootFolderNode: FolderNode {
        FolderNode.buildRootTree()
    }
    
    var body: some View {
        @Bindable var appState = appState
        
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if appState.showFavorites && !appState.favoriteURLs.isEmpty {
                    collapsibleSection(
                        title: appState.tr(.favorites),
                        isExpanded: $appState.isFavoritesExpanded,
                        items: appState.favoriteURLs.map { sidebarItem(for: $0) },
                        isFavoritesSection: true
                    )
                    Divider().padding(.horizontal, 12)
                }
                
                if appState.showMacSection {
                    collapsibleSection(
                        title: appState.tr(.mac),
                        isExpanded: $appState.isMacExpanded,
                        items: macItems,
                        isFavoritesSection: false
                    )
                    Divider().padding(.horizontal, 12)
                    
                    if appState.showRecents && !recentItems.isEmpty {
                        collapsibleSection(
                            title: appState.tr(.recents),
                            isExpanded: $appState.isRecentsExpanded,
                            items: recentItems,
                            isFavoritesSection: false
                        )
                        Divider().padding(.horizontal, 12)
                    }
                }
                
                if appState.showNetworkAndCloud {
                    let networkShares = NetworkDiscoveryService.shared.discoveredShares.map {
                        SidebarItem(name: $0.name, iconName: "network", url: $0.url)
                    }
                    if !networkShares.isEmpty {
                        collapsibleSection(
                            title: appState.tr(.networkAndCloud),
                            isExpanded: $appState.isNetworkExpanded,
                            items: networkShares,
                            isFavoritesSection: false
                        )
                        Divider().padding(.horizontal, 12)
                    }
                }
                
                if appState.sidebarMode == .places {
                    collapsibleSection(
                        title: appState.tr(.places),
                        isExpanded: $appState.isDevicesExpanded,
                        items: devices,
                        isFavoritesSection: false
                    )
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        sectionHeader(title: appState.tr(.directoryTree), isExpanded: $appState.isTreeExpanded)
                        if appState.isTreeExpanded {
                            DirectoryTreeNodeView(node: rootFolderNode, depth: 0, appState: appState)
                        }
                    }
                }
                
                if appState.showTags {
                    Divider().padding(.horizontal, 12)
                    VStack(alignment: .leading, spacing: 4) {
                        sectionHeader(title: appState.tr(.tags), isExpanded: $appState.isTagsExpanded)
                        if appState.isTagsExpanded {
                            tagRow(tag: "Red", colorKey: .red)
                            tagRow(tag: "Orange", colorKey: .orange)
                            tagRow(tag: "Yellow", colorKey: .yellow)
                            tagRow(tag: "Green", colorKey: .green)
                            tagRow(tag: "Blue", colorKey: .blue)
                            tagRow(tag: "Purple", colorKey: .purple)
                            tagRow(tag: "Gray", colorKey: .gray)
                        }
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .frame(minWidth: LayoutTokens.sidebarMinWidth, idealWidth: LayoutTokens.sidebarIdealWidth, maxHeight: .infinity)
        .background(
            ZStack {
                TranslucentVisualEffectView(material: .sidebar)
                Color(NSColor.windowBackgroundColor)
                    .opacity(1.0 - Double(appState.translucentLevel) / 100.0)
            }
            .ignoresSafeArea()
        )
    }
    
    private func sectionHeader(title: String, isExpanded: Binding<Bool>) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                isExpanded.wrappedValue.toggle()
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 12)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func tagRow(tag: String, colorKey: L10n.Key) -> some View {
        let query = "tag:\(tag.lowercased())"
        let isSel = appState.searchQuery.lowercased() == query
        return Button(action: {
            if isSel {
                appState.searchQuery = ""
            } else {
                appState.searchQuery = query
            }
        }) {
            HStack(spacing: 6) {
                Circle().fill(colorForTag(tag)).frame(width: 10, height: 10)
                Text(appState.tr(colorKey))
                    .font(.system(size: 12, weight: isSel ? .bold : .regular))
                    .foregroundColor(isSel ? .white : .primary)
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(isSel ? Color.accentColor : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
    }
    
    private func collapsibleSection(title: String, isExpanded: Binding<Bool>, items: [SidebarItem], isFavoritesSection: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader(title: title, isExpanded: isExpanded)
            if isExpanded.wrappedValue {
                ForEach(items) { item in
                    sidebarRow(for: item, isFavoritesSection: isFavoritesSection)
                }
            }
        }
    }
    
    private func sidebarItem(for url: URL) -> SidebarItem {
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        let std = url.standardizedFileURL
        let path = std.path
        
        let icon: String
        let name: String
        
        if path == home.path {
            name = appState.tr(.home); icon = "house.fill"
        } else if path == home.appendingPathComponent("Desktop").path {
            name = appState.tr(.desktop); icon = "desktopcomputer"
        } else if path == home.appendingPathComponent("Documents").path {
            name = appState.tr(.documents); icon = "doc.fill"
        } else if path == home.appendingPathComponent("Downloads").path {
            name = appState.tr(.downloads); icon = "arrow.down.circle.fill"
        } else if path == "/Applications" {
            name = appState.tr(.applications); icon = "square.grid.3x3.fill"
        } else if path == home.appendingPathComponent("Music").path {
            name = appState.tr(.music); icon = "music.note"
        } else if path == home.appendingPathComponent("Pictures").path {
            name = appState.tr(.pictures); icon = "photo.fill"
        } else if path == home.appendingPathComponent("Movies").path {
            name = appState.tr(.movies); icon = "film.fill"
        } else if path == home.appendingPathComponent(".Trash").path {
            name = appState.tr(.trash); icon = "trash.fill"
        } else {
            name = std.lastPathComponent
            icon = "folder.fill"
        }
        return SidebarItem(name: name, iconName: icon, url: std)
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
                if item.url.path.hasPrefix("/Volumes/") && item.url.path != "/" {
                    Button(action: {
                        let target = item.url
                        try? NSWorkspace.shared.unmountAndEjectDevice(at: target)
                        appState.refreshCurrentDirectory()
                    }) {
                        Image(systemName: "eject.fill")
                            .font(.system(size: 11))
                            .foregroundColor(isSel ? .white : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Eject Volume")
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(isSel ? Color.accentColor : Color.clear).cornerRadius(6)
        }
        .buttonStyle(.plain).padding(.horizontal, 8)
        .contextMenu {
            Button(appState.tr(.open)) { appState.navigateTo(item.url) }
            Button(appState.tr(.copyPath)) {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(item.url.path, forType: .string)
            }
            Divider()
            if isFavoritesSection || appState.isFavorite(item.url) {
                Button(appState.tr(.removeFromFavorites)) {
                    appState.removeFavorite(item.url)
                }
            } else {
                Button(appState.tr(.addToFavorites)) {
                    appState.addFavorite(item.url)
                }
            }
            Divider()
            Button("\(appState.tr(.properties)) (Cmd+I)") {
                let fileItem = FileItem(url: item.url, icon: NSWorkspace.shared.icon(forFile: item.url.path))
                appState.propertiesItem = fileItem
            }
        }
    }
}
