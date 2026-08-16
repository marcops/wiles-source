import Foundation

public extension AppState {
    /// Resets selection state, then assigns `searchQuery` normally so its `didSet` actually fires
    /// the search (`refreshCurrentDirectory()`) — the same call a manually-typed query triggers.
    /// Selection is cleared *before* that assignment so the search's async completion never finds
    /// a stale `pendingSelectionURL`/`selectedURLs` from whatever was selected before the smart
    /// folder ran and reinstates it.
    func prepareForSmartFolderRun(_ folder: SmartFolder) {
        smartFolder.activeFolderID = folder.id
        selectedURLs.removeAll()
        selection.pendingSelectionURL = nil
        if !isSearching {
            smartFolder.suppressNextSearchFocus = true
        }
        isSearching = true
        searchQuery = folder.searchQuery
    }
}
