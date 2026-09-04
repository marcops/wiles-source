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
        guard !folder.scopePath.isEmpty else {
            prepareForSmartFolderRun(folder)
            refreshCurrentDirectory(isUserInitiated: true)
            return
        }
        let scopeURL = URL(fileURLWithPath: folder.scopePath)
        // A `/Volumes/…` scope resolves asynchronously (`navigateToAwaitingCompletion`) — preparing
        // and running the query only after it actually lands, instead of right after firing it off,
        // avoids racing the navigation's own later completion, which would otherwise reset the state
        // just prepared. A local scope keeps the exact synchronous path it always had — `fileExists`
        // on a local path is cheap enough to check inline, and never reaches this synchronous check
        // for a /Volumes/ path at all.
        guard SlowVolumePathValidator.isLikelySlowVolume(folder.scopePath) else {
            if FileManager.default.fileExists(atPath: folder.scopePath) {
                navigateTo(scopeURL)
            }
            prepareForSmartFolderRun(folder)
            refreshCurrentDirectory(isUserInitiated: true)
            return
        }
        // Captured before the `await` so it reflects wherever the app actually was at the moment
        // this smart folder was opened — the baseline `navigation.currentURL` should still be at
        // if nothing else navigates in the meantime, whether or not `scopeURL` turns out to exist.
        let preRunURL = navigation.currentURL
        Task { [weak self] in
            guard let self else { return }
            await navigateToAwaitingCompletion(scopeURL)
            // Two outcomes leave `currentURL` untouched from this call's own perspective: it landed
            // on `scopeURL` (the share exists), or the share doesn't exist and `completeNavigation`
            // left `currentURL` exactly where it was before this call (`preRunURL`) — both are this
            // call's own navigation actually resolving, and must still prepare/run the query. Any
            // OTHER value means a different, later navigation raced and won — acting here
            // would show this folder's name/query pill over whatever directory that other
            // navigation landed on instead. Bail in that case only.
            let current = navigation.currentURL.standardizedFileURL
            guard current == scopeURL.standardizedFileURL || current == preRunURL.standardizedFileURL else { return }
            prepareForSmartFolderRun(folder)
            refreshCurrentDirectory(isUserInitiated: true)
        }
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
