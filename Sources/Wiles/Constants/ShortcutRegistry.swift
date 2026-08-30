import SwiftUI

/// Single source of truth for every keyboard shortcut in the app. Menu items (`*MenuCommands`),
/// the `GlobalKeyMonitor` dispatch, the shortcuts cheat sheet (`ShortcutsHUDOverlay`), and
/// context-menu hints all read their key combos and labels from here, so the four can't drift
/// out of sync. Replaces the old scatter of literal `.keyboardShortcut("x", …)`, raw `KeyCode`
/// constants in the monitor, and hand-typed `KeyLabel`/`"Cmd+X"` strings (was [A3]/[M75]/[M77]).
enum ShortcutRegistry {
    enum Command: CaseIterable {
        // Menu-backed
        case settings, undo, redo, cut, copy, paste, selectAll, find
        case newWindow, closeWindow, newFolder, newFile, open, properties, quickLook, moveToTrash
        case goBack, goForward, goToFolder, connectToServer, enclosingFolder
        case help, shortcutsHUD, toggleTerminal, togglePreview, toggleDiskUsage
        // Monitor / hidden-button only (no menu item)
        case toggleHiddenFiles, clearSelection, openSelected
        case zoomIn, zoomOut, zoomReset
        case renameMacOS, renameGnome
        case openSelectedGnome, enclosingFolderGnome
        case arrowNavigation, favoriteReorder
    }

    struct Shortcut {
        /// For SwiftUI `.keyboardShortcut(...)`. `nil` for a monitor-only command with no menu item.
        var key: KeyEquivalent?
        var modifiers: EventModifiers = []
        /// `NSEvent.keyCode`s this command answers to in `GlobalKeyMonitor`. Empty for a menu-only command.
        var physicalKeyCodes: [UInt16] = []
        /// `KeyboardShortcut(localization: .custom)` — only `⌘/`, which must not be auto-remapped per locale.
        var customLocalization = false
        /// Human label for the cheat sheet and context-menu hints. Not localized — a physical key's
        /// symbol doesn't change per language.
        var label: String
    }

    static func shortcut(_ command: Command) -> Shortcut {
        table[command] ?? Shortcut(key: nil, label: "")
    }

    static func label(_ command: Command) -> String {
        shortcut(command).label
    }

    /// Physical keycodes for a monitor command, resolved once so the dispatch code has a single
    /// definition instead of its own `KeyCode` literals.
    static func physicalKeyCodes(_ command: Command) -> [UInt16] {
        shortcut(command).physicalKeyCodes
    }

