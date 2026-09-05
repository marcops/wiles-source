import SwiftUI

struct DirectoryTreeNodeView: View {
    let node: FolderNode
    let depth: Int
    var appState: AppState
    let childrenCache: BoundedFolderNodeCache
    @Binding var rightClickedNodePath: String?
    /// This node's OWN loaded children, set once `loadChildrenIfNeeded()` completes. Local `@State`
    /// (not the shared `childrenCache`) is what SwiftUI actually observes to re-render THIS node —
    /// `childrenCache` is a plain reference now precisely so writing to it does NOT fan out to every
    /// other node sharing it. See `BoundedFolderNodeCache`'s doc comment for the full story.
    @State private var loadedChildren: [FolderNode]?

    init(
        node: FolderNode, depth: Int = 0, appState: AppState, childrenCache: BoundedFolderNodeCache,
        rightClickedNodePath: Binding<String?>) {
        self.node = node
        self.depth = depth
        self.appState = appState
        self.childrenCache = childrenCache
        _rightClickedNodePath = rightClickedNodePath
    }

    private var expansion: DirectoryTreeExpansion {
        .pathSet(Binding(
            get: { appState.preferences.sidebar.expandedTreePaths },
            set: { appState.preferences.sidebar.expandedTreePaths = $0 }))
    }

    /// Deep folders (outside the eagerly-loaded home ancestor chain) arrive with `node.children == nil`
    /// even though `hasSubfolders` is true; their children are fetched lazily on expand. Checks the
    /// local `loadedChildren` first (this node's own completed load — the only source SwiftUI
    /// actually observes here), falling back to the shared cache for a folder some earlier
    /// mount/session already resolved.
    private var children: [FolderNode]? {
        node.children ?? loadedChildren ?? childrenCache[node.url]
    }

    private var isExpanded: Bool {
        expansion.isExpanded(node.url)
    }

    private var displayName: String {
        node.displayName(rootLabel: appState.tr(.macintoshHDName))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            rowContent
            if node.hasSubfolders, isExpanded, let children {
                // Plain `VStack`, not `LazyVStack`: this nests recursively (once per expanded
                // node), all sharing the sidebar's single outer `ScrollView`. `LazyVStack` expects
                // to sit close to its `ScrollView` to participate correctly in scroll geometry —
                // stacking it recursively, combined with children arriving asynchronously well
                // after initial layout (`loadChildrenIfNeeded`), left the outer `NSScrollView`'s
                // content-size tracking stuck, so its scroller stopped updating/showing once the
                // tree was expanded. Each node's own children list is just its immediate
                // subfolders — small enough that losing view virtualization here costs nothing.
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(children) { child in
                        Self(
                            node: child, depth: depth + 1, appState: appState, childrenCache: childrenCache,
                            rightClickedNodePath: $rightClickedNodePath)
                    }
                }
            }
        }
        .padding(.leading, depth == 0 ? 5 : 12)
        .task(id: isExpanded, loadChildrenIfNeeded)
    }

    private func toggleExpanded() {
        expansion.toggle(node.url)
    }

    private func loadChildrenIfNeeded() async {
        guard isExpanded, children == nil else { return }
        let url = node.url
        let loaded = await FolderNode.loadChildrenOffMainActor(of: url)
        guard !Task.isCancelled else { return }
        // Local state is what actually triggers THIS node's re-render (see `children` above and
        // `BoundedFolderNodeCache`'s doc comment); the shared cache write below is a side-channel
        // for reuse across remounts/other nodes and intentionally carries no observation of its own.
        loadedChildren = loaded
        childrenCache[url] = loaded
    }

    /// See SWIFT_LANG_RULES.md "Custom Tappable Content MUST Have an Explicit `.contentShape`": a real `Button` on macOS does not reliably honor
    /// `.contentShape` for
    /// composite (icon + text) label content, so this uses a plain view + `.onTapGesture` instead.
    private var rowContent: some View {
        let isSel = appState.navigation.currentURL.standardizedFileURL == node.url.standardizedFileURL
            || rightClickedNodePath == node.url.path
        return HStack(spacing: 6) {
            if node.hasSubfolders {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
                    .onTapGesture { toggleExpanded() }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(appState.tr(isExpanded ? .collapseFolder : .expandFolder))
                    .accessibilityHint(appState.tr(.expandCollapseFolderHint))
            } else {
                Color.clear.frame(width: 16, height: 16)
            }
            Image(systemName: "folder.fill")
                .font(.system(size: 12))
                .foregroundColor(.accentColor)
            Text(displayName)
                .font(.system(size: 12, weight: isSel ? .semibold : .regular))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
        .hoverHighlight(isSelected: isSel, selectedBackground: Color.accentColor.opacity(0.15), cornerRadius: 6)
        .contentShape(Rectangle())
        .help(displayName)
        .onTapGesture {
            rightClickedNodePath = nil
            appState.navigateTo(node.url)
        }
        .accessibilityAddTraits(isSel ? [.isButton, .isSelected] : [.isButton])
        .accessibilityIdentifier(node.name)
        .accessibilityLabel(displayName)
        .accessibilityHint(appState.tr(.folder))
        .accessibilityValue(node.hasSubfolders ? appState.tr(isExpanded ? .collapseFolder : .expandFolder) : "")
        .overlay(
            RightClickDetector { rightClickedNodePath = node.url.path })
        .contextMenu {
            SidebarItemContextMenu(url: node.url, appState: appState)
        }
    }
}
