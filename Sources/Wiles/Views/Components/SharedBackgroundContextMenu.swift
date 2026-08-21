import AppKit
import SwiftUI

struct SharedBackgroundContextMenu: View {
    var appState: AppState
    /// Overrides `appState.navigation.currentURL` as the New Folder/File creation location.
    var targetFolderURL: URL?
    @Environment(WindowUIState.self)
    private var windowUIState

    var body: some View {
        Button(appState.trWithShortcutHint(.newFolder, shortcut: "Shift+Cmd+N")) {
            appState.createNewFolderAndRename(in: targetFolderURL, windowUIState: windowUIState)
        }
        Button(appState.tr(.newFileTitle)) {
            appState.createNewFileAndRename(in: targetFolderURL, windowUIState: windowUIState)
        }
        if appState.transient.clipboard != nil {
            Button(appState.trWithShortcutHint(.paste, shortcut: "Cmd+V")) {
                appState.pasteToCurrentDirectory()
            }
        } else {
            Button(appState.trWithShortcutHint(.paste, shortcut: "Cmd+V")) { }.disabled(true)
        }
        Button(appState.trWithShortcutHint(.selectAll, shortcut: "Cmd+A")) {
            appState.selectedURLs = Set(appState.fileSystem.items.map(\.url))
        }
        Divider()
        Menu(appState.tr(.copyPath)) {
            Button(appState.tr(.copyPathAbsolute)) {
                CopyPathService.copy(urls: [appState.navigation.currentURL], variant: .absolute)
            }
            Button(appState.tr(.copyPathRelative)) {
                CopyPathService.copy(
                    urls: [appState.navigation.currentURL],
                    variant: .relative,
                    relativeTo: appState.navigation.currentURL.deletingLastPathComponent())
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
