import SwiftUI

struct FolderPickerNodeView: View {
    let node: FolderNode
    let depth: Int
    var appState: AppState
    @Binding var selectedURL: URL?
    @Binding var expandedPaths: Set<URL>
    @Binding var childrenCache: [URL: [FolderNode]]
    @Binding var loadingURLs: Set<URL>

    private var children: [FolderNode]? {
        node.children ?? childrenCache[node.url]
    }

    private var isExpanded: Bool {
        expandedPaths.contains(node.url)
    }

    private var isLoadingChildren: Bool {
        loadingURLs.contains(node.url)
    }

    /// `FolderNode.loadSubfolders` returns `[]` both for "genuinely empty" and "permission
    /// denied" — this only fires the latter's messaging, since `hasSubfolders` already told us a
    /// subfolder exists, so an empty result here means the read itself failed.
    private var failedToLoadChildren: Bool {
        !isLoadingChildren && (children?.isEmpty ?? false)
    }

    /// `FolderNode.buildRootTree()`'s root carries a hardcoded "Root (/)" name; localize it here
    /// the same way `SidebarView`'s fallback root node already does.
    private var displayName: String {
        node.url.path == "/" ? appState.tr(.macintoshHDName) : node.name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            rowLabel
            if node.hasSubfolders, isExpanded {
                childrenContent
            }
        }
        .padding(.leading, depth == 0 ? 0 : 12)
        .id(node.url)
    }

    @ViewBuilder private var childrenContent: some View {
        if isLoadingChildren {
            ProgressView().controlSize(.small).padding(.leading, 12)
        } else if failedToLoadChildren {
            Text(appState.tr(.folderPickerCantReadFolder))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.leading, 12)
        } else if let children {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(children) { child in
                    Self(
                        node: child,
                        depth: depth + 1,
                        appState: appState,
                        selectedURL: $selectedURL,
                        expandedPaths: $expandedPaths,
                        childrenCache: $childrenCache,
                        loadingURLs: $loadingURLs)
                }
            }
        }
    }

    private var rowLabel: some View {
        let isSelected = selectedURL?.standardizedFileURL == node.url.standardizedFileURL
        return TappableRow(accessibilityLabel: displayName, isSelected: isSelected, action: { selectedURL = node.url }, content: {
            rowLabelContent(isSelected: isSelected)
        })
    }

    private func rowLabelContent(isSelected: Bool) -> some View {
        HStack(spacing: 4) {
            if node.hasSubfolders {
                TappableRow(
                    accessibilityLabel: appState.tr(isExpanded ? .collapseFolder : .expandFolder),
                    action: { toggleExpanded() },
                    content: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .frame(width: 10)
                    })
            } else {
                Color.clear.frame(width: 10)
            }
            Image(systemName: "folder.fill")
                .font(.system(size: 12))
                .foregroundColor(.accentColor)
            Text(displayName)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(4)
    }

    private func toggleExpanded() {
        if isExpanded {
            expandedPaths.remove(node.url)
        } else {
            expandedPaths.insert(node.url)
            loadChildrenIfNeeded()
        }
    }

    /// Loads `node`'s children off `@MainActor` (mirrors `DirectoryTreeNodeView.loadChildrenIfNeeded()`)
    /// so expanding a folder under a stalled network share can't block the UI.
    private func loadChildrenIfNeeded() {
        guard children == nil, !loadingURLs.contains(node.url) else { return }
        let url = node.url
        loadingURLs.insert(url)
        Task {
            let loaded = await Task.detached(priority: .userInitiated) {
                FolderNode.loadChildren(of: url)
            }.value
            loadingURLs.remove(url)
            // Only apply if the node is still expanded — collapsing before the load finishes must not
            // resurrect a stale result.
            guard expandedPaths.contains(url) else { return }
            childrenCache[url] = loaded
        }
    }
}
