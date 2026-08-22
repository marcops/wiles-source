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
        SmartFolderService.shared.executeQuery(for: folder) { [weak self] items in
            Task { @MainActor in
                self?.fileSystem.items = items
            }
        }
    }

    func addSmartFolder(_ folder: SmartFolder) {
        preferences.smartFolders.append(folder)
        persistSmartFolders(context: "Adding smart folder")
    }

    func removeSmartFolder(_ folder: SmartFolder) {
        preferences.smartFolders.removeAll { $0.id == folder.id }
        persistSmartFolders(context: "Removing smart folder")
    }

    /// Renames a smart folder in place (same id) — trims and ignores an empty/whitespace-only name.
    func renameSmartFolder(_ folder: SmartFolder, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let idx = preferences.smartFolders.firstIndex(where: { $0.id == folder.id }) else { return }
        preferences.smartFolders[idx].name = trimmed
        persistSmartFolders(context: "Renaming smart folder")
    }

    /// Overwrites a smart folder's saved query in place (same id) — e.g. "Update Search" after
    /// editing the search box while that smart folder's results are showing. Without this, editing
    /// the query text only ever affected the current session; re-running the smart folder later
    /// always went back to whatever it was originally saved with.
    func updateSmartFolderQuery(_ folder: SmartFolder, to newQuery: String) {
        guard let idx = preferences.smartFolders.firstIndex(where: { $0.id == folder.id }) else { return }
        preferences.smartFolders[idx].searchQuery = newQuery
        persistSmartFolders(context: "Updating smart folder search")
    }

    private func persistSmartFolders(context: String) {
        do {
            try SmartFolderService.saveSmartFolders(preferences.smartFolders)
        } catch {
            ErrorReporter.report(error, context: context)
            showError(error.localizedDescription)
        }
    }
}
