import Foundation
import Observation

/// The user's sidebar favorites. Split out of `PreferencesStore` (SRP) so the favorites *data*
/// lives next to the favorites *logic* in `AppState+Favorites`, rather than being one more concern
/// on the preferences god object. Reached as `appState.preferences.favorites`.
@Observable
@MainActor
public final class FavoritesStore: PersistablePreferenceStore {
    @ObservationIgnored var isRestoringDefaults = false

    public var favoriteURLs: [URL] = [] {
        didSet {
            standardizedFavoritePaths = Set(favoriteURLs.map(\.standardizedFileURL.path))
            recomputeResolvedFavoritePaths()
            guard !isRestoringDefaults else { return }
            persist(favoriteURLs.map(\.path), .favoriteURLs)
        }
    }

    @ObservationIgnored private var resolvedPathsTask: Task<Void, Never>?

    /// Pure: symlink-resolved standardized paths of `urls`.
    nonisolated static func resolvedPaths(for urls: [URL]) -> Set<String> {
        Set(urls.map { $0.resolvingSymlinksInPath().standardizedFileURL.path })
    }

    /// Recomputes `resolvedFavoritePaths` on every `favoriteURLs` change. Local favorites resolve
    /// now (a fast `lstat`); only `/Volumes/` favorites — where `resolvingSymlinksInPath()` can block
    /// seconds on a stalled share — are deferred off the main actor and merged in when they land.
    private func recomputeResolvedFavoritePaths() {
        resolvedPathsTask?.cancel()
        let urls = favoriteURLs
        let slow = urls.filter { SlowVolumePathValidator.isLikelySlowVolume($0.path) }
        let localResolved = Self.resolvedPaths(for: urls.filter { !slow.contains($0) })
        resolvedFavoritePaths = localResolved
        guard !slow.isEmpty else { return }
        resolvedPathsTask = Task { [weak self] in
            let slowResolved = await Task.detached(priority: .utility) { Self.resolvedPaths(for: slow) }.value
            guard !Task.isCancelled, let self, favoriteURLs == urls else { return }
            resolvedFavoritePaths = localResolved.union(slowResolved)
        }
    }

    /// Plain standardized paths (no symlink resolution) — lets `AppState.isFavorite(_:)` answer the
    /// ~99% common case with zero `stat`, resolving symlinks only when a candidate path isn't a
    /// direct member. Recomputed only when the list changes.
    public private(set) var standardizedFavoritePaths: Set<String> = []

    /// Symlink-resolved paths of `favoriteURLs`, recomputed only when the list changes — so
    /// `AppState.isFavorite(_:)` (called per visible row) is an O(1) `Set` lookup instead of an
    /// O(favorites) `resolvingSymlinksInPath()` stat storm every render.
    public private(set) var resolvedFavoritePaths: Set<String> = []

    public init() {
        loadFavoriteURLs(UserDefaults.standard)
    }

    private func loadFavoriteURLs(_ defaults: UserDefaults) {
        if let savedFavs = defaults.stringArray(forKey: DefaultsKey.favoriteURLs.rawValue) {
            withRestoringDefaults {
                favoriteURLs = savedFavs.compactMap { path in
                    SlowVolumePathValidator.existsOptimistically(atPath: path) ? URL(fileURLWithPath: path) : nil
                }
            }
            Task { [weak self] in
                await self?.validateSlowVolumeFavorites()
            }
        } else {
            favoriteURLs = [
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop"),
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents"),
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
            ].filter { FileManager.default.fileExists(atPath: $0.path) }
        }
    }

    /// `/Volumes/` favorites are accepted optimistically above instead of a synchronous
    /// `fileExists` check that could stall init against a sleeping network share (same pattern as
    /// `NavigationStore.init`). Verifies them afterward and drops a favorite ONLY when its volume is
    /// mounted but the folder itself is gone — never when the whole `/Volumes/<name>` is offline,
    /// which would permanently wipe a hand-curated favorite over a transient state (MH-118).
    private func validateSlowVolumeFavorites() async {
        let slowPaths = Set(favoriteURLs.map(\.path).filter(SlowVolumePathValidator.isLikelySlowVolume))
        guard !slowPaths.isEmpty else { return }
        let mountRoots = Set(slowPaths.compactMap(SlowVolumePathValidator.volumeMountRoot(forPath:)))
        let pathsToCheck = slowPaths.union(mountRoots)

        let existence = await Task.detached(priority: .utility) {
            Dictionary(uniqueKeysWithValues: pathsToCheck.map { ($0, FileManager.default.fileExists(atPath: $0)) })
        }.value

        favoriteURLs = favoriteURLs.filter { url in
            guard SlowVolumePathValidator.isLikelySlowVolume(url.path) else { return true }
            if existence[url.path] ?? true {
                return true
            }
            return SlowVolumePathValidator.shouldKeepUnreachableSlowVolumePath(url.path, exists: existence)
        }
    }
}
