import AppKit
import SwiftUI

struct DirectoryTreeNodeView: View {
    let node: FolderNode
    let depth: Int
    var appState: AppState
    @State private var isRightClicked = false

    init(node: FolderNode, depth: Int = 0, appState: AppState) {
        self.node = node
        self.depth = depth
        self.appState = appState
    }

    private var isExpandedBinding: Binding<Bool> {
        Binding(
            get: { appState.preferences.expandedTreePaths.contains(node.url.path) },
            set: { newValue in
                if newValue {
                    appState.preferences.expandedTreePaths.insert(node.url.path)
                } else {
                    appState.preferences.expandedTreePaths.remove(node.url.path)
                }
            })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let children = node.children, !children.isEmpty {
                DisclosureGroup(isExpanded: isExpandedBinding) {
                    ForEach(children) { child in
                        Self(node: child, depth: depth + 1, appState: appState)
                    }
                } label: {
                    rowContent
                }
            } else {
                rowContent
            }
        }
        .padding(.leading, CGFloat(depth) * 12)
    }

    /// See AGENTS.md rule 33: a real `Button` on macOS does not reliably honor `.contentShape` for
    /// composite (icon + text) label content, so this uses a plain view + `.onTapGesture` instead.
    private var rowContent: some View {
        let isSel = appState.navigation.currentURL.standardizedFileURL == node.url.standardizedFileURL || isRightClicked
        return HStack(spacing: 6) {
            Image(systemName: "folder.fill")
                .font(.system(size: 12))
                .foregroundColor(.accentColor)
            Text(node.name)
                .font(.system(size: 12, weight: isSel ? .semibold : .regular))
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(isSel ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture {
            isRightClicked = false
            appState.navigateTo(node.url)
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(node.name)
        .accessibilityHint(appState.tr(.folder))
        .overlay(
            RightClickDetector { isRightClicked = true })
        .contextMenu {
            SidebarItemContextMenu(url: node.url, appState: appState)
        }
    }
}
