import SwiftUI

/// Help menu: help & shortcuts, feedback, shortcuts cheat sheet HUD. Split out of
/// `WilesApp.swift` — pure code motion, no behavior change.
struct HelpMenuCommands: Commands {
    let sharedPreferences: PreferencesStore
    @FocusedValue(\.windowUIState)
    private var windowUIState

    private func tr(_ key: L10n.Key) -> String {
        L10n.string(key, lang: sharedPreferences.appLanguage)
    }

    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button(tr(.wilesHelpAndShortcuts)) { windowUIState?.showHelpSheet = true }
                .keyboardShortcut("?", modifiers: .command)
            Button(tr(.feedbackMenuItem)) { windowUIState?.showFeedbackSheet = true }
            Button(tr(.shortcutsCheatsheetTitle)) {
                withAnimation(MotionTokens.snappySpring) {
                    windowUIState?.showShortcutsHUD.toggle()
                }
            }
            .keyboardShortcut(KeyboardShortcut("/", modifiers: .command, localization: .custom))
        }
    }
}
