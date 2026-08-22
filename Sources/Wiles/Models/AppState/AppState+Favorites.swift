import Foundation

public extension AppState {
    func addFavorite(_ url: URL) {
        let std = url.standardizedFileURL
        if !preferences.favoriteURLs.contains(where: { $0.standardizedFileURL == std }) {
            preferences.favoriteURLs.append(std)
        }
    }

    func removeFavorite(_ url: URL) {
        let std = url.standardizedFileURL
        preferences.favoriteURLs.removeAll { $0.standardizedFileURL == std }
    }

    func isFavorite(_ url: URL) -> Bool {
        let std = url.standardizedFileURL
        return preferences.favoriteURLs.contains(where: { $0.standardizedFileURL == std })
    }

    /// Single entry point for every in-app move (cut/paste, drag onto a folder row, breadcrumb
    /// drop, sidebar-favorite drop) — moves the item on disk, then keeps favorites in sync. Every
    /// call site should go through this, not call `FileSystemService.moveItem` directly, so a
    /// second in-app move location can never again forget to re-sync favorites (see
    /// `remapFavorites` below for why it must be called after every move).
    @discardableResult
    func moveItem(at url: URL, toFolder targetFolder: URL) throws -> URL {
        let destURL = try FileSystemService.moveItem(at: url, toFolder: targetFolder)
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
        let oldStd = oldURL.standardizedFileURL
        let newStd = newURL.standardizedFileURL
        for (index, favorite) in preferences.favoriteURLs.enumerated() {
            let favStd = favorite.standardizedFileURL
            if favStd == oldStd {
                preferences.favoriteURLs[index] = newStd
            } else if favStd.path.hasPrefix(oldStd.path + "/") {
                let relativePath = String(favStd.path.dropFirst(oldStd.path.count))
                preferences.favoriteURLs[index] = URL(fileURLWithPath: newStd.path + relativePath)
            }
        }
    }

    func moveSelectedFavorite(offset: Int, windowUIState: WindowUIState) {
        guard let selected = windowUIState.selectedFavoriteURL?.standardizedFileURL,
              selected == navigation.currentURL.standardizedFileURL,
              let index = preferences.favoriteURLs.firstIndex(where: { $0.standardizedFileURL == selected }) else { return }
        let newIndex = index + offset
        guard preferences.favoriteURLs.indices.contains(newIndex) else { return }
        preferences.favoriteURLs.swapAt(index, newIndex)
    }
}
