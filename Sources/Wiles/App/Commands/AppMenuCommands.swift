import SwiftUI

/// "Wiles" app menu: About + Settings. Split out of `WilesApp.swift` — pure code motion, no
/// behavior change.
struct AppMenuCommands: Commands {
    let sharedPreferences: PreferencesStore
    @FocusedValue(\.windowUIState)
    private var windowUIState

    private func tr(_ key: L10n.Key) -> String {
        L10n.string(key, lang: sharedPreferences.appLanguage)
    }

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(tr(.aboutWiles)) { windowUIState?.showAboutSheet = true }
        }
        // `SettingsView` is presented as a sheet (`windowUIState.showSettingsSheet`, wired in
        // `MainContentView`) rather than a `Settings { }` scene — a real scene always gets its own
        // native title bar/traffic-light window chrome that fights the app's own header/footer sheet
        // styling, and every attempt to strip that chrome via `NSWindow` still left rendering glitches.
        // A sheet has no window chrome to fight in the first place, matching `HelpSheet`/`AboutSheet`.
        // This also sidesteps the old duplicate-menu-item bug for good: that bug came from SwiftUI
        // auto-generating its own native "Settings…" item whenever a `Settings` scene exists, which
        // collided with `CommandGroup(replacing: .appSettings)` adding a second, translated one. With
        // no `Settings` scene at all, there's nothing left for SwiftUI to auto-generate.
        CommandGroup(replacing: .appSettings) {
            Button(tr(.settingsMenuItem)) { windowUIState?.showSettingsSheet = true }
                .keyboardShortcut(",", modifiers: .command)
        }
    }
}
