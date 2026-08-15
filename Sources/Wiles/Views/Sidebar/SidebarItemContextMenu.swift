import AppKit
import SwiftUI

/// Shared Open / Copy Path / Properties context menu content for a folder-like sidebar item.
/// Used by both `SidebarRowView` and `DirectoryTreeNodeView`, which each present the same base
/// menu for a folder `URL` and layer their own extra items (favorites, empty trash) around it.
struct SidebarItemContextMenu: View {
    let url: URL
    var appState: AppState
    @Environment(WindowUIState.self)
    private var windowUIState

    var body: some View {
        Button(appState.tr(.open)) { appState.navigateTo(url) }
        Menu(appState.tr(.copyPath)) {
            Button(appState.tr(.copyPathAbsolute)) {
                CopyPathService.copy(urls: [url], variant: .absolute)
            }
            Button(appState.tr(.copyPathRelative)) {
                CopyPathService.copy(urls: [url], variant: .relative, relativeTo: appState.navigation.currentURL)
            }
            Button(appState.tr(.copyPathURL)) {
                CopyPathService.copy(urls: [url], variant: .fileURL)
            }
            Button(appState.tr(.copyPathTerminal)) {
                CopyPathService.copy(urls: [url], variant: .terminalEscaped)
            }
        }
        Divider()
        Button("\(appState.tr(.properties)) (Cmd+I)") {
            let fileItem = FileItem(url: url, icon: NSWorkspace.shared.icon(forFile: url.path))
            windowUIState.propertiesItem = fileItem
        }
    }
}
