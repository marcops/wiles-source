import SwiftUI

/// Tools menu: auto-organization, duplicate finder, copy-path variants. Split out of
/// `WilesApp.swift` — pure code motion, no behavior change.
struct ToolsMenuCommands: LocalizedCommands {
    let sharedPreferences: PreferencesStore
    @FocusedValue(\.appState)
    private var appState
    @FocusedValue(\.windowUIState)
    private var windowUIState

    var body: some Commands {
        CommandMenu(tr(.toolsMenuTitle)) {
            Button(tr(.autoOrganizationEllipsis)) { windowUIState?.activeModal = .autoOrganization }
            Button(tr(.findDuplicates)) { windowUIState?.activeModal = .duplicateCleaner }
            Divider()
            if let appState {
                Menu(tr(.copyPath)) {
                    CopyPathMenuContent(
                        urls: [appState.navigation.currentURL],
                        relativeTo: appState.navigation.currentURL.deletingLastPathComponent(),
                        appState: appState)
                }
            }
        }
    }
}
