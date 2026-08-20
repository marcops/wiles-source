import AppKit
import Foundation
import SwiftUI

/// Caps `navigation.historyBack`/`navigation.historyForward` so a long session of folder-hopping
/// doesn't grow these arrays (and the recent-folders UI they drive) without bound.
private let maxNavigationHistoryCount = 200

public extension AppState {
    func navigateTo(_ url: URL, addToHistory: Bool = true) {
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
            Task { [weak self] in
                let isDirectory = await Task.detached(priority: .userInitiated) {
                    var isDir: ObjCBool = false
                    let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                    return exists && isDir.boolValue
                }.value
                self?.completeNavigation(to: url, isDirectory: isDirectory, addToHistory: addToHistory)
            }
            return
        }
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        completeNavigation(to: url, isDirectory: exists && isDir.boolValue, addToHistory: addToHistory)
    }

    private func navigateToRecentsVirtual(addToHistory: Bool) {
        if addToHistory, Self.recentsVirtualURL != navigation.currentURL {
            navigation.historyBack.append(navigation.currentURL)
            if navigation.historyBack.count > maxNavigationHistoryCount {
                navigation.historyBack.removeFirst()
            }
            navigation.historyForward.removeAll()
        }
        navigation.currentURL = Self.recentsVirtualURL
        smartFolder.activeFolderID = nil
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
        let standardizedURL = url.standardizedFileURL
        let leavingChildURL = childToRestore(whenLeaving: navigation.currentURL, movingTo: standardizedURL)
        if addToHistory, standardizedURL != navigation.currentURL {
            navigation.historyBack.append(navigation.currentURL)
            if navigation.historyBack.count > maxNavigationHistoryCount {
                navigation.historyBack.removeFirst()
            }
            navigation.historyForward.removeAll()
        }
        navigation.currentURL = standardizedURL
        smartFolder.activeFolderID = nil
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

    func goBack() {
        guard let prev = navigation.historyBack.popLast() else { return }
        navigation.historyForward.append(navigation.currentURL)
        if navigation.historyForward.count > maxNavigationHistoryCount {
            navigation.historyForward.removeFirst()
        }
        navigateTo(prev, addToHistory: false)
    }

    func goForward() {
        guard let next = navigation.historyForward.popLast() else { return }
        navigation.historyBack.append(navigation.currentURL)
        if navigation.historyBack.count > maxNavigationHistoryCount {
            navigation.historyBack.removeFirst()
        }
        navigateTo(next, addToHistory: false)
    }

    func goUp() {
        let parent = navigation.currentURL.deletingLastPathComponent()
        if parent != navigation.currentURL {
            navigateTo(parent)
        }
    }

    /// Snapshot of the state `refreshCurrentDirectory()` needs, captured before entering the
    /// refresh Task so a concurrent preference change can't alter an in-flight refresh's behavior.
    private struct RefreshSnapshot {
        let target: URL
        let hidden: Bool
        let tags: Bool
        let ownerGroup: Bool
        let query: String
        let sort: SortOption
        let asc: Bool
        let searchEverywhere: Bool
        let scope: SearchScope
        let caseSensitive: Bool
    }

    func refreshCurrentDirectory(isUserInitiated: Bool = false) {
        if isUserInitiated, fileSystem.items.isEmpty {
            fileSystem.isLoading = true
        }
        let query = searchQuery
        let snapshot = RefreshSnapshot(
            target: navigation.currentURL,
            hidden: preferences.showHiddenFiles,
            tags: preferences.showTags,
            ownerGroup: isColumnVisible(.owner) || isColumnVisible(.group),
            query: query,
            sort: preferences.sortOption,
            asc: preferences.sortAscending,
            searchEverywhere: preferences.searchEverywhere && !query.isEmpty,
            scope: preferences.searchScope,
            caseSensitive: preferences.searchCaseSensitive)

        startDirectoryMonitoring(for: snapshot.target)

        if query.isEmpty, let cached = DirectoryCacheService.shared.cachedResult(for: snapshot.target) {
            applyLoadedItems(cached.items, target: snapshot.target)
        }

        // Cancel any load already in flight — every keystroke of a search or rapid navigation used to
        // spawn an unstructured Task with no cancellation, letting a stale result race a fresher one.
        fileSystem.refreshTask?.cancel()
        fileSystem.refreshTask = Task {
            await performRefresh(snapshot)
        }
    }

    private func performRefresh(_ snapshot: RefreshSnapshot) async {
        let target = snapshot.target
        let query = snapshot.query
        let (strippedQuery, includeHidden) = SearchFilterService.extractHiddenFlag(from: query)
        let options = DirectoryLoadOptions(
            showHidden: snapshot.hidden,
            showTags: snapshot.tags,
            searchQuery: strippedQuery,
            sortOption: snapshot.sort,
            sortAscending: snapshot.asc,
            showOwnerGroup: snapshot.ownerGroup,
            searchScope: snapshot.scope,
            searchCaseSensitive: snapshot.caseSensitive)
        if snapshot.searchEverywhere {
            await FileSystemService.loadRecursiveSearchResults(at: .userHome, options: options, includeHidden: includeHidden) { [weak self] batch in
                Task { @MainActor in
                    guard let self, !Task.isCancelled else { return }
                    guard self.navigation.currentURL == target, self.searchQuery == query else { return }
                    self.applyLoadedItems(batch, target: target)
                }
            }
        } else {
            let loaded = await FileSystemService.loadDirectoryContents(at: target, options: options)
            guard !Task.isCancelled else { return }
            if navigation.currentURL == target, searchQuery == query {
                await MainActor.run {
                    self.applyLoadedItems(loaded, target: target)
                    self.refreshTrashSizeIfNeeded(target: target)
                }
            }
        }
    }

    /// `updateTrashSize()` recursively enumerates all of `~/.Trash` — too expensive to run
    /// unconditionally on every navigation, search keystroke, and FSEvents auto-refresh. Only run it
    /// when the user actually navigated into Trash, or opportunistically at most once per
    /// `trashSizeCheckInterval` so the footer/sidebar figure still drifts back into sync over time.
    private func refreshTrashSizeIfNeeded(target: URL) {
        let trashURL = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first
        let isTrash = trashURL.map { $0.standardizedFileURL == target.standardizedFileURL } ?? false
        let dueForCoarseCheck = Date().timeIntervalSince(transient.lastOpportunisticTrashSizeCheck) >= TransientStore.trashSizeCheckInterval
        guard isTrash || dueForCoarseCheck else { return }
        transient.lastOpportunisticTrashSizeCheck = Date()
        updateTrashSize()
    }

    /// Applies a freshly-loaded (or cached) item list — used by both the instant cache render and the
    /// real async load, so revisiting a folder shows cached contents immediately while the real load
    /// still runs and reconciles afterward. The `Equatable` on `FileItem` (which ignores `icon`) means
    /// this is a no-op re-render when the cache already matched reality.
    private func applyLoadedItems(_ loaded: [FileItem], target: URL) {
        guard navigation.currentURL == target else { return }
        guard fileSystem.renamingURL == nil else { return }
        if fileSystem.items != loaded {
            fileSystem.items = loaded
        }
        fileSystem.isLoading = false
        if let pending = selection.pendingSelectionURL {
            selection.pendingSelectionURL = nil
            if loaded.contains(where: { $0.url == pending }) {
                selectedURLs = [pending]
            }
        }
    }

    func addToRecents(_ url: URL) {
        let std = url.standardizedFileURL
        if std == Self.recentsVirtualURL || std.scheme == "wiles" {
            return
        }
        var current = navigation.recentOpenedURLs.filter { $0.standardizedFileURL != std }
        current.insert(std, at: 0)
        if current.count > 50 {
            current = Array(current.prefix(50))
        }
        navigation.recentOpenedURLs = current
    }
}
