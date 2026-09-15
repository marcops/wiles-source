import AppKit
import GitBeacon
import SwiftUI

public extension AppState {
    @discardableResult
    func pasteToCurrentDirectory(windowUIState: WindowUIState) -> Task<Void, Never> {
        HapticService.shared.play(.generic)
        guard let clip = transient.clipboard, !clip.urls.isEmpty else {
            if let urls = PasteboardService.readFromPasteboard(), !urls.isEmpty {
                return executePaste(urls: urls, isCut: false, windowUIState: windowUIState)
            }
            return pasteClipboardContentAsFile()
        }
        // `transient.clipboard` is NOT cleared here — a 100%-failed cut-paste would lose the pending
        // cut with nothing moved. `executePaste` clears it once at least one item has actually moved.
        return executePaste(urls: clip.urls, isCut: clip.action == .cut, windowUIState: windowUIState)
    }

    /// Reached only once both the internal clipboard and the system pasteboard have no files on
    /// them — the last remaining case is pasteboard content with no file behind it at all (a
    /// copied screenshot, a copied text selection), which `createFileFromPasteboardContent`
    /// materializes as a new file instead of silently doing nothing.
    @discardableResult
    private func pasteClipboardContentAsFile() -> Task<Void, Never> {
        let folder = navigation.currentURL
        return runDetachedFileOperation(
            context: "Creating file from pasteboard content",
            refreshOnSuccess: false,
            onSuccess: { [weak self] (createdURL: URL?) in
                guard let self, let createdURL else { return }
                undoRedoService.recordAction(.createFile(url: createdURL))
                invalidateCurrentDirectoryCacheAndRefresh()
                selection.selectedURLs = [createdURL]
            },
            operation: { try PasteboardService.createFileFromPasteboardContent(in: folder) })
    }

    /// Bundles `pasteAllItems`'s fixed-per-call context so the function itself stays under the
    /// 5-parameter lint limit — only `urls` (what varies per loop iteration) is passed alongside it.
    private struct PasteContext {
        let targetFolder: URL
        let isCut: Bool
        let undoRedoService: UndoRedoService
        let taskID: UUID
        let backgroundOperations: BackgroundOperationsService
        weak var owner: AppState?
        weak var windowUIState: WindowUIState?
    }

    /// Runs on `@MainActor` — the orchestration loop itself is light. The heavy, potentially
    /// slow-mount disk work is delegated to `FileSystemService.moveItem`/`copyItem`, each of which
    /// detaches its own copy/delete off the main actor.
    @discardableResult
    private func executePaste(urls: [URL], isCut: Bool, windowUIState: WindowUIState) -> Task<Void, Never> {
        let targetFolder = navigation.currentURL
        let undoRedoService = undoRedoService
        let titleKey = tr(.pastingItemsEllipsis)
        let backgroundOperations = backgroundOperations
        let taskID = backgroundOperations.addTask(title: titleKey, totalUnits: Int64(urls.count))
        let pasteTask = Task(priority: .userInitiated) { @MainActor [weak self] in
            let context = PasteContext(
                targetFolder: targetFolder, isCut: isCut, undoRedoService: undoRedoService,
                taskID: taskID, backgroundOperations: backgroundOperations, owner: self, windowUIState: windowUIState)
            let (failureCount, movedDestinations) = await Self.pasteAllItems(urls: urls, context: context)
            backgroundOperations.completeTask(id: taskID)
            guard let self else { return }
            if isCut, !movedDestinations.isEmpty {
                selection.selectedURLs = Set(movedDestinations)
                // Clear the pending cut only now that something actually moved (full or partial
                // success) — a 100%-failed / fully-cancelled cut-paste keeps it for retry.
                transient.clipboard = nil
            }
            if failureCount > 0 {
                showPartialFailure(.pastePartialFailure, failed: failureCount, total: urls.count)
            }
            invalidateCurrentDirectoryCacheAndRefresh()
        }
        backgroundOperations.registerCancellation(id: taskID) { pasteTask.cancel() }
        return pasteTask
    }

    /// Extracted out of `executePaste` so that closure stays short. A cut paste reuses
    /// `moveBatchResolvingCollisions` — the exact same collision-resolving loop the drag-onto-folder
    /// path uses — recording a `.move` undo per item; a copy paste finds a free name per item and
    /// records `.createFile`. Heavy I/O is detached inside `FileSystemService`.
    private static func pasteAllItems(urls: [URL], context: PasteContext) async -> (failureCount: Int, movedDestinations: [URL]) {
        guard context.isCut else { return await copyAllItems(urls: urls, context: context) }
        guard let owner = context.owner else { return (0, []) }
        var undoActions: [UndoActionType] = []
        let (moved, failureCount) = await owner.moveBatchResolvingCollisions(
            urls, into: context.targetFolder, windowUIState: context.windowUIState,
            onMoved: { source, dest, _, displacedTrashedURL in
                if let owner = context.owner {
                    undoActions.append(contentsOf: owner.resolvedMoveUndoActions(source: source, dest: dest, displacedTrashedURL: displacedTrashedURL))
                }
            },
            progress: { completed in
                if shouldReportProgress(index: completed - 1, count: urls.count) {
                    context.backgroundOperations.updateProgress(id: context.taskID, unitsDone: Int64(completed))
                }
            })
        // One grouped undo entry for the whole cut/paste, not one per item.
        context.owner?.undoRedoService.recordActions(undoActions)
        return (failureCount, moved)
    }

    private static func copyAllItems(urls: [URL], context: PasteContext) async -> (failureCount: Int, movedDestinations: [URL]) {
        var failureCount = 0
        var undoActions: [UndoActionType] = []
        for (index, url) in urls.enumerated() {
            guard !Task.isCancelled else { break }
            do {
                let destURL = try await FileSystemService.copyItem(at: url, toFolder: context.targetFolder)
                undoActions.append(.createFile(url: destURL))
            } catch {
                ErrorReporter.report(error, context: "Pasting items to current directory")
                failureCount += 1
            }
            if shouldReportProgress(index: index, count: urls.count) {
                context.backgroundOperations.updateProgress(id: context.taskID, unitsDone: Int64(index + 1))
            }
        }
        // One grouped undo entry for the whole paste, not one per file.
        context.undoRedoService.recordActions(undoActions)
        return (failureCount, [])
    }
}
