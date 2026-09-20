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
                .keyboardShortcut(.goBack, preferences: sharedPreferences)
                .disabled((appState?.navigation.historyBack.isEmpty) ?? true)
            Button(tr(.forward)) { appState?.goForward() }
                .keyboardShortcut(.goForward, preferences: sharedPreferences)
                .disabled((appState?.navigation.historyForward.isEmpty) ?? true)
            Button(tr(.enclosingFolder)) { appState?.goUp() }
                .keyboardShortcut(.enclosingFolder, preferences: sharedPreferences)
            Divider()
            Button(tr(.goToFolder)) {
                if let appState, let windowUIState {
                    appState.startEditingPath(windowUIState: windowUIState)
                }
            }
            .keyboardShortcut(.goToFolder, preferences: sharedPreferences)
            Button(tr(.connectToServerEllipsis)) { windowUIState?.activeModal = .connectToServer }
                .keyboardShortcut(.connectToServer, preferences: sharedPreferences)
        }
    }
}
