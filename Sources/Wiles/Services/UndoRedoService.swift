import Foundation

/// Owned per-window (one instance per `AppState`), not a shared singleton — a `.shared` undo/redo
/// stack let ⌘Z in one window undo an action performed in a different window.
@MainActor
public final class UndoRedoService {
    private var undoStack: [UndoRecord] = []
    private var redoStack: [UndoRecord] = []
    private let maxHistoryLimit = 50
    /// One step at a time: a second ⌘Z while the first is mid-`await` would pop the next record and
    /// run both reverse actions interleaved against a half-changed disk.
    private var isProcessing = false

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
        guard !isProcessing, let record = undoStack.popLast() else { return nil }
        isProcessing = true
        defer { isProcessing = false }
        do {
            let outcome = try await executeReverseAction(record.actionType)
            redoStack.append(UndoRecord(actionType: outcome.resultingAction))
            return outcome.url
        } catch {
            // Action wasn't actually undone: put the record back so it remains available
            // to retry, instead of silently promoting it to a bogus redo entry.
            undoStack.append(record)
            throw error
        }
    }

    public func redo() async throws -> URL? {
        guard !isProcessing, let record = redoStack.popLast() else { return nil }
        isProcessing = true
        defer { isProcessing = false }
        do {
            let outcome = try await executeForwardAction(record.actionType)
            undoStack.append(UndoRecord(actionType: outcome.resultingAction))
            return outcome.url
        } catch {
            redoStack.append(record)
            throw error
        }
    }

    /// `url` is where the file ended up; `resultingAction` is the action to push onto the opposite
    /// stack — rewritten to point at that URL when `.keepBoth` had to land the item on a free name,
    /// so a later redo/undo acts on the file's real location instead of a stale path.
    private struct ActionOutcome {
        let url: URL
        let resultingAction: UndoActionType
    }

    private func executeReverseAction(_ action: UndoActionType) async throws -> ActionOutcome {
        switch action {
        case let .rename(oldURL, newURL):
            let result = try await FileSystemService.renameItem(
                at: newURL, newName: oldURL.lastPathComponent, onCollision: .keepBoth)
            onFileRelocated?(newURL, result)
            return ActionOutcome(url: result, resultingAction: .rename(oldURL: result, newURL: newURL))
        case let .move(sourceURL, destinationURL):
            let result = try await FileSystemService.moveItem(
                at: destinationURL, toFolder: sourceURL.deletingLastPathComponent(), onCollision: .keepBoth)
            onFileRelocated?(destinationURL, result)
            return ActionOutcome(
                url: result, resultingAction: .move(sourceURL: result, destinationURL: destinationURL))
        case let .createFolder(url), let .createFile(url):
            _ = try await FileSystemService.moveToTrash(url: url)
            return ActionOutcome(url: url.deletingLastPathComponent(), resultingAction: action)
        case let .trash(originalURL, trashedURL):
            let result = try await FileSystemService.moveItem(
                at: trashedURL, toFolder: originalURL.deletingLastPathComponent(), onCollision: .keepBoth)
            onFileRelocated?(trashedURL, result)
            return ActionOutcome(
                url: result, resultingAction: .trash(originalURL: result, trashedURL: trashedURL))
        case let .chmod(url, previous):
            return try await applyChmod(url: url, permissions: previous)
        }
    }

    /// Sets `url`'s POSIX permissions to `permissions`, off the main actor, and returns the
    /// opposite-stack action carrying whatever they were just before.
    private func applyChmod(url: URL, permissions: POSIXPermissions) async throws -> ActionOutcome {
        let priorPermissions = try await Task.detached(priority: .userInitiated) { () -> POSIXPermissions in
            let prior = FilePermissionsService.getPermissions(for: url) ?? permissions
            try FilePermissionsService.setPermissions(for: url, permissions: permissions)
            return prior
        }.value
        return ActionOutcome(url: url, resultingAction: .chmod(url: url, previous: priorPermissions))
    }

    private func executeForwardAction(_ action: UndoActionType) async throws -> ActionOutcome {
        switch action {
        case let .rename(oldURL, newURL):
            let result = try await FileSystemService.renameItem(
                at: oldURL, newName: newURL.lastPathComponent, onCollision: .keepBoth)
            onFileRelocated?(oldURL, result)
            return ActionOutcome(url: result, resultingAction: .rename(oldURL: oldURL, newURL: result))
        case let .move(sourceURL, destinationURL):
            let result = try await FileSystemService.moveItem(
                at: sourceURL, toFolder: destinationURL.deletingLastPathComponent(), onCollision: .keepBoth)
            onFileRelocated?(sourceURL, result)
            return ActionOutcome(
                url: result, resultingAction: .move(sourceURL: sourceURL, destinationURL: result))
        case let .createFolder(url):
            let folder = url.deletingLastPathComponent()
            let name = url.lastPathComponent
            let result = try await FileSystemService.createDirectory(at: folder, name: name)
            return ActionOutcome(url: result, resultingAction: action)
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
            let trashed = try await FileSystemService.moveToTrash(url: originalURL)
            return ActionOutcome(
                url: originalURL.deletingLastPathComponent(),
                resultingAction: .trash(originalURL: originalURL, trashedURL: trashed))
        case let .chmod(url, previous):
            return try await applyChmod(url: url, permissions: previous)
        }
    }
}
