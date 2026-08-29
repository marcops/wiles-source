import Foundation

/// Smart folder CRUD, split out of `PreferencesStore.swift` to keep that file under the 500-line
/// lint cap — these methods all operate on `PreferencesStore.smartFolders`, declared there.
///
/// Each returns the persistence error (or `nil` on success) so the caller — `AppState+SmartFolders`,
/// which has a window to show it in — can surface a failed rename/removal/update instead of
/// leaving the user thinking it worked.
public extension PreferencesStore {
    @discardableResult
    func addSmartFolder(_ folder: SmartFolder) -> (any Error)? {
        persistSmartFolders(smartFolders + [folder])
    }

    @discardableResult
    func removeSmartFolder(_ folder: SmartFolder) -> (any Error)? {
        persistSmartFolders(smartFolders.filter { $0.id != folder.id })
    }

    /// Renames a smart folder in place (same id) — trims and ignores an empty/whitespace-only name.
    @discardableResult
    func renameSmartFolder(_ folder: SmartFolder, to newName: String) -> (any Error)? {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let idx = smartFolders.firstIndex(where: { $0.id == folder.id }) else { return nil }
        var updated = smartFolders
        updated[idx].name = trimmed
        return persistSmartFolders(updated)
    }

    /// Overwrites a smart folder's saved query in place (same id) — e.g. "Update Search" after
    /// editing the search box while that smart folder's results are showing.
    @discardableResult
    func updateSmartFolderQuery(_ folder: SmartFolder, to newQuery: String) -> (any Error)? {
        guard let idx = smartFolders.firstIndex(where: { $0.id == folder.id }) else { return nil }
        var updated = smartFolders
        updated[idx].searchQuery = newQuery
        return persistSmartFolders(updated)
    }

    /// Saves `candidate` to disk first, only updating in-memory `smartFolders` on success — so a
    /// save failure never leaves the sidebar showing an add/rename/removal that didn't actually
    /// survive to disk. Returns the failure (or `nil`) rather than swallowing it.
    @discardableResult
    func persistSmartFolders(_ candidate: [SmartFolder]) -> (any Error)? {
        do {
            try SmartFolderService.saveSmartFolders(candidate)
            smartFolders = candidate
            return nil
        } catch {
            return error
        }
    }
}
