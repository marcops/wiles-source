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
            resolvedFavoritePaths = Set(favoriteURLs.map { $0.resolvingSymlinksInPath().standardizedFileURL.path })
            guard !isRestoringDefaults else { return }
            persist(favoriteURLs.map(\.path), .favoriteURLs)
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
    /// `NavigationStore.init`). Verifies them afterward and drops any that turned out to be gone.
    private func validateSlowVolumeFavorites() async {
        let pathsToCheck = Set(favoriteURLs.map(\.path).filter(SlowVolumePathValidator.isLikelySlowVolume))
        guard !pathsToCheck.isEmpty else { return }

        let existence = await Task.detached(priority: .utility) {
            Dictionary(uniqueKeysWithValues: pathsToCheck.map { ($0, FileManager.default.fileExists(atPath: $0)) })
        }.value

        favoriteURLs = favoriteURLs.filter { existence[$0.path] ?? true }
    }
}
