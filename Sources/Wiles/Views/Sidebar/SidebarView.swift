import SwiftUI
import AppKit

struct SidebarView: View {
    var appState: AppState
    @State private var rightClickedRowKey: String?

    var devices: [SidebarItem] {
        let home = URL.userHome
        let cloudDocs = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        let airDrop = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app/Contents/Applications/AirDrop.app")
        let trashURL = URL.userTrash

        return [
            SidebarItem(name: appState.tr(.applications), iconName: "square.grid.3x3.fill", url: URL(fileURLWithPath: "/Applications")),
            SidebarItem(name: appState.tr(.airDrop), iconName: "dot.radiowaves.left.and.right", url: airDrop),
            SidebarItem(name: appState.tr(.iCloudDrive), iconName: "icloud.fill", url: cloudDocs),
            SidebarItem(name: "Macintosh HD", iconName: "internaldrive.fill", url: URL(fileURLWithPath: "/")),
            SidebarItem(name: appState.tr(.sidebarTrash), iconName: "trash.fill", url: trashURL)
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

        let favItems = appState.favoriteURLs.map { sidebarItem(for: $0) }

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if appState.showRecents {
                    let recentsItem = SidebarItem(name: appState.tr(.recents), iconName: "clock.fill", url: AppState.recentsVirtualURL)
                    sidebarRow(for: recentsItem, sectionKey: "Recents")
                }

                if appState.showFavorites && !favItems.isEmpty {
                    collapsibleSection(
                        title: appState.tr(.favorites),
                        isExpanded: $appState.isFavoritesExpanded,
                        items: favItems,
                        isFavoritesSection: true
                    )
                }

                if appState.showNetworkAndCloud {
                    let items: [SidebarItem] = {
                        let networkShares = NetworkDiscoveryService.shared.discoveredShares.map {
                            SidebarItem(name: $0.name, iconName: "network", url: $0.url)
                        }
                        var list = [SidebarItem(name: "Network", iconName: "network", url: URL(fileURLWithPath: "/Network"))]
                        list.append(contentsOf: networkShares)
                        return list
                    }()
                    collapsibleSection(
                        title: appState.tr(.networkAndCloud),
                        isExpanded: $appState.isNetworkExpanded,
                        items: items,
                        isFavoritesSection: false
                    )
                }

                if appState.showPlaces && appState.sidebarMode == .places {
                    collapsibleSection(
                        title: appState.tr(.places),
                        isExpanded: $appState.isDevicesExpanded,
                        items: devices,
                        isFavoritesSection: false
                    )
                } else if appState.sidebarMode == .tree {
                    VStack(alignment: .leading, spacing: 4) {
                        if appState.showSidebarSectionTitles {
                            sectionHeader(title: appState.tr(.directoryTree), isExpanded: $appState.isTreeExpanded)
                        }
                        if !appState.showSidebarSectionTitles || appState.isTreeExpanded {
                            DirectoryTreeNodeView(node: rootFolderNode, depth: 0, appState: appState)
                        }
                    }
                }

                if appState.showTags {
                    VStack(alignment: .leading, spacing: 4) {
                        if appState.showSidebarSectionTitles {
                            sectionHeader(title: appState.tr(.tags), isExpanded: $appState.isTagsExpanded)
                        }
                        if !appState.showSidebarSectionTitles || appState.isTagsExpanded {
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

                if !appState.smartFolders.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        if appState.showSidebarSectionTitles {
                            sectionHeader(title: appState.tr(.smartFolders), isExpanded: $appState.isSmartFoldersExpanded)
                        }
                        if !appState.showSidebarSectionTitles || appState.isSmartFoldersExpanded {
                            ForEach(appState.smartFolders) { folder in
                                smartFolderRow(folder: folder)
                            }
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
        Button {
            withAnimation(MotionTokens.quickEase) {
                isExpanded.wrappedValue.toggle()
            }
        } label: {
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
        return Button {
            if isSel {
                appState.searchQuery = ""
            } else {
                appState.searchQuery = query
            }
        } label: {
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
            if appState.showSidebarSectionTitles {
                sectionHeader(title: title, isExpanded: isExpanded)
            }
            if !appState.showSidebarSectionTitles || isExpanded.wrappedValue {
                ForEach(items) { item in
                    sidebarRow(for: item, sectionKey: title, isFavoritesSection: isFavoritesSection)
                }
            }
        }
    }

    private func sidebarItem(for url: URL) -> SidebarItem {
        let home = URL.userHome.standardizedFileURL
        let std = url.standardizedFileURL
        let path = std.path

        let icon: String
        let name: String

        if url == AppState.recentsVirtualURL || std.absoluteString == AppState.recentsVirtualURL.absoluteString {
            name = appState.tr(.recents); icon = "clock.fill"
        } else if path == home.path {
            name = appState.tr(.home); icon = "house.fill"
        } else if path == home.appendingPathComponent("Desktop").path {
            name = appState.tr(.desktop); icon = "desktopcomputer"
        } else if path == home.appendingPathComponent("Documents").path {
            name = appState.tr(.sidebarDocuments); icon = "doc.fill"
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
            name = appState.tr(.sidebarTrash); icon = "trash.fill"
        } else if path == "/" {
            name = "Macintosh HD"; icon = "internaldrive.fill"
        } else {
            name = std.lastPathComponent.isEmpty ? "/" : std.lastPathComponent
            icon = "folder.fill"
        }
        return SidebarItem(name: name, iconName: icon, url: std)
    }

    private func smartFolderRow(folder: SmartFolder) -> some View {
        Button {
            appState.searchQuery = folder.searchQuery
            appState.isSearching = true
            SmartFolderService.shared.executeQuery(for: folder) { items in
                Task { @MainActor in
                    appState.items = items
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: folder.icon)
                    .foregroundColor(.accentColor)
                    .frame(width: 16, height: 16)
                Text(folder.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(appState.tr(.moveToTrash), role: .destructive) {
                appState.removeSmartFolder(folder)
            }
        }
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

    @State private var isHovered = false

    var body: some View {
        let isCurrentFolder = appState.currentURL.standardizedFileURL == item.url.standardizedFileURL
        let isSel = isRightClicked || (isCurrentFolder && !isAnotherRowRightClicked)
        let isTrash = item.url.standardizedFileURL == URL.userTrash.standardizedFileURL
        return Button {
            onLeftClick()
            appState.navigateTo(item.url)
        } label: {
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
                    } else if !appState.trashSizeString.isEmpty
                        && !["Zero KB", "0 KB", "0 bytes"].contains(appState.trashSizeString) {
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
                    Button {
                        let target = item.url
                        do {
                            try NSWorkspace.shared.unmountAndEjectDevice(at: target)
                            appState.refreshCurrentDirectory()
                        } catch {
                            appState.showError(error.localizedDescription)
                        }
                    } label: {
                        Image(systemName: "eject.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Eject Volume")
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(
                isDragTargeted ? Color.accentColor.opacity(0.25) :
                (isSel ? Color.accentColor.opacity(0.18) :
                (isHovered ? Color.primary.opacity(0.06) : Color.clear))
            )
            .cornerRadius(8)
            .scaleEffect(isDragTargeted ? 1.02 : 1.0)
            .animation(MotionTokens.snappySpring, value: isDragTargeted)
            .animation(MotionTokens.quickEase, value: isHovered)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).padding(.horizontal, 8)
        .onHover { isHovered = $0 }
        .overlay(
            RightClickDetector { onRightClick() }
        )
        .springLoadedFolder(folderURL: item.url, isDirectory: true, appState: appState) { targeted in
            withAnimation(MotionTokens.quickEase) { isDragTargeted = targeted }
        }
        .contextMenu {
            Button(appState.tr(.open)) { appState.navigateTo(item.url) }
            Menu(appState.tr(.copyPath)) {
                Button(appState.tr(.copyPathAbsolute)) {
                    CopyPathService.copy(urls: [item.url], variant: .absolute)
                }
                Button(appState.tr(.copyPathRelative)) {
                    CopyPathService.copy(urls: [item.url], variant: .relative, relativeTo: appState.currentURL)
                }
                Button(appState.tr(.copyPathURL)) {
                    CopyPathService.copy(urls: [item.url], variant: .fileURL)
                }
                Button(appState.tr(.copyPathTerminal)) {
                    CopyPathService.copy(urls: [item.url], variant: .terminalEscaped)
                }
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
                    do {
                        _ = try FileSystemService.moveItem(at: url, toFolder: targetFolder)
                        appState.refreshCurrentDirectory()
                    } catch {
                        appState.showError(error.localizedDescription)
                    }
                }
            }
        }
    }
}
