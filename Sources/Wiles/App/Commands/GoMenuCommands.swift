import SwiftUI

/// Go menu: navigation history back/forward, enclosing folder, go-to-folder, connect to server.
/// Split out of `WilesApp.swift` — pure code motion, no behavior change.
struct GoMenuCommands: LocalizedCommands {
    let sharedPreferences: PreferencesStore
    @FocusedValue(\.appState)
    private var appState
    @FocusedValue(\.windowUIState)
    private var windowUIState

    var body: some Commands {
        CommandMenu(tr(.goMenuTitle)) {
            Button(tr(.back)) { appState?.goBack() }
                .keyboardShortcut(.goBack)
                .disabled((appState?.navigation.historyBack.isEmpty) ?? true)
            Button(tr(.forward)) { appState?.goForward() }
                .keyboardShortcut(.goForward)
                .disabled((appState?.navigation.historyForward.isEmpty) ?? true)
            Button(tr(.enclosingFolder)) { appState?.goUp() }
                .keyboardShortcut(.enclosingFolder)
            Divider()
            Button(tr(.goToFolder)) {
                if let appState, let windowUIState {
                    appState.startEditingPath(windowUIState: windowUIState)
                }
            }
            .keyboardShortcut(.goToFolder)
            Button(tr(.connectToServerEllipsis)) { windowUIState?.activeModal = .connectToServer }
                .keyboardShortcut(.connectToServer)
        }
    }
}
