import SwiftUI
import AppKit

struct DirectoryTreeNodeView: View {
    let node: FolderNode
    let depth: Int
    var appState: AppState
    @Environment(WindowUIState.self) private var windowUIState
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
            }
        )
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

    private var rowContent: some View {
        let isSel = appState.navigation.currentURL.standardizedFileURL == node.url.standardizedFileURL || isRightClicked
        return Button {
            isRightClicked = false
            appState.navigateTo(node.url)
        } label: {
            HStack(spacing: 6) {
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
        }
        .buttonStyle(.plain)
        .overlay(
            RightClickDetector { isRightClicked = true }
        )
        .contextMenu {
            Button(appState.tr(.open)) { appState.navigateTo(node.url) }
            Menu(appState.tr(.copyPath)) {
                Button(appState.tr(.copyPathAbsolute)) {
                    CopyPathService.copy(urls: [node.url], variant: .absolute)
                }
                Button(appState.tr(.copyPathRelative)) {
                    CopyPathService.copy(urls: [node.url], variant: .relative, relativeTo: appState.navigation.currentURL)
                }
                Button(appState.tr(.copyPathURL)) {
                    CopyPathService.copy(urls: [node.url], variant: .fileURL)
                }
                Button(appState.tr(.copyPathTerminal)) {
                    CopyPathService.copy(urls: [node.url], variant: .terminalEscaped)
                }
            }
            Divider()
            Button("\(appState.tr(.properties)) (Cmd+I)") {
                let fileItem = FileItem(url: node.url, icon: NSWorkspace.shared.icon(forFile: node.url.path))
                windowUIState.propertiesItem = fileItem
            }
        }
    }
}
