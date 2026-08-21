import SwiftUI

/// Go menu: navigation history back/forward, enclosing folder, go-to-folder, connect to server.
/// Split out of `WilesApp.swift` — pure code motion, no behavior change.
struct GoMenuCommands: Commands {
    let sharedPreferences: PreferencesStore
    @FocusedValue(\.appState)
    private var appState
    @FocusedValue(\.windowUIState)
    private var windowUIState

    private func tr(_ key: L10n.Key) -> String {
        L10n.string(key, lang: sharedPreferences.appLanguage)
    }

    var body: some Commands {
        CommandMenu(tr(.goMenuTitle)) {
            Button(tr(.back)) { appState?.goBack() }
                .keyboardShortcut("[", modifiers: .command)
                .disabled((appState?.navigation.historyBack.isEmpty) ?? true)
            Button(tr(.forward)) { appState?.goForward() }
                .keyboardShortcut("]", modifiers: .command)
                .disabled((appState?.navigation.historyForward.isEmpty) ?? true)
            Button(tr(.enclosingFolder)) { appState?.goUp() }
            Divider()
            Button(tr(.goToFolder)) {
                if let appState, let windowUIState {
                    appState.startEditingPath(windowUIState: windowUIState)
                }
            }
            .keyboardShortcut("l", modifiers: .command)
            Button(tr(.connectToServerEllipsis)) { windowUIState?.showConnectToServerSheet = true }
                .keyboardShortcut("k", modifiers: .command)
        }
    }
}
