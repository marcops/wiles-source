import SwiftUI
import AppKit

struct SidebarView: View {
    var appState: AppState
    @State private var rightClickedRowKey: String?

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
        
        let favItems: [SidebarItem] = {
            var items = appState.favoriteURLs.map { sidebarItem(for: $0) }
            if appState.showRecents {
                let recentsItem = SidebarItem(name: appState.tr(.recents), iconName: "clock.fill", url: AppState.recentsVirtualURL)
                items.insert(recentsItem, at: 0)
            }
            return items
        }()

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if appState.showFavorites && !favItems.isEmpty {
                    collapsibleSection(
                        title: appState.tr(.favorites),
                        isExpanded: $appState.isFavoritesExpanded,
                        items: favItems,
                        isFavoritesSection: true
                    )
                }
                
                if appState.showMacSection {
                    collapsibleSection(
                        title: appState.tr(.mac),
                        isExpanded: $appState.isMacExpanded,
                        items: macItems,
                        isFavoritesSection: false
                    )
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
            .padding(.top, LayoutTokens.sidebarTrafficLightInset)
            .padding(.bottom, 12)
        }
        .frame(minWidth: LayoutTokens.sidebarMinWidth, idealWidth: LayoutTokens.sidebarIdealWidth, maxHeight: .infinity)
        .background(
            ZStack {
                TranslucentVisualEffectView(material: .sidebar)
                Color(NSColor.windowBackgroundColor)
                    .opacity(appState.sidebarOverlayOpacity)
            }
            .ignoresSafeArea()
        )
        .overlay(alignment: .top) {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: LayoutTokens.sidebarDoubleClickZoneHeight)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    NSApp.keyWindow?.zoom(nil)
                }
        }
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
                    .font(.system(size: 12, weight: isSel ? .semibold : .regular))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(isSel ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
    }
    
    private func collapsibleSection(title: String, isExpanded: Binding<Bool>, items: [SidebarItem], isFavoritesSection: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader(title: title, isExpanded: isExpanded)
            if isExpanded.wrappedValue {
                ForEach(items) { item in
                    sidebarRow(for: item, sectionKey: title, isFavoritesSection: isFavoritesSection)
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
    
    private func sidebarRow(for item: SidebarItem, sectionKey: String, isFavoritesSection: Bool = false) -> some View {
        let rowKey = "\(sectionKey)|\(item.url.path)"
        return SidebarRowView(
            item: item,
            appState: appState,
            isFavoritesSection: isFavoritesSection,
            isRightClicked: rightClickedRowKey == rowKey,
            isAnotherRowRightClicked: rightClickedRowKey != nil && rightClickedRowKey != rowKey,
            onRightClick: { rightClickedRowKey = rowKey },
            onLeftClick: { rightClickedRowKey = nil }
        )
    }
}

private struct SidebarRowView: View {
    let item: SidebarItem
    var appState: AppState
    let isFavoritesSection: Bool
    let isRightClicked: Bool
    let isAnotherRowRightClicked: Bool
    let onRightClick: () -> Void
    let onLeftClick: () -> Void

    @State private var isDragTargeted = false

    var body: some View {
        let isCurrentFolder = appState.currentURL.standardizedFileURL == item.url.standardizedFileURL
        let isSel = isRightClicked || (isCurrentFolder && !isAnotherRowRightClicked)
        let isTrash = item.url.standardizedFileURL == FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first?.standardizedFileURL
        return Button(action: {
            onLeftClick()
            appState.navigateTo(item.url)
        }) {
            HStack(spacing: 10) {
                Image(systemName: item.iconName)
                    .font(.system(size: 15)).foregroundColor(.accentColor).frame(width: 20)
                Text(item.name)
                    .font(.system(size: 13, weight: isSel ? .semibold : .regular))
                    .foregroundColor(.primary)
                Spacer()
                if isTrash {
                    if appState.isTrashUpdating {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.mini)
                            .scaleEffect(0.6)
                            .frame(width: 16, height: 16)
                    } else if !appState.trashSizeString.isEmpty && appState.trashSizeString != "Zero KB" && appState.trashSizeString != "0 KB" && appState.trashSizeString != "0 bytes" {
                        Text(appState.trashSizeString)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(10)
                    }
                }
                if item.url.path.hasPrefix("/Volumes/") && item.url.path != "/" {
                    Button(action: {
                        let target = item.url
                        try? NSWorkspace.shared.unmountAndEjectDevice(at: target)
                        appState.refreshCurrentDirectory()
                    }) {
                        Image(systemName: "eject.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Eject Volume")
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(isDragTargeted ? Color.accentColor.opacity(0.25) : (isSel ? Color.accentColor.opacity(0.15) : Color.clear))
            .cornerRadius(8)
            .scaleEffect(isDragTargeted ? 1.02 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDragTargeted)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).padding(.horizontal, 8)
        .overlay(
            RightClickDetector { onRightClick() }
        )
        .onDrop(of: [.fileURL], isTargeted: $isDragTargeted) { providers in
            handleDrop(providers: providers, targetFolder: item.url)
            return true
        }
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
            if isTrash {
                Divider()
                Button("\(appState.tr(.emptyTrash))...") {
                    appState.showEmptyTrashAlert = true
                }
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider], targetFolder: URL) {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else { return }
                Task { @MainActor in
                    _ = try? FileSystemService.moveItem(at: url, toFolder: targetFolder)
                    appState.refreshCurrentDirectory()
                }
            }
        }
    }
}
