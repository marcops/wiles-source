import Foundation

/// Non-view directory-tree logic shared by the sidebar tree (`DirectoryTreeNodeView`) and the
/// folder-picker tree (`FolderPickerNodeView`), keeping both recursive views as thin shells.
extension FolderNode {
    /// Localized display name; `buildRootTree()`'s root carries a hardcoded "Root (/)" placeholder
    /// that both trees swap for the localized volume name.
    func displayName(rootLabel: String) -> String {
        url.path == "/" ? rootLabel : name
    }

    /// Eagerly-loaded `children` when present, else this folder's entry in the lazy `cache`.
    func resolvedChildren(in cache: BoundedFolderNodeCache) -> [FolderNode]? {
        children ?? cache[url]
    }

    /// Whether a lazy child-load should start: nothing resolved yet and no load already in flight.
    func needsChildLoad(cache: BoundedFolderNodeCache, inFlight: Set<URL>) -> Bool {
        resolvedChildren(in: cache) == nil && !inFlight.contains(url)
    }

    /// Loads immediate subfolders off the main actor — a stalled share must never block the UI
    /// (both trees previously inlined this `Task.detached` hop).
    static func loadChildrenOffMainActor(of url: URL) async -> [FolderNode] {
        await Task.detached(priority: .userInitiated) { Self.loadChildren(of: url) }.value
    }
}
