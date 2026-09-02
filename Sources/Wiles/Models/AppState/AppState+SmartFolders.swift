import Foundation

public extension AppState {
    /// Resets selection state, then sets `selection.searchQuery` to the folder's query *silently* —
    /// `runSmartFolder` runs its own Spotlight query right after, and the normal debounced search
    /// refresh would otherwise re-read the current directory and race those results. Selection is
    /// cleared first so the query's async completion never reinstates a stale `pendingSelectionURL`
    /// / `selectedURLs` from whatever was selected before the smart folder ran.
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
    }

    /// Preps the search UI for `folder` via `prepareForSmartFolderRun`, then runs its Spotlight
    /// query and applies the results to `fileSystem.items`. `SmartFolderService.executeQuery`
    /// already guards its completion with a per-call UUID token so an older, slower-finishing
    /// query can't clobber a newer one's results (see its doc comment) — this just re-enters the
    /// main actor before writing to AppState, matching every other Service-completion call site.
    func runSmartFolder(_ folder: SmartFolder) {
        prepareForSmartFolderRun(folder)
        // `prepareForSmartFolderRun`'s `searchQuery` assignment above already fired a normal
        // directory refresh via `onSearchQueryChanged` — that refresh and this Spotlight query
        // would otherwise race to write `fileSystem.items` last. Cancel it so only the smart
        // folder's own results land.
        fileSystem.refreshTask?.cancel()
        let target = navigation.currentURL
        smartFolderService.executeQuery(for: folder) { [weak self] items in
            // `SmartFolderService.runQuery` already invokes this completion from inside a
            // `Task { @MainActor }`, so assume isolation instead of nesting another one (SM-055).
            MainActor.assumeIsolated {
                guard let self else { return }
                self.smartFolder.lastRunTimedOut = self.smartFolderService.lastRunTimedOut
                self.applyLoadedItems(
                    items, target: target,
                    truncatedAtCap: items.count >= SmartFolderService.maxResultCount)
            }
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
