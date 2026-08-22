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
                Task { @MainActor in
                    do {
                        _ = try self.moveItem(at: droppedURL, toFolder: targetFolder)
                        self.refreshCurrentDirectory()
                    } catch {
                        ErrorReporter.report(error, context: "Handling file drop")
                        self.showError(error)
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
            undoRedoService.recordAction(.create(url: createdURL))
            refreshCurrentDirectory()
            selection.selectedURLs = [createdURL]
        } catch {
            ErrorReporter.report(error, context: "Creating file from pasteboard content")
            showError(error)
        }
    }

    private func executePaste(urls: [URL], isCut: Bool) {
        let targetFolder = navigation.currentURL
        let undoRedoService = self.undoRedoService
        Task.detached(priority: .userInitiated) {
            for url in urls {
                do {
                    if isCut {
                        // Stays off @MainActor here (rule 29.16 — sequential bulk disk I/O must
                        // not block the main actor across a whole paste of many files). The
                        // shared AppState.moveItem(at:toFolder:) wrapper is @MainActor-isolated
                        // (correct for the single-item drag-and-drop call sites, which already run
                        // on MainActor), so it can't be reused for this loop — only the
                        // MainActor-only favorites sync is shared via remapFavorites below.
                        let destURL = try FileSystemService.moveItem(at: url, toFolder: targetFolder)
                        await undoRedoService.recordAction(.move(sourceURL: url, destinationURL: destURL))
                        await MainActor.run { [weak self] in
                            self?.remapFavorites(from: url, to: destURL)
                        }
                    } else {
                        let destURL = try FileSystemService.copyItem(at: url, toFolder: targetFolder)
                        await undoRedoService.recordAction(.create(url: destURL))
                    }
                } catch {
                    ErrorReporter.report(error, context: "Pasting items to current directory")
                    await MainActor.run { [weak self] in
                        self?.showError(error)
                    }
                }
            }
            await MainActor.run { [weak self] in
                self?.refreshCurrentDirectory()
            }
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
        let undoRedoService = self.undoRedoService
        Task.detached(priority: .userInitiated) {
            for url in urls {
                do {
                    let trashed = try FileSystemService.moveToTrash(url: url)
                    await undoRedoService.recordAction(.trash(originalURL: url, trashedURL: trashed))
                } catch {
                    ErrorReporter.report(error, context: "Moving item to Trash")
                    await MainActor.run { [weak self] in
                        self?.showError(error.localizedDescription)
                    }
                }
            }
            await MainActor.run { [weak self] in
                self?.selection.selectedURLs.removeAll()
                self?.refreshCurrentDirectory()
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
                self.showError(error.localizedDescription)
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
                self.showError(error.localizedDescription)
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
        do {
            let createdURL = try FileSystemService.createUniqueDirectory(
                at: targetFolder, baseName: tr(.defaultFolderName))
            enterRenameForNewlyCreated(at: createdURL, inFolder: targetFolder, windowUIState: windowUIState)
        } catch {
            ErrorReporter.report(error, context: "Creating new folder")
            showError(error.localizedDescription)
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
            showError(error.localizedDescription)
        }
    }

    /// `folder` may differ from `navigation.currentURL` — only touch `fileSystem.items` when
    /// they're the same folder.
    private func enterRenameForNewlyCreated(at url: URL, inFolder: URL, windowUIState: WindowUIState) {
        let newItem = FileItem(url: url)
        fileSystem.renamingURL = url
        selection.selectedURLs = [url]
        windowUIState.renameItem = newItem
        guard inFolder.standardizedFileURL == navigation.currentURL.standardizedFileURL else { return }
        DirectoryCacheService.shared.invalidate(url: navigation.currentURL)
        fileSystem.items.insert(newItem, at: 0)
    }

    func toggleSearching() {
        selection.isSearching.toggle()
        if !selection.isSearching {
            selection.searchQuery = ""
        }
    }

    /// Shared shape for a whole-selection file operation: run `operation` off the main actor, then
    /// re-enter the main actor exactly once — either to run `onSuccess` and refresh (operation
    /// succeeded), or to report and surface the error (operation threw). `operation` may be
    /// synchronous or asynchronous throwing work; either coerces fine to the `async throws`
    /// closure type. Not a fit for operations that need to keep going after a per-item failure
    /// (e.g. a loop that reports one error per failed URL but still processes the rest) — those
    /// stay bespoke.
    private func runDetachedFileOperation(
        context: String,
        priority: TaskPriority = .userInitiated,
        onSuccess: (@MainActor () -> Void)? = nil,
        operation: @escaping @Sendable () async throws -> Void) {
        Task.detached(priority: priority) { [weak self] in
            do {
                try await operation()
                await MainActor.run {
                    onSuccess?()
                    self?.refreshCurrentDirectory()
                }
            } catch {
                ErrorReporter.report(error, context: context)
                await MainActor.run {
                    self?.showError(error.localizedDescription)
                }
            }
        }
    }
}
