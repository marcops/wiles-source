import Foundation
import GitBeacon

/// Smart folder CRUD, split out of `PreferencesStore.swift` to keep that file under the 500-line
/// lint cap — these methods all operate on `PreferencesStore.smartFolders`, declared there.
public extension PreferencesStore {
    func addSmartFolder(_ folder: SmartFolder) {
        persistSmartFolders(smartFolders + [folder])
    }

    func removeSmartFolder(_ folder: SmartFolder) {
        persistSmartFolders(smartFolders.filter { $0.id != folder.id })
    }

    /// Renames a smart folder in place (same id) — trims and ignores an empty/whitespace-only name.
    func renameSmartFolder(_ folder: SmartFolder, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let idx = smartFolders.firstIndex(where: { $0.id == folder.id }) else { return }
        var updated = smartFolders
        updated[idx].name = trimmed
        persistSmartFolders(updated)
    }

    /// Overwrites a smart folder's saved query in place (same id) — e.g. "Update Search" after
    /// editing the search box while that smart folder's results are showing.
    func updateSmartFolderQuery(_ folder: SmartFolder, to newQuery: String) {
        guard let idx = smartFolders.firstIndex(where: { $0.id == folder.id }) else { return }
        var updated = smartFolders
        updated[idx].searchQuery = newQuery
        persistSmartFolders(updated)
    }

    /// Saves `candidate` to disk first, only updating in-memory `smartFolders` on success — so a
    /// save failure never leaves the sidebar showing an add/rename/removal that didn't actually
    /// survive to disk.
    func persistSmartFolders(_ candidate: [SmartFolder]) {
        do {
            try SmartFolderService.saveSmartFolders(candidate)
            smartFolders = candidate
        } catch {
            ErrorReporter.report(error, context: "Persisting smart folders")
        }
    }
}
