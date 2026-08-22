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

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            rowContent
            if node.hasSubfolders, isExpanded, let children {
                ForEach(children) { child in
                    Self(
                        node: child, depth: depth + 1, appState: appState, childrenCache: $childrenCache,
                        rightClickedNodePath: $rightClickedNodePath)
                }
            }
        }
        .padding(.leading, depth == 0 ? 0 : 12)
        .onAppear {
            if isExpanded {
                loadChildrenIfNeeded()
            }
        }
    }

    private func toggleExpanded() {
        if isExpanded {
            appState.preferences.expandedTreePaths.remove(node.url.path)
        } else {
            appState.preferences.expandedTreePaths.insert(node.url.path)
            loadChildrenIfNeeded()
        }
    }

    private func loadChildrenIfNeeded() {
        guard children == nil else { return }
        let url = node.url
        Task {
            let loaded = await Task.detached(priority: .userInitiated) {
                FolderNode.loadChildren(of: url)
            }.value
            childrenCache[url] = loaded
        }
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
                    .frame(width: 10)
                    .contentShape(Rectangle())
                    .onTapGesture { toggleExpanded() }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(appState.tr(isExpanded ? .collapseFolder : .expandFolder))
                    .accessibilityHint(appState.tr(.expandCollapseFolderHint))
            } else {
                Color.clear.frame(width: 10)
            }
            Image(systemName: "folder.fill")
                .font(.system(size: 12))
                .foregroundColor(.accentColor)
            Text(node.name)
                .font(.system(size: 12, weight: isSel ? .semibold : .regular))
                .foregroundColor(.primary)
                .lineLimit(1)
                .fixedSize()
            Spacer()
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(isSel ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture {
            rightClickedNodePath = nil
            appState.navigateTo(node.url)
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(node.name)
        .accessibilityHint(appState.tr(.folder))
        .overlay(
            RightClickDetector { rightClickedNodePath = node.url.path })
        .contextMenu {
            SidebarItemContextMenu(url: node.url, appState: appState)
        }
    }
}
