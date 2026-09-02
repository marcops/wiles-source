import Foundation

public enum UndoActionType: Sendable {
    case rename(oldURL: URL, newURL: URL)
    case move(sourceURL: URL, destinationURL: URL)
    case createFolder(url: URL)
    case createFile(url: URL)
    case trash(originalURL: URL, trashedURL: URL)
    /// A single-item POSIX permission change; `previous` is what it was before, for `⌘Z`.
    case chmod(url: URL, previous: POSIXPermissions)
    /// One user action that touched N items (multi-file trash / move / cut-paste / copy-paste /
    /// batch-rename / duplicate-clean). Recorded ONCE — via `UndoRedoService.recordActions(_:)` —
    /// so a single `⌘Z` reverts the whole thing and the 50-record history cap counts user actions,
    /// not items (finding HH-089). Sub-actions are stored in the order they happened; `undo`
    /// reverses them last-first, `redo` re-applies them first-last, and each is reverted/re-applied
    /// independently so one failed item doesn't strand the rest.
    case batch([Self])
}
