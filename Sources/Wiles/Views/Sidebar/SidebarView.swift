import AppKit
import SwiftUI

struct SidebarView: View {
    private static let trafficLightInset: CGFloat = 12.0
    private static let doubleClickZoneHeight: CGFloat = trafficLightInset
    private static let peekCollapseDelayMs: Int = 250

    var appState: AppState
    @Environment(WindowUIState.self)
    private var windowUIState
    @State private var rightClickedRowKey: String?
    @State private var renamingSmartFolderID: SmartFolder.ID?
    @State private var smartFolderRenameText: String = ""
    @FocusState private var isSmartFolderRenameFocused: Bool
    @State private var collapseWorkItem: DispatchWorkItem?

    private var isCompact: Bool {
        appState.preferences.view.isSidebarCollapsed && !windowUIState.isSidebarPeeking
    }

    /// Memoized "Favorites" / "Places" / "Network & Cloud" item lists — rebuilt by `rebuildPlaces()`
    /// only when favorites, discovered network shares, or the app language change, not on every
    /// `body` pass. See `SidebarPlacesBuilder`.
    @State private var favoriteItems: [SidebarItem] = []
    @State private var placeItems: [SidebarItem] = []
    @State private var networkAndCloudItems: [SidebarItem] = []

    @State private var rootFolderNode: FolderNode?
    /// `let`, not `@State` (see `BoundedFolderNodeCache`'s doc comment): a plain reference passed
    /// straight down the tree, deliberately outside SwiftUI's observation so one node's cache write
    /// can't invalidate every other node sharing it.
    private let treeChildrenCache = BoundedFolderNodeCache()
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
            // The tree's recursive `LazyVStack` (see `DirectoryTreeNodeView`) used to break this
            // `NSScrollView`'s content-size tracking outright; that's fixed at the source there.
            // `ScrollerAutoHideSetter` still nudges the scroller to recompute on every layout —
            // expanding a node whose whole ancestor chain is already loaded grows the document view
            // by a lot in one pass, which AppKit doesn't always pick up on its own.
        }
        .frame(minWidth: LayoutTokens.sidebarMinWidth, idealWidth: LayoutTokens.sidebarIdealWidth, maxHeight: .infinity)
        .onHover(perform: handleSidebarHover)
        .onDisappear { collapseWorkItem?.cancel() }
        .onChange(of: appState.preferences.favorites.favoriteURLs, initial: true) { _, _ in rebuildPlaces() }
        .onChange(of: appState.preferences.appearance.appLanguage) { _, _ in rebuildPlaces() }
        .onChange(of: appState.networkDiscoveryService.discoveredShares) { _, _ in rebuildPlaces() }
        .task(id: treeBuildGeneration, buildDirectoryTree)
        .translucentBackground(material: .sidebar, opacity: appState.preferences.appearance.sidebarOverlayOpacity, ignoresSafeArea: true)
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

    private func handleSidebarHover(_ hovering: Bool) {
        guard appState.preferences.view.isSidebarCollapsed else { return }
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

    /// After `RootDirectoryTreeLoader.fallbackTimeout`, leaves `rootFolderNode` nil so the Retry
    /// button shows instead of a fake node — the still-running scan can still finish and populate it.
    private func buildDirectoryTree() async {
        await RootDirectoryTreeLoader.load(
            isPending: { rootFolderNode == nil },
            setTimedOut: { treeBuildTimedOut = $0 },
            apply: { rootFolderNode = $0 })
    }

    private func retryTreeBuild() {
        rootFolderNode = nil
        treeBuildTimedOut = false
        treeBuildGeneration += 1
    }

    private func rebuildPlaces() {
        let lang = appState.preferences.appearance.appLanguage
        favoriteItems = SidebarPlacesBuilder.favorites(urls: appState.preferences.favorites.favoriteURLs, lang: lang)
        placeItems = SidebarPlacesBuilder.devices(lang: lang)
        networkAndCloudItems = SidebarPlacesBuilder.networkAndCloud(
            lang: lang, discoveredShares: appState.networkDiscoveryService.discoveredShares)
    }

    @ViewBuilder private var sidebarSectionsContent: some View {
        @Bindable var appState = appState

        if appState.showsRecentsSection {
            let recentsItem = SidebarItem(name: appState.tr(.recents), iconName: "clock.fill", url: AppState.recentsVirtualURL)
            sidebarRow(for: recentsItem, sectionKey: "RECENTS")
        }
        if appState.showsFavoritesSection {
            collapsibleSection(
                title: appState.tr(.favorites), identifierKey: "FAVORITES",
                isExpanded: $appState.preferences.sidebar.isFavoritesExpanded, items: favoriteItems, isFavoritesSection: true,
                hideAction: { appState.preferences.sidebar.showFavorites = false })
        }
        if appState.showsNetworkSection {
            collapsibleSection(
                title: appState.tr(.networkAndCloud), identifierKey: "NETWORK",
                isExpanded: $appState.preferences.sidebar.isNetworkExpanded, items: networkAndCloudItems, isFavoritesSection: false,
                hideAction: { appState.preferences.sidebar.showNetworkAndCloud = false })
                // SMB discovery runs only while this section is on screen, not for the whole app run.
                .onAppear { appState.networkDiscoveryService.start() }
                .onDisappear { appState.networkDiscoveryService.stop() }
        }
        if appState.showsPlacesSection {
            collapsibleSection(
                title: appState.tr(.places), identifierKey: "PLACES",
                isExpanded: $appState.preferences.sidebar.isDevicesExpanded, items: placeItems, isFavoritesSection: false,
                hideAction: { appState.preferences.sidebar.showPlaces = false })
        }
        // The tree/tags/smart-folder sections have their own nested structure that doesn't reduce
        // to a flat icon list, so they're skipped in the collapsed rail rather than shown.
        if !isCompact {
            if appState.showsDirectoryTreeSection {
                DirectoryTreeSectionView(
                    appState: appState, isExpanded: $appState.preferences.sidebar.isTreeExpanded,
                    rootFolderNode: rootFolderNode, childrenCache: treeChildrenCache,
                    didTimeOut: treeBuildTimedOut, onRetry: retryTreeBuild)
            }
            if appState.showsTagsSection {
                TagsSectionView(appState: appState, isExpanded: $appState.preferences.sidebar.isTagsExpanded)
            }
            if appState.showsSmartFoldersSection {
                SmartFoldersSectionView(
                    appState: appState, isExpanded: $appState.preferences.sidebar.isSmartFoldersExpanded,
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
