import AppKit
import SwiftUI

/// Edit menu: undo/redo plus cut/copy/paste/select-all/find. Split out of `WilesApp.swift` —
/// pure code motion, no behavior change.
struct EditMenuCommands: LocalizedCommands {
    let sharedPreferences: PreferencesStore
    @FocusedValue(\.appState)
    private var appState
    @FocusedValue(\.windowUIState)
    private var windowUIState
    @FocusedValue(\.isTextFieldEditingActive)
    private var isTextFieldEditingActive

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button(tr(.undo)) { appState?.undoLastAction() }
                .keyboardShortcut(.undo)
            Button(tr(.redo)) { appState?.redoLastAction() }
                .keyboardShortcut(.redo)
        }
        CommandGroup(replacing: .pasteboard) {
            // While ANY text field is focused (rename, path bar, the header search box, or a field
            // inside a sheet), these keep their shortcut but forward to the system's standard text
            // editing actions instead — so the field's own text gets cut/copied/pasted/selected
            // rather than the selected files (finding MM-133).
            let isRenaming = isEditingText
            cutCommandButton(isRenaming: isRenaming)
            copyCommandButton(isRenaming: isRenaming)
            pasteCommandButton(isRenaming: isRenaming)
            Divider()
            selectAllCommandButton(isRenaming: isRenaming)
            Divider()
            Button(tr(.find)) { appState?.toggleSearching() }
                .keyboardShortcut(.find)
        }
    }

    /// True when a text field currently owns keyboard focus, so file cut/copy/paste/select-all must
    /// defer to `NSText`'s own actions. `isTextFieldEditingActive` is the per-window signal for the
    /// rename field / path bar; `isSearching` and the live first-responder check add the header
    /// search box and any sheet text field it doesn't track (finding MM-133).
    private var isEditingText: Bool {
        if isTextFieldEditingActive ?? false {
            return true
        }
        if appState?.selection.isSearching ?? false {
            return true
        }
        return NSApplication.shared.keyWindow?.firstResponder is NSText
    }

    private func cutCommandButton(isRenaming: Bool) -> some View {
        Button(tr(.cut)) {
            if isRenaming {
                NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
            } else {
                appState?.cutSelected()
            }
        }
        .keyboardShortcut(.cut)
        .disabled(!isRenaming && (appState?.selection.selectedURLs.isEmpty ?? true))
    }

    private func copyCommandButton(isRenaming: Bool) -> some View {
        Button(tr(.copy)) {
            if isRenaming {
                NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
            } else {
                appState?.copySelected()
            }
        }
        .keyboardShortcut(.copy)
        .disabled(!isRenaming && (appState?.selection.selectedURLs.isEmpty ?? true))
    }

    private func pasteCommandButton(isRenaming: Bool) -> some View {
        Button(tr(.paste)) {
            if isRenaming {
                NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
            } else if let appState, let windowUIState {
                appState.pasteToCurrentDirectory(windowUIState: windowUIState)
            }
        }
        .keyboardShortcut(.paste)
        .disabled(!isRenaming && !canPasteFiles)
    }

    private var canPasteFiles: Bool {
        if let clipboard = appState?.transient.clipboard, !clipboard.urls.isEmpty {
            return true
        }
        return PasteboardService.hasPasteableContent()
    }

    private func selectAllCommandButton(isRenaming: Bool) -> some View {
        Button(tr(.selectAll)) {
            if isRenaming {
                NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
            } else {
                appState?.selectAllItems()
            }
        }
        .keyboardShortcut(.selectAll)
    }
}
