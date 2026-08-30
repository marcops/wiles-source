import SwiftUI

struct FolderPickerNodeView: View {
    let node: FolderNode
    let depth: Int
    var appState: AppState
    @Binding var selectedURL: URL?
    @Binding var expandedPaths: Set<URL>
    @Binding var childrenCache: BoundedFolderNodeCache
    @Binding var loadingURLs: Set<URL>

    private var expansion: DirectoryTreeExpansion {
        .urlSet($expandedPaths)
    }

    private var children: [FolderNode]? {
        node.resolvedChildren(in: childrenCache)
    }

    private var isExpanded: Bool {
        expansion.isExpanded(node.url)
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

    private var displayName: String {
        node.displayName(rootLabel: appState.tr(.macintoshHDName))
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
        let wasExpanded = isExpanded
        expansion.toggle(node.url)
        if !wasExpanded {
            loadChildrenIfNeeded()
        }
    }

    private func loadChildrenIfNeeded() {
        guard node.needsChildLoad(cache: childrenCache, inFlight: loadingURLs) else { return }
        let url = node.url
        loadingURLs.insert(url)
        Task {
            let loaded = await FolderNode.loadChildrenOffMainActor(of: url)
            loadingURLs.remove(url)
            // Only apply if the node is still expanded — collapsing before the load finishes must not
            // resurrect a stale result.
            guard expandedPaths.contains(url) else { return }
            childrenCache[url] = loaded
        }
    }
}
