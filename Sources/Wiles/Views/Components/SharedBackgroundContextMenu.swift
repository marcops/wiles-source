import SwiftUI

struct SharedBackgroundContextMenu: View {
    var appState: AppState
    /// Overrides `appState.navigation.currentURL` as the New Folder/File creation location.
    var targetFolderURL: URL?
    @Environment(WindowUIState.self)
    private var windowUIState

    var body: some View {
        Button(appState.trWithShortcutHint(.newFolder, shortcut: ShortcutRegistry.label(.newFolder, in: appState.preferences.view.activeShortcutsByCommand))) {
            appState.createNewFolderAndRename(in: targetFolderURL, windowUIState: windowUIState)
        }
        Button(appState.tr(.newFileTitle)) {
            appState.createNewFileAndRename(in: targetFolderURL, windowUIState: windowUIState)
        }
        if appState.transient.clipboard != nil {
            Button(appState.trWithShortcutHint(.paste, shortcut: ShortcutRegistry.label(.paste, in: appState.preferences.view.activeShortcutsByCommand))) {
                appState.pasteToCurrentDirectory(windowUIState: windowUIState)
            }
        } else {
            Button(appState.trWithShortcutHint(.paste, shortcut: ShortcutRegistry.label(.paste, in: appState.preferences.view.activeShortcutsByCommand))) { }
                .disabled(true)
        }
        Button(appState.trWithShortcutHint(.selectAll, shortcut: ShortcutRegistry.label(.selectAll, in: appState.preferences.view.activeShortcutsByCommand))) {
            appState.selection.selectedURLs = Set(appState.fileSystem.items.map(\.url))
        }
        Divider()
        Menu(appState.tr(.copyPath)) {
            CopyPathMenuContent(
                urls: [appState.navigation.currentURL],
                relativeTo: appState.navigation.currentURL.deletingLastPathComponent(),
                appState: appState)
        }
        Button(appState.tr(.shareFolderWifi)) {
            windowUIState.activeModal = .httpShare(appState.navigation.currentURL)
        }
        Divider()
        Button(appState.tr(.folderProperties)) {
            // Properties sheet shows Owner/Group, so keep needsOwnerGroup default; let init resolve
            // the icon from .effectiveIcon instead of a blocking NSWorkspace LaunchServices IPC.
            let fileItem = FileItem.load(url: appState.navigation.currentURL)
            windowUIState.activeModal = .properties(fileItem)
        }
    }
}
