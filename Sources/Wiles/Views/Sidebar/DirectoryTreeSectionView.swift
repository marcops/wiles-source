import SwiftUI

struct DirectoryTreeSectionView: View {
    var appState: AppState
    @Binding var isExpanded: Bool
    let rootFolderNode: FolderNode?
    @Binding var childrenCache: BoundedFolderNodeCache
    var didTimeOut: Bool = false
    var onRetry: (() -> Void)?
    @State private var rightClickedNodePath: String?

    var body: some View {
        SidebarSectionContainer(
            appState: appState, title: appState.tr(.directoryTree), identifierKey: "DIRECTORY_TREE", isExpanded: $isExpanded) {
                if let rootFolderNode {
                    DirectoryTreeNodeView(
                        node: rootFolderNode, depth: 0, appState: appState, childrenCache: $childrenCache,
                        rightClickedNodePath: $rightClickedNodePath)
                } else {
                    loadingState
                }
            }
    }

    @ViewBuilder private var loadingState: some View {
        if didTimeOut {
            Button {
                onRetry?()
            } label: {
                Label(appState.tr(.retry), systemImage: "arrow.clockwise")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
        } else {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(appState.tr(.loadingEntries)).font(.system(size: 11)).foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(appState.tr(.loadingEntries))
        }
    }
}
