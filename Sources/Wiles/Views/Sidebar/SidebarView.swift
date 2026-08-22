import AppKit
import SwiftUI

struct SidebarView: View {
    var appState: AppState
    @Environment(WindowUIState.self)
    private var windowUIState
    @State private var rightClickedRowKey: String?
    @State private var renamingSmartFolderID: SmartFolder.ID?
    @State private var smartFolderRenameText: String = ""
    @FocusState private var isSmartFolderRenameFocused: Bool
    @State private var collapseWorkItem: DispatchWorkItem?

    private var isCompact: Bool {
        appState.preferences.isSidebarCollapsed && !windowUIState.isSidebarPeeking
    }

    var devices: [SidebarItem] {
        let home = URL.userHome
        let cloudDocs = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        let airDrop = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app/Contents/Applications/AirDrop.app")
        let trashURL = URL.userTrash

        return [
            SidebarItem(name: appState.tr(.applications), iconName: "square.grid.3x3.fill", url: URL(fileURLWithPath: "/Applications")),
            SidebarItem(name: appState.tr(.airDrop), iconName: "dot.radiowaves.left.and.right", url: airDrop),
            SidebarItem(name: appState.tr(.iCloudDrive), iconName: "icloud.fill", url: cloudDocs),
            SidebarItem(name: appState.tr(.macintoshHDName), iconName: "internaldrive.fill", url: URL(fileURLWithPath: "/")),
            SidebarItem(name: appState.tr(.sidebarTrash), iconName: "trash.fill", url: trashURL)
        ]
    }

    var recentItems: [SidebarItem] {
        var seen = Set<URL>()
        var items: [SidebarItem] = []
        for url in appState.navigation.historyBack.reversed() {
            let std = url.standardizedFileURL
            if !seen.contains(std), std != appState.navigation.currentURL.standardizedFileURL {
                seen.insert(std)
                items.append(sidebarItem(for: std))
                if items.count >= LayoutTokens.maxRecentItemsCount {
                    break
                }
            }
        }
        return items
    }

    @State private var rootFolderNode: FolderNode?
    @State private var treeChildrenCache = BoundedFolderNodeCache()

