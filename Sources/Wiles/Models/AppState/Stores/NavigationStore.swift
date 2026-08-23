import Foundation
import Observation

@Observable
@MainActor
public final class NavigationStore {
    public var currentURL: URL {
        didSet {
            pathText = currentURL.path
            UserDefaults.standard.set(currentURL.path, forKey: DefaultsKey.lastOpenedFolder.rawValue)
        }
    }

    public var pathText: String = ""
    public var historyBack: [URL] = []
    public var historyForward: [URL] = []
    /// Cancelled and replaced whenever a new `/Volumes/` navigation starts, so a slow-resolving
    /// mount can't finish after a faster subsequent navigation and yank the user back to it.
    public var pendingSlowVolumeCheck: Task<Void, Never>?
    public var recentOpenedURLs: [URL] = [] {
        didSet {
            guard !isInitializing else { return }
            let paths = recentOpenedURLs.map(\.path)
            UserDefaults.standard.set(paths, forKey: DefaultsKey.recentOpenedURLs.rawValue)
        }
    }

    /// Suppresses `recentOpenedURLs`'s persistence `didSet` while `init` populates it from
    /// already-persisted data, so construction doesn't redundantly write back what it just read.
    private var isInitializing = true

    /// Caps `historyBack`/`historyForward` so a long session of folder-hopping doesn't grow these
    /// arrays (and the recent-folders UI they drive) without bound.
    private let maxNavigationHistoryCount = 200
    private let maxRecentOpenedCount = 50

    /// Set by `AppState.init` to `{ [weak self] fallback in self?.navigateTo(fallback) }` — lets a
    /// dead saved volume route through the real navigation path (refresh, history, recents) instead
    /// of `validateSlowVolumePaths` silently reassigning `currentURL` with no reload. Same idiom as
    /// `SelectionStore.onSearchQueryChanged`.
    public var onVolumeUnreachable: ((URL) -> Void)?

    public init(initialURL: URL = FileManager.default.homeDirectoryForCurrentUser) {
        let savedPath = UserDefaults.standard.string(forKey: DefaultsKey.lastOpenedFolder.rawValue)
        let resolvedURL: URL = if let path = savedPath, Self.existsOptimistically(atPath: path) {
            URL(fileURLWithPath: path).standardizedFileURL
        } else {
            initialURL
        }
        currentURL = resolvedURL
        pathText = resolvedURL.path

        if let savedRecents = UserDefaults.standard.stringArray(forKey: DefaultsKey.recentOpenedURLs.rawValue) {
            recentOpenedURLs = savedRecents.compactMap { path in
                Self.existsOptimistically(atPath: path) ? URL(fileURLWithPath: path) : nil
            }
        }
        isInitializing = false

        Task { [weak self] in
            await self?.validateSlowVolumePaths()
        }
    }

    /// `/Volumes/` paths (network shares, external drives) are accepted optimistically at init
    /// time instead of a synchronous `fileExists` check, which could stall window construction for
    /// seconds against a sleeping/unreachable mount (same rationale as `AppState+Navigation.swift`'s
    /// `navigateTo`). This verifies them afterward and corrects state if any turned out to be gone.
    private func validateSlowVolumePaths() async {
        let pathsToCheck = Set(([currentURL] + recentOpenedURLs).map(\.path).filter(Self.isLikelySlowVolume))
        guard !pathsToCheck.isEmpty else { return }

        let existence = await Task.detached(priority: .utility) {
            Dictionary(uniqueKeysWithValues: pathsToCheck.map { ($0, FileManager.default.fileExists(atPath: $0)) })
        }.value

        if let exists = existence[currentURL.path], !exists {
            let fallback = FileManager.default.homeDirectoryForCurrentUser
            if let onVolumeUnreachable {
                onVolumeUnreachable(fallback)
            } else {
                currentURL = fallback
            }
        }
        recentOpenedURLs = recentOpenedURLs.filter { existence[$0.path] ?? true }
    }

    private static func isLikelySlowVolume(_ path: String) -> Bool {
        path.hasPrefix("/Volumes/")
    }

    /// Skips the synchronous `fileExists` check for a `/Volumes/` path — it's accepted as-is here
    /// and verified later off-`@MainActor` by `validateSlowVolumePaths()`.
    private static func existsOptimistically(atPath path: String) -> Bool {
        isLikelySlowVolume(path) || FileManager.default.fileExists(atPath: path)
    }

    /// Inserts/refreshes `url` at the front of `recentOpenedURLs`, capped at 50 entries. Excludes
    /// the synthetic Recents-virtual-folder URL and any `wiles://`-scheme virtual URL, neither of
    /// which represents a real openable location worth remembering.
    ///
    /// Merges against `UserDefaults` (not the in-memory copy) so a concurrent write from another window isn't clobbered.
    public func addToRecents(_ url: URL) {
        let std = url.standardizedFileURL
        if std == AppState.recentsVirtualURL || std.scheme == "wiles" {
            return
        }
        let persistedPaths = UserDefaults.standard.stringArray(forKey: DefaultsKey.recentOpenedURLs.rawValue) ?? []
        var current = persistedPaths.map { URL(fileURLWithPath: $0) }.filter { $0.standardizedFileURL != std }
        current.insert(std, at: 0)
        if current.count > maxRecentOpenedCount {
            current = Array(current.prefix(maxRecentOpenedCount))
        }
        recentOpenedURLs = current
    }

    /// Caps `stack` at `maxNavigationHistoryCount` by dropping its oldest (first) entry once over
    /// the limit. Shared by `recordVisit`/`popBackForGoBack`/`popForwardForGoForward` so the cap
    /// logic exists in exactly one place instead of being copy-pasted at each call site.
    private func cap(_ stack: inout [URL]) {
        while stack.count > maxNavigationHistoryCount {
            stack.removeFirst()
        }
    }

    /// Records a completed navigation away from the current `currentURL` toward `newURL` in the
    /// back/forward history: pushes `currentURL` (the URL being left) onto `historyBack` (capped)
    /// and clears `historyForward`, since a fresh navigation invalidates whatever "forward" history
    /// existed. A no-op when `newURL` is the already-current folder — call this before actually
    /// updating `currentURL` to the new value.
    public func recordVisit(to newURL: URL) {
        guard newURL.standardizedFileURL != currentURL.standardizedFileURL else { return }
        historyBack.append(currentURL)
        cap(&historyBack)
        historyForward.removeAll()
    }

    /// Pops the most recent entry off `historyBack` for a "go back" action, pushing the (still
    /// current, not-yet-updated) `currentURL` onto `historyForward` (capped) so "go forward" can
    /// return to it. Returns `nil` (and leaves both stacks untouched) when there's nowhere to go
    /// back to.
    public func popBackForGoBack() -> URL? {
        guard let prev = historyBack.popLast() else { return nil }
        historyForward.append(currentURL)
        cap(&historyForward)
        return prev
    }

    /// Mirror of `popBackForGoBack` for "go forward": pops `historyForward`, pushes `currentURL`
    /// onto `historyBack` (capped). Returns `nil` when there's nowhere to go forward to.
    public func popForwardForGoForward() -> URL? {
        guard let next = historyForward.popLast() else { return nil }
        historyBack.append(currentURL)
        cap(&historyBack)
        return next
    }
}
