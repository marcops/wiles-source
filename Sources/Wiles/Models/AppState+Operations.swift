import SwiftUI
import AppKit

extension AppState {
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
        Task {
            for url in urls {
                do {
                    if isCut {
                        let destURL = try FileSystemService.moveItem(at: url, toFolder: currentURL)
                        UndoRedoService.shared.recordAction(.move(sourceURL: url, destinationURL: destURL))
                    } else {
                        let destURL = try FileSystemService.copyItem(at: url, toFolder: currentURL)
                        UndoRedoService.shared.recordAction(.create(url: destURL))
                    }
                } catch {
                    print("Paste error for \(url): \(error)")
                }
            }
            refreshCurrentDirectory()
        }
    }
    
    public func deleteSelected() {
        guard !selectedURLs.isEmpty else { return }
        let urls = Array(selectedURLs)
        Task {
            for url in urls {
                if let trashed = try? FileSystemService.moveToTrash(url: url) {
                    UndoRedoService.shared.recordAction(.trash(originalURL: url, trashedURL: trashed))
                }
            }
            selectedURLs.removeAll()
            refreshCurrentDirectory()
        }
    }
    
    public func deletePermanentlySelected() {
        guard !selectedURLs.isEmpty else { return }
        let urls = Array(selectedURLs)
        do {
            try FileShredderService.deletePermanently(urls: urls)
            selectedURLs.removeAll()
            refreshCurrentDirectory()
        } catch {
            print("Error deleting permanently: \(error)")
        }
    }
    
    public func shredSelected() {
        guard !selectedURLs.isEmpty else { return }
        let urls = Array(selectedURLs)
        Task.detached(priority: .utility) {
            try? await FileShredderService.shredFiles(urls: urls)
            await MainActor.run {
                self.selectedURLs.removeAll()
                self.refreshCurrentDirectory()
            }
        }
    }
    
    public func copyContentOfSelected() {
        guard let firstURL = selectedURLs.first else { return }
        FileSystemService.copyFileContentToClipboard(url: firstURL)
    }
    
    public func undoLastAction() {
        Task {
            if let targetURL = await UndoRedoService.shared.undo() {
                self.refreshCurrentDirectory()
                self.selectedURLs = [targetURL]
            }
        }
    }
    
    public func redoLastAction() {
        Task {
            if let targetURL = await UndoRedoService.shared.redo() {
                self.refreshCurrentDirectory()
                self.selectedURLs = [targetURL]
            }
        }
    }

    public func selectAllItems() {
        selectedURLs = Set(items.map { $0.url })
    }

    public func openSelectedItem() {
        if let first = selectedURLs.first {
            navigateTo(first)
        }
    }

    public func triggerQuickLookForSelected() {
        if let first = selectedURLs.first {
            quickLookURL = first
        }
    }

    public func openPropertiesForSelected() {
        if let first = selectedURLs.first, let item = items.first(where: { $0.url == first }) {
            propertiesItem = item
        }
    }

    public func startEditingPath() {
        pathText = currentURL.path
        isEditingPath = true
    }

    public func toggleSearching() {
        isSearching.toggle()
        if !isSearching { searchQuery = "" }
    }
}
