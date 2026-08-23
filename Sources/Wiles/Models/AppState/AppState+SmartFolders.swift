import Foundation
import GitBeacon

public extension AppState {
    /// Resets selection state, then assigns `selection.searchQuery` normally so its `didSet` actually fires
    /// the search (`refreshCurrentDirectory()`) — the same call a manually-typed query triggers.
    /// Selection is cleared *before* that assignment so the search's async completion never finds
    /// a stale `pendingSelectionURL`/`selection.selectedURLs` from whatever was selected before the smart
    /// folder ran and reinstates it.
    func prepareForSmartFolderRun(_ folder: SmartFolder) {
        smartFolder.activeFolderID = folder.id
        selection.selectedURLs.removeAll()
        selection.pendingSelectionURL = nil
        if !selection.isSearching {
            smartFolder.suppressNextSearchFocus = true
        }
        selection.isSearching = true
        selection.searchQuery = folder.searchQuery
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
        SmartFolderService.shared.executeQuery(for: folder) { [weak self] items in
            Task { @MainActor in
                self?.applyLoadedItems(items, target: target)
            }
        }
    }

    func addSmartFolder(_ folder: SmartFolder) {
        preferences.addSmartFolder(folder)
    }

    func removeSmartFolder(_ folder: SmartFolder) {
        preferences.removeSmartFolder(folder)
    }

    /// Renames a smart folder in place (same id) — trims and ignores an empty/whitespace-only name.
    func renameSmartFolder(_ folder: SmartFolder, to newName: String) {
        preferences.renameSmartFolder(folder, to: newName)
    }

    /// Overwrites a smart folder's saved query in place (same id) — e.g. "Update Search" after
    /// editing the search box while that smart folder's results are showing. Without this, editing
    /// the query text only ever affected the current session; re-running the smart folder later
    /// always went back to whatever it was originally saved with.
    func updateSmartFolderQuery(_ folder: SmartFolder, to newQuery: String) {
        preferences.updateSmartFolderQuery(folder, to: newQuery)
    }
}
