import SwiftUI

/// Single source of truth for every keyboard shortcut in the app. Menu items (`*MenuCommands`),
/// `GlobalKeyMonitor`'s raw dispatch, the shortcuts cheat sheet (`ShortcutsHUDOverlay`), and
/// context-menu hints all read the *live* combo for a command from
/// `ViewPreferences.activeShortcutsByCommand` — never from a fixed table here — so all of them
/// can't drift out of sync with whatever the user actually has bound right now.
///
/// This type itself only defines the two built-in **presets** (`preset(for:)`, used to bulk-apply
/// Windows or Mac when the user picks one in Settings) and command-agnostic helpers
/// (`label(_:in:)`, `conflictingCommand`). There is no per-mode branching anywhere outside
/// `preset(for:)` — every dispatch/label/menu call site reads the one live dictionary
/// unconditionally, so switching modes changes what's *in* that dictionary, never how it's read.
public enum ShortcutRegistry {
    public enum Command: String, CaseIterable, Codable, Sendable {
        // Menu-backed
        case settings, undo, redo, cut, copy, paste, selectAll, find
        case newWindow, closeWindow, newFolder, newFile, open, properties, quickLook, moveToTrash, rename
        case goBack, goForward, goToFolder, connectToServer, enclosingFolder
        case help, shortcutsHUD, toggleTerminal, togglePreview, toggleDiskUsage
        // Monitor / hidden-button only (no menu item)
        case toggleHiddenFiles, clearSelection
        case zoomIn, zoomOut, zoomReset
        // One combo per logical action, replacing the old Windows/Mac-specific pairs — which key
        // triggers "rename the anchor selection" / "open the anchor selection" / "go up with no
        // selection" is just data (see `windowsOnlyBindings`/`macOnlyBindings`), not two Command cases.
        case quickRename, openSelected, quickGoUp
        // Fixed, non-editable, non-remappable spatial interactions — never in the live store, never
        // bulk-reset by a preset. `label(_:in:)` falls back to `fixedLabel` for these two.
        case arrowNavigation, favoriteReorder
    }

    /// Every command whose combo a Custom-mode user can individually remap and that a Windows/Mac
    /// preset bulk-writes into the live store. Excludes `arrowNavigation`/`favoriteReorder` — not a
    /// single rebindable combo to begin with.
    static let editableCommands: [Command] = Command.allCases.filter { $0 != .arrowNavigation && $0 != .favoriteReorder }

    /// `.toggleHiddenFiles`'s fixed secondary combo — its own hidden button in `MainContentView`,
    /// unaffected by the primary key's remap (same fixed-alternate shape as `moveToTrashAlternate`).
    static let toggleHiddenFilesAlternate = KeyboardShortcut("h", modifiers: .control)

    /// Forward-delete is a second physical key for the same "Delete" action on an extended keyboard —
    /// always live alongside whatever `.moveToTrash`'s primary (customizable) key currently is, the
    /// same way `⌃H` always works alongside `.toggleHiddenFiles`'s primary key.
    static let moveToTrashAlternatePhysicalKeyCode = KeyCode.forwardDelete

