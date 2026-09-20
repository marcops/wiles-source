import AppKit
import Foundation
import SwiftUI

/// Arrow-key selection navigation (incl. Shift-range-select), Cmd+Up/Down favorite reordering, and
/// the live-shortcut-driven edit actions (go up, open the anchor selection, quick-rename, move to
/// Trash), extracted from `GlobalKeyMonitor.KeyMonitorNSView` so this logic is unit-testable without
/// an `NSView`/window. Stateless: callers pass `AppState`/`WindowUIState` per call rather than this
/// type holding a reference to the view.
///
/// Every edit action below reads `appState.preferences.view.activeShortcutsByCommand` directly and
/// unconditionally — there is no `navigationMode` branching here. Switching Windows/Mac/Custom only
/// changes what's *in* that store (`ViewPreferences.applyPreset`/`setShortcutBinding`), never how
/// this file reads it.
@MainActor
struct KeyboardSelectionNavigator {
    private enum ArrowKey: Equatable {
        case up, down, left, right

        init?(code: UInt16) {
            switch code {
            case KeyCode.arrowUp: self = .up
            case KeyCode.arrowDown: self = .down
            case KeyCode.arrowLeft: self = .left
            case KeyCode.arrowRight: self = .right
            default: return nil
            }
        }
    }

    /// Handles arrow-key navigation, favorite reordering, and the live-shortcut edit actions.
    /// Returns `true` if `code` was handled (caller should swallow the event).
    func handleNavigationKeyDown(code: UInt16, isCmd: Bool, appState: AppState, windowUIState: WindowUIState) -> Bool {
        if let arrowCode = ArrowKey(code: code),
           isFavoriteReorderShortcut(
               isCmd: isCmd, arrowCode: arrowCode,
               selectedFavorite: windowUIState.selectedFavoriteURL, currentURL: appState.navigation.currentURL) {
            appState.moveSelectedFavorite(offset: arrowCode == .up ? -1 : 1, windowUIState: windowUIState)
            return true
        }
        if handleLiveShortcutKeyDown(code: code, isCmd: isCmd, appState: appState, windowUIState: windowUIState) {
            return true
        }
        if let arrowCode = ArrowKey(code: code) {
            let isShift = NSEvent.modifierFlags.contains(.shift)
            handleArrowKeyDown(arrowCode, isShift: isShift, appState: appState)
            return true
        }
        return false
    }

    /// True when Cmd+Up/Down was pressed while the sidebar's currently-selected favorite
    /// happens to also be the folder being browsed — the shortcut for reordering that favorite
    /// in the list, rather than a plain navigation arrow press.
    private func isFavoriteReorderShortcut(isCmd: Bool, arrowCode: ArrowKey, selectedFavorite: URL?, currentURL: URL) -> Bool {
        guard isCmd, let selectedFavorite else { return false }
        guard selectedFavorite.standardizedFileURL == currentURL.standardizedFileURL else { return false }
        return arrowCode == .up || arrowCode == .down
    }

    private func handleArrowKeyDown(_ key: ArrowKey, isShift: Bool, appState: AppState) {
        switch key {
        case .up:
            let offset = appState.currentViewMode == .grid ? -appState.selection.gridColumnCount : -1
            moveSelection(by: offset, isShift: isShift, appState: appState)
        case .down:
            let offset = appState.currentViewMode == .grid ? appState.selection.gridColumnCount : 1
            moveSelection(by: offset, isShift: isShift, appState: appState)
        case .left:
            if appState.currentViewMode == .grid {
                moveSelection(by: -1, isShift: isShift, appState: appState)
            } else {
                appState.goUp()
            }
        case .right:
            if appState.currentViewMode == .grid {
                moveSelection(by: 1, isShift: isShift, appState: appState)
            } else if let target = directoryToEnter(from: appState) {
                appState.navigateTo(target)
            }
        }
    }

    /// The single selected item's URL, but only when it's actually a directory — `.right` in
    /// list view should enter a folder, not "navigate to" a selected file.
    private func directoryToEnter(from appState: AppState) -> URL? {
        guard let first = appState.selection.selectedURLs.first else { return nil }
        guard let item = appState.fileSystem.itemsByURL[first] else { return nil }
        return item.isDirectory ? first : nil
    }

