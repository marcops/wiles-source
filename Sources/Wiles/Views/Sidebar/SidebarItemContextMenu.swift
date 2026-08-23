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
        Button(appState.tr(.showInFinder)) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        Menu(appState.tr(.copyPath)) {
            CopyPathMenuContent(urls: [url], relativeTo: appState.navigation.currentURL, appState: appState)
        }
        Divider()
        Button(appState.trWithShortcutHint(.properties, shortcut: "Cmd+I")) {
            let fileItem = FileItem(url: url, icon: NSWorkspace.shared.icon(forFile: url.path))
            windowUIState.propertiesItem = fileItem
        }
    }
}
