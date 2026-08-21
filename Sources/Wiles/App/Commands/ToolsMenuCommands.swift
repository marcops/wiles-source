import SwiftUI

/// Tools menu: auto-organization, duplicate finder, copy-path variants. Split out of
/// `WilesApp.swift` — pure code motion, no behavior change.
struct ToolsMenuCommands: Commands {
    let sharedPreferences: PreferencesStore
    @FocusedValue(\.appState)
    private var appState
    @FocusedValue(\.windowUIState)
    private var windowUIState

    private func tr(_ key: L10n.Key) -> String {
        L10n.string(key, lang: sharedPreferences.appLanguage)
    }

    var body: some Commands {
        CommandMenu(tr(.toolsMenuTitle)) {
            Button(tr(.autoOrganizationEllipsis)) { windowUIState?.showAutoOrganizationSheet = true }
            Button(tr(.findDuplicates)) { windowUIState?.showDuplicateCleanerSheet = true }
            Divider()
            if let appState {
                Menu(tr(.copyPath)) {
                    Button(tr(.copyPathAbsolute)) {
                        CopyPathService.copy(urls: [appState.navigation.currentURL], variant: .absolute)
                    }
                    Button(tr(.copyPathRelative)) {
                        CopyPathService.copy(
                            urls: [appState.navigation.currentURL],
                            variant: .relative,
                            relativeTo: appState.navigation.currentURL.deletingLastPathComponent())
                    }
                    Button(tr(.copyPathURL)) {
                        CopyPathService.copy(urls: [appState.navigation.currentURL], variant: .fileURL)
                    }
                    Button(tr(.copyPathTerminal)) {
                        CopyPathService.copy(urls: [appState.navigation.currentURL], variant: .terminalEscaped)
                    }
                }
            }
        }
    }
}
