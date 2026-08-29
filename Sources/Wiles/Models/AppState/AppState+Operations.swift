import AppKit
import GitBeacon
import SwiftUI

public extension AppState {
    func handleDrop(providers: [NSItemProvider], targetFolder: URL, windowUIState: WindowUIState) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            var urls: [URL] = []
            for provider in providers {
                if let url = await Self.loadDroppedURL(from: provider) {
                    urls.append(url)
                }
            }
            // Comparing the `URL` values themselves (even standardized) isn't reliable here: a URL
            // round-tripped through `NSItemProvider` can gain a directory trailing slash that a URL
            // built locally never gets. `.path` (after resolving symlinks, e.g. ~/Desktop under
            // iCloud Desktop & Documents sync) has no such ambiguity — so "drop a folder onto
            // itself" is caught reliably.
            let targetPath = targetFolder.resolvingSymlinksInPath().standardizedFileURL.path
            let movable = urls.filter { $0.resolvingSymlinksInPath().standardizedFileURL.path != targetPath }
            guard !movable.isEmpty else { return }
            _ = await moveItemsResolvingCollisions(movable, toFolder: targetFolder, windowUIState: windowUIState)
            refreshCurrentDirectory()
        }
    }

    private static func loadDroppedURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                continuation.resume(returning: url)
            }
        }
    }

    func downloadFromiCloud(url: URL) {
        runDetachedFileOperation(context: "Downloading item from iCloud") {
            try FileManager.default.startDownloadingUbiquitousItem(at: url)
        }
    }

    func cutSelected() {
        guard !selection.selectedURLs.isEmpty else { return }
        transient.clipboard = ClipboardState(urls: Array(selection.selectedURLs), action: .cut)
    }

    func copySelected() {
        guard !selection.selectedURLs.isEmpty else { return }
        let urls = Array(selection.selectedURLs)
        transient.clipboard = ClipboardState(urls: urls, action: .copy)
        PasteboardService.writeToPasteboard(urls: urls)
    }

    func pasteToCurrentDirectory(windowUIState: WindowUIState) {
        HapticService.shared.play(.generic)
        guard let clip = transient.clipboard, !clip.urls.isEmpty else {
            if let urls = PasteboardService.readFromPasteboard(), !urls.isEmpty {
                executePaste(urls: urls, isCut: false, windowUIState: windowUIState)
            } else {
                pasteClipboardContentAsFile()
            }
            return
        }
        executePaste(urls: clip.urls, isCut: clip.action == .cut, windowUIState: windowUIState)
        if clip.action == .cut {
            transient.clipboard = nil
        }
    }

    /// Reached only once both the internal clipboard and the system pasteboard have no files on
    /// them — the last remaining case is pasteboard content with no file behind it at all (a
    /// copied screenshot, a copied text selection), which `createFileFromPasteboardContent`
    /// materializes as a new file instead of silently doing nothing.
    private func pasteClipboardContentAsFile() {
        do {
            guard let createdURL = try PasteboardService.createFileFromPasteboardContent(in: navigation.currentURL) else { return }
            undoRedoService.recordAction(.createFile(url: createdURL))
            refreshCurrentDirectory()
            selection.selectedURLs = [createdURL]
        } catch {
            showError(error, context: "Creating file from pasteboard content")
        }
    }

    /// Bundles `pasteAllItems`'s fixed-per-call context so the function itself stays under the
    /// 5-parameter lint limit — only `urls` (what varies per loop iteration) is passed alongside it.
    private struct PasteContext {
        let targetFolder: URL
        let isCut: Bool
        let undoRedoService: UndoRedoService
        let taskID: UUID
        weak var owner: AppState?
        weak var windowUIState: WindowUIState?
    }

    /// Runs on `@MainActor` — the orchestration loop itself is light. The heavy, potentially
    /// slow-mount disk work is delegated to `FileSystemService.moveItem`/`copyItem`, each of which
    /// detaches its own copy/delete off the main actor.
    private func executePaste(urls: [URL], isCut: Bool, windowUIState: WindowUIState) {
        let targetFolder = navigation.currentURL
        let undoRedoService = undoRedoService
        let titleKey = tr(.pastingItemsEllipsis)
        let taskID = BackgroundOperationsService.shared.addTask(title: titleKey, totalBytes: Int64(urls.count))
        let pasteTask = Task(priority: .userInitiated) { @MainActor [weak self] in
            let context = PasteContext(
                targetFolder: targetFolder, isCut: isCut, undoRedoService: undoRedoService,
                taskID: taskID, owner: self, windowUIState: windowUIState)
            let (failureCount, movedDestinations) = await Self.pasteAllItems(urls: urls, context: context)
            BackgroundOperationsService.shared.completeTask(id: taskID)
            guard let self else { return }
            if isCut, !movedDestinations.isEmpty {
                selection.selectedURLs = Set(movedDestinations)
            }
            if failureCount > 0 {
                showError(WilesError.operationFailed(
                    reason: "\(failureCount) of \(urls.count) items could not be pasted."))
            }
            refreshCurrentDirectory()
        }
        BackgroundOperationsService.shared.registerCancellation(id: taskID) { pasteTask.cancel() }
    }

    private enum CutPasteOutcome {
        case moved(URL)
        case skipped
        /// The user picked Cancel (or a sticky "apply to all → Cancel") — stop the whole paste.
        case cancelled
    }

    /// Extracted out of `executePaste` so that closure stays short — pastes every item sequentially
    /// and reports per-item progress as it goes. The per-file heavy I/O is delegated to
    /// `FileSystemService.moveItem`/`copyItem`, which each detach their own off-actor copy/delete.
    private static func pasteAllItems(urls: [URL], context: PasteContext) async -> (failureCount: Int, movedDestinations: [URL]) {
        var failureCount = 0
        var movedDestinations: [URL] = []
        var sticky: MoveCollisionChoice.Action?
        for (index, url) in urls.enumerated() {
            guard !Task.isCancelled else { break }
            do {
                if context.isCut {
                    let (outcome, newSticky) = try await moveCutPasteItem(url: url, index: index, total: urls.count, context: context, sticky: sticky)
                    sticky = newSticky
                    switch outcome {
                    case let .moved(destURL): movedDestinations.append(destURL)
                    case .skipped: break
                    case .cancelled: return (failureCount, movedDestinations)
                    }
                } else {
                    let destURL = try await FileSystemService.copyItem(at: url, toFolder: context.targetFolder)
                    context.undoRedoService.recordAction(.createFile(url: destURL))
                }
            } catch {
                ErrorReporter.report(error, context: "Pasting items to current directory")
                failureCount += 1
            }
            BackgroundOperationsService.shared.updateProgress(id: context.taskID, bytesTransferred: Int64(index + 1))
        }
        return (failureCount, movedDestinations)
    }

    /// Moves one cut item into the paste target, resolving a name collision via the per-window
    /// prompt (Replace / Keep Both / Cancel, "apply to all"). A `.replace` iteration does **not**
    /// record an undo action — the displaced file only lives in Trash. Returns the (possibly
    /// updated) sticky choice for the rest of the batch.
    private static func moveCutPasteItem(
        url: URL,
        index: Int,
        total: Int,
        context: PasteContext,
        sticky: MoveCollisionChoice.Action?) async throws -> (CutPasteOutcome, MoveCollisionChoice.Action?) {
        do {
            let destURL = try await FileSystemService.moveItem(at: url, toFolder: context.targetFolder)
            context.undoRedoService.recordAction(.move(sourceURL: url, destinationURL: destURL))
            context.owner?.remapFavorites(from: url, to: destURL)
            return (.moved(destURL), sticky)
        } catch WilesError.destinationExists {
            guard let owner = context.owner, let windowUIState = context.windowUIState else {
                return (.skipped, sticky)
            }
            let resolution = await owner.resolveCollision(
                itemName: url.lastPathComponent,
                moreCollisionsPossible: index < total - 1,
                sticky: sticky,
                windowUIState: windowUIState)
            if resolution.action == .cancel {
                return (.cancelled, resolution.sticky)
            }
            let policy: MoveCollisionPolicy = resolution.action == .replace ? .replace : .keepBoth
            let destURL = try await FileSystemService.moveItem(at: url, toFolder: context.targetFolder, onCollision: policy)
            if resolution.action == .keepBoth {
                context.undoRedoService.recordAction(.move(sourceURL: url, destinationURL: destURL))
            }
            context.owner?.remapFavorites(from: url, to: destURL)
            return (.moved(destURL), resolution.sticky)
        }
    }

    func deleteSelected(windowUIState: WindowUIState) {
        guard !selection.selectedURLs.isEmpty else { return }
        if preferences.skipDeleteConfirmation {
            performDeleteSelected()
        } else {
            windowUIState.showDeleteConfirmAlert = true
        }
    }

    func performDeleteSelected() {
        guard !selection.selectedURLs.isEmpty else { return }
        HapticService.shared.play(.levelChange)
        let urls = Array(selection.selectedURLs)
        let undoRedoService = undoRedoService
        let titleKey = tr(.movingToTrashEllipsis)
        let taskID = BackgroundOperationsService.shared.addTask(title: titleKey, totalBytes: Int64(urls.count))
        let deleteTask = Task.detached(priority: .userInitiated) {
            var failureCount = 0
            for (index, url) in urls.enumerated() {
                guard !Task.isCancelled else { break }
                do {
                    let trashed = try await FileSystemService.moveToTrash(url: url)
                    await undoRedoService.recordAction(.trash(originalURL: url, trashedURL: trashed))
                } catch {
                    ErrorReporter.report(error, context: "Moving item to Trash")
                    failureCount += 1
                }
                await MainActor.run { BackgroundOperationsService.shared.updateProgress(id: taskID, bytesTransferred: Int64(index + 1)) }
            }
            await MainActor.run { [weak self] in
                BackgroundOperationsService.shared.completeTask(id: taskID)
                guard let self else { return }
                selection.selectedURLs.removeAll()
                if failureCount > 0 {
                    showError(String(format: tr(.moveToTrashPartialFailure), failureCount, urls.count))
                }
                refreshCurrentDirectory()
            }
        }
        BackgroundOperationsService.shared.registerCancellation(id: taskID) { deleteTask.cancel() }
    }

    func deletePermanentlySelected(windowUIState: WindowUIState) {
        guard !selection.selectedURLs.isEmpty else { return }
        if preferences.skipDeleteConfirmation {
            performDeletePermanentlySelected()
        } else {
            windowUIState.showDeletePermanentlyConfirmAlert = true
        }
    }

    func performDeletePermanentlySelected() {
        guard !selection.selectedURLs.isEmpty else { return }
        HapticService.shared.play(.levelChange)
        let urls = Array(selection.selectedURLs)
        runDetachedFileOperation(context: "Deleting item permanently", onSuccess: { [weak self] in
            self?.selection.selectedURLs.removeAll()
        }, operation: {
            try FileShredderService.deletePermanently(urls: urls)
        })
    }

    func copyContentOfSelected() {
        guard let firstURL = primarySelectedURL else { return }
        Task {
            do {
                try await PasteboardService.copyFileContentToClipboard(url: firstURL)
            } catch {
                showError(error, context: "Copying file content to clipboard")
            }
        }
    }

    func undoLastAction() {
        Task {
            do {
                if let targetURL = try await self.undoRedoService.undo() {
                    self.refreshCurrentDirectory()
                    self.selection.selectedURLs = [targetURL]
                }
            } catch {
                self.showError(error, context: "Undoing last action")
            }
        }
    }

    func redoLastAction() {
        Task {
            do {
                if let targetURL = try await self.undoRedoService.redo() {
                    self.refreshCurrentDirectory()
                    self.selection.selectedURLs = [targetURL]
                }
            } catch {
                self.showError(error, context: "Redoing last action")
            }
        }
    }

    func selectAllItems() {
        selection.selectedURLs = Set(fileSystem.items.map(\.url))
    }

    func openSelectedItem() {
        if let first = primarySelectedURL {
            openItem(first)
        }
    }

    func triggerQuickLookForSelected(windowUIState: WindowUIState) {
        if let first = primarySelectedURL {
            windowUIState.quickLookURL = first
        }
    }

    func openPropertiesForSelected(windowUIState: WindowUIState) {
        if let first = primarySelectedURL, let item = fileSystem.items.first(where: { $0.url == first }) {
            windowUIState.propertiesItem = item
        }
    }

    func startEditingPath(windowUIState: WindowUIState) {
        navigation.pathText = navigation.currentURL.path
        windowUIState.isEditingPath = true
    }

    func createNewFolderAndRename(in folder: URL? = nil, windowUIState: WindowUIState) {
        let targetFolder = folder ?? navigation.currentURL
        Task {
            do {
                let createdURL = try await FileSystemService.createUniqueDirectory(
                    at: targetFolder, baseName: tr(.defaultFolderName))
                enterRenameForNewlyCreated(at: createdURL, inFolder: targetFolder, windowUIState: windowUIState)
            } catch {
                showError(error, context: "Creating new folder")
            }
        }
    }

    func createNewFileAndRename(in folder: URL? = nil, windowUIState: WindowUIState) {
        let targetFolder = folder ?? navigation.currentURL
        do {
            let createdURL = try NewFileTemplateService.createTemplateFile(
                in: targetFolder, fileName: "", template: .text, language: preferences.appLanguage)
            enterRenameForNewlyCreated(at: createdURL, inFolder: targetFolder, windowUIState: windowUIState)
        } catch {
            showError(error, context: "Creating new file")
        }
    }

    /// `folder` may differ from `navigation.currentURL` — only touch `fileSystem.items` when
    /// they're the same folder.
    private func enterRenameForNewlyCreated(at url: URL, inFolder: URL, windowUIState: WindowUIState) {
        // Built on @MainActor for a freshly-created local file; the rename row doesn't show
        // Owner/Group, so skip that extra stat/getpwuid syscall path (M3).
        let newItem = FileItem.load(url: url, needsOwnerGroup: false)
        fileSystem.renamingURL = url
        selection.selectedURLs = [url]
        windowUIState.renameItem = newItem
        windowUIState.onRenameCleared = { [weak self] in self?.fileSystem.renamingURL = nil }
        guard inFolder.standardizedFileURL == navigation.currentURL.standardizedFileURL else { return }
        DirectoryCacheService.shared.invalidate(url: navigation.currentURL)
        // Place it where the current sort puts it, not at the top — otherwise it visibly jumps
        // when the follow-up refresh reorders the list.
        fileSystem.items = FileSystemService.sortItems(
            fileSystem.items + [newItem], by: preferences.sortOption, ascending: preferences.sortAscending)
    }

    /// Shared shape for a whole-selection file operation: run `operation` off the main actor, then
    /// re-enter the main actor exactly once — either to run `onSuccess` and refresh (operation
    /// succeeded), or to report and surface the error (operation threw). `operation` may be
    /// synchronous or asynchronous throwing work; either coerces fine to the `async throws`
    /// closure type. Not a fit for operations that need to keep going after a per-item failure
    /// (e.g. a loop that reports one error per failed URL but still processes the rest) — those
    /// stay bespoke.
    /// `taskTitle`, when supplied, publishes a `BackgroundOperationsService` entry for the
    /// operation's duration (an all-or-nothing 0→1 progress bar, since these operations don't
    /// report incremental progress internally) — otherwise this ran with zero UI signal until
    /// the final refresh, indistinguishable from the app being frozen on a large file.
    func runDetachedFileOperation(
        context: String,
        priority: TaskPriority = .userInitiated,
        taskTitle: String? = nil,
        onSuccess: (@MainActor () -> Void)? = nil,
        operation: @escaping @Sendable () async throws -> Void) {
        let taskID: UUID? = taskTitle.map { BackgroundOperationsService.shared.addTask(title: $0, totalBytes: 1) }
        let opTask = Task.detached(priority: priority) { [weak self] in
            do {
                try await operation()
                guard let self else { return }
                await handleDetachedOperationSuccess(onSuccess: onSuccess, taskID: taskID)
            } catch {
                ErrorReporter.report(error, context: context)
                guard let self else { return }
                await handleDetachedOperationFailure(error, taskID: taskID)
            }
        }
        if let taskID {
            BackgroundOperationsService.shared.registerCancellation(id: taskID) { opTask.cancel() }
        }
    }

    @MainActor
    private func handleDetachedOperationSuccess(onSuccess: (@MainActor () -> Void)?, taskID: UUID?) {
        if let taskID {
            BackgroundOperationsService.shared.completeTask(id: taskID)
        }
        onSuccess?()
        refreshCurrentDirectory()
    }

    @MainActor
    private func handleDetachedOperationFailure(_ error: any Error, taskID: UUID?) {
        if let taskID {
            BackgroundOperationsService.shared.completeTask(id: taskID)
        }
        showError(error)
    }

    /// Same shape as `runDetachedFileOperation` above, for the common case where the operation
    /// produces a single new/renamed URL: on success it records the undo action `recordUndo`
    /// returns (if any), refreshes, and selects `[url]`; on failure it reports + `showError`.
    /// Consolidates the hand-copied "detached op → hop → record undo + refresh + select" block.
    func runDetachedFileOperation(
        context: String,
        priority: TaskPriority = .userInitiated,
        taskTitle: String? = nil,
        operation: @escaping @Sendable () async throws -> URL,
        recordUndo: @escaping @MainActor (URL) -> UndoActionType?) {
        let taskID: UUID? = taskTitle.map { BackgroundOperationsService.shared.addTask(title: $0, totalBytes: 1) }
        let opTask = Task.detached(priority: priority) { [weak self] in
            do {
                let url = try await operation()
                guard let self else { return }
                await finishDetachedURLOperation(url: url, recordUndo: recordUndo, taskID: taskID)
            } catch {
                ErrorReporter.report(error, context: context)
                guard let self else { return }
                await handleDetachedOperationFailure(error, taskID: taskID)
            }
        }
        if let taskID {
            BackgroundOperationsService.shared.registerCancellation(id: taskID) { opTask.cancel() }
        }
    }

    @MainActor
    private func finishDetachedURLOperation(url: URL, recordUndo: @MainActor (URL) -> UndoActionType?, taskID: UUID?) {
        if let taskID {
            BackgroundOperationsService.shared.completeTask(id: taskID)
        }
        if let action = recordUndo(url) {
            undoRedoService.recordAction(action)
        }
        refreshCurrentDirectory()
        selection.selectedURLs = [url]
    }
}