    var body: some View {
        @Bindable var appState = appState

        return GeometryReader { proxy in
            // Vertical only: rows truncate labels instead of needing horizontal scroll.
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 14) {
                    sidebarSectionsContent
                }
                .frame(
                    minWidth: proxy.size.width,
                    maxWidth: proxy.size.width,
                    minHeight: proxy.size.height - LayoutTokens.scrollbarReservedThickness,
                    alignment: .topLeading)
                .padding(.top, LayoutTokens.sidebarTrafficLightInset)
                .padding(.bottom, 12)
            }
            .background(ScrollerAutoHideSetter())
        }
        .frame(minWidth: LayoutTokens.sidebarMinWidth, idealWidth: LayoutTokens.sidebarIdealWidth, maxHeight: .infinity)
        .onHover { hovering in
            guard appState.preferences.isSidebarCollapsed else { return }
            collapseWorkItem?.cancel()
            if hovering {
                windowUIState.isSidebarPeeking = true
            } else {
                let workItem = DispatchWorkItem { windowUIState.isSidebarPeeking = false }
                collapseWorkItem = workItem
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + .milliseconds(LayoutTokens.sidebarPeekCollapseDelayMs), execute: workItem)
            }
        }
        .task {
            guard rootFolderNode == nil else { return }
            let buildTask = Task.detached(priority: .userInitiated) { FolderNode.buildRootTree() }
            // GCD timer, not a sibling Task: a stuck detached scan can starve the cooperative thread
            // pool, and a `Task.sleep` timeout sharing that pool would starve right along with it.
            let fallbackWorkItem = DispatchWorkItem {
                guard rootFolderNode == nil else { return }
                buildTask.cancel()
                let root = URL(fileURLWithPath: "/")
                rootFolderNode = FolderNode(id: root, name: "Root (/)", url: root, children: [], hasSubfolders: false)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: fallbackWorkItem)
            let node = await buildTask.value
            guard rootFolderNode == nil else { return }
            fallbackWorkItem.cancel()
            rootFolderNode = node
        }
        .background(
            ZStack {
                TranslucentVisualEffectView(material: .sidebar)
                Color(NSColor.windowBackgroundColor)
                    .opacity(appState.preferences.sidebarOverlayOpacity)
            }
            .ignoresSafeArea())
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

    private var favoriteItems: [SidebarItem] {
        appState.preferences.favoriteURLs.map { sidebarItem(for: $0) }
    }

    private var networkAndCloudItems: [SidebarItem] {
        let networkShares = NetworkDiscoveryService.shared.discoveredShares.map {
            SidebarItem(name: $0.name, iconName: "network", url: $0.url)
        }
        var list = [SidebarItem(name: appState.tr(.networkVolumeName), iconName: "network", url: URL(fileURLWithPath: "/Network"))]
        list.append(contentsOf: networkShares)
        return list
    }

    @ViewBuilder private var sidebarSectionsContent: some View {
        @Bindable var appState = appState

        if appState.preferences.showRecents {
            let recentsItem = SidebarItem(name: appState.tr(.recents), iconName: "clock.fill", url: AppState.recentsVirtualURL)
            sidebarRow(for: recentsItem, sectionKey: "Recents")
        }
        if appState.preferences.showFavorites, !favoriteItems.isEmpty {
            collapsibleSection(
                title: appState.tr(.favorites), identifierKey: "FAVORITES",
                isExpanded: $appState.preferences.isFavoritesExpanded, items: favoriteItems, isFavoritesSection: true)
        }
        if appState.preferences.showNetworkAndCloud {
            collapsibleSection(
                title: appState.tr(.networkAndCloud), identifierKey: "NETWORK",
                isExpanded: $appState.preferences.isNetworkExpanded, items: networkAndCloudItems, isFavoritesSection: false)
        }
        if appState.preferences.showPlaces {
            collapsibleSection(
                title: appState.tr(.places), identifierKey: "PLACES",
                isExpanded: $appState.preferences.isDevicesExpanded, items: devices, isFavoritesSection: false)
        }
        // The tree/tags/smart-folder sections have their own nested structure that doesn't reduce
        // to a flat icon list, so they're skipped in the collapsed rail rather than shown.
        if !isCompact {
            if appState.preferences.showDirectoryTree {
                DirectoryTreeSectionView(
                    appState: appState, isExpanded: $appState.preferences.isTreeExpanded,
                    rootFolderNode: rootFolderNode, childrenCache: $treeChildrenCache)
            }
            if appState.preferences.showTags {
                TagsSectionView(appState: appState, isExpanded: $appState.preferences.isTagsExpanded)
            }
            if !appState.preferences.smartFolders.isEmpty {
                SmartFoldersSectionView(
                    appState: appState, isExpanded: $appState.preferences.isSmartFoldersExpanded,
                    renamingSmartFolderID: $renamingSmartFolderID, smartFolderRenameText: $smartFolderRenameText,
                    isRenameFocused: $isSmartFolderRenameFocused)
            }
        }
    }

    private func shouldShowSectionItems(isExpanded: Bool) -> Bool {
        isCompact || !appState.preferences.showSidebarSectionTitles || isExpanded
    }

    private func collapsibleSection(
        title: String,
        identifierKey: String,
        isExpanded: Binding<Bool>,
        items: [SidebarItem],
        isFavoritesSection: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if appState.preferences.showSidebarSectionTitles, !isCompact {
                SidebarSectionHeaderView(title: title, identifierKey: identifierKey, appState: appState, isExpanded: isExpanded)
            }
            if shouldShowSectionItems(isExpanded: isExpanded.wrappedValue) {
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
        case home.path: (appState.tr(.home), "house.fill")
        case home.appendingPathComponent("Desktop").path: (appState.tr(.desktop), "desktopcomputer")
        case home.appendingPathComponent("Documents").path: (appState.tr(.sidebarDocuments), "doc.fill")
        case home.appendingPathComponent("Downloads").path: (appState.tr(.downloads), "arrow.down.circle.fill")
        case "/Applications": (appState.tr(.applications), "square.grid.3x3.fill")
        case home.appendingPathComponent("Music").path: (appState.tr(.music), "music.note")
        case home.appendingPathComponent("Pictures").path: (appState.tr(.pictures), "photo.fill")
        case home.appendingPathComponent("Movies").path: (appState.tr(.movies), "film.fill")
        case home.appendingPathComponent(".Trash").path: (appState.tr(.sidebarTrash), "trash.fill")
        case "/": (appState.tr(.macintoshHDName), "internaldrive.fill")
        default: nil
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
            isCompact: isCompact,
            onRightClick: { rightClickedRowKey = rowKey },
            onLeftClick: { rightClickedRowKey = nil })
    }
}
