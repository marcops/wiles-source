import Foundation
import GitBeacon

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
        preferences.resolvedFavoritePaths.contains(url.resolvingSymlinksInPath().standardizedFileURL.path)
    }

    /// Follows all path-keyed per-item state to an in-app relocation: `remapFavorites` (kept public
    /// for favorites-only cases and tests) plus the per-folder view mode key. Call after
    /// every in-app move.
    func remapRelocatedState(from oldURL: URL, to newURL: URL) {
        remapFavorites(from: oldURL, to: newURL)
        remapPerFolderViewMode(from: oldURL, to: newURL)
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
    func moveItem(
        at url: URL,
        toFolder targetFolder: URL,
        onCollision: MoveCollisionPolicy = .failIfExists) async throws -> URL {
        let destURL = try await FileSystemService.moveItem(at: url, toFolder: targetFolder, onCollision: onCollision)
        remapRelocatedState(from: url, to: destURL)
        return destURL
    }

    /// Moves each URL into `targetFolder` sequentially via `moveOneResolvingCollision` (the same
    /// per-item mover the cut/paste loop uses), aggregating failures into one alert. `.cancel` stops
    /// the batch. Used by the drag-onto-folder and breadcrumb-drop paths, which don't record undo.
    @discardableResult
    func moveItemsResolvingCollisions(
        _ urls: [URL],
        toFolder targetFolder: URL,
        windowUIState: WindowUIState) async -> [URL] {
        var sticky: MoveCollisionChoice.Action?
        var moved: [URL] = []
        var failureCount = 0
        for (index, url) in urls.enumerated() {
            guard !Task.isCancelled else { break }
            do {
                let (outcome, newSticky) = try await moveOneResolvingCollision(
                    url, into: targetFolder, sticky: sticky,
                    moreFollow: index < urls.count - 1, windowUIState: windowUIState)
                sticky = newSticky
                switch outcome {
                case let .moved(dest, _): moved.append(dest)
                case .skipped: break
                case .cancelled: return finishBatchMove(moved, failureCount: failureCount, total: urls.count)
                }
            } catch {
                ErrorReporter.report(error, context: "Moving item into folder")
                failureCount += 1
            }
        }
        return finishBatchMove(moved, failureCount: failureCount, total: urls.count)
    }

    private func finishBatchMove(_ moved: [URL], failureCount: Int, total: Int) -> [URL] {
        if failureCount > 0 {
            showError(WilesError.operationFailed(reason: "\(failureCount) of \(total) items could not be moved."))
        }
        return moved
    }

    /// Moves one item into `targetFolder`, resolving a name collision via the per-window prompt
    /// (Replace / Keep Both / Cancel, with "apply to all") and keeping favorites/view-mode keys in
    /// sync. Records no undo — the caller does, since only some callers want it. Returns the outcome
    /// and the (possibly updated) sticky choice for the rest of the batch.
    internal func moveOneResolvingCollision(
        _ url: URL,
        into targetFolder: URL,
        sticky: MoveCollisionChoice.Action?,
        moreFollow: Bool,
        windowUIState: WindowUIState?) async throws -> (BatchMoveOutcome, MoveCollisionChoice.Action?) {
        do {
            let dest = try await FileSystemService.moveItem(at: url, toFolder: targetFolder)
            remapRelocatedState(from: url, to: dest)
            return (.moved(to: dest, displacedExisting: false), sticky)
        } catch WilesError.destinationExists {
            guard let windowUIState else { return (.skipped, sticky) }
            let resolution = await resolveCollision(
                itemName: url.lastPathComponent, moreCollisionsPossible: moreFollow,
                sticky: sticky, windowUIState: windowUIState)
            if resolution.action == .cancel {
                return (.cancelled, resolution.sticky)
            }
            let isReplace = resolution.action == .replace
            let policy: MoveCollisionPolicy = isReplace ? .replace : .keepBoth
            let dest = try await FileSystemService.moveItem(at: url, toFolder: targetFolder, onCollision: policy)
            remapRelocatedState(from: url, to: dest)
            return (.moved(to: dest, displacedExisting: isReplace), resolution.sticky)
        }
    }

    /// Resolves one name collision: returns the remembered `sticky` action if the user already chose
    /// "apply to all", otherwise prompts and returns the new sticky (non-nil only if they checked it).
    /// Shared by `moveItemsResolvingCollisions` and the cut/paste loop.
    func resolveCollision(
        itemName: String,
        moreCollisionsPossible: Bool,
        sticky: MoveCollisionChoice.Action?,
        windowUIState: WindowUIState) async -> (action: MoveCollisionChoice.Action, sticky: MoveCollisionChoice.Action?) {
        if let sticky {
            return (sticky, sticky)
        }
        let choice = await windowUIState.promptMoveCollision(itemName: itemName, showApplyToAll: moreCollisionsPossible)
        return (choice.action, choice.applyToAll ? choice.action : nil)
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
