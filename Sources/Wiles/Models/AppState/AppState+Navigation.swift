import Foundation
import AppKit
import SwiftUI

extension AppState {
    public func navigateTo(_ url: URL, addToHistory: Bool = true) {
        HapticService.shared.play(.alignment)
        if url == Self.recentsVirtualURL {
            if addToHistory && url != currentURL {
                historyBack.append(currentURL)
                historyForward.removeAll()
            }
            currentURL = url
            selectedURLs.removeAll()
            isSearching = false
            searchQuery = ""
            refreshCurrentDirectory()
            return
        }
        addToRecents(url)
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            let leavingChildURL = childToRestore(whenLeaving: currentURL, movingTo: url.standardizedFileURL)
            if addToHistory && url != currentURL {
                historyBack.append(currentURL)
                historyForward.removeAll()
            }
            currentURL = url.standardizedFileURL
            selectedURLs.removeAll()
            pendingSelectionURL = leavingChildURL
            isSearching = false
            searchQuery = ""
            refreshCurrentDirectory()
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    /// If `newURL` is an ancestor of `oldURL`, returns the direct child of `newURL` on the path to `oldURL` —
    /// this is the folder being "left" and should be reselected once `newURL`'s contents load.
    private func childToRestore(whenLeaving oldURL: URL, movingTo newURL: URL) -> URL? {
        let oldComponents = oldURL.standardizedFileURL.pathComponents
        let newComponents = newURL.pathComponents
        guard newComponents.count < oldComponents.count,
              Array(oldComponents.prefix(newComponents.count)) == newComponents else { return nil }
        return newURL.appendingPathComponent(oldComponents[newComponents.count])
    }

    public func goBack() {
        guard let prev = historyBack.popLast() else { return }
        historyForward.append(currentURL)
        navigateTo(prev, addToHistory: false)
    }

    public func goForward() {
        guard let next = historyForward.popLast() else { return }
        historyBack.append(currentURL)
        navigateTo(next, addToHistory: false)
    }

    public func goUp() {
        let parent = currentURL.deletingLastPathComponent()
        if parent != currentURL { navigateTo(parent) }
    }

    public func refreshCurrentDirectory(isUserInitiated: Bool = false) {
        if isUserInitiated && self.items.isEmpty {
            isLoading = true
        }
        let target = currentURL
        let hidden = showHiddenFiles
        let tags = showTags
        let query = searchQuery
        let sort = sortOption
        let asc = sortAscending

        startDirectoryMonitoring(for: target)

        if query.isEmpty, let cached = DirectoryCacheService.shared.cachedResult(for: target) {
            applyLoadedItems(cached.items, target: target)
        }

        Task {
            let loaded = await FileSystemService.loadDirectoryContents(
                at: target,
                options: DirectoryLoadOptions(showHidden: hidden, showTags: tags, searchQuery: query, sortOption: sort, sortAscending: asc)
            )
            if self.currentURL == target {
                await MainActor.run {
                    self.applyLoadedItems(loaded, target: target)
                }
            }
            self.updateTrashSize()
        }
    }

    /// Applies a freshly-loaded (or cached) item list — used by both the instant cache render and the
    /// real async load, so revisiting a folder shows cached contents immediately while the real load
    /// still runs and reconciles afterward. The `Equatable` on `FileItem` (which ignores `icon`) means
    /// this is a no-op re-render when the cache already matched reality.
    private func applyLoadedItems(_ loaded: [FileItem], target: URL) {
        guard self.currentURL == target else { return }
        if self.items != loaded {
            self.items = loaded
        }
        self.isLoading = false
        if let pending = self.pendingSelectionURL {
            self.pendingSelectionURL = nil
            if loaded.contains(where: { $0.url == pending }) {
                self.selectedURLs = [pending]
            }
        }
    }

    public func addToRecents(_ url: URL) {
        let std = url.standardizedFileURL
        if std == Self.recentsVirtualURL || std.scheme == "wiles" { return }
        var current = recentOpenedURLs.filter { $0.standardizedFileURL != std }
        current.insert(std, at: 0)
        if current.count > 50 {
            current = Array(current.prefix(50))
        }
        self.recentOpenedURLs = current
    }
}
