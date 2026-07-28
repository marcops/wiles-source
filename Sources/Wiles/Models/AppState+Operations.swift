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
            // Check if system pasteboard has URLs
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
                        try FileSystemService.moveItem(at: url, toFolder: currentURL)
                    } else {
                        try FileSystemService.copyItem(at: url, toFolder: currentURL)
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
                try? FileSystemService.moveToTrash(url: url)
            }
            selectedURLs.removeAll()
            refreshCurrentDirectory()
        }
    }
    
    public func copyContentOfSelected() {
        guard let firstURL = selectedURLs.first else { return }
        FileSystemService.copyFileContentToClipboard(url: firstURL)
    }
}
