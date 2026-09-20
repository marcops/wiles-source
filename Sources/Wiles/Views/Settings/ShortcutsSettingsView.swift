import AppKit
import SwiftUI

/// "Shortcuts" tab of `SettingsView`: the Windows/Mac/Custom mode picker (moved out of
/// `GeneralSettingsView`) plus, only in Custom mode, one editable row per
/// `ShortcutRegistry.editableCommands` entry. Tapping a row starts a capture: the next key pressed
/// becomes that command's new binding, written straight into `appState.preferences.view.activeShortcuts`
/// (see `ViewPreferences.setShortcutBinding`). Selecting Windows or Mac instead bulk-overwrites the
/// live store with that preset (`ViewPreferences.applyPreset`) — destructive, with no undo.
struct ShortcutsSettingsView: View {
    private typealias Command = ShortcutRegistry.Command

    private struct PendingConflict {
        let command: Command
        let conflicting: Command
        let binding: ShortcutBinding
    }

    /// One label per `ShortcutRegistry.editableCommands` entry, reusing an existing menu/cheat-sheet
    /// key wherever one already names the same action. A dictionary (not a `switch`) keeps this
    /// well under `cyclomatic_complexity`'s limit — same reasoning as `ShortcutRegistry`'s own table
    /// (see its doc comment).
    private static let labelKeys: [Command: L10n.Key] = [
        .settings: .settingsMenuItem, .undo: .actUndo, .redo: .actRedo, .cut: .actCutShortcut,
        .copy: .actCopyShortcut, .paste: .actPasteShortcut, .selectAll: .shortcutsSelectAll, .find: .actSearch,
        .newWindow: .newWindow, .closeWindow: .close, .newFolder: .actNewFolderShortcut, .newFile: .shortcutsNewFile,
        .open: .open, .properties: .actItemProperties, .quickLook: .actQuickLook, .moveToTrash: .actMoveTrash,
        .rename: .rename, .goBack: .back, .goForward: .forward, .goToFolder: .goToFolder,
        .connectToServer: .actConnectServer, .enclosingFolder: .actParentFolder, .help: .wilesHelpAndShortcuts,
        .shortcutsHUD: .shortcutsToggleOverlay, .toggleTerminal: .actToggleTerminal, .togglePreview: .actTogglePreview,
        .toggleDiskUsage: .actDiskVisualizer, .toggleHiddenFiles: .shortcutsToggleHidden,
        .clearSelection: .shortcutsClearSelection, .zoomIn: .shortcutsZoomIn, .zoomOut: .shortcutsZoomOut,
        .zoomReset: .shortcutsZoomReset, .quickRename: .shortcutsRename, .openSelected: .shortcutsOpenFolder,
        .quickGoUp: .shortcutsBackspaceGoUp
    ]

    private static let sectionSpacing: CGFloat = 24
    private static let sectionCornerRadius: CGFloat = 8
    private static let rowVerticalPadding: CGFloat = 6
    private static let rowHorizontalPadding: CGFloat = 12

