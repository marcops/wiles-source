import AppKit
import Foundation
import GitBeacon
import SwiftUI

public extension AppState {
    /// Navigate into a folder. If `url` turns out to be a file this quietly does nothing —
    /// callers that mean "activate whatever the user clicked" should use `openItem(_:)`.
    func navigateTo(_ url: URL, addToHistory: Bool = true) {
        resolveAndNavigate(to: url, addToHistory: addToHistory, openFileWithSystem: false)
    }

    /// Activate `url`: navigate into it if it's a folder, hand it to the system to open if it's a
    /// file (double-click, "Open" menu item, keyboard activate).
    func openItem(_ url: URL) {
        resolveAndNavigate(to: url, addToHistory: true, openFileWithSystem: true)
    }

    private func resolveAndNavigate(to url: URL, addToHistory: Bool, openFileWithSystem: Bool) {
        if url == Self.recentsVirtualURL {
            HapticService.shared.play(.alignment)
            navigateToRecentsVirtual(addToHistory: addToHistory)
            return
        }
        // fileExists(atPath:) is a synchronous disk call. For a local path it resolves in
        // microseconds, so we check it inline to keep navigation instant. But for anything under
        // /Volumes — an SMB/FTP/SFTP share or external drive — the same call can block for many
        // seconds if the mount has stalled or gone unreachable, freezing the whole UI. Only that
        // case hops off @MainActor.
        if SlowVolumePathValidator.isLikelySlowVolume(url.path) {
            fileSystem.isLoading = true
            navigation.pendingSlowVolumeCheck?.cancel()
            navigation.pendingSlowVolumeCheck = Task { [weak self] in
                let (exists, isDirectory) = await Task.detached(priority: .userInitiated) {
                    var isDir: ObjCBool = false
                    let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                    return (exists, exists && isDir.boolValue)
                }.value
                guard !Task.isCancelled else { return }
                self?.completeNavigation(
                    to: url, exists: exists, isDirectory: isDirectory,
                    addToHistory: addToHistory, openFileWithSystem: openFileWithSystem)
            }
            return
        }
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        completeNavigation(
            to: url, exists: exists, isDirectory: exists && isDir.boolValue,
            addToHistory: addToHistory, openFileWithSystem: openFileWithSystem)
    }

    private func navigateToRecentsVirtual(addToHistory: Bool) {
        if addToHistory {
            navigation.recordVisit(to: Self.recentsVirtualURL)
        }
        navigation.currentURL = Self.recentsVirtualURL
        resetViewStateForNavigation()
    }

    /// The per-navigation view-state reset shared by `navigateToRecentsVirtual` and
    /// `completeNavigation`: drops the active smart folder, any in-progress rename, the selection,
    /// and the search — then reloads. Clears the search silently since it reloads right after
    /// anyway (no debounced search refresh should race this).
    private func resetViewStateForNavigation(pendingChild: URL? = nil) {
        smartFolder.activeFolderID = nil
        fileSystem.renamingURL = nil
        selection.selectedURLs.removeAll()
        selection.pendingSelectionURL = pendingChild
        selection.isSearching = false
        selection.setSearchQuerySilently("")
        refreshCurrentDirectory()
    }

    private func completeNavigation(
        to url: URL, exists: Bool, isDirectory: Bool, addToHistory: Bool, openFileWithSystem: Bool) {
        guard isDirectory else {
            fileSystem.isLoading = false
            if !exists {
                showError(WilesError.itemNotFound(path: url.path))
            } else if openFileWithSystem {
                NSWorkspace.shared.open(url)
            }
            return
        }
        HapticService.shared.play(.alignment)
        navigation.addToRecents(url)
        let standardizedURL = url.standardizedFileURL
        let leavingChildURL = childToRestore(whenLeaving: navigation.currentURL, movingTo: standardizedURL)
        if addToHistory {
            navigation.recordVisit(to: standardizedURL)
        }
        navigation.currentURL = standardizedURL
        resetViewStateForNavigation(pendingChild: leavingChildURL)
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
        guard let prev = navigation.popBackForGoBack() else { return }
        navigateTo(prev, addToHistory: false)
    }

    func goForward() {
        guard let next = navigation.popForwardForGoForward() else { return }
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

    func startDirectoryMonitoring(for url: URL) {
        fileSystem.startDirectoryMonitoring(for: url) { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.refreshCurrentDirectory(isUserInitiated: false)
            }
        }
    }

    /// Called from `SelectionStore.searchQuery`'s `didSet`. Waits out a short quiet period so a
    /// burst of typing / key-repeat collapses into a single refresh instead of one per character.
    func scheduleSearchRefresh() {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task { [weak self] in
            try? await Task.sleep(for: Self.searchDebounceInterval)
            guard !Task.isCancelled else { return }
            self?.refreshCurrentDirectory()
        }
    }

    /// Applies a sort-option / sort-direction change without touching the disk: the file set is
    /// unchanged, so the already-loaded items just get reordered in memory. A live "search
    /// everywhere" is the one exception — its recursive walk captured the old sort at start, so it
    /// has to be restarted to pick up the new one.
    func resortCurrentItems() {
        if preferences.search.searchEverywhere, !selection.searchQuery.isEmpty {
            refreshCurrentDirectory()
            return
        }
        fileSystem.items = FileSystemService.sortItems(
            fileSystem.items, by: preferences.view.sortOption, ascending: preferences.view.sortAscending)
    }

