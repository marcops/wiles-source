import SwiftUI
import AppKit

extension AppState {
    public func downloadFromiCloud(url: URL) {
        Task.detached(priority: .userInitiated) {
            do {
                try FileManager.default.startDownloadingUbiquitousItem(at: url)
                await MainActor.run { [weak self] in
                    self?.refreshCurrentDirectory()
                }
            } catch {
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

    public func createNewFolderAndRename(windowUIState: WindowUIState) {
        do {
            let createdURL = try FileSystemService.createUniqueDirectory(
                at: navigation.currentURL, baseName: tr(.defaultFolderName))
            enterRenameForNewlyCreated(at: createdURL, windowUIState: windowUIState)
        } catch {
            showError(error.localizedDescription)
        }
    }

    public func createNewFileAndRename(windowUIState: WindowUIState) {
        do {
            let createdURL = try NewFileTemplateService.createTemplateFile(
                in: navigation.currentURL, fileName: "", template: .text)
            enterRenameForNewlyCreated(at: createdURL, windowUIState: windowUIState)
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func enterRenameForNewlyCreated(at url: URL, windowUIState: WindowUIState) {
        DirectoryCacheService.shared.invalidate(url: navigation.currentURL)
        fileSystem.renamingURL = url
        let newItem = FileItem(url: url)
        fileSystem.items.insert(newItem, at: 0)
        selectedURLs = [url]
        windowUIState.renameItem = newItem
    }

    public func toggleSearching() {
        isSearching.toggle()
        if !isSearching { searchQuery = "" }
    }
}