    var appState: AppState
    @State private var editingCommand: Command?
    @State private var captureController = ShortcutCaptureController()
    @State private var pendingConflict: PendingConflict?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Self.sectionSpacing) {
                modeSection
                if appState.preferences.view.navigationMode == .custom {
                    customShortcutsSection
                }
            }
            .padding()
        }
        .onDisappear { stopCapturing() }
        .confirmationDialog(
            conflictMessage,
            isPresented: Binding(get: { pendingConflict != nil }, set: {
                if !$0 {
                    pendingConflict = nil
                }
            }),
            titleVisibility: .visible) {
                Button(appState.tr(.shortcutConflictContinueButton)) { confirmConflictSwap() }
                Button(appState.tr(.cancel), role: .cancel) { pendingConflict = nil }
        }
        .accessibilityLabel(Text(appState.tr(.settingsShortcutsTab)))
    }

    private var modeSection: some View {
        @Bindable var appState = appState
        return groupedSection(title: appState.tr(.settingsShortcutModeSection)) {
            Picker(appState.tr(.shortcutMode), selection: $appState.preferences.view.navigationMode) {
                ForEach(NavigationMode.allCases) { mode in
                    Text(appState.tr(mode.l10nKey)).tag(mode)
                }
            }
            .padding(.vertical, Self.rowVerticalPadding)
            .padding(.horizontal, Self.rowHorizontalPadding)
            .onChange(of: appState.preferences.view.navigationMode) { _, newMode in
                guard newMode != .custom else { return }
                appState.preferences.view.applyPreset(newMode)
            }
        }
    }

    private var customShortcutsSection: some View {
        groupedSection(title: appState.tr(.settingsCustomShortcutsSection)) {
            ForEach(Array(ShortcutRegistry.editableCommands.enumerated()), id: \.element) { index, command in
                shortcutRow(command)
                if index < ShortcutRegistry.editableCommands.count - 1 {
                    Divider().padding(.leading, Self.rowHorizontalPadding)
                }
            }
        }
    }

    /// Replicates `.formStyle(.grouped)`'s look (caps section title above a rounded, tinted box) by
    /// hand — a plain `ScrollView`/`VStack`, not a `Form`/`List`, since a `List`-backed row on macOS
    /// swallows a tap before either `.onTapGesture` or a `Button` with `.contentShape` in its label
    /// reliably sees it (confirmed against the real app both ways); outside a `List` the shared
    /// `TappableRow` pattern works normally.
    private func groupedSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(spacing: 0, content: content)
                .background(RoundedRectangle(cornerRadius: Self.sectionCornerRadius).fill(Color(NSColor.controlBackgroundColor)))
        }
    }

    private func shortcutRow(_ command: Command) -> some View {
        let isEditing = editingCommand == command
        let title = appState.tr(labelKey(for: command))
        let currentLabel = ShortcutRegistry.label(command, in: appState.preferences.view.activeShortcutsByCommand)
        let valueText = isEditing ? appState.tr(.shortcutCaptureHint) : currentLabel
        return TappableRow(
            accessibilityLabel: title,
            accessibilityHint: isEditing ? appState.tr(.shortcutCaptureHint) : nil,
            action: { startCapturing(command) },
            content: {
                HStack {
                    Text(title)
                    Spacer()
                    Text(valueText)
                        .foregroundStyle(isEditing ? Color.accentColor : Color.secondary)
                        .font(.system(.body, design: .monospaced))
                }
                .padding(.vertical, Self.rowVerticalPadding)
                .padding(.horizontal, Self.rowHorizontalPadding)
            })
    }

    private func startCapturing(_ command: Command) {
        editingCommand = command
        captureController.start { [appState] event in
            handleCapturedEvent(event, for: command, appState: appState)
        }
    }

    private func stopCapturing() {
        captureController.stop()
        editingCommand = nil
    }

    private func handleCapturedEvent(_ event: NSEvent, for command: Command, appState: AppState) {
        stopCapturing()
        // `charactersIgnoringModifiers` is the right source in principle, but a synthetic/edge-case
        // event can hand a local monitor a Cmd-held keyDown with that field empty even though the
        // key is a normal printable one — `characters` (which does reflect Cmd, unlike Shift/Option,
        // since Cmd isn't a character-remapping modifier) is a reliable fallback for exactly that case.
        let resolvedCharacters = [event.charactersIgnoringModifiers, event.characters].compactMap { $0 }.first { !$0.isEmpty }
        guard let characters = resolvedCharacters else { return }
        let binding = ShortcutBinding(character: characters, modifiers: Self.modifiers(from: event.modifierFlags), physicalKeyCode: event.keyCode)
        if let conflicting = ShortcutRegistry.conflictingCommand(for: binding, excluding: command, in: appState.preferences.view.activeShortcutsByCommand) {
            pendingConflict = PendingConflict(command: command, conflicting: conflicting, binding: binding)
        } else {
            appState.preferences.view.setShortcutBinding(binding, for: command)
        }
    }

    private func confirmConflictSwap() {
        guard let pendingConflict else { return }
        appState.preferences.view.setShortcutBinding(pendingConflict.binding, for: pendingConflict.command, clearingConflictOf: pendingConflict.conflicting)
        self.pendingConflict = nil
    }

    private var conflictMessage: String {
        guard let pendingConflict else { return "" }
        return String(format: appState.tr(.shortcutConflictMessageFormat), appState.tr(labelKey(for: pendingConflict.conflicting)))
    }

    private static func modifiers(from flags: NSEvent.ModifierFlags) -> EventModifiers {
        var modifiers: EventModifiers = []
        if flags.contains(.command) {
            modifiers.insert(.command)
        }
        if flags.contains(.shift) {
            modifiers.insert(.shift)
        }
        if flags.contains(.option) {
            modifiers.insert(.option)
        }
        if flags.contains(.control) {
            modifiers.insert(.control)
        }
        return modifiers
    }

    /// `.arrowNavigation`/`.favoriteReorder` are unreachable here — `editableCommands` excludes both
    /// — so they fall back to a placeholder rather than needing a real entry in `labelKeys`.
    private func labelKey(for command: Command) -> L10n.Key {
        Self.labelKeys[command] ?? .shortcutsNav
    }
}
