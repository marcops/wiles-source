import AppKit
import Foundation
import GitBeacon
import SwiftUI

public extension AppState {
    /// Navigate into a folder. If `url` turns out to be a file this quietly does nothing —
    /// callers that mean "activate whatever the user clicked" should use `openItem(_:)`.
    ///
    /// Fire-and-forget: resolves synchronously for a local path but hops off `@MainActor` first for
    /// a `/Volumes/…` one, with nothing in this signature distinguishing the two. A caller that needs
    /// to run code once navigation has actually landed must use `navigateToAwaitingCompletion`
    /// instead of assuming this returning means the navigation settled (see that method's doc).
    func navigateTo(_ url: URL, addToHistory: Bool = true) {
        resolveAndNavigate(to: url, addToHistory: addToHistory, openFileWithSystem: false)
    }

    /// Activate `url`: navigate into it if it's a folder, hand it to the system to open if it's a
    /// file (double-click, "Open" menu item, keyboard activate).
    func openItem(_ url: URL) {
        resolveAndNavigate(to: url, addToHistory: true, openFileWithSystem: true)
    }

    /// Awaitable form of `navigateTo`: resolves only once the navigation has actually completed —
    /// either `navigation.currentURL` reflects `url` (it existed), or `completeNavigation` has shown
    /// its "not found" error and left `currentURL` untouched — regardless of whether it took the
    /// synchronous (local path) or asynchronous (`/Volumes/…`) branch internally. Any caller that
    /// prepares state depending on the post-navigation folder (e.g. running a smart folder's query
    /// against it) must go through this instead of calling `navigateTo` and assuming it already
    /// landed — `AppState+SmartFolders.runSmartFolder` is the reference. That same caller is also
    /// the one that has to tell "resolved, volume just doesn't exist" apart from "superseded by a
    /// different, later navigation" — this method itself has no opinion on which outcome
    /// `currentURL` ended up at, only that the wait is over.
    func navigateToAwaitingCompletion(_ url: URL, addToHistory: Bool = true) async {
        navigation.pendingSlowVolumeCheck?.cancel()
        if url == Self.recentsVirtualURL {
            HapticService.shared.play(.alignment)
            navigateToRecentsVirtual(addToHistory: addToHistory)
            return
        }
        guard SlowVolumePathValidator.isLikelySlowVolume(url.path) else {
            completeLocalPathNavigation(to: url, addToHistory: addToHistory, openFileWithSystem: false)
            return
        }
        fileSystem.isLoading = true
        let checkTask = spawnSlowVolumeCheck(for: url, addToHistory: addToHistory, openFileWithSystem: false)
        navigation.pendingSlowVolumeCheck = checkTask
        // Awaiting here is what makes this method genuinely awaitable end-to-end: a later, unrelated
        // `resolveAndNavigate`/`navigateToAwaitingCompletion` call still cancels `checkTask` via the
        // guard inside it (and this `await` then unblocks quickly, since a cancelled task still runs
        // to its early `return`), so this doesn't hang the caller forever.
        await checkTask.value
    }

