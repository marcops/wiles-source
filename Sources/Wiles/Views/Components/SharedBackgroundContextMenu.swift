import SwiftUI
import AppKit

struct SharedBackgroundContextMenu: View {
    var appState: AppState
    @Environment(WindowUIState.self)
    private var windowUIState

    var body: some View {
        Button("\(appState.tr(.newFolder)) (Shift+Cmd+N)") {
            windowUIState.showNewFolderSheet = true
        }
        Button("\(appState.tr(.newFileTitle))...") {
            windowUIState.showNewFileSheet = true
        }
        if appState.clipboard != nil {
            Button("\(appState.tr(.paste)) (Cmd+V)") {
                appState.pasteToCurrentDirectory()
            }
        } else {
            Button("\(appState.tr(.paste)) (Cmd+V)") {}.disabled(true)
        }
        Button("\(appState.tr(.selectAll)) (Cmd+A)") {
            appState.selectedURLs = Set(appState.fileSystem.items.map { $0.url })
        }
        Divider()
        Menu(appState.tr(.copyPath)) {
            Button(appState.tr(.copyPathAbsolute)) {
                CopyPathService.copy(urls: [appState.navigation.currentURL], variant: .absolute)
            }
            Button(appState.tr(.copyPathRelative)) {
                CopyPathService.copy(urls: [appState.navigation.currentURL], variant: .relative, relativeTo: appState.navigation.currentURL.deletingLastPathComponent())
            }
            Button(appState.tr(.copyPathURL)) {
                CopyPathService.copy(urls: [appState.navigation.currentURL], variant: .fileURL)
            }
            Button(appState.tr(.copyPathTerminal)) {
                CopyPathService.copy(urls: [appState.navigation.currentURL], variant: .terminalEscaped)
            }
        }
        Button(appState.tr(.shareFolderWifi)) {
            windowUIState.httpShareFolderURL = appState.navigation.currentURL
            windowUIState.showHttpShareSheet = true
        }
        Divider()
        Button(appState.tr(.folderProperties)) {
            let fileItem = FileItem(url: appState.navigation.currentURL, icon: NSWorkspace.shared.icon(forFile: appState.navigation.currentURL.path))
            windowUIState.propertiesItem = fileItem
        }
    }
}
