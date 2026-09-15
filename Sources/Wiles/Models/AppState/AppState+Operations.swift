import AppKit
import GitBeacon
import SwiftUI

public extension AppState {
    /// Same progress-bar-plus-cancel scaffolding `executePaste` wires up for cut/paste — a drag
    /// onto a folder row or breadcrumb drop runs the identical `moveBatchResolvingCollisions` loop,
    /// so a large drop deserves the same visible progress and a way to stop it, not a silent,
    /// uncancellable `Task`.
    func handleDrop(providers: [NSItemProvider], targetFolder: URL, windowUIState: WindowUIState) {
        let backgroundOperations = backgroundOperations
        let taskID = backgroundOperations.addTask(title: tr(.movingItemsEllipsis), totalUnits: Int64(providers.count))
        let dropTask = Task(priority: .userInitiated) { @MainActor [weak self] in
            guard let self else { return }
            var urls: [URL] = []
            for provider in providers {
                if let url = await Self.loadDroppedURL(from: provider) {
                    urls.append(url)
                }
            }
            let movable = await Self.droppableExcludingSelf(urls, targetFolder: targetFolder)
            guard !Task.isCancelled, !movable.isEmpty else {
                backgroundOperations.completeTask(id: taskID)
                return
            }
            _ = await moveItemsResolvingCollisions(
                movable, toFolder: targetFolder, windowUIState: windowUIState,
                progress: { completed in
                    if Self.shouldReportProgress(index: completed - 1, count: movable.count) {
                        backgroundOperations.updateProgress(id: taskID, unitsDone: Int64(completed))
                    }
                })
            backgroundOperations.completeTask(id: taskID)
            // Drop onto the current folder leaves its cached listing stale — invalidate like the
            // other in-place mutation paths (paste/delete) do, not a bare refresh.
            invalidateCurrentDirectoryCacheAndRefresh()
        }
        backgroundOperations.registerCancellation(id: taskID) { dropTask.cancel() }
    }

    /// Off-main: drops any URL that resolves to `targetFolder` itself. Comparing the `URL`s
    /// directly isn't reliable — one round-tripped through `NSItemProvider` can gain a trailing
    /// slash a locally built URL never has; the symlink-resolved `.path` has no such ambiguity.
    /// `resolvingSymlinksInPath` is disk I/O, so it must not run on `@MainActor` (a `/Volumes` drop
    /// target could stall it).
    private static func droppableExcludingSelf(_ urls: [URL], targetFolder: URL) async -> [URL] {
        await Task.detached(priority: .userInitiated) {
            let targetPath = targetFolder.resolvingSymlinksInPath().standardizedFileURL.path
            return urls.filter { $0.resolvingSymlinksInPath().standardizedFileURL.path != targetPath }
        }.value
    }