    /// The combo every `editableCommands` entry starts at, before any mode/Custom edit — everything
    /// that doesn't vary between Windows and Mac (the vast majority: menu items, zoom, clipboard, …).
    private static let commonBindings: [Command: ShortcutBinding] = [
        .settings: ShortcutBinding(character: ",", modifiers: .command, physicalKeyCode: nil),
        .undo: ShortcutBinding(character: "z", modifiers: .command, physicalKeyCode: nil),
        .redo: ShortcutBinding(character: "z", modifiers: [.command, .shift], physicalKeyCode: nil),
        .cut: ShortcutBinding(character: "x", modifiers: .command, physicalKeyCode: nil),
        .copy: ShortcutBinding(character: "c", modifiers: .command, physicalKeyCode: nil),
        .paste: ShortcutBinding(character: "v", modifiers: .command, physicalKeyCode: nil),
        .selectAll: ShortcutBinding(character: "a", modifiers: .command, physicalKeyCode: nil),
        .find: ShortcutBinding(character: "f", modifiers: .command, physicalKeyCode: nil),
        .newWindow: ShortcutBinding(character: "n", modifiers: .command, physicalKeyCode: nil),
        .closeWindow: ShortcutBinding(character: "w", modifiers: .command, physicalKeyCode: nil),
        .newFolder: ShortcutBinding(character: "n", modifiers: [.command, .shift], physicalKeyCode: nil),
        .newFile: ShortcutBinding(character: "n", modifiers: [.command, .option], physicalKeyCode: nil),
        .open: ShortcutBinding(character: "o", modifiers: .command, physicalKeyCode: nil),
        .properties: ShortcutBinding(character: "i", modifiers: .command, physicalKeyCode: nil),
        .quickLook: ShortcutBinding(character: " ", modifiers: [], physicalKeyCode: nil),
        .rename: ShortcutBinding(character: "r", modifiers: .command, physicalKeyCode: nil),
        .moveToTrash: ShortcutBinding(character: "\u{7F}", modifiers: [], physicalKeyCode: KeyCode.backspace),
        .goBack: ShortcutBinding(character: "[", modifiers: .command, physicalKeyCode: nil),
        .goForward: ShortcutBinding(character: "]", modifiers: .command, physicalKeyCode: nil),
        .goToFolder: ShortcutBinding(character: "l", modifiers: .command, physicalKeyCode: nil),
        .connectToServer: ShortcutBinding(character: "k", modifiers: .command, physicalKeyCode: nil),
        // `GlobalKeyMonitor` swallows every arrow keydown first, so `physicalKeyCode` is what
        // actually fires this; `key`/`modifiers` still render the visible ⌘↑ menu hint.
        .enclosingFolder: ShortcutBinding(character: "\u{F700}", modifiers: .command, physicalKeyCode: KeyCode.arrowUp),
        .help: ShortcutBinding(character: "?", modifiers: .command, physicalKeyCode: nil),
        .shortcutsHUD: ShortcutBinding(character: "/", modifiers: .command, physicalKeyCode: nil),
        .toggleTerminal: ShortcutBinding(character: "j", modifiers: .command, physicalKeyCode: nil),
        .togglePreview: ShortcutBinding(character: "p", modifiers: [.command, .shift], physicalKeyCode: nil),
        .toggleDiskUsage: ShortcutBinding(character: "d", modifiers: [.command, .shift], physicalKeyCode: nil),
        .toggleHiddenFiles: ShortcutBinding(character: ".", modifiers: [.command, .shift], physicalKeyCode: nil),
        .clearSelection: ShortcutBinding(character: "\u{1B}", modifiers: [], physicalKeyCode: nil),
        // Cmd+] is `goForward` (standard macOS); zoom-in stays on `⌘=` / keypad `+` only.
        .zoomIn: ShortcutBinding(character: "=", modifiers: .command, physicalKeyCode: KeyCode.equals),
        .zoomOut: ShortcutBinding(character: "-", modifiers: .command, physicalKeyCode: KeyCode.minus),
        .zoomReset: ShortcutBinding(character: "0", modifiers: .command, physicalKeyCode: KeyCode.zero)
    ]

    /// Windows-preset-only combos: F2 renames, Return opens, Backspace-with-no-selection goes up.
    private static let windowsOnlyBindings: [Command: ShortcutBinding] = [
        .quickRename: ShortcutBinding(character: "\u{F705}", modifiers: [], physicalKeyCode: KeyCode.f2),
        .openSelected: ShortcutBinding(character: "\r", modifiers: [], physicalKeyCode: KeyCode.returnKey),
        .quickGoUp: ShortcutBinding(character: "\u{7F}", modifiers: [], physicalKeyCode: KeyCode.backspace)
    ]

