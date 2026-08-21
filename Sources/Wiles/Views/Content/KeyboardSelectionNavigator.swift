import AppKit
import Foundation

/// Arrow-key selection navigation (incl. Shift-range-select), Cmd+Up/Down favorite reordering,
/// and F2/Delete/Return edit shortcuts, extracted from `GlobalKeyMonitor.KeyMonitorNSView` so
/// this logic is unit-testable without an `NSView`/window. Stateless: callers pass
/// `AppState`/`WindowUIState` per call rather than this type holding a reference to the view.
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

    /// Handles arrow-key navigation, favorite reordering, and edit-action shortcuts
    /// (F2/Delete/Return). Returns `true` if `code` was handled (caller should swallow the event).
    func handleNavigationKeyDown(code: UInt16, isCmd: Bool, appState: AppState, windowUIState: WindowUIState) -> Bool {
        if let arrowCode = ArrowKey(code: code) {
            if isFavoriteReorderShortcut(
                isCmd: isCmd, arrowCode: arrowCode,
                selectedFavorite: windowUIState.selectedFavoriteURL, currentURL: appState.navigation.currentURL) {
                appState.moveSelectedFavorite(offset: arrowCode == .up ? -1 : 1, windowUIState: windowUIState)
                return true
            }
            let isShift = NSEvent.modifierFlags.contains(.shift)
            handleArrowKeyDown(arrowCode, isShift: isShift, appState: appState)
            return true
        }
        return handleEditActionKeyDown(code: code, isCmd: isCmd, appState: appState, windowUIState: windowUIState)
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
            let offset = appState.preferences.viewMode == .grid ? -appState.selection.gridColumnCount : -1
            moveSelection(by: offset, isShift: isShift, appState: appState)
        case .down:
            let offset = appState.preferences.viewMode == .grid ? appState.selection.gridColumnCount : 1
            moveSelection(by: offset, isShift: isShift, appState: appState)
        case .left:
            if appState.preferences.viewMode == .grid {
                moveSelection(by: -1, isShift: isShift, appState: appState)
            } else {
                appState.goUp()
            }
        case .right:
            if appState.preferences.viewMode == .grid {
                moveSelection(by: 1, isShift: isShift, appState: appState)
            } else if let target = directoryToEnter(from: appState) {
                appState.navigateTo(target)
            }
        }
    }

    /// The single selected item's URL, but only when it's actually a directory — `.right` in
    /// list view should enter a folder, not "navigate to" a selected file.
    private func directoryToEnter(from appState: AppState) -> URL? {
        guard let first = appState.selectedURLs.first else { return nil }
        guard let item = appState.fileSystem.items.first(where: { $0.url == first }) else { return nil }
        return item.isDirectory ? first : nil
    }

    /// `selectedURLs` is a `Set` (no stable order), so `.first` can only ever stand in for
    /// "the current item" when the set holds exactly one element — true for a plain move, but
    /// not once Shift has grown the selection to a range. For a Shift move, the moving end of
    /// that range is derived instead: whichever selected index sits farthest from the anchor.
    private func moveSelection(by offset: Int, isShift: Bool, appState: AppState) {
        let items = appState.fileSystem.items
        guard !items.isEmpty else { return }

        if isShift {
            let anchorURL = appState.selection.keyboardSelectionAnchorURL ?? appState.selectedURLs.first
            let anchorIndex = items.firstIndex(where: { $0.url == anchorURL }) ?? 0
            appState.selection.keyboardSelectionAnchorURL = items[anchorIndex].url

            let selectedIndices = appState.selectedURLs.compactMap { url in items.firstIndex(where: { $0.url == url }) }
            let cursorIndex = selectedIndices.max(by: { abs($0 - anchorIndex) < abs($1 - anchorIndex) }) ?? anchorIndex

            let newIndex = max(0, min(items.count - 1, cursorIndex + offset))
            let lo = min(anchorIndex, newIndex)
            let hi = max(anchorIndex, newIndex)
            appState.selectedURLs = Set(items[lo ... hi].map(\.url))
            appState.selection.lastMovedURL = items[newIndex].url
        } else {
            let currentIndex = items.firstIndex(where: { $0.url == appState.selectedURLs.first }) ?? -1
            let newIndex = max(0, min(items.count - 1, currentIndex + offset))
            let newURL = items[newIndex].url
            appState.selection.keyboardSelectionAnchorURL = newURL
            appState.selectedURLs = [newURL]
            appState.selection.lastMovedURL = newURL
        }
    }

    private func handleEditActionKeyDown(code: UInt16, isCmd: Bool, appState: AppState, windowUIState: WindowUIState) -> Bool {
        if code == KeyCode.f2 {
            if !appState.selectedURLs.isEmpty {
                triggerRenameForSelected(appState: appState, windowUIState: windowUIState)
                return true
            }
        } else if code == KeyCode.backspace || code == KeyCode.forwardDelete {
            if !appState.selectedURLs.isEmpty {
                appState.deleteSelected(windowUIState: windowUIState)
                return true
            } else if appState.preferences.navigationMode == .gnome, !isCmd {
                appState.goUp()
                return true
            }
        } else if code == KeyCode.returnKey {
            return handleReturnKeyDown(isCmd: isCmd, appState: appState, windowUIState: windowUIState)
        }
        return false
    }

    private func handleReturnKeyDown(isCmd: Bool, appState: AppState, windowUIState: WindowUIState) -> Bool {
        if isCmd, !appState.selectedURLs.isEmpty {
            appState.deleteSelected(windowUIState: windowUIState)
            return true
        } else if !isCmd {
            if appState.preferences.navigationMode == .gnome, let first = appState.selectedURLs.first {
                appState.navigateTo(first)
                return true
            } else if appState.preferences.navigationMode == .macOS, let first = appState.selectedURLs.first,
                      let item = appState.fileSystem.items.first(where: { $0.url == first }) {
                windowUIState.renameItem = item
                return true
            }
        }
        return false
    }

    private func triggerRenameForSelected(appState: AppState, windowUIState: WindowUIState) {
        if appState.selectedURLs.count > 1 {
            windowUIState.showBatchRenameSheet = true
        } else if let first = appState.selectedURLs.first, let item = appState.fileSystem.items.first(where: { $0.url == first }) {
            windowUIState.renameItem = item
        }
    }
}
