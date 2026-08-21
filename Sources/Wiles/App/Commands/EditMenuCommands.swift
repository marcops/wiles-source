import AppKit
import SwiftUI

/// Edit menu: undo/redo plus cut/copy/paste/select-all/find. Split out of `WilesApp.swift` —
/// pure code motion, no behavior change.
struct EditMenuCommands: Commands {
    let sharedPreferences: PreferencesStore
    @FocusedValue(\.appState)
    private var appState
    @FocusedValue(\.isTextFieldEditingActive)
    private var isTextFieldEditingActive

    private func tr(_ key: L10n.Key) -> String {
        L10n.string(key, lang: sharedPreferences.appLanguage)
    }

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button(tr(.undo)) { appState?.undoLastAction() }
                .keyboardShortcut("z", modifiers: .command)
            Button(tr(.redo)) { appState?.redoLastAction() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
        }
        CommandGroup(replacing: .pasteboard) {
            // While the rename field or the path bar's text field is active, these keep their
            // shortcut but forward to the system's standard text editing actions instead, so that
            // field's own text gets cut/copied/pasted/selected instead of the selected files.
            let isRenaming = isTextFieldEditingActive ?? false
            cutCommandButton(isRenaming: isRenaming)
            copyCommandButton(isRenaming: isRenaming)
            pasteCommandButton(isRenaming: isRenaming)
            Divider()
            selectAllCommandButton(isRenaming: isRenaming)
            Divider()
            Button(tr(.find)) { appState?.toggleSearching() }
                .keyboardShortcut("f", modifiers: .command)
        }
    }

    private func cutCommandButton(isRenaming: Bool) -> some View {
        Button(tr(.cut)) {
            if isRenaming {
                NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
            } else {
                appState?.cutSelected()
            }
        }
        .keyboardShortcut("x", modifiers: .command)
        .disabled(!isRenaming && (appState?.selectedURLs.isEmpty ?? true))
    }

    private func copyCommandButton(isRenaming: Bool) -> some View {
        Button(tr(.copy)) {
            if isRenaming {
                NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
            } else {
                appState?.copySelected()
            }
        }
        .keyboardShortcut("c", modifiers: .command)
        .disabled(!isRenaming && (appState?.selectedURLs.isEmpty ?? true))
    }

    private func pasteCommandButton(isRenaming: Bool) -> some View {
        Button(tr(.paste)) {
            if isRenaming {
                NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
            } else {
                appState?.pasteToCurrentDirectory()
            }
        }
        .keyboardShortcut("v", modifiers: .command)
    }

    private func selectAllCommandButton(isRenaming: Bool) -> some View {
        Button(tr(.selectAll)) {
            if isRenaming {
                NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
            } else {
                appState?.selectAllItems()
            }
        }
        .keyboardShortcut("a", modifiers: .command)
    }
}