    /// `selectedURLs` is a `Set` (no stable order), so `.first` can't reliably stand in for "the
    /// current item" — both branches below derive it from `keyboardSelectionAnchorURL` instead.
    /// For a Shift move, the moving end of the range is whichever selected index sits farthest
    /// from the anchor.
    private func moveSelection(by offset: Int, isShift: Bool, appState: AppState) {
        let items = appState.fileSystem.items
        guard !items.isEmpty else { return }
        let indexByURL = appState.fileSystem.indexByURL

        if isShift {
            let anchorURL = appState.selection.keyboardSelectionAnchorURL ?? appState.selection.selectedURLs.first
            let anchorIndex = anchorURL.flatMap { indexByURL[$0] } ?? 0
            appState.selection.keyboardSelectionAnchorURL = items[anchorIndex].url

            let selectedIndices = appState.selection.selectedURLs.compactMap { indexByURL[$0] }
            let cursorIndex = selectedIndices.max(by: { abs($0 - anchorIndex) < abs($1 - anchorIndex) }) ?? anchorIndex

            let newIndex = max(0, min(items.count - 1, cursorIndex + offset))
            let lo = min(anchorIndex, newIndex)
            let hi = max(anchorIndex, newIndex)
            appState.selection.selectedURLs = Set(items[lo ... hi].map(\.url))
            appState.selection.lastMovedURL = items[newIndex].url
        } else {
            let currentURL = appState.selection.keyboardSelectionAnchorURL ?? appState.selection.selectedURLs.first
            let currentIndex = currentURL.flatMap { indexByURL[$0] } ?? -1
            let newIndex = max(0, min(items.count - 1, currentIndex + offset))
            let newURL = items[newIndex].url
            appState.selection.keyboardSelectionAnchorURL = newURL
            appState.selection.selectedURLs = [newURL]
            appState.selection.lastMovedURL = newURL
        }
    }

    /// Go up (`.enclosingFolder`), open the anchor selection (`.openSelected`), quick-rename
    /// (`.quickRename`), move to Trash (`.moveToTrash`, plus its two fixed aliases below), and
    /// go-up-with-no-selection (`.quickGoUp`) — every one read directly from the live store, with no
    /// mode check anywhere. A Windows-preset user has `.quickRename` bound to F2 and `.quickGoUp`
    /// bound to Backspace; a Mac-preset user has `.quickRename` on Return and no `.quickGoUp` binding
    /// at all (so this simply never matches); a Custom user has whatever they typed.
    private func handleLiveShortcutKeyDown(code: UInt16, isCmd: Bool, appState: AppState, windowUIState: WindowUIState) -> Bool {
        let store = appState.preferences.view.activeShortcutsByCommand
        let modifiers = Self.currentEventModifiers(isCmd: isCmd)

        if matches(.enclosingFolder, code: code, modifiers: modifiers, in: store) {
            appState.goUp()
            return true
        }
        if matches(.openSelected, code: code, modifiers: modifiers, in: store) {
            appState.openSelectedItem()
            return true
        }
        if matches(.quickRename, code: code, modifiers: modifiers, in: store), !appState.selection.selectedURLs.isEmpty {
            appState.triggerRenameForSelected(windowUIState: windowUIState)
            return true
        }
        if matchesMoveToTrash(code: code, modifiers: modifiers, in: store), !appState.selection.selectedURLs.isEmpty {
            appState.deleteSelected(windowUIState: windowUIState)
            return true
        }
        if matches(.quickGoUp, code: code, modifiers: modifiers, in: store), appState.selection.selectedURLs.isEmpty {
            appState.goUp()
            return true
        }
        return false
    }

    private func matches(
        _ command: ShortcutRegistry.Command,
        code: UInt16,
        modifiers: EventModifiers,
        in store: [ShortcutRegistry.Command: ShortcutBinding]) -> Bool {
        guard let binding = store[command], let physicalKeyCode = binding.physicalKeyCode else { return false }
        return physicalKeyCode == code && binding.modifiers == modifiers
    }

    /// `.moveToTrash` answers to its live binding plus two fixed, non-customizable aliases: a
    /// physical forward-delete key (a second hardware key for the same "Delete" action on an
    /// extended keyboard — same shape as `.toggleHiddenFiles`'s `⌃H`), and Cmd+Return (a
    /// long-standing convenience alias, independent of whatever key `.quickRename`/`.openSelected`
    /// currently have).
    private func matchesMoveToTrash(code: UInt16, modifiers: EventModifiers, in store: [ShortcutRegistry.Command: ShortcutBinding]) -> Bool {
        if matches(.moveToTrash, code: code, modifiers: modifiers, in: store) {
            return true
        }
        if modifiers.isEmpty, code == ShortcutRegistry.moveToTrashAlternatePhysicalKeyCode {
            return true
        }
        return modifiers == .command && code == KeyCode.returnKey
    }

    /// `isCmd` is the authoritative source for the Command flag — the same parameter every caller
    /// (`GlobalKeyMonitor`, and every test in `KeyboardShortcutDispatchTests`) already threads
    /// through explicitly. Shift/Option/Control aren't passed as parameters, so those three still
    /// read live `NSEvent.modifierFlags`, matching `handleArrowKeyDown`'s own `isShift` lookup above.
    private static func currentEventModifiers(isCmd: Bool) -> EventModifiers {
        let flags = NSEvent.modifierFlags
        var modifiers: EventModifiers = []
        if isCmd {
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
}
