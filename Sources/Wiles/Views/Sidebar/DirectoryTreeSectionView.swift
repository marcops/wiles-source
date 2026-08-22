import SwiftUI

struct DirectoryTreeSectionView: View {
    var appState: AppState
    @Binding var isExpanded: Bool
    let rootFolderNode: FolderNode?
    @Binding var childrenCache: BoundedFolderNodeCache
    @State private var rightClickedNodePath: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if appState.preferences.showSidebarSectionTitles {
                SidebarSectionHeaderView(
                    title: appState.tr(.directoryTree), identifierKey: "DIRECTORY_TREE", appState: appState, isExpanded: $isExpanded)
            }
            if !appState.preferences.showSidebarSectionTitles || isExpanded {
                if let rootFolderNode {
                    DirectoryTreeNodeView(
                        node: rootFolderNode, depth: 0, appState: appState, childrenCache: $childrenCache,
                        rightClickedNodePath: $rightClickedNodePath)
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.horizontal, 12)
                }
            }
        }
    }
}
