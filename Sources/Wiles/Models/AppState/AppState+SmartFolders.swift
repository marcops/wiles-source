import Foundation

public extension AppState {
    /// Puts the search UI into "showing smart folder `folder`" state: sidebar highlight, cleared
    /// selection, spinner, and `folder.searchQuery` set *silently* (the caller drives the reload
    /// itself, so the debounced search refresh must not also fire and race it). Selection is
    /// cleared first so a slow reload's completion can't reinstate a stale `pendingSelectionURL` /
    /// `selectedURLs` from whatever was selected before.
    func prepareForSmartFolderRun(_ folder: SmartFolder) {
        smartFolder.activeFolderID = folder.id
        smartFolder.lastRunTimedOut = false
        selection.selectedURLs.removeAll()
        selection.pendingSelectionURL = nil
        if !selection.isSearching {
            smartFolder.suppressNextSearchFocus = true
        }
        selection.isSearching = true
        selection.setSearchQuerySilently(folder.searchQuery)
        fileSystem.isLoading = true
    }

    /// Opens a saved smart folder: navigates to the folder it was saved from, then runs its query
    /// through the **same engine as the header search field** (`refreshCurrentDirectory`), so it
    /// honors the live search settings — "search everywhere", name/content scope, case sensitivity.
    /// The old path went straight to Spotlight (`NSMetadataQuery`) scoped to `folder.scopePath`,
    /// which ignored every one of those settings and returned nothing when Spotlight had no local
    /// index for that scope.
    func runSmartFolder(_ folder: SmartFolder, windowUIState: WindowUIState) {
        // Show the folder's sidebar name as a non-editable pill, not the raw editable query.
        windowUIState.isEditingSearch = false
        if !folder.scopePath.isEmpty, FileManager.default.fileExists(atPath: folder.scopePath) {
            navigateTo(URL(fileURLWithPath: folder.scopePath))
        }
        prepareForSmartFolderRun(folder)
        refreshCurrentDirectory(isUserInitiated: true)
    }

    /// These forward to `PreferencesStore+SmartFolders` and surface a persistence failure — the
    /// store has no window to show one in, this layer does.
    func addSmartFolder(_ folder: SmartFolder) {
        surfaceSmartFolderError(preferences.addSmartFolder(folder))
    }

    func removeSmartFolder(_ folder: SmartFolder) {
        surfaceSmartFolderError(preferences.removeSmartFolder(folder))
    }

    func renameSmartFolder(_ folder: SmartFolder, to newName: String) {
        surfaceSmartFolderError(preferences.renameSmartFolder(folder, to: newName))
    }

    func updateSmartFolderQuery(_ folder: SmartFolder, to newQuery: String) {
        surfaceSmartFolderError(preferences.updateSmartFolderQuery(folder, to: newQuery))
    }

    private func surfaceSmartFolderError(_ error: (any Error)?) {
        guard let error else { return }
        showError(error, context: "Persisting smart folders")
    }
}
