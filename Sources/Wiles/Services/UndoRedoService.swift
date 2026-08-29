import Foundation

/// Owned per-window (one instance per `AppState`), not a shared singleton — a `.shared` undo/redo
/// stack let ⌘Z in one window undo an action performed in a different window.
@MainActor
public final class UndoRedoService {
    private var undoStack: [UndoRecord] = []
    private var redoStack: [UndoRecord] = []
    private let maxHistoryLimit = 50

    /// Called after an undo/redo step relocates a file on disk (rename / move / trash-restore).
    /// `AppState` uses it to keep favorites pointing at the new path — undo/redo must not call
    /// `FileSystemService.moveItem` without this, or a favorited folder's undo breaks the favorite.
    public var onFileRelocated: ((_ from: URL, _ to: URL) -> Void)?

    public init() { }

    public func recordAction(_ action: UndoActionType) {
        undoStack.append(UndoRecord(actionType: action))
        if undoStack.count > maxHistoryLimit {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
    }

    public func canUndo() -> Bool {
        !undoStack.isEmpty
    }

    public func canRedo() -> Bool {
        !redoStack.isEmpty
    }

    public func undo() async throws -> URL? {
        guard let record = undoStack.popLast() else { return nil }
        do {
            let url = try await executeReverseAction(record.actionType)
            redoStack.append(record)
            return url
        } catch {
            // Action wasn't actually undone: put the record back so it remains available
            // to retry, instead of silently promoting it to a bogus redo entry.
            undoStack.append(record)
            throw error
        }
    }

    public func redo() async throws -> URL? {
        guard let record = redoStack.popLast() else { return nil }
        do {
            let url = try await executeForwardAction(record.actionType)
            undoStack.append(record)
            return url
        } catch {
            redoStack.append(record)
            throw error
        }
    }

    private func executeReverseAction(_ action: UndoActionType) async throws -> URL {
        switch action {
        case let .rename(oldURL, newURL):
            let result = try await FileSystemService.renameItem(at: newURL, newName: oldURL.lastPathComponent)
            onFileRelocated?(newURL, result)
            return result
        case let .move(sourceURL, destinationURL):
            let result = try await FileSystemService.moveItem(at: destinationURL, toFolder: sourceURL.deletingLastPathComponent())
            onFileRelocated?(destinationURL, result)
            return result
        case let .createFolder(url), let .createFile(url):
            _ = try await FileSystemService.moveToTrash(url: url)
            return url.deletingLastPathComponent()
        case let .trash(originalURL, trashedURL):
            let result = try await FileSystemService.moveItem(at: trashedURL, toFolder: originalURL.deletingLastPathComponent())
            onFileRelocated?(trashedURL, result)
            return result
        }
    }

    private func executeForwardAction(_ action: UndoActionType) async throws -> URL {
        switch action {
        case let .rename(oldURL, newURL):
            let result = try await FileSystemService.renameItem(at: oldURL, newName: newURL.lastPathComponent)
            onFileRelocated?(oldURL, result)
            return result
        case let .move(sourceURL, destinationURL):
            let result = try await FileSystemService.moveItem(at: sourceURL, toFolder: destinationURL.deletingLastPathComponent())
            onFileRelocated?(sourceURL, result)
            return result
        case let .createFolder(url):
            let folder = url.deletingLastPathComponent()
            let name = url.lastPathComponent
            return try await FileSystemService.createDirectory(at: folder, name: name)
        case .createFile:
            // Unlike .createFolder (an empty folder has no content to lose, so recreating it via
            // createDirectory is always faithful), a file's redo would need its original content —
            // which .createFile never stored (the paste-from-pasteboard-content call site has no
            // source at all to redo from). Throw explicitly instead of silently creating a folder
            // where the file used to be.
            throw WilesError.fileCreationNotRedoable
        case let .trash(originalURL, _):
            // originalURL, not the stale trashedURL: undo() already moved the file back to
            // originalURL, so the old trashedURL path no longer exists on disk by the time
            // redo runs (moveToTrash on it would throw, incorrectly failing every trash redo).
            _ = try await FileSystemService.moveToTrash(url: originalURL)
            return originalURL.deletingLastPathComponent()
        }
    }
}