    private static let table: [Command: Shortcut] = [
        .settings: Shortcut(key: ",", modifiers: .command, label: "⌘ ,"),
        .undo: Shortcut(key: "z", modifiers: .command, label: "⌘ Z"),
        .redo: Shortcut(key: "z", modifiers: [.command, .shift], label: "⌘ ⇧ Z"),
        .cut: Shortcut(key: "x", modifiers: .command, label: "⌘ X"),
        .copy: Shortcut(key: "c", modifiers: .command, label: "⌘ C"),
        .paste: Shortcut(key: "v", modifiers: .command, label: "⌘ V"),
        .selectAll: Shortcut(key: "a", modifiers: .command, label: "⌘ A"),
        .find: Shortcut(key: "f", modifiers: .command, label: "⌘ F"),
        .newWindow: Shortcut(key: "n", modifiers: .command, label: "⌘ N"),
        .closeWindow: Shortcut(key: "w", modifiers: .command, label: "⌘ W"),
        .newFolder: Shortcut(key: "n", modifiers: [.command, .shift], label: "⌘ ⇧ N"),
        .newFile: Shortcut(key: "n", modifiers: [.command, .option], label: "⌘ ⌥ N"),
        .open: Shortcut(key: "o", modifiers: .command, label: "⌘ O"),
        .properties: Shortcut(key: "i", modifiers: .command, label: "⌘ I"),
        .quickLook: Shortcut(key: " ", modifiers: [], label: "Space"),
        .moveToTrash: Shortcut(
            key: .delete, modifiers: [], physicalKeyCodes: [KeyCode.backspace, KeyCode.forwardDelete], label: "Delete"),
        .goBack: Shortcut(key: "[", modifiers: .command, label: "⌘ ["),
        .goForward: Shortcut(key: "]", modifiers: .command, label: "⌘ ]"),
        .goToFolder: Shortcut(key: "l", modifiers: .command, label: "⌘ L"),
        .connectToServer: Shortcut(key: "k", modifiers: .command, label: "⌘ K"),
        // Finder-standard "enclosing folder". `GlobalKeyMonitor` is what actually fires it (it
        // swallows every arrow keydown first); the menu carries the same combo as a visible hint.
        .enclosingFolder: Shortcut(key: .upArrow, modifiers: .command, label: "⌘ ↑"),
        .help: Shortcut(key: "?", modifiers: .command, label: "⌘ ?"),
        .shortcutsHUD: Shortcut(key: "/", modifiers: .command, customLocalization: true, label: "⌘ /"),
        .toggleTerminal: Shortcut(key: "j", modifiers: .command, label: "⌘ J"),
        .togglePreview: Shortcut(key: "p", modifiers: [.command, .shift], label: "⌘ ⇧ P"),
        .toggleDiskUsage: Shortcut(key: "d", modifiers: [.command, .shift], label: "⌘ ⇧ D"),
        // No menu item — the `⌘⇧.` combo plus an alternate `⌃H` are wired as hidden buttons.
        .toggleHiddenFiles: Shortcut(key: ".", modifiers: [.command, .shift], label: "⌘ ⇧ ."),
        .clearSelection: Shortcut(key: .escape, modifiers: [], label: "Esc"),
        .openSelected: Shortcut(key: .downArrow, modifiers: .command, label: "⌘ ↓"),
        // Cmd+] is `goForward` (standard macOS); zoom-in stays on `⌘=` / keypad `+` only.
        .zoomIn: Shortcut(key: "=", modifiers: .command, physicalKeyCodes: [KeyCode.equals, KeyCode.keypadPlus], label: "⌘ ="),
        .zoomOut: Shortcut(key: "-", modifiers: .command, physicalKeyCodes: [KeyCode.minus, KeyCode.keypadMinus], label: "⌘ -"),
        .zoomReset: Shortcut(key: "0", modifiers: .command, physicalKeyCodes: [KeyCode.zero], label: "⌘ 0"),
        .renameMacOS: Shortcut(key: nil, physicalKeyCodes: [KeyCode.returnKey], label: "Return"),
        .renameGnome: Shortcut(key: nil, physicalKeyCodes: [KeyCode.f2], label: "F2"),
        // gnome-mode navigation: Return opens, Backspace goes up a level (no selection).
        .openSelectedGnome: Shortcut(key: nil, physicalKeyCodes: [KeyCode.returnKey], label: "Enter"),
        .enclosingFolderGnome: Shortcut(key: nil, physicalKeyCodes: [KeyCode.backspace], label: "Backspace"),
        .arrowNavigation: Shortcut(
            key: nil,
            physicalKeyCodes: [KeyCode.arrowUp, KeyCode.arrowDown, KeyCode.arrowLeft, KeyCode.arrowRight],
            label: "↑ ↓ ← →"),
        .favoriteReorder: Shortcut(
            key: nil, modifiers: .command, physicalKeyCodes: [KeyCode.arrowUp, KeyCode.arrowDown], label: "⌘ ↑  /  ⌘ ↓")
    ]
}

extension View {
    /// Applies a registry command's key combo to a menu `Button`/`Toggle`. A monitor-only command
    /// (nil `key`) is a no-op — those are dispatched by `GlobalKeyMonitor`, not a menu.
    @ViewBuilder
    func keyboardShortcut(_ command: ShortcutRegistry.Command) -> some View {
        let shortcut = ShortcutRegistry.shortcut(command)
        if let key = shortcut.key {
            keyboardShortcut(KeyboardShortcut(
                key, modifiers: shortcut.modifiers, localization: shortcut.customLocalization ? .custom : .automatic))
        } else {
            self
        }
    }
}
