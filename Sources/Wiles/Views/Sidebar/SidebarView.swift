import AppKit
import SwiftUI

struct SidebarView: View {
    private static let trafficLightInset: CGFloat = 12.0
    private static let doubleClickZoneHeight: CGFloat = trafficLightInset
    /// Tall enough to sit fully behind the traffic-light buttons (they extend past
    /// `trafficLightInset`), so `trafficLightFrostStrip` gives them a backdrop rather than
    /// leaving them floating over bare content.
    private static let trafficLightZoneHeight: CGFloat = 26.0
    /// Taller than `trafficLightInset` on purpose: its bottom few points reach slightly into the
    /// first row's normal (non-overscrolled) position, so that row's label starts a soft fade-in
    /// instead of a hard edge — without moving `trafficLightInset` (and therefore the first row's
    /// resting position) itself.
    private static let topFadeHeight: CGFloat = 20.0
    private static let peekCollapseDelayMs: Int = 250
    private static let rootTreeFallbackTimeout: TimeInterval = 6

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
        let trashURL = URL.userTrash

        return [
            SidebarItem(name: appState.tr(.applications), iconName: "square.grid.3x3.fill", url: URL(fileURLWithPath: "/Applications")),
            SidebarItem(name: appState.tr(.airDrop), iconName: "dot.radiowaves.left.and.right", url: SidebarItem.airDropURL),
            SidebarItem(name: appState.tr(.iCloudDrive), iconName: "icloud.fill", url: cloudDocs),
            SidebarItem(name: appState.tr(.macintoshHDName), iconName: "internaldrive.fill", url: URL(fileURLWithPath: "/")),
            SidebarItem(name: appState.tr(.sidebarTrash), iconName: "trash.fill", url: trashURL)
        ]
    }

    @State private var rootFolderNode: FolderNode?
    @State private var treeChildrenCache = BoundedFolderNodeCache()
    @State private var treeBuildTimedOut = false
    @State private var treeBuildGeneration = 0

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
                .padding(.top, Self.trafficLightInset)
                .padding(.bottom, 12)
            }
            .background(ScrollerAutoHideSetter())
        }
        .frame(minWidth: LayoutTokens.sidebarMinWidth, idealWidth: LayoutTokens.sidebarIdealWidth, maxHeight: .infinity)
        .onHover(perform: handleSidebarHover)
        .onDisappear { collapseWorkItem?.cancel() }
        .task(id: treeBuildGeneration, buildDirectoryTree)
        .translucentBackground(material: .sidebar, opacity: appState.preferences.sidebarOverlayOpacity, ignoresSafeArea: true)
        // At the SidebarView level (not the ScrollView's), so it reaches the true window top —
        // the ScrollView insets its own overlay past the traffic lights, landing the strip below them.
        .overlay(alignment: .top) {
            trafficLightFrostStrip.ignoresSafeArea(.all, edges: .top)
        }
        .overlay(alignment: .top) {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: Self.doubleClickZoneHeight)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    NSApp.keyWindow?.zoom(nil)
                }
        }
    }

    /// A translucent frosted backdrop for the traffic-light buttons: solid over the button zone,
    /// then fading out. It replaces a hard mask that erased content there — an overscrolled row
    /// label stays faintly visible through the blur instead of dropping into a bare gap, while the
    /// buttons still read against a real (if see-through) background.
    private var trafficLightFrostStrip: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .frame(height: Self.trafficLightZoneHeight + Self.topFadeHeight)
            .mask(alignment: .top) {
                VStack(spacing: 0) {
                    Color.black.frame(height: Self.trafficLightZoneHeight)
                    LinearGradient(
                        colors: [.black, .black.opacity(0)],
                        startPoint: .top, endPoint: .bottom)
                        .frame(height: Self.topFadeHeight)
                }
            }
            .allowsHitTesting(false)
    }

    private func handleSidebarHover(_ hovering: Bool) {
        guard appState.preferences.isSidebarCollapsed else { return }
        collapseWorkItem?.cancel()
        if hovering {
            windowUIState.isSidebarPeeking = true
        } else {
            let workItem = DispatchWorkItem { windowUIState.isSidebarPeeking = false }
            collapseWorkItem = workItem
            DispatchQueue.main.asyncAfter(
                deadline: .now() + .milliseconds(Self.peekCollapseDelayMs), execute: workItem)
        }
    }

    /// After `rootTreeFallbackTimeout`, leaves `rootFolderNode` nil so the Retry button shows
    /// instead of a fake node — the still-running scan can still finish and populate it later.
    private func buildDirectoryTree() async {
        guard rootFolderNode == nil else { return }
        treeBuildTimedOut = false
        let buildTask = Task.detached(priority: .userInitiated) { FolderNode.buildRootTree() }
        // GCD timer, not a sibling Task: a stuck detached scan can starve the cooperative thread
        // pool, and a `Task.sleep` timeout sharing that pool would starve right along with it.
        let fallbackWorkItem = DispatchWorkItem {
            guard rootFolderNode == nil else { return }
            treeBuildTimedOut = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.rootTreeFallbackTimeout, execute: fallbackWorkItem)
        let node = await buildTask.value
        fallbackWorkItem.cancel()
        treeBuildTimedOut = false
        rootFolderNode = node
    }

    private func retryTreeBuild() {
        rootFolderNode = nil
        treeBuildTimedOut = false
        treeBuildGeneration += 1
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
            sidebarRow(for: recentsItem, sectionKey: "RECENTS")
        }
        if appState.preferences.showFavorites, !favoriteItems.isEmpty {
            collapsibleSection(
                title: appState.tr(.favorites), identifierKey: "FAVORITES",
                isExpanded: $appState.preferences.isFavoritesExpanded, items: favoriteItems, isFavoritesSection: true,
                hideAction: { appState.preferences.showFavorites = false })
        }
        if appState.preferences.showNetworkAndCloud {
            collapsibleSection(
                title: appState.tr(.networkAndCloud), identifierKey: "NETWORK",
                isExpanded: $appState.preferences.isNetworkExpanded, items: networkAndCloudItems, isFavoritesSection: false,
                hideAction: { appState.preferences.showNetworkAndCloud = false })
        }
        if appState.preferences.showPlaces {
            collapsibleSection(
                title: appState.tr(.places), identifierKey: "PLACES",
                isExpanded: $appState.preferences.isDevicesExpanded, items: devices, isFavoritesSection: false,
                hideAction: { appState.preferences.showPlaces = false })
        }
        // The tree/tags/smart-folder sections have their own nested structure that doesn't reduce
        // to a flat icon list, so they're skipped in the collapsed rail rather than shown.
        if !isCompact {
            if appState.preferences.showDirectoryTree {
                DirectoryTreeSectionView(
                    appState: appState, isExpanded: $appState.preferences.isTreeExpanded,
                    rootFolderNode: rootFolderNode, childrenCache: $treeChildrenCache,
                    didTimeOut: treeBuildTimedOut, onRetry: retryTreeBuild)
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

    private func collapsibleSection(
        title: String,
        identifierKey: String,
        isExpanded: Binding<Bool>,
        items: [SidebarItem],
        isFavoritesSection: Bool = false,
        hideAction: (() -> Void)? = nil) -> some View {
        SidebarSectionContainer(
            appState: appState, title: title, identifierKey: identifierKey, isExpanded: isExpanded,
            hideHeader: isCompact, forceShowContent: isCompact, hideAction: hideAction) {
                ForEach(items) { item in
                    sidebarRow(for: item, sectionKey: identifierKey, isFavoritesSection: isFavoritesSection)
                }
            }
    }

    /// Path -> (localization key, icon) for well-known folders, built once since `URL.userHome`
    /// is fixed for the process. Avoids re-constructing ~9 URLs via `appendingPathComponent`
    /// on every sidebar row on every render.
    private static let wellKnownPaths: [String: (key: L10n.Key, icon: String)] = {
        let home = URL.userHome.standardizedFileURL
        return [
            home.path: (.home, "house.fill"),
            home.appendingPathComponent("Desktop").path: (.desktop, "desktopcomputer"),
            home.appendingPathComponent("Documents").path: (.sidebarDocuments, "doc.fill"),
            home.appendingPathComponent("Downloads").path: (.downloads, "arrow.down.circle.fill"),
            "/Applications": (.applications, "square.grid.3x3.fill"),
            home.appendingPathComponent("Music").path: (.music, "music.note"),
            home.appendingPathComponent("Pictures").path: (.pictures, "photo.fill"),
            home.appendingPathComponent("Movies").path: (.movies, "film.fill"),
            URL.userTrash.standardizedFileURL.path: (.sidebarTrash, "trash.fill"),
            "/": (.macintoshHDName, "internaldrive.fill")
        ]
    }()

    private func sidebarItem(for url: URL) -> SidebarItem {
        let std = url.standardizedFileURL

        if std == AppState.recentsVirtualURL.standardizedFileURL {
            return SidebarItem(name: appState.tr(.recents), iconName: "clock.fill", url: std)
        }
        if let wellKnown = wellKnownSidebarInfo(forPath: std.path) {
            return SidebarItem(name: wellKnown.name, iconName: wellKnown.icon, url: std)
        }
        let name = std.lastPathComponent.isEmpty ? "/" : std.lastPathComponent
        return SidebarItem(name: name, iconName: "folder.fill", url: std)
    }

    private func wellKnownSidebarInfo(forPath path: String) -> (name: String, icon: String)? {
        guard let entry = Self.wellKnownPaths[path] else { return nil }
        return (appState.tr(entry.key), entry.icon)
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
