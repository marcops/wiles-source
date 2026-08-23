import Foundation

public extension AppState {
    func addFavorite(_ url: URL) {
        if !preferences.favoriteURLs.contains(where: { isSameLocation($0, url) }) {
            preferences.favoriteURLs.append(url.standardizedFileURL)
        }
    }

    func removeFavorite(_ url: URL) {
        preferences.favoriteURLs.removeAll { isSameLocation($0, url) }
    }

    func isFavorite(_ url: URL) -> Bool {
        preferences.favoriteURLs.contains(where: { isSameLocation($0, url) })
    }

    /// "Same location" for favorites/path comparisons — resolves symlinks so a path reached via a
    /// symlinked ancestor (e.g. `~/Desktop` under iCloud Desktop & Documents sync) still matches its
    /// real target instead of silently going stale. `favoriteURLs` is always a short, hand-curated
    /// list, so the extra `stat` this involves is bounded and cheap here.
    private func isSameLocation(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.resolvingSymlinksInPath().standardizedFileURL == rhs.resolvingSymlinksInPath().standardizedFileURL
    }

    /// Single entry point for every in-app move (cut/paste, drag onto a folder row, breadcrumb
    /// drop, sidebar-favorite drop) — moves the item on disk, then keeps favorites in sync. Every
    /// call site should go through this, not call `FileSystemService.moveItem` directly, so a
    /// second in-app move location can never again forget to re-sync favorites (see
    /// `remapFavorites` below for why it must be called after every move).
    @discardableResult
    func moveItem(at url: URL, toFolder targetFolder: URL) async throws -> URL {
        let destURL = try await FileSystemService.moveItem(at: url, toFolder: targetFolder)
        remapFavorites(from: url, to: destURL)
        return destURL
    }

    /// Favorites are stored as plain paths (`PreferencesStore.favoriteURLs`), not macOS bookmark
    /// data, so a favorited folder moved outside the app (Finder, another app) has no way to be
    /// re-found — that's a real capability gap, not a bug. But a move performed *inside* Wiles
    /// already gives us both the old and new URL in the same call, so there's no excuse for a
    /// favorite silently going stale in that case. Called by `moveItem(at:toFolder:)` above for
    /// every single-item in-app move; `AppState+Operations.executePaste` calls it directly too,
    /// since its bulk-move loop must keep the actual disk move off `@MainActor` (rule 29.16) and
    /// can only hop back to `@MainActor` for this lightweight favorites sync, not the whole
    /// `moveItem(at:toFolder:)` wrapper. Not `public` — not meant as a general entry point outside
    /// AppState's own move paths. Handles both the favorited item itself moving and a favorited
    /// item nested inside a moved ancestor folder.
    func remapFavorites(from oldURL: URL, to newURL: URL) {
        let oldStd = oldURL.resolvingSymlinksInPath().standardizedFileURL
        let newStd = newURL.standardizedFileURL
        var updated = preferences.favoriteURLs
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
        preferences.favoriteURLs = updated
    }

    func moveSelectedFavorite(offset: Int, windowUIState: WindowUIState) {
        guard let selected = windowUIState.selectedFavoriteURL,
              isSameLocation(selected, navigation.currentURL),
              let index = preferences.favoriteURLs.firstIndex(where: { isSameLocation($0, selected) }) else { return }
        let newIndex = index + offset
        guard preferences.favoriteURLs.indices.contains(newIndex) else { return }
        preferences.favoriteURLs.swapAt(index, newIndex)
    }
}
