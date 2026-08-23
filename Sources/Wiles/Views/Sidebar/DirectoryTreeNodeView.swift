import SwiftUI

struct DirectoryTreeNodeView: View {
    let node: FolderNode
    let depth: Int
    var appState: AppState
    @Binding var childrenCache: BoundedFolderNodeCache
    @Binding var rightClickedNodePath: String?

    init(
        node: FolderNode, depth: Int = 0, appState: AppState, childrenCache: Binding<BoundedFolderNodeCache>,
        rightClickedNodePath: Binding<String?>) {
        self.node = node
        self.depth = depth
        self.appState = appState
        _childrenCache = childrenCache
        _rightClickedNodePath = rightClickedNodePath
    }

    /// Deep folders (outside the eagerly-loaded home ancestor chain) arrive with `node.children == nil`
    /// even though `hasSubfolders` is true; their children are fetched lazily into `childrenCache` on expand.
    private var children: [FolderNode]? {
        node.children ?? childrenCache[node.url]
    }

    private var isExpanded: Bool {
        appState.preferences.expandedTreePaths.contains(node.url.path)
    }

    /// `FolderNode.buildRootTree()`'s root carries a hardcoded "Root (/)" name; localize it here
    /// the same way `SidebarView`'s fallback root node already does.
    private var displayName: String {
        node.url.path == "/" ? appState.tr(.macintoshHDName) : node.name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            rowContent
            if node.hasSubfolders, isExpanded, let children {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(children) { child in
                        Self(
                            node: child, depth: depth + 1, appState: appState, childrenCache: $childrenCache,
                            rightClickedNodePath: $rightClickedNodePath)
                    }
                }
            }
        }
        .padding(.leading, depth == 0 ? 0 : 12)
        .task(id: isExpanded, loadChildrenIfNeeded)
    }

    private func toggleExpanded() {
        if isExpanded {
            appState.preferences.expandedTreePaths.remove(node.url.path)
        } else {
            appState.preferences.expandedTreePaths.insert(node.url.path)
        }
    }

    private func loadChildrenIfNeeded() async {
        guard isExpanded, children == nil else { return }
        let url = node.url
        let loaded = await Task.detached(priority: .userInitiated) {
            FolderNode.loadChildren(of: url)
        }.value
        guard !Task.isCancelled else { return }
        childrenCache[url] = loaded
    }

    /// See AGENTS.md rule 33: a real `Button` on macOS does not reliably honor `.contentShape` for
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
