import Foundation
import GitBeacon

public extension AppState {
    func addFavorite(_ url: URL) {
        if !preferences.favorites.favoriteURLs.contains(where: { isSameLocation($0, url) }) {
            preferences.favorites.favoriteURLs.append(url.standardizedFileURL)
        }
    }

    func removeFavorite(_ url: URL) {
        preferences.favorites.favoriteURLs.removeAll { isSameLocation($0, url) }
    }

    func isFavorite(_ url: URL) -> Bool {
        // Fast path first: a plain standardized-path match needs no `stat`. Only fall back to
        // symlink resolution (one syscall) when the plain path isn't a direct member — covers a
        // favorite reached through a symlinked ancestor without a per-row stat storm.
        if preferences.favorites.standardizedFavoritePaths.contains(url.standardizedFileURL.path) {
            return true
        }
        guard !preferences.favorites.resolvedFavoritePaths.isEmpty else { return false }
        return preferences.favorites.resolvedFavoritePaths.contains(url.resolvingSymlinksInPath().standardizedFileURL.path)
    }

    /// Follows all path-keyed per-item state to an in-app relocation: `remapFavorites` (kept public
    /// for favorites-only cases and tests) plus the per-folder view mode key. Call after
    /// every in-app move.
    func remapRelocatedState(from oldURL: URL, to newURL: URL) {
        remapFavorites(from: oldURL, to: newURL)
        remapPerFolderViewMode(from: oldURL, to: newURL)
        // Both endpoints' cached listings are now stale; drop them so the next refresh can't flash old contents.
        DirectoryCacheService.shared.invalidate(url: oldURL.deletingLastPathComponent())
        DirectoryCacheService.shared.invalidate(url: newURL.deletingLastPathComponent())
    }

    /// "Same location" for favorites/path comparisons — resolves symlinks so a path reached via a
    /// symlinked ancestor (e.g. `~/Desktop` under iCloud Desktop & Documents sync) still matches its
    /// real target instead of silently going stale. `favoriteURLs` is always a short, hand-curated
    /// list, so the extra `stat` this involves is bounded and cheap here.
    private func isSameLocation(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.resolvingSymlinksInPath().standardizedFileURL == rhs.resolvingSymlinksInPath().standardizedFileURL
    }

    /// Favorites are stored as plain paths (`PreferencesStore.favoriteURLs`), not macOS bookmark
    /// data, so a favorited folder moved outside the app (Finder, another app) has no way to be
    /// re-found — that's a real capability gap, not a bug. But a move performed *inside* Wiles
    /// already gives us both the old and new URL in the same call, so there's no excuse for a
    /// favorite silently going stale in that case. Called by `moveItem(at:toFolder:)` above for
    /// every single-item in-app move; `AppState+Operations.executePaste` calls it directly too,
    /// since its bulk-move loop must keep the actual disk move off `@MainActor` (DEV_RULES.md pre-commit checklist "Sequential Bulk Disk I/O on the Main
    /// Actor") and
    /// can only hop back to `@MainActor` for this lightweight favorites sync, not the whole
    /// `moveItem(at:toFolder:)` wrapper. Not `public` — not meant as a general entry point outside
    /// AppState's own move paths. Handles both the favorited item itself moving and a favorited
    /// item nested inside a moved ancestor folder.
    func remapFavorites(from oldURL: URL, to newURL: URL) {
        let oldStd = oldURL.resolvingSymlinksInPath().standardizedFileURL
        let newStd = newURL.standardizedFileURL
        var updated = preferences.favorites.favoriteURLs
        var didChange = false
        for (index, favorite) in updated.enumerated() {
            let favStd = favorite.resolvingSymlinksInPath().standardizedFileURL
            if favStd == oldStd {
                updated[index] = newStd
                didChange = true
            } else if favStd.path.hasPrefix(oldStd.path + "/") {
                // swiftlint:disable:previous no_naive_path_prefix_check — trailing "/" already appended above, the exact safe pattern this rule recommends.
                let relativePath = String(favStd.path.dropFirst(oldStd.path.count))
                updated[index] = URL(fileURLWithPath: newStd.path + relativePath)
                didChange = true
            }
        }
        guard didChange else { return }
        preferences.favorites.favoriteURLs = updated
    }

    func moveSelectedFavorite(offset: Int, windowUIState: WindowUIState) {
        guard let selected = windowUIState.selectedFavoriteURL,
              isSameLocation(selected, navigation.currentURL),
              let index = preferences.favorites.favoriteURLs.firstIndex(where: { isSameLocation($0, selected) }) else { return }
        let newIndex = index + offset
        guard preferences.favorites.favoriteURLs.indices.contains(newIndex) else { return }
        preferences.favorites.favoriteURLs.swapAt(index, newIndex)
    }
}