    /// Mac-preset-only combos: Return renames, Cmd+Down opens. No `quickGoUp` — Backspace-goes-up is
    /// a Windows-only convenience, so the Mac preset simply never binds it (absent, not "off").
    private static let macOnlyBindings: [Command: ShortcutBinding] = [
        .quickRename: ShortcutBinding(character: "\r", modifiers: [], physicalKeyCode: KeyCode.returnKey),
        .openSelected: ShortcutBinding(character: "\u{F701}", modifiers: .command, physicalKeyCode: KeyCode.arrowDown)
    ]

    /// The full combo set a Windows or Mac preset bulk-writes into `ViewPreferences.activeShortcuts`
    /// when the user selects that mode — destructively replacing whatever was there before,
    /// including any Custom edits. `.custom` has no preset of its own (selecting it never resets the
    /// live store); the branch exists only so this stays a total function.
    static func preset(for mode: NavigationMode) -> [Command: ShortcutBinding] {
        switch mode {
        case .windows, .custom: commonBindings.merging(windowsOnlyBindings) { _, new in new }
        case .macOS: commonBindings.merging(macOnlyBindings) { _, new in new }
        }
    }

    /// Fixed, human-readable labels for `arrowNavigation`/`favoriteReorder` — informational only in
    /// the Help cheat sheet, since neither is ever a key in the live store.
    private static func fixedLabel(_ command: Command) -> String {
        switch command {
        case .arrowNavigation: "↑ ↓ ← →"
        case .favoriteReorder: "⌘ ↑  /  ⌘ ↓"
        default: ""
        }
    }

    /// The label for whatever `command` is actually bound to right now.
    static func label(_ command: Command, in activeShortcuts: [Command: ShortcutBinding]) -> String {
        guard let binding = activeShortcuts[command] else { return fixedLabel(command) }
        return ShortcutLabelFormatter.label(character: binding.character, modifiers: binding.modifiers)
    }

    /// The other command already bound to `binding`, if any — checked before writing a single-row
    /// edit in Custom mode so the caller can confirm the swap with the user first. Only checks
    /// `activeShortcuts` itself: `arrowNavigation`/`favoriteReorder` are deliberately excluded since
    /// they're designed to layer with a live-store combo (e.g. Cmd+Down is both the Mac preset's
    /// `openSelected` and, in the narrow context of a selected favorite, favorite-reordering) rather
    /// than exclusively own it — flagging that overlap as a "conflict" would be a false positive.
    static func conflictingCommand(for binding: ShortcutBinding, excluding: Command, in activeShortcuts: [Command: ShortcutBinding]) -> Command? {
        activeShortcuts.first { $0.key != excluding && $0.value.character == binding.character && $0.value.modifiers == binding.modifiers }?.key
    }
}

extension View {
    /// Applies whatever `command` is actually bound to right now to a menu `Button`/`Toggle`. A
    /// command absent from `activeShortcuts` (only possible for the two fixed, non-editable
    /// commands, which never have a menu item) is a no-op.
    @ViewBuilder
    func keyboardShortcut(_ command: ShortcutRegistry.Command, activeShortcuts: [ShortcutRegistry.Command: ShortcutBinding]) -> some View {
        if let binding = activeShortcuts[command], let key = binding.keyEquivalent {
            keyboardShortcut(KeyboardShortcut(
                key, modifiers: binding.modifiers,
                localization: command == .shortcutsHUD ? .custom : .automatic))
        } else {
            self
        }
    }

    /// Convenience over the primitive above, reading the live store straight from the shared store —
    /// what every real call site actually has in scope.
    func keyboardShortcut(_ command: ShortcutRegistry.Command, preferences: PreferencesStore) -> some View {
        keyboardShortcut(command, activeShortcuts: preferences.view.activeShortcutsByCommand)
    }
}