    func refreshCurrentDirectory(isUserInitiated: Bool = false) {
        searchDebounceTask?.cancel()
        if isUserInitiated, fileSystem.items.isEmpty {
            fileSystem.isLoading = true
        }
        let query = selection.searchQuery
        let snapshot = RefreshSnapshot(
            target: navigation.currentURL,
            hidden: preferences.view.showHiddenFiles,
            tags: preferences.sidebar.showTags,
            ownerGroup: isColumnVisible(.owner) || isColumnVisible(.group),
            query: query,
            sort: preferences.view.sortOption,
            asc: preferences.view.sortAscending,
            searchEverywhere: preferences.search.searchEverywhere && !query.isEmpty,
            scope: preferences.search.searchScope,
            caseSensitive: preferences.search.searchCaseSensitive)

        startDirectoryMonitoring(for: snapshot.target)

        if query.isEmpty, let cached = DirectoryCacheService.shared.cachedResult(for: snapshot.target) {
            // Cache is keyed by URL only, so re-sort to the current option — showing it raw flickers the wrong order.
            let ordered = FileSystemService.sortItems(cached.items, by: snapshot.sort, ascending: snapshot.asc)
            applyLoadedItems(ordered, target: snapshot.target)
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
            await performSearchEverywhereRefresh(target: target, query: query, options: options, includeHidden: includeHidden)
        } else {
            await performDirectoryRefresh(target: target, query: query, options: options)
        }
    }

    private func performSearchEverywhereRefresh(target: URL, query: String, options: DirectoryLoadOptions, includeHidden: Bool) async {
        do {
            try await FileSystemService.loadRecursiveSearchResults(at: .userHome, options: options, includeHidden: includeHidden) { [weak self] batch in
                Task { @MainActor in
                    guard let self, !Task.isCancelled, self.isStillCurrent(target: target, query: query) else { return }
                    self.applyLoadedItems(batch, target: target)
                }
            }
        } catch {
            guard !Task.isCancelled else { return }
            await reportRefreshFailure(error, target: target, query: query, context: "Searching everywhere from \(target.path)")
        }
    }

    private func performDirectoryRefresh(target: URL, query: String, options: DirectoryLoadOptions) async {
        do {
            let loaded = try await FileSystemService.loadDirectoryContents(
                at: target, options: options, recentURLs: navigation.recentOpenedURLs)
            guard !Task.isCancelled, isStillCurrent(target: target, query: query) else { return }
            await MainActor.run {
                self.applyLoadedItems(loaded, target: target)
                self.refreshTrashSizeIfNeeded(target: target)
            }
        } catch {
            guard !Task.isCancelled else { return }
            await reportRefreshFailure(error, target: target, query: query, context: "Loading directory contents for \(target.path)")
        }
    }

    /// Whether `target`/`query` still describe what the window is actually showing — a refresh
    /// whose async work finished after a newer navigation or search edit must not overwrite it.
    private func isStillCurrent(target: URL, query: String) -> Bool {
        navigation.currentURL == target && selection.searchQuery == query
    }

    private func reportRefreshFailure(_ error: any Error, target: URL, query: String, context: String) async {
        ErrorReporter.report(error, context: context)
        guard isStillCurrent(target: target, query: query) else { return }
        await MainActor.run {
            self.showError(error)
            self.fileSystem.isLoading = false
        }
    }

    /// `updateTrashSize()` recursively enumerates all of `~/.Trash` — too expensive to run
    /// unconditionally on every navigation, search keystroke, and FSEvents auto-refresh. Only run it
    /// when the user actually navigated into Trash, or opportunistically at most once per
    /// `TrashState.recomputeInterval` so the footer/sidebar figure still drifts back into sync over time.
    private func refreshTrashSizeIfNeeded(target: URL) {
        let trashURL = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first
        let isTrash = trashURL.map { $0.standardizedFileURL == target.standardizedFileURL } ?? false
        let dueForCoarseCheck = fileSystem.trash.shouldRecompute()
        guard isTrash || dueForCoarseCheck else { return }
        // Reset the coarse-check clock on a direct visit to Trash too (not just on the periodic
        // check `shouldRecompute()` itself stamps), so the figure doesn't immediately re-enumerate
        // again right after this navigation-triggered refresh already brought it up to date.
        if isTrash {
            fileSystem.trash.lastOpportunisticCheck = Date()
        }
        updateTrashSize()
    }

    /// Applies a freshly-loaded (or cached) item list — used by both the instant cache render and the
    /// real async load, so revisiting a folder shows cached contents immediately while the real load
    /// still runs and reconciles afterward. The `Equatable` on `FileItem` (which ignores `icon`) means
    /// this is a no-op re-render when the cache already matched reality.
    func applyLoadedItems(_ loaded: [FileItem], target: URL) {
        guard navigation.currentURL == target else { return }
        guard fileSystem.renamingURL == nil else { return }
        if fileSystem.items != loaded {
            fileSystem.items = loaded
        }
        fileSystem.isLoading = false
        if let pending = selection.pendingSelectionURL {
            selection.pendingSelectionURL = nil
            if loaded.contains(where: { $0.url == pending }) {
                selection.selectedURLs = [pending]
            }
        }
    }
}
