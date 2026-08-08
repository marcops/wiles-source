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
        for url in appState.navigation.historyBack.reversed() {
            let std = url.standardizedFileURL
            if !seen.contains(std) && std != appState.navigation.currentURL.standardizedFileURL {
                seen.insert(std)
                items.append(sidebarItem(for: std))
                if items.count >= LayoutTokens.maxRecentItemsCount { break }
            }
        }
        return items
    }

    @State private var rootFolderNode: FolderNode?

    var body: some View {
        @Bindable var appState = appState

        let favItems = appState.preferences.favoriteURLs.map { sidebarItem(for: $0) }

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if appState.preferences.showRecents {
                    let recentsItem = SidebarItem(name: appState.tr(.recents), iconName: "clock.fill", url: AppState.recentsVirtualURL)
                    sidebarRow(for: recentsItem, sectionKey: "Recents")
                }

                if appState.preferences.showFavorites && !favItems.isEmpty {
                    collapsibleSection(
                        title: appState.tr(.favorites),
                        identifierKey: "FAVORITES",
                        isExpanded: $appState.preferences.isFavoritesExpanded,
                        items: favItems,
                        isFavoritesSection: true
                    )
                }

                if appState.preferences.showNetworkAndCloud {
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
                        identifierKey: "NETWORK",
                        isExpanded: $appState.preferences.isNetworkExpanded,
                        items: items,
                        isFavoritesSection: false
                    )
                }

                if appState.preferences.showPlaces {
                    collapsibleSection(
                        title: appState.tr(.places),
                        identifierKey: "PLACES",
                        isExpanded: $appState.preferences.isDevicesExpanded,
                        items: devices,
                        isFavoritesSection: false
                    )
                }

                if appState.preferences.showDirectoryTree {
                    VStack(alignment: .leading, spacing: 4) {
                        if appState.preferences.showSidebarSectionTitles {
                            sectionHeader(title: appState.tr(.directoryTree), identifierKey: "DIRECTORY_TREE", isExpanded: $appState.preferences.isTreeExpanded)
                        }
                        if !appState.preferences.showSidebarSectionTitles || appState.preferences.isTreeExpanded {
                            if let rootFolderNode {
                                DirectoryTreeNodeView(node: rootFolderNode, depth: 0, appState: appState)
                            } else {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.horizontal, 12)
                            }
                        }
                    }
                }

                if appState.preferences.showTags {
                    VStack(alignment: .leading, spacing: 4) {
                        if appState.preferences.showSidebarSectionTitles {
                            sectionHeader(title: appState.tr(.tags), identifierKey: "TAGS", isExpanded: $appState.preferences.isTagsExpanded)
                        }
                        if !appState.preferences.showSidebarSectionTitles || appState.preferences.isTagsExpanded {
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
                        if appState.preferences.showSidebarSectionTitles {
                            sectionHeader(title: appState.tr(.smartFolders), identifierKey: "SMART_FOLDERS", isExpanded: $appState.preferences.isSmartFoldersExpanded)
                        }
                        if !appState.preferences.showSidebarSectionTitles || appState.preferences.isSmartFoldersExpanded {
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
        .task {
            guard rootFolderNode == nil else { return }
            let node = await Task.detached(priority: .userInitiated) {
                FolderNode.buildRootTree()
            }.value
            rootFolderNode = node
        }
        .background(
            ZStack {
                TranslucentVisualEffectView(material: .sidebar)
                Color(NSColor.windowBackgroundColor)
                    .opacity(appState.preferences.sidebarOverlayOpacity)
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

    // `identifierKey` is a fixed, non-localized key (e.g. "FAVORITES") kept separate from the
    // localized `title` shown on screen — accessibility identifiers must stay stable across
    // languages so UI tests and automation don't break when the OS language changes.
    // See AGENTS.md rule 33: a real `Button` on macOS does not reliably honor `.contentShape` for
    // composite (icon + text) label content, so this uses a plain view + `.onTapGesture` instead.
    private func sectionHeader(title: String, identifierKey: String, isExpanded: Binding<Bool>) -> some View {
        HStack(spacing: 4) {
            Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 12)
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(MotionTokens.quickEase) {
                isExpanded.wrappedValue.toggle()
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("Section_\(identifierKey)")
        .accessibilityLabel(title)
        .accessibilityHint(appState.tr(.folder))
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
                    .font(.system(size: 12, weight: isSel ? .semibold : .regular, design: .rounded))
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

    private func collapsibleSection(title: String, identifierKey: String, isExpanded: Binding<Bool>, items: [SidebarItem], isFavoritesSection: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if appState.preferences.showSidebarSectionTitles {
                sectionHeader(title: title, identifierKey: identifierKey, isExpanded: isExpanded)
            }
            if !appState.preferences.showSidebarSectionTitles || isExpanded.wrappedValue {
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

        if url == AppState.recentsVirtualURL || std.absoluteString == AppState.recentsVirtualURL.absoluteString {
            return SidebarItem(name: appState.tr(.recents), iconName: "clock.fill", url: std)
        }
        if let wellKnown = wellKnownSidebarInfo(forPath: path, home: home) {
            return SidebarItem(name: wellKnown.name, iconName: wellKnown.icon, url: std)
        }
        let name = std.lastPathComponent.isEmpty ? "/" : std.lastPathComponent
        return SidebarItem(name: name, iconName: "folder.fill", url: std)
    }

    private func wellKnownSidebarInfo(forPath path: String, home: URL) -> (name: String, icon: String)? {
        switch path {
        case home.path: return (appState.tr(.home), "house.fill")
        case home.appendingPathComponent("Desktop").path: return (appState.tr(.desktop), "desktopcomputer")
        case home.appendingPathComponent("Documents").path: return (appState.tr(.sidebarDocuments), "doc.fill")
        case home.appendingPathComponent("Downloads").path: return (appState.tr(.downloads), "arrow.down.circle.fill")
        case "/Applications": return (appState.tr(.applications), "square.grid.3x3.fill")
        case home.appendingPathComponent("Music").path: return (appState.tr(.music), "music.note")
        case home.appendingPathComponent("Pictures").path: return (appState.tr(.pictures), "photo.fill")
        case home.appendingPathComponent("Movies").path: return (appState.tr(.movies), "film.fill")
        case home.appendingPathComponent(".Trash").path: return (appState.tr(.sidebarTrash), "trash.fill")
        case "/": return ("Macintosh HD", "internaldrive.fill")
        default: return nil
        }
    }

    private func smartFolderRow(folder: SmartFolder) -> some View {
        Button {
            runSmartFolder(folder)
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

    private func runSmartFolder(_ folder: SmartFolder) {
        appState.searchQuery = folder.searchQuery
        appState.isSearching = true
        SmartFolderService.shared.executeQuery(for: folder) { items in
            Task { @MainActor in
                appState.fileSystem.items = items
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
    @Environment(WindowUIState.self)
    private var windowUIState
    let isFavoritesSection: Bool
    let isRightClicked: Bool
    let isAnotherRowRightClicked: Bool
    let onRightClick: () -> Void
    let onLeftClick: () -> Void

    @State private var isDragTargeted = false

    @State private var isHovered = false

    var body: some View {
        let isCurrentFolder = appState.navigation.currentURL.standardizedFileURL == item.url.standardizedFileURL
        let isSel = isRightClicked || (isCurrentFolder && !isAnotherRowRightClicked)
        let isTrash = item.url.standardizedFileURL == URL.userTrash.standardizedFileURL
        // See AGENTS.md rule 33: a real `Button` on macOS does not reliably honor `.contentShape`
        // for composite (icon + text) label content, so this uses a plain view + `.onTapGesture`.
        return HStack(spacing: 10) {
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
                .help(appState.tr(.ejectVolume))
                .accessibilityLabel(appState.tr(.ejectVolume))
                .accessibilityHint(appState.tr(.ejectVolume))
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
        .onTapGesture {
            onLeftClick()
            appState.navigateTo(item.url)
            appState.selectedFavoriteURL = isFavoritesSection ? item.url : nil
        }
        .padding(.horizontal, 8)
        .accessibilityAddTraits(isSel ? [.isButton, .isSelected] : [.isButton])
        .accessibilityIdentifier(item.name)
        .accessibilityLabel(item.name)
        .accessibilityHint(appState.tr(.folder))
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
                    CopyPathService.copy(urls: [item.url], variant: .relative, relativeTo: appState.navigation.currentURL)
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
                windowUIState.propertiesItem = fileItem
            }
            if isTrash {
                Divider()
                Button("\(appState.tr(.emptyTrash))...") {
                    windowUIState.showEmptyTrashAlert = true
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
                        appState.showError(error)
                    }
                }
            }
        }
    }
}