    private static func loadDroppedURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                continuation.resume(returning: url)
            }
        }
    }

    @discardableResult
    func downloadFromiCloud(url: URL) -> Task<Void, Never> {
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

    /// `nil` when nothing's selected, or when this just opens the confirmation alert.
    @discardableResult
    func deleteSelected(windowUIState: WindowUIState) -> Task<Void, Never>? {
        guard !selection.selectedURLs.isEmpty else { return nil }
        if preferences.view.skipDeleteConfirmation {
            return performDeleteSelected()
        }
        windowUIState.showDeleteConfirmAlert = true
        return nil
    }

    @discardableResult
    func performDeleteSelected() -> Task<Void, Never>? {
        guard !selection.selectedURLs.isEmpty else { return nil }
        HapticService.shared.play(.levelChange)
        let urls = Array(selection.selectedURLs)
        let titleKey = tr(.movingToTrashEllipsis)
        let backgroundOperations = backgroundOperations
        let taskID = backgroundOperations.addTask(title: titleKey, totalUnits: Int64(urls.count))
        let deleteTask = Task(priority: .userInitiated) { @MainActor [weak self] in
            let failureCount = await Self.trashItems(
                urls: urls, taskID: taskID, undoRedoService: self?.undoRedoService, backgroundOperations: backgroundOperations)
            backgroundOperations.completeTask(id: taskID)
            guard let self else { return }
            selection.selectedURLs.removeAll()
            if failureCount > 0 {
                showPartialFailure(.moveToTrashPartialFailure, failed: failureCount, total: urls.count)
            }
            invalidateCurrentDirectoryCacheAndRefresh()
        }
        backgroundOperations.registerCancellation(id: taskID) { deleteTask.cancel() }
        return deleteTask
    }

    /// Progress is hopped to `@MainActor` at most every `progressReportStride` items (plus a final
    /// update) rather than once per item — trashing 20k files shouldn't mean 20k actor hops.
    static let progressReportStride = 64

    /// Off-main trash loop: no `self` capture, per-item progress hopped back to `@MainActor`. The
    /// whole multi-file trash is recorded as ONE grouped undo entry so a single ⌘Z restores every
    /// item.
    private static func trashItems(
        urls: [URL], taskID: UUID, undoRedoService: UndoRedoService?, backgroundOperations: BackgroundOperationsService) async -> Int {
        var failureCount = 0
        var undoActions: [UndoActionType] = []
        for (index, url) in urls.enumerated() {
            guard !Task.isCancelled else { break }
            do {
                let trashed = try await FileSystemService.moveToTrash(url: url)
                undoActions.append(.trash(originalURL: url, trashedURL: trashed))
            } catch {
                ErrorReporter.report(error, context: "Moving item to Trash")
                failureCount += 1
            }
            if shouldReportProgress(index: index, count: urls.count) {
                await MainActor.run { backgroundOperations.updateProgress(id: taskID, unitsDone: Int64(index + 1)) }
            }
        }
        undoRedoService?.recordActions(undoActions)
        return failureCount
    }

    static func shouldReportProgress(index: Int, count: Int) -> Bool {
        (index + 1) % progressReportStride == 0 || index == count - 1
    }

    /// Permanent delete (`FileShredderService`) bypasses the Trash — there is no undo and no
    /// safety net — so it **always** confirms, regardless of `view.skipDeleteConfirmation` (that
    /// preference is about the reversible "move to Trash" only).
    func deletePermanentlySelected(windowUIState: WindowUIState) {
        guard !selection.selectedURLs.isEmpty else { return }
        windowUIState.showDeletePermanentlyConfirmAlert = true
    }

    func performDeletePermanentlySelected() {
        guard !selection.selectedURLs.isEmpty else { return }
        HapticService.shared.play(.levelChange)
        let urls = Array(selection.selectedURLs)
        runDetachedFileOperation(context: "Deleting item permanently", taskTitle: tr(.deletingPermanentlyEllipsis), onSuccess: { [weak self] _ in
            guard let self else { return }
            selection.selectedURLs.removeAll()
            DirectoryCacheService.shared.invalidate(url: navigation.currentURL)
        }, operation: {
            try FileShredderService.deletePermanently(urls: urls)
        })
    }

    @discardableResult
    func copyContentOfSelected() -> Task<Void, Never>? {
        guard let firstURL = primarySelectedURL else { return nil }
        return runDetachedFileOperation(context: "Copying file content to clipboard", refreshOnSuccess: false) {
            try await PasteboardService.copyFileContentToClipboard(url: firstURL)
        }
    }

    @discardableResult
    func undoLastAction() -> Task<Void, Never> {
        let service = undoRedoService
        // A trash undo can take a couple of seconds for a large item, so it gets its own title.
        let title = service.nextUndoIsTrashRestore ? tr(.restoringEllipsis) : tr(.undoingEllipsis)
        return runDetachedFileOperation(context: "Undoing last action", taskTitle: title, detached: false, onSuccess: { [weak self] (target: URL?) in
            if let target {
                self?.selection.selectedURLs = [target]
            }
        }, operation: { try await service.undo() })
    }

    @discardableResult
    func redoLastAction() -> Task<Void, Never> {
        let service = undoRedoService
        return runDetachedFileOperation(
            context: "Redoing last action",
            taskTitle: tr(.redoingEllipsis),
            detached: false,
            onSuccess: { [weak self] (target: URL?) in
                if let target {
                    self?.selection.selectedURLs = [target]
                }
            },
            operation: { try await service.redo() })
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
        if let first = primarySelectedURL, let item = fileSystem.itemsByURL[first] {
            windowUIState.activeModal = .properties(item)
        }
    }

    /// Single shared entry point for triggering rename on the current selection — opens the
    /// inline rename field for one item, or the Batch Rename sheet for 2+. Shared by the
    /// context menu, the F2/Return keyboard shortcuts, and the File menu's Rename item.
    func triggerRenameForSelected(windowUIState: WindowUIState) {
        guard !selection.selectedURLs.isEmpty else { return }
        if selection.selectedURLs.count > 1 {
            windowUIState.activeModal = .batchRename
        } else if let first = primarySelectedURL, let item = fileSystem.itemsByURL[first] {
            windowUIState.renameItem = item
        }
    }

    func startEditingPath(windowUIState: WindowUIState) {
        // `HeaderCenterMode.resolve` only ever shows the editable path bar when `isSearching` is
        // false — while a search or Smart Folder is active, setting `isEditingPath` alone has no
        // visible effect, since the header keeps showing the search field / smart-folder pill.
        selection.isSearching = false
        navigation.pathText = navigation.currentURL.path
        windowUIState.isEditingPath = true
    }

    func createNewFolderAndRename(in folder: URL? = nil, windowUIState: WindowUIState) {
        let targetFolder = folder ?? navigation.currentURL
        let baseName = tr(.defaultFolderName)
        runDetachedFileOperation(context: "Creating new folder", refreshOnSuccess: false, onSuccess: { [weak self] (url: URL) in
            self?.enterRenameForNewlyCreated(at: url, inFolder: targetFolder, windowUIState: windowUIState)
        }, operation: {
            try await FileSystemService.createUniqueDirectory(at: targetFolder, baseName: baseName)
        })
    }

    func createNewFileAndRename(in folder: URL? = nil, windowUIState: WindowUIState) {
        let targetFolder = folder ?? navigation.currentURL
        runDetachedFileOperation(context: "Creating new file", refreshOnSuccess: false, onSuccess: { [weak self] (url: URL) in
            self?.enterRenameForNewlyCreated(at: url, inFolder: targetFolder, windowUIState: windowUIState)
        }, operation: {
            try NewFileTemplateService.createTextFile(in: targetFolder)
        })
    }

    /// Only enters rename UI when the item was created in the folder currently on screen. Creating
    /// in a different folder (e.g. a sidebar/tree context-menu action) must NOT set `renamingURL`
    /// for an off-screen item — that both shows a rename overlay for something not in the list and
    /// freezes the visible directory's refresh until the rename ends.
    private func enterRenameForNewlyCreated(at url: URL, inFolder: URL, windowUIState: WindowUIState) {
        guard inFolder.standardizedFileURL == navigation.currentURL.standardizedFileURL else {
            DirectoryCacheService.shared.invalidate(url: inFolder)
            return
        }
        // Built on @MainActor for a freshly-created local file; the rename row doesn't show
        // Owner/Group, so skip that extra stat/getpwuid syscall path (M3).
        let newItem = FileItem.load(url: url, needsOwnerGroup: false)
        fileSystem.renamingURL = url
        selection.selectedURLs = [url]
        windowUIState.renameItem = newItem
        windowUIState.onRenameCleared = { [weak self] in
            guard let self else { return }
            fileSystem.renamingURL = nil
            // External changes during an open rename get their refresh results discarded; re-trigger
            // once on clear so the listing reconciles even if no further FSEvents arrives. Idempotent
            // with `InlineRenameField.endSuppressedRefreshIfNeeded`.
            refreshCurrentDirectory()
        }
        DirectoryCacheService.shared.invalidate(url: navigation.currentURL)
        // Place it where the current sort puts it, not at the top — otherwise it visibly jumps
        // when the follow-up refresh reorders the list.
        fileSystem.items = FileSystemService.sortItems(
            fileSystem.items + [newItem], by: preferences.view.sortOption, ascending: preferences.view.sortAscending)
    }

    /// Shared shape for a whole-selection file operation: run `operation` inside a real
    /// `Task.detached` so its work is off the main actor **structurally** — not relying on SE-0338
    /// (a non-isolated `@Sendable async` closure hopping off the caller's actor), which silently
    /// stops working the moment a caller passes a closure that captures `@MainActor` state. Then
    /// re-enter the main actor exactly once — run `onSuccess` with the result and refresh, or
    /// report and surface the error. `operation` may be synchronous or asynchronous throwing work.
    /// Not a fit for operations that keep going after a per-item failure (a loop reporting one
    /// error per failed URL but still processing the rest) — those stay bespoke.
    /// `taskTitle`, when supplied, publishes a `BackgroundOperationsService` entry for the
    /// operation's duration (an all-or-nothing 0→1 bar, since these don't report incremental
    /// progress) — otherwise this ran with zero UI signal until the final refresh,
    /// indistinguishable from the app being frozen on a large file.
    /// `operation` MUST be genuinely `nonisolated`/`Sendable`: the `Task.detached` here does NOT
    /// move `@MainActor`-isolated work off-main (SE-0338 / R3). A caller whose `operation` is
    /// `@MainActor`-isolated (undo/redo pass `service.undo()` on a `@MainActor` service) must pass
    /// `detached: false` — the detach buys nothing structurally there and only adds a Task.
    /// Returns the `Task` (`@discardableResult`, real callers keep ignoring it) so a test can
    /// `await` it instead of polling for the operation's side effect.
    @discardableResult
    func runDetachedFileOperation<T: Sendable>(
        context: String,
        priority: TaskPriority = .userInitiated,
        taskTitle: String? = nil,
        refreshOnSuccess: Bool = true,
        reportError: Bool = true,
        detached: Bool = true,
        onSuccess: @escaping @MainActor (T) -> Void = { _ in },
        operation: @escaping @Sendable () async throws -> T) -> Task<Void, Never> {
        let taskID: UUID? = taskTitle.map { backgroundOperations.addTask(title: $0, totalUnits: 1) }
        let opTask = Task(priority: priority) { @MainActor [weak self] in
            do {
                let result = try await Self.runFileOperation(operation, detached: detached, priority: priority)
                guard let self else { return }
                if let taskID {
                    backgroundOperations.completeTask(id: taskID)
                }
                onSuccess(result)
                if refreshOnSuccess {
                    refreshCurrentDirectory()
                }
            } catch is CancellationError {
                // The user cancelled via the operations popover ✕ — just clear the progress entry,
                // never surface it as an error alert.
                if let taskID {
                    self?.backgroundOperations.completeTask(id: taskID)
                }
            } catch {
                // Skipped when `operation` already reports richer diagnostics itself (e.g. ArchiveService's stderr capture).
                if reportError {
                    ErrorReporter.report(error, context: context)
                }
                self?.handleDetachedOperationFailure(error, taskID: taskID)
            }
        }
        if let taskID {
            backgroundOperations.registerCancellation(id: taskID) { opTask.cancel() }
        }
        return opTask
    }

    /// `detached`: run `operation` in a real `Task.detached` (structural off-main guarantee) and
    /// forward cancellation into it. `!detached`: `operation` is itself `@MainActor`-isolated, so a
    /// detach wrapper is meaningless — run it directly and let cooperative cancellation reach it.
    private static func runFileOperation<T: Sendable>(
        _ operation: @escaping @Sendable () async throws -> T,
        detached: Bool,
        priority: TaskPriority) async throws -> T {
        guard detached else { return try await operation() }
        let inner = Task.detached(priority: priority) { try await operation() }
        return try await withTaskCancellationHandler {
            try await inner.value
        } onCancel: {
            inner.cancel()
        }
    }

    @MainActor
    private func handleDetachedOperationFailure(_ error: any Error, taskID: UUID?) {
        if let taskID {
            backgroundOperations.completeTask(id: taskID)
        }
        showError(error)
    }

    /// `runDetachedFileOperation` for the common case where the operation produces a single
    /// new/renamed URL: records the undo action `recordUndo` returns (if any), then selects `[url]`.
    func runDetachedURLOperation(
        context: String,
        priority: TaskPriority = .userInitiated,
        taskTitle: String? = nil,
        operation: @escaping @Sendable () async throws -> URL,
        recordUndo: @escaping @MainActor (URL) -> UndoActionType?) {
        runDetachedFileOperation(
            context: context, priority: priority, taskTitle: taskTitle,
            onSuccess: { [weak self] url in
                guard let self else { return }
                if let action = recordUndo(url) {
                    undoRedoService.recordAction(action)
                }
                selection.selectedURLs = [url]
            }, operation: operation)
    }
}
