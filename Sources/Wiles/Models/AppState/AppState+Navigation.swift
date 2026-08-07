import Foundation
import AppKit
import SwiftUI

extension AppState {
    public func navigateTo(_ url: URL, addToHistory: Bool = true) {
        HapticService.shared.play(.alignment)
        if url == Self.recentsVirtualURL {
            navigateToRecentsVirtual(addToHistory: addToHistory)
            return
        }
        addToRecents(url)
        // fileExists(atPath:) is a synchronous disk call. For a local path it resolves in
        // microseconds, so we check it inline to keep navigation instant. But for anything under
        // /Volumes — an SMB/FTP/SFTP share or external drive — the same call can block for many
        // seconds if the mount has stalled or gone unreachable, freezing the whole UI. Only that
        // case hops off @MainActor.
        if url.path.hasPrefix("/Volumes/") {
            Task.detached(priority: .userInitiated) { [weak self] in
                var isDir: ObjCBool = false
                let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                await MainActor.run {
                    self?.completeNavigation(to: url, isDirectory: exists && isDir.boolValue, addToHistory: addToHistory)
                }
            }
            return
        }
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        completeNavigation(to: url, isDirectory: exists && isDir.boolValue, addToHistory: addToHistory)
    }

    private func navigateToRecentsVirtual(addToHistory: Bool) {
        if addToHistory && Self.recentsVirtualURL != navigation.currentURL {
            navigation.historyBack.append(navigation.currentURL)
            navigation.historyForward.removeAll()
        }
        navigation.currentURL = Self.recentsVirtualURL
        selectedURLs.removeAll()
        isSearching = false
        searchQuery = ""
        refreshCurrentDirectory()
    }

    private func completeNavigation(to url: URL, isDirectory: Bool, addToHistory: Bool) {
        guard isDirectory else {
            NSWorkspace.shared.open(url)
            return
        }
        let leavingChildURL = childToRestore(whenLeaving: navigation.currentURL, movingTo: url.standardizedFileURL)
        if addToHistory && url != navigation.currentURL {
            navigation.historyBack.append(navigation.currentURL)
            navigation.historyForward.removeAll()
        }
        navigation.currentURL = url.standardizedFileURL
        selectedURLs.removeAll()
        selection.pendingSelectionURL = leavingChildURL
        isSearching = false
        searchQuery = ""
        refreshCurrentDirectory()
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
        guard let prev = navigation.historyBack.popLast() else { return }
        navigation.historyForward.append(navigation.currentURL)
        navigateTo(prev, addToHistory: false)
    }

    public func goForward() {
        guard let next = navigation.historyForward.popLast() else { return }
        navigation.historyBack.append(navigation.currentURL)
        navigateTo(next, addToHistory: false)
    }

    public func goUp() {
        let parent = navigation.currentURL.deletingLastPathComponent()
        if parent != navigation.currentURL { navigateTo(parent) }
    }

    public func refreshCurrentDirectory(isUserInitiated: Bool = false) {
        if isUserInitiated && self.fileSystem.items.isEmpty {
            fileSystem.isLoading = true
        }
        let target = navigation.currentURL
        let hidden = preferences.showHiddenFiles
        let tags = preferences.showTags
        let query = searchQuery
        let sort = preferences.sortOption
        let asc = preferences.sortAscending

        startDirectoryMonitoring(for: target)

        if query.isEmpty, let cached = DirectoryCacheService.shared.cachedResult(for: target) {
            applyLoadedItems(cached.items, target: target)
        }

        Task {
            let loaded = await FileSystemService.loadDirectoryContents(
                at: target,
                options: DirectoryLoadOptions(showHidden: hidden, showTags: tags, searchQuery: query, sortOption: sort, sortAscending: asc)
            )
            if self.navigation.currentURL == target {
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
        guard self.navigation.currentURL == target else { return }
        if self.fileSystem.items != loaded {
            self.fileSystem.items = loaded
        }
        self.fileSystem.isLoading = false
        if let pending = self.selection.pendingSelectionURL {
            self.selection.pendingSelectionURL = nil
            if loaded.contains(where: { $0.url == pending }) {
                self.selectedURLs = [pending]
            }
        }
    }

    public func addToRecents(_ url: URL) {
        let std = url.standardizedFileURL
        if std == Self.recentsVirtualURL || std.scheme == "wiles" { return }
        var current = navigation.recentOpenedURLs.filter { $0.standardizedFileURL != std }
        current.insert(std, at: 0)
        if current.count > 50 {
            current = Array(current.prefix(50))
        }
        self.navigation.recentOpenedURLs = current
    }
}
