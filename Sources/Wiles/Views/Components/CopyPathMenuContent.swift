import SwiftUI

/// Shared "Copy Path" submenu, used by `SidebarItemContextMenu` and `SharedFileItemContextMenu`.
struct CopyPathMenuContent: View {
    let urls: [URL]
    let relativeTo: URL
    var appState: AppState

    var body: some View {
        Button(appState.tr(.copyPathAbsolute)) {
            CopyPathService.copy(urls: urls, variant: .absolute)
        }
        Button(appState.tr(.copyPathRelative)) {
            CopyPathService.copy(urls: urls, variant: .relative, relativeTo: relativeTo)
        }
        Button(appState.tr(.copyPathURL)) {
            CopyPathService.copy(urls: urls, variant: .fileURL)
        }
        Button(appState.tr(.copyPathTerminal)) {
            CopyPathService.copy(urls: urls, variant: .terminalEscaped)
        }
    }
}
