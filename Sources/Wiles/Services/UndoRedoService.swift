import Foundation

@MainActor
public final class UndoRedoService {
    public static let shared = UndoRedoService()

    private var undoStack: [UndoRecord] = []
    private var redoStack: [UndoRecord] = []
    private let maxHistoryLimit = 50

    private init() {}

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
        case .rename(let oldURL, let newURL):
            return try FileSystemService.renameItem(at: newURL, newName: oldURL.lastPathComponent)
        case .move(let sourceURL, let destinationURL):
            return try FileSystemService.moveItem(at: destinationURL, toFolder: sourceURL.deletingLastPathComponent())
        case .create(let url):
            _ = try FileSystemService.moveToTrash(url: url)
            return url.deletingLastPathComponent()
        case .trash(let originalURL, let trashedURL):
            return try FileSystemService.moveItem(at: trashedURL, toFolder: originalURL.deletingLastPathComponent())
        }
    }

    private func executeForwardAction(_ action: UndoActionType) async throws -> URL {
        switch action {
        case .rename(let oldURL, let newURL):
            return try FileSystemService.renameItem(at: oldURL, newName: newURL.lastPathComponent)
        case .move(let sourceURL, let destinationURL):
            return try FileSystemService.moveItem(at: sourceURL, toFolder: destinationURL.deletingLastPathComponent())
        case .create(let url):
            let folder = url.deletingLastPathComponent()
            let name = url.lastPathComponent
            return try FileSystemService.createDirectory(at: folder, name: name)
        case .trash(let originalURL, _):
            // originalURL, not the stale trashedURL: undo() already moved the file back to
            // originalURL, so the old trashedURL path no longer exists on disk by the time
            // redo runs (moveToTrash on it would throw, incorrectly failing every trash redo).
            _ = try FileSystemService.moveToTrash(url: originalURL)
            return originalURL.deletingLastPathComponent()
        }
    }
}
