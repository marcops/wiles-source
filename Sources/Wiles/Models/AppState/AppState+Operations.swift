import SwiftUI
import AppKit
import GitBeacon

extension AppState {
    public func handleDrop(providers: [NSItemProvider], targetFolder: URL) {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { droppedURL, _ in
                guard let droppedURL = droppedURL, droppedURL.standardizedFileURL != targetFolder.standardizedFileURL else { return }
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

    public func downloadFromiCloud(url: URL) {
        Task.detached(priority: .userInitiated) {
            do {
                try FileManager.default.startDownloadingUbiquitousItem(at: url)
                await MainActor.run { [weak self] in
                    self?.refreshCurrentDirectory()
                }
            } catch {
                ErrorReporter.report(error, context: "Downloading item from iCloud")
                await MainActor.run { [weak self] in
                    self?.showError(error.localizedDescription)
                }
            }
        }
    }

    public func cutSelected() {
        guard !selectedURLs.isEmpty else { return }
        clipboard = ClipboardState(urls: Array(selectedURLs), action: .cut)
    }

    public func copySelected() {
        guard !selectedURLs.isEmpty else { return }
        let urls = Array(selectedURLs)
        clipboard = ClipboardState(urls: urls, action: .copy)
        FileSystemService.writeToPasteboard(urls: urls)
    }

    public func pasteToCurrentDirectory() {
        HapticService.shared.play(.generic)
        guard let clip = clipboard, !clip.urls.isEmpty else {
            if let urls = FileSystemService.readFromPasteboard(), !urls.isEmpty {
                executePaste(urls: urls, isCut: false)
            }
            return
        }
        executePaste(urls: clip.urls, isCut: clip.action == .cut)
        if clip.action == .cut {
            clipboard = nil
        }
    }

    private func executePaste(urls: [URL], isCut: Bool) {
        let targetFolder = navigation.currentURL
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
                        await UndoRedoService.shared.recordAction(.move(sourceURL: url, destinationURL: destURL))
                        await MainActor.run { [weak self] in
                            self?.remapFavorites(from: url, to: destURL)
                        }
                    } else {
                        let destURL = try FileSystemService.copyItem(at: url, toFolder: targetFolder)
                        await UndoRedoService.shared.recordAction(.create(url: destURL))
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

    public func deleteSelected(windowUIState: WindowUIState) {
        guard !selectedURLs.isEmpty else { return }
        if preferences.skipDeleteConfirmation {
            performDeleteSelected()
        } else {
            windowUIState.showDeleteConfirmAlert = true
        }
    }

    public func performDeleteSelected() {
        guard !selectedURLs.isEmpty else { return }
        HapticService.shared.play(.levelChange)
        let urls = Array(selectedURLs)
        Task.detached(priority: .userInitiated) {
            for url in urls {
                do {
                    let trashed = try FileSystemService.moveToTrash(url: url)
                    await UndoRedoService.shared.recordAction(.trash(originalURL: url, trashedURL: trashed))
                } catch {
                    ErrorReporter.report(error, context: "Moving item to Trash")
                    await MainActor.run { [weak self] in
                        self?.showError(error.localizedDescription)
                    }
                }
            }
            await MainActor.run { [weak self] in
                self?.selectedURLs.removeAll()
                self?.refreshCurrentDirectory()
            }
        }
    }

    public func deletePermanentlySelected() {
        guard !selectedURLs.isEmpty else { return }
        HapticService.shared.play(.levelChange)
        let urls = Array(selectedURLs)
        Task.detached(priority: .userInitiated) {
            do {
                try FileShredderService.deletePermanently(urls: urls)
                await MainActor.run { [weak self] in
                    self?.selectedURLs.removeAll()
                    self?.refreshCurrentDirectory()
                }
            } catch {
                ErrorReporter.report(error, context: "Deleting item permanently")
                await MainActor.run { [weak self] in
                    self?.showError(error.localizedDescription)
                }
            }
        }
    }

    public func shredSelected() {
        guard !selectedURLs.isEmpty else { return }
        HapticService.shared.play(.levelChange)
        let urls = Array(selectedURLs)
        Task.detached(priority: .utility) {
            do {
                try await FileShredderService.shredFiles(urls: urls)
                await MainActor.run { [weak self] in
                    self?.selectedURLs.removeAll()
                    self?.refreshCurrentDirectory()
                }
            } catch {
                ErrorReporter.report(error, context: "Shredding files")
                await MainActor.run { [weak self] in
                    self?.showError(error.localizedDescription)
                }
            }
        }
    }

    public func copyContentOfSelected() {
        guard let firstURL = selectedURLs.first else { return }
        FileSystemService.copyFileContentToClipboard(url: firstURL)
    }

    public func undoLastAction() {
        Task {
            do {
                if let targetURL = try await UndoRedoService.shared.undo() {
                    self.refreshCurrentDirectory()
                    self.selectedURLs = [targetURL]
                }
            } catch {
                ErrorReporter.report(error, context: "Undoing last action")
                self.showError(error.localizedDescription)
            }
        }
    }

    public func redoLastAction() {
        Task {
            do {
                if let targetURL = try await UndoRedoService.shared.redo() {
                    self.refreshCurrentDirectory()
                    self.selectedURLs = [targetURL]
                }
            } catch {
                ErrorReporter.report(error, context: "Redoing last action")
                self.showError(error.localizedDescription)
            }
        }
    }

    public func selectAllItems() {
        selectedURLs = Set(fileSystem.items.map { $0.url })
    }

    public func openSelectedItem() {
        if let first = selectedURLs.first {
            navigateTo(first)
        }
    }

    public func triggerQuickLookForSelected(windowUIState: WindowUIState) {
        if let first = selectedURLs.first {
            windowUIState.quickLookURL = first
        }
    }

    public func openPropertiesForSelected(windowUIState: WindowUIState) {
        if let first = selectedURLs.first, let item = fileSystem.items.first(where: { $0.url == first }) {
            windowUIState.propertiesItem = item
        }
    }

    public func startEditingPath(windowUIState: WindowUIState) {
        navigation.pathText = navigation.currentURL.path
        windowUIState.isEditingPath = true
    }

    public func createNewFolderAndRename(in folder: URL? = nil, windowUIState: WindowUIState) {
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

    public func createNewFileAndRename(in folder: URL? = nil, windowUIState: WindowUIState) {
        let targetFolder = folder ?? navigation.currentURL
        do {
            let createdURL = try NewFileTemplateService.createTemplateFile(
                in: targetFolder, fileName: "", template: .text)
            enterRenameForNewlyCreated(at: createdURL, inFolder: targetFolder, windowUIState: windowUIState)
        } catch {
            ErrorReporter.report(error, context: "Creating new file")
            showError(error.localizedDescription)
        }
    }

    // Column view creates items in whichever column was right-clicked, not necessarily
    // `navigation.currentURL` — only touch `fileSystem.items` when they're the same folder.
    private func enterRenameForNewlyCreated(at url: URL, inFolder: URL, windowUIState: WindowUIState) {
        let newItem = FileItem(url: url)
        fileSystem.renamingURL = url
        selectedURLs = [url]
        windowUIState.renameItem = newItem
        guard inFolder.standardizedFileURL == navigation.currentURL.standardizedFileURL else { return }
        DirectoryCacheService.shared.invalidate(url: navigation.currentURL)
        fileSystem.items.insert(newItem, at: 0)
    }

    public func toggleSearching() {
        isSearching.toggle()
        if !isSearching { searchQuery = "" }
    }
}
