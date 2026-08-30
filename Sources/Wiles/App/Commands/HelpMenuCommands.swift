import SwiftUI

/// Help menu: help & shortcuts, feedback, shortcuts cheat sheet HUD. Split out of
/// `WilesApp.swift` — pure code motion, no behavior change.
struct HelpMenuCommands: LocalizedCommands {
    let sharedPreferences: PreferencesStore
    @FocusedValue(\.windowUIState)
    private var windowUIState

    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button(tr(.wilesHelpAndShortcuts)) { windowUIState?.activeModal = .help }
                .keyboardShortcut(.help)
            Button(tr(.feedbackMenuItem)) { windowUIState?.activeModal = .feedback }
            Button(tr(.shortcutsCheatsheetTitle)) {
                withAnimation(MotionTokens.snappySpring) {
                    windowUIState?.showShortcutsHUD.toggle()
                }
            }
            .keyboardShortcut(.shortcutsHUD)
        }
    }
}