    private func resolveAndNavigate(to url: URL, addToHistory: Bool, openFileWithSystem: Bool) {
        // Cancel any in-flight slow-volume check unconditionally, before dispatching on `url`'s own
        // shape — not just when the NEW target is itself a slow volume. Without this, a pending
        // check for a previous `/Volumes/…` target survives a subsequent fast (local) navigation and
        // can complete afterward, silently overwriting the user's current location.
        navigation.pendingSlowVolumeCheck?.cancel()
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
            navigation.pendingSlowVolumeCheck = spawnSlowVolumeCheck(
                for: url, addToHistory: addToHistory, openFileWithSystem: openFileWithSystem)
            return
        }
        completeLocalPathNavigation(to: url, addToHistory: addToHistory, openFileWithSystem: openFileWithSystem)
    }

    /// The off-main existence check + `completeNavigation` shared by `resolveAndNavigate`'s
    /// fire-and-forget slow-volume branch and `navigateToAwaitingCompletion`'s awaited one.
    private func spawnSlowVolumeCheck(for url: URL, addToHistory: Bool, openFileWithSystem: Bool) -> Task<Void, Never> {
        Task { [weak self] in
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
    }

    /// The synchronous local-path resolution shared by `resolveAndNavigate` and
    /// `navigateToAwaitingCompletion` — a local path resolves in microseconds, so both call this
    /// inline rather than hopping off `@MainActor`.
    private func completeLocalPathNavigation(to url: URL, addToHistory: Bool, openFileWithSystem: Bool) {
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
        let newComponents = newURL.standardizedFileURL.pathComponents
        guard newComponents.count < oldComponents.count,
              oldURL.isDescendantOrSelf(of: newURL) else { return nil }
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
            // Invoked from `FileSystemStore.handleMonitorEvent`, already on `@MainActor` — assume
            // isolation instead of spawning an unstructured `Task { @MainActor }` per event.
            MainActor.assumeIsolated {
                self?.refreshCurrentDirectory(isUserInitiated: false)
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

    /// For a mutation done in the current directory (paste, delete): drop its cached listing first
    /// so `refreshCurrentDirectory`'s cache fast-path can't paint a stale frame before the reload.
    func invalidateCurrentDirectoryCacheAndRefresh() {
        DirectoryCacheService.shared.invalidate(url: navigation.currentURL)
        refreshCurrentDirectory()
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

        // "Search everywhere" results come from a recursive `~` walk, not `snapshot.target` — a
        // monitor on `target` would re-run the whole home recrawl on every `.DS_Store`/download write.
        if snapshot.searchEverywhere {
            fileSystem.stopDirectoryMonitoring()
        } else {
            startDirectoryMonitoring(for: snapshot.target)
        }

        if query.isEmpty, let cached = DirectoryCacheService.shared.cachedResult(for: snapshot.target) {
            // Cache is keyed by URL only, so re-sort to the current option — showing it raw flickers the wrong order.
            let ordered = FileSystemService.sortItems(cached.items, by: snapshot.sort, ascending: snapshot.asc)
            // Carry the truncation flag through the fast path so the "showing N of many" notice doesn't blink off.
            applyLoadedItems(
                ordered, target: snapshot.target,
                truncatedAtCap: cached.items.count >= FileSystemService.directoryListingLimit)
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
            // Each cumulative batch re-assigns the whole match list; defer the derived-index rebuild
            // to one pass once the crawl settles instead of once per batch.
            fileSystem.beginBatchStreaming()
            defer { fileSystem.endBatchStreaming() }
            try await FileSystemService.loadRecursiveSearchResults(at: .userHome, options: options, includeHidden: includeHidden) { [weak self] batch in
                Task { @MainActor in
                    // No `Task.isCancelled` check — this is a fresh unparented `Task`, so it's always
                    // `false` here; `isStillCurrent` is the real staleness guard.
                    guard let self, self.isStillCurrent(target: target, query: query) else { return }
                    self.applyLoadedItems(
                        batch, target: target,
                        truncatedAtCap: batch.count >= FileSystemService.recursiveSearchResultLimit)
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
                self.applyLoadedItems(
                    loaded, target: target,
                    truncatedAtCap: loaded.count >= FileSystemService.directoryListingLimit)
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
        let isTrash = URL.userTrash.standardizedFileURL == target.standardizedFileURL
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
    func applyLoadedItems(_ loaded: [FileItem], target: URL, truncatedAtCap: Bool = false) {
        guard navigation.currentURL == target else { return }
        guard fileSystem.renamingURL == nil else {
            // Load finished; we just don't apply its items mid-rename. Still clear the spinner so it
            // doesn't stay stuck until the next completed refresh.
            fileSystem.isLoading = false
            return
        }
        fileSystem.resultsTruncated = truncatedAtCap
        selection.cachedSelectedFileSizeBytes = nil
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
