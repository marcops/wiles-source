import AppKit
import GitBeacon
import SwiftUI

public extension AppState {
    func handleDrop(providers: [NSItemProvider], targetFolder: URL) {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { droppedURL, _ in
                // Comparing the `URL` values themselves (even standardized) isn't reliable here:
                // a URL round-tripped through `NSItemProvider` can gain a directory trailing
                // slash that a URL built locally via `.appendingPathComponent` never gets, so two
                // URLs for the exact same folder compare unequal via `==`/`!=`. `.path` has no
                // such ambiguity — compare that (after resolving symlinks, e.g. ~/Desktop under
                // iCloud Drive's Desktop & Documents sync) so "drop a folder onto itself" is
                // caught reliably.
                guard let droppedURL,
                      droppedURL.resolvingSymlinksInPath().standardizedFileURL.path
                      != targetFolder.resolvingSymlinksInPath().standardizedFileURL.path else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    do {
                        _ = try await moveItem(at: droppedURL, toFolder: targetFolder)
                        refreshCurrentDirectory()
                    } catch {
                        ErrorReporter.report(error, context: "Handling file drop")
                        showError(error)
                    }
                }
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

    func pasteToCurrentDirectory() {
        HapticService.shared.play(.generic)
        guard let clip = transient.clipboard, !clip.urls.isEmpty else {
            if let urls = PasteboardService.readFromPasteboard(), !urls.isEmpty {
                executePaste(urls: urls, isCut: false)
            } else {
                pasteClipboardContentAsFile()
            }
            return
        }
        executePaste(urls: clip.urls, isCut: clip.action == .cut)
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
            ErrorReporter.report(error, context: "Creating file from pasteboard content")
            showError(error)
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
    }

    private func executePaste(urls: [URL], isCut: Bool) {
        let targetFolder = navigation.currentURL
        let undoRedoService = undoRedoService
        let titleKey = tr(.pastingItemsEllipsis)
        Task.detached(priority: .userInitiated) { [weak self] in
            let taskID = await MainActor.run { BackgroundOperationsService.shared.addTask(title: titleKey, totalBytes: Int64(urls.count)) }
            let context = PasteContext(targetFolder: targetFolder, isCut: isCut, undoRedoService: undoRedoService, taskID: taskID, owner: self)
            let (failureCount, movedDestinations) = await Self.pasteAllItems(urls: urls, context: context)
            // swiftformat:disable redundantSelf
            await MainActor.run { [weak self] in
                BackgroundOperationsService.shared.completeTask(id: taskID)
                guard let self else { return }
                if isCut, !movedDestinations.isEmpty {
                    self.selection.selectedURLs = Set(movedDestinations)
                }
                if failureCount > 0 {
                    self.showError(WilesError.operationFailed(
                        reason: "\(failureCount) of \(urls.count) items could not be pasted."))
                }
                self.refreshCurrentDirectory()
            }
            // swiftformat:enable redundantSelf
        }
    }

    /// Extracted out of `executePaste`'s detached task so that closure stays short — pastes every
    /// item sequentially (stays off @MainActor per rule 29.16 — bulk disk I/O across many files
    /// must not block the main actor) and reports per-item progress as it goes.
    private static func pasteAllItems(urls: [URL], context: PasteContext) async -> (failureCount: Int, movedDestinations: [URL]) {
        var failureCount = 0
        var movedDestinations: [URL] = []
        for (index, url) in urls.enumerated() {
            guard !Task.isCancelled else { break }
            do {
                if context.isCut {
                    // The shared AppState.moveItem(at:toFolder:) wrapper is @MainActor-isolated
                    // (correct for the single-item drag-and-drop call sites, which already run on
                    // MainActor), so it can't be reused for this loop — only the MainActor-only
                    // favorites sync is shared via remapFavorites below.
                    let destURL = try await FileSystemService.moveItem(at: url, toFolder: context.targetFolder)
                    await context.undoRedoService.recordAction(.move(sourceURL: url, destinationURL: destURL))
                    await MainActor.run { context.owner?.remapFavorites(from: url, to: destURL) }
                    movedDestinations.append(destURL)
                } else {
                    let destURL = try await FileSystemService.copyItem(at: url, toFolder: context.targetFolder)
                    context.undoRedoService.recordAction(.createFile(url: destURL))
                }
            } catch {
                ErrorReporter.report(error, context: "Pasting items to current directory")
                failureCount += 1
            }
            await MainActor.run { BackgroundOperationsService.shared.updateProgress(id: context.taskID, bytesTransferred: Int64(index + 1)) }
        }
        return (failureCount, movedDestinations)
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
        Task.detached(priority: .userInitiated) {
            let taskID = await MainActor.run { BackgroundOperationsService.shared.addTask(title: titleKey, totalBytes: Int64(urls.count)) }
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
    }

    func deletePermanentlySelected() {
        guard !selection.selectedURLs.isEmpty else { return }
        HapticService.shared.play(.levelChange)
        let urls = Array(selection.selectedURLs)
        runDetachedFileOperation(context: "Deleting item permanently", onSuccess: { [weak self] in
            self?.selection.selectedURLs.removeAll()
        }, operation: {
            try FileShredderService.deletePermanently(urls: urls)
        })
    }

    func shredSelected() {
        guard !selection.selectedURLs.isEmpty else { return }
        HapticService.shared.play(.levelChange)
        let urls = Array(selection.selectedURLs)
        runDetachedFileOperation(context: "Shredding files", priority: .utility, onSuccess: { [weak self] in
            self?.selection.selectedURLs.removeAll()
        }, operation: {
            try await FileShredderService.shredFiles(urls: urls)
        })
    }

    func copyContentOfSelected() {
        guard let firstURL = selection.selectedURLs.first else { return }
        PasteboardService.copyFileContentToClipboard(url: firstURL)
    }

    func undoLastAction() {
        Task {
            do {
                if let targetURL = try await self.undoRedoService.undo() {
                    self.refreshCurrentDirectory()
                    self.selection.selectedURLs = [targetURL]
                }
            } catch {
                ErrorReporter.report(error, context: "Undoing last action")
                self.showError(error)
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
                ErrorReporter.report(error, context: "Redoing last action")
                self.showError(error)
            }
        }
    }

    func selectAllItems() {
        selection.selectedURLs = Set(fileSystem.items.map(\.url))
    }

    func openSelectedItem() {
        if let first = selection.selectedURLs.first {
            navigateTo(first)
        }
    }

    func triggerQuickLookForSelected(windowUIState: WindowUIState) {
        if let first = selection.selectedURLs.first {
            windowUIState.quickLookURL = first
        }
    }

    func openPropertiesForSelected(windowUIState: WindowUIState) {
        if let first = selection.selectedURLs.first, let item = fileSystem.items.first(where: { $0.url == first }) {
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
                ErrorReporter.report(error, context: "Creating new folder")
                showError(error)
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
            ErrorReporter.report(error, context: "Creating new file")
            showError(error)
        }
    }

    /// `folder` may differ from `navigation.currentURL` — only touch `fileSystem.items` when
    /// they're the same folder.
    private func enterRenameForNewlyCreated(at url: URL, inFolder: URL, windowUIState: WindowUIState) {
        let newItem = FileItem(url: url)
        fileSystem.renamingURL = url
        selection.selectedURLs = [url]
        windowUIState.renameItem = newItem
        windowUIState.onRenameCleared = { [weak self] in self?.fileSystem.renamingURL = nil }
        guard inFolder.standardizedFileURL == navigation.currentURL.standardizedFileURL else { return }
        DirectoryCacheService.shared.invalidate(url: navigation.currentURL)
        fileSystem.items.insert(newItem, at: 0)
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
        Task.detached(priority: priority) { [weak self] in
            let taskID: UUID? = if let taskTitle {
                await MainActor.run { BackgroundOperationsService.shared.addTask(title: taskTitle, totalBytes: 1) }
            } else {
                nil
            }
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
    private func handleDetachedOperationFailure(_ error: Error, taskID: UUID?) {
        if let taskID {
            BackgroundOperationsService.shared.completeTask(id: taskID)
        }
        showError(error)
    }
}
