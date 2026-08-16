import Foundation

public extension AppState {
    /// Resets search/selection state before a smart folder's own cross-directory query runs.
    /// Uses `setSearchQuery(_:triggerRefresh:false)` so displaying the smart folder's query text
    /// doesn't also kick off a normal single-directory reload of whatever folder is currently
    /// open — that reload used to race the smart folder's own results and silently overwrite
    /// them, which is why a freshly-clicked smart folder item's selection kept reverting to
    /// whatever was selected before the smart folder ran.
    func prepareForSmartFolderRun(_ folder: SmartFolder) {
        smartFolder.isActive = true
        smartFolder.activeFolderID = folder.id
        setSearchQuery(folder.searchQuery, triggerRefresh: false)
        if !isSearching {
            smartFolder.suppressNextSearchFocus = true
        }
        isSearching = true
        selectedURLs.removeAll()
        // A stale `pendingSelectionURL` from an earlier "go up a folder" navigation never gets
        // consumed while smart-folder mode blocks refreshCurrentDirectory() — left alone, it fires
        // the moment a real reload finally runs again (e.g. editing the search text to exit smart-
        // folder mode) and silently reinstates that old selection in a completely unrelated context.
        selection.pendingSelectionURL = nil
    }
}
