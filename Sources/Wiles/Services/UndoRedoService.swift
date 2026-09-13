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

    /// Called when an undo/redo step could NOT put the file back under its intended name because
    /// that name is taken again, so the `.keepBoth` policy landed it on a free one instead (e.g.
    /// undoing a rename of `A`→`B` after a new `A` was created restores the file as `A 2`, not `A`).
    /// The step still "succeeded" and is safe, but the state wasn't fully reverted — `AppState`
    /// surfaces this so the user isn't misled. `intendedName` is what the step
    /// aimed to restore; `actualName` is what it got.
    public var onRestoreDiverged: ((_ intendedName: String, _ actualName: String) -> Void)?

    /// Fires `onRestoreDiverged` when `result`'s name differs from `intendedName`.
    private func noteRestoreDivergence(intendedName: String, result: URL) {
        guard result.lastPathComponent != intendedName else { return }
        onRestoreDiverged?(intendedName, result.lastPathComponent)
    }

    public init() { }

    public func recordAction(_ action: UndoActionType) {
        undoStack.append(UndoRecord(actionType: action))
        if undoStack.count > maxHistoryLimit {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
    }

    /// Records N per-item actions from ONE user operation as a single grouped `.batch` entry (or,
    /// for exactly one, that action verbatim). This is what call sites doing bulk trash / move /
    /// paste / batch-rename must use instead of a `for` loop of `recordAction` — otherwise `⌘Z`
    /// reverts one item at a time and the `maxHistoryLimit` cap silently drops the oldest items of
    /// a >50-item operation with no way to undo them. Empty input is a no-op.
    public func recordActions(_ actions: [UndoActionType]) {
        guard let first = actions.first else { return }
        recordAction(actions.count == 1 ? first : .batch(actions))
    }

    public func canUndo() -> Bool {
        !undoStack.isEmpty
    }

    /// Whether the next `undo()` call would restore a trashed item — lets a caller show a more
    /// specific "Restoring…" progress title instead of the generic "Undoing…" for this one case.
    /// A `.batch` counts if its first action does, since a multi-file "Move to Trash" records one
    /// `.batch` of per-item `.trash` entries.
    public var nextUndoIsTrashRestore: Bool {
        guard var action = undoStack.last?.actionType else { return false }
        while case let .batch(actions) = action, let first = actions.first {
            action = first
        }
        if case .trash = action {
            return true
        }
        return false
    }

    public func canRedo() -> Bool {
        !redoStack.isEmpty
    }

    public func undo() async throws -> URL? {
        guard !isProcessing, let record = undoStack.popLast() else { return nil }
        isProcessing = true
        defer { isProcessing = false }
        if case let .batch(actions) = record.actionType {
            return try await undoBatch(actions)
        }
        do {
            let outcome = try await executeReverseAction(record.actionType)
            if outcome.redoable {
                redoStack.append(UndoRecord(actionType: outcome.resultingAction))
            }
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
        if case let .batch(actions) = record.actionType {
            return try await redoBatch(actions)
        }
        do {
            let outcome = try await executeForwardAction(record.actionType)
            undoStack.append(UndoRecord(actionType: outcome.resultingAction))
            return outcome.url
        } catch {
            redoStack.append(record)
            throw error
        }
    }

    private func wrap(_ actions: [UndoActionType]) -> UndoActionType {
        actions.count == 1 ? actions[0] : .batch(actions)
    }

    /// Reverts a batch last-first, each sub-action independently: whatever reverts goes to the redo
    /// stack (grouped, only when every reverted piece is redoable); whatever fails is re-pushed as a
    /// retryable batch on the undo stack and reported. Returns the first restored URL for selection.
    private func undoBatch(_ actions: [UndoActionType]) async throws -> URL? {
        // Reversing a name rotation is itself a rotation — naive per-item reverse hits `.keepBoth`
        // and strands files on `… 2`. Stage colliding groups through hidden temps, like the forward path.
        if let renamePairs = renamePairsIfAllRenames(actions), renamesFormACollidingPermutation(renamePairs) {
            return try await undoRenamePermutation(renamePairs, originalActions: actions)
        }

        var revertedForward: [UndoActionType] = []
        var failedOriginals: [UndoActionType] = []
        var allRedoable = true
        var firstURL: URL?
        for action in actions.reversed() {
            do {
                let outcome = try await executeReverseAction(action)
                revertedForward.insert(outcome.resultingAction, at: 0)
                allRedoable = allRedoable && outcome.redoable
                firstURL = firstURL ?? outcome.url
            } catch {
                failedOriginals.insert(action, at: 0)
            }
        }
        if !revertedForward.isEmpty, allRedoable {
            redoStack.append(UndoRecord(actionType: wrap(revertedForward)))
        }
        guard failedOriginals.isEmpty else {
            undoStack.append(UndoRecord(actionType: wrap(failedOriginals)))
            throw WilesError.localized(
                key: .undoPartialFailure, arguments: ["\(failedOriginals.count)", "\(actions.count)"])
        }
        return firstURL
    }

    /// `[(oldURL, newURL)]` when every action in the batch is a `.rename`, else `nil` (the cyclic
    /// path only applies to a homogeneous rename batch).
    private func renamePairsIfAllRenames(_ actions: [UndoActionType]) -> [(oldURL: URL, newURL: URL)]? {
        var pairs: [(oldURL: URL, newURL: URL)] = []
        for action in actions {
            guard case let .rename(oldURL, newURL) = action else { return nil }
            pairs.append((oldURL, newURL))
        }
        return pairs
    }

    /// True when reversing the batch would land a file on a name a sibling in the same batch still
    /// holds (the rotation case needing temp staging); a batch with all-free reverse names uses the plain loop.
    private func renamesFormACollidingPermutation(_ pairs: [(oldURL: URL, newURL: URL)]) -> Bool {
        let byDirectory = Dictionary(grouping: pairs) { $0.newURL.deletingLastPathComponent() }
        return byDirectory.values.contains { group in
            let sourceNames = Set(group.map(\.newURL.lastPathComponent))
            let targetNames = Set(group.map(\.oldURL.lastPathComponent))
            return !sourceNames.isDisjoint(with: targetNames)
        }
    }

    /// Reverses a name-permuting batch-rename: stage cyclic groups to hidden temps, then rename each
    /// back to its pre-rename name. On failure, unstage and re-push the batch for retry.
    private func undoRenamePermutation(
        _ pairs: [(oldURL: URL, newURL: URL)], originalActions: [UndoActionType]) async throws -> URL? {
        var revertedForward: [UndoActionType] = []
        var firstURL: URL?
        // Declared outside the `do` (empty until staging succeeds) so the `catch` below can still
        // restore whatever WAS staged if a later rename fails — while also covering a failure in
        // staging itself, which is now inside the same recovery scope (DEV_RULES.md R6): a
        // staging failure used to escape this `do`/`catch` entirely, silently dropping
        // `originalActions` instead of re-pushing it for retry like every other failure path here does.
        var staged: [URL: URL] = [:]
        do {
            staged = try await BatchRenameService.stagePermutationCycles(
                pairs: pairs.map { (url: $0.newURL, newName: $0.oldURL.lastPathComponent) })
            for pair in pairs.reversed() {
                let currentURL = staged[pair.newURL] ?? pair.newURL
                let result = try await FileSystemService.renameItem(
                    at: currentURL, newName: pair.oldURL.lastPathComponent, onCollision: .keepBoth)
                onFileRelocated?(pair.newURL, result)
                noteRestoreDivergence(intendedName: pair.oldURL.lastPathComponent, result: result)
                revertedForward.insert(.rename(oldURL: result, newURL: pair.newURL), at: 0)
                firstURL = firstURL ?? result
            }
        } catch {
            // A no-op when staging itself is what failed (`staged` is still empty — and
            // `stagePermutationCycles` already rolled back its own partial staging internally).
            await BatchRenameService.restoreStaged(staged)
            undoStack.append(UndoRecord(actionType: wrap(originalActions)))
            throw error
        }
        redoStack.append(UndoRecord(actionType: wrap(revertedForward)))
        return firstURL
    }

    /// Forward-direction mirror of `renamesFormACollidingPermutation` — redo of a reversed rotation
    /// also has to stage through temps.
    private func redoRenamesFormACollidingPermutation(_ pairs: [(oldURL: URL, newURL: URL)]) -> Bool {
        let byDirectory = Dictionary(grouping: pairs) { $0.oldURL.deletingLastPathComponent() }
        return byDirectory.values.contains { group in
            let sourceNames = Set(group.map(\.oldURL.lastPathComponent))
            let targetNames = Set(group.map(\.newURL.lastPathComponent))
            return !sourceNames.isDisjoint(with: targetNames)
        }
    }

    /// Re-applies a batch-rename that permuted names, staging the cyclic groups to hidden temps
    /// first — the forward-direction mirror of `undoRenamePermutation`.
    private func redoRenamePermutation(
        _ pairs: [(oldURL: URL, newURL: URL)], originalActions: [UndoActionType]) async throws -> URL? {
        var reappliedReverse: [UndoActionType] = []
        var firstURL: URL?
        // See `undoRenamePermutation`'s matching comment (DEV_RULES.md R6): staging must be
        // inside this recovery scope too, not before it.
        var staged: [URL: URL] = [:]
        do {
            staged = try await BatchRenameService.stagePermutationCycles(
                pairs: pairs.map { (url: $0.oldURL, newName: $0.newURL.lastPathComponent) })
            for pair in pairs {
                let currentURL = staged[pair.oldURL] ?? pair.oldURL
                let result = try await FileSystemService.renameItem(
                    at: currentURL, newName: pair.newURL.lastPathComponent, onCollision: .keepBoth)
                onFileRelocated?(pair.oldURL, result)
                noteRestoreDivergence(intendedName: pair.newURL.lastPathComponent, result: result)
                reappliedReverse.append(.rename(oldURL: pair.oldURL, newURL: result))
                firstURL = firstURL ?? result
            }
        } catch {
            await BatchRenameService.restoreStaged(staged)
            redoStack.append(UndoRecord(actionType: wrap(originalActions)))
            throw error
        }
        undoStack.append(UndoRecord(actionType: wrap(reappliedReverse)))
        return firstURL
    }

    /// Mirror of `undoBatch` for `⌘⇧Z`: re-applies a batch first-last.
    private func redoBatch(_ actions: [UndoActionType]) async throws -> URL? {
        if let renamePairs = renamePairsIfAllRenames(actions), redoRenamesFormACollidingPermutation(renamePairs) {
            return try await redoRenamePermutation(renamePairs, originalActions: actions)
        }

        var reappliedReverse: [UndoActionType] = []
        var failedOriginals: [UndoActionType] = []
        var firstURL: URL?
        for action in actions {
            do {
                let outcome = try await executeForwardAction(action)
                reappliedReverse.append(outcome.resultingAction)
                firstURL = firstURL ?? outcome.url
            } catch {
                failedOriginals.append(action)
            }
        }
        if !reappliedReverse.isEmpty {
            undoStack.append(UndoRecord(actionType: wrap(reappliedReverse)))
        }
        guard failedOriginals.isEmpty else {
            redoStack.append(UndoRecord(actionType: wrap(failedOriginals)))
            throw WilesError.localized(
                key: .undoPartialFailure, arguments: ["\(failedOriginals.count)", "\(actions.count)"])
        }
        return firstURL
    }

    /// `url` is where the file ended up; `resultingAction` is the action to push onto the opposite
    /// stack — rewritten to point at that URL when `.keepBoth` had to land the item on a free name,
    /// so a later redo/undo acts on the file's real location instead of a stale path.
    ///
    /// A false `redoable` means "push nothing onto the redo stack" (⌘⇧Z is a silent no-op). Used for
    /// the reverse of `.createFile`, and of a `.createFolder` non-empty at undo time.
    private struct ActionOutcome {
        let url: URL
        let resultingAction: UndoActionType
        var redoable = true
    }

    private func executeReverseAction(_ action: UndoActionType) async throws -> ActionOutcome {
        switch action {
        case let .rename(oldURL, newURL):
            let result = try await FileSystemService.renameItem(
                at: newURL, newName: oldURL.lastPathComponent, onCollision: .keepBoth)
            onFileRelocated?(newURL, result)
            noteRestoreDivergence(intendedName: oldURL.lastPathComponent, result: result)
            return ActionOutcome(url: result, resultingAction: .rename(oldURL: result, newURL: newURL))
        case let .move(sourceURL, destinationURL):
            let result = try await FileSystemService.moveItem(
                at: destinationURL, toFolder: sourceURL.deletingLastPathComponent(), onCollision: .keepBoth)
            onFileRelocated?(destinationURL, result)
            noteRestoreDivergence(intendedName: sourceURL.lastPathComponent, result: result)
            return ActionOutcome(
                url: result, resultingAction: .move(sourceURL: result, destinationURL: destinationURL))
        case let .createFolder(url):
            // If the folder gained contents after creation, redoing it would recreate an empty shell
            // while those contents sit in the Trash — so non-empty → no redo entry. Off-main:
            // `url` can be on a stalled /Volumes/ mount, and this class is @MainActor.
            let folderWasEmpty = await Task.detached(priority: .userInitiated) {
                ((try? FileManager.default.contentsOfDirectory(
                    at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]))?.isEmpty) ?? true
            }.value
            _ = try await FileSystemService.moveToTrash(url: url)
            return ActionOutcome(
                url: url.deletingLastPathComponent(), resultingAction: action, redoable: folderWasEmpty)
        case let .createFile(url):
            _ = try await FileSystemService.moveToTrash(url: url)
            // No redo entry: a created file's content was never captured, so it can't be redone —
            // ⌘⇧Z should quietly do nothing rather than raise `fileCreationNotRedoable`.
            return ActionOutcome(url: url.deletingLastPathComponent(), resultingAction: action, redoable: false)
        case let .trash(originalURL, trashedURL):
            let result = try await FileSystemService.restoreFromTrash(trashedURL: trashedURL, to: originalURL)
            onFileRelocated?(trashedURL, result)
            noteRestoreDivergence(intendedName: originalURL.lastPathComponent, result: result)
            return ActionOutcome(
                url: result, resultingAction: .trash(originalURL: result, trashedURL: trashedURL))
        case let .chmod(url, previous):
            return try await applyChmod(url: url, permissions: previous)
        case let .batch(actions):
            return try await reverseNestedBatch(actions)
        }
    }

    /// Top-level `.batch` records are handled by `undoBatch` (which owns partial-failure recovery);
    /// this covers only the defensive nested case — revert last-first, all-or-throw.
    private func reverseNestedBatch(_ actions: [UndoActionType]) async throws -> ActionOutcome {
        var reverted: [UndoActionType] = []
        var redoable = true
        var url: URL?
        for action in actions.reversed() {
            let outcome = try await executeReverseAction(action)
            reverted.insert(outcome.resultingAction, at: 0)
            redoable = redoable && outcome.redoable
            url = url ?? outcome.url
        }
        return ActionOutcome(
            url: url ?? URL(fileURLWithPath: "/"), resultingAction: wrap(reverted), redoable: redoable)
    }

    /// Mirror of `reverseNestedBatch` for the defensive nested redo case.
    private func forwardNestedBatch(_ actions: [UndoActionType]) async throws -> ActionOutcome {
        var reapplied: [UndoActionType] = []
        var url: URL?
        for action in actions {
            let outcome = try await executeForwardAction(action)
            reapplied.append(outcome.resultingAction)
            url = url ?? outcome.url
        }
        return ActionOutcome(url: url ?? URL(fileURLWithPath: "/"), resultingAction: wrap(reapplied))
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
            noteRestoreDivergence(intendedName: newURL.lastPathComponent, result: result)
            return ActionOutcome(url: result, resultingAction: .rename(oldURL: oldURL, newURL: result))
        case let .move(sourceURL, destinationURL):
            let result = try await FileSystemService.moveItem(
                at: sourceURL, toFolder: destinationURL.deletingLastPathComponent(), onCollision: .keepBoth)
            onFileRelocated?(sourceURL, result)
            noteRestoreDivergence(intendedName: destinationURL.lastPathComponent, result: result)
            return ActionOutcome(
                url: result, resultingAction: .move(sourceURL: sourceURL, destinationURL: result))
        case let .createFolder(url):
            // Only reached when the reverse marked this redoable, i.e. the folder was empty at undo
            // time, so recreating the empty folder here loses nothing.
            let folder = url.deletingLastPathComponent()
            let name = url.lastPathComponent
            let result = try await FileSystemService.createDirectory(at: folder, name: name)
            return ActionOutcome(url: result, resultingAction: action)
        case .createFile:
            // Unlike a redoable .createFolder (empty at undo time, so recreating it via
            // createDirectory loses nothing), a file's redo would need its original content —
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
        case let .batch(actions):
            return try await forwardNestedBatch(actions)
        }
    }
}
