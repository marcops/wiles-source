import Foundation

/// Drop-in replacement for `[URL: [FolderNode]]` used by the directory-tree caches (sidebar tree and
/// folder picker), same subscript-based access, but capped at `maxEntryCount` entries so a long
/// browsing session can't grow it without bound. Evicts oldest-inserted entries first once the cap
/// is exceeded.
///
/// `final class`, not `struct` (MM-freeze-fix): both trees used to thread this as a `@Binding` shared
/// across EVERY recursive node view. Since it wasn't `Equatable`, SwiftUI could not tell that one
/// node's cache write was irrelevant to another's rendering — every node sharing the binding got
/// re-evaluated on every OTHER node's independent completion. With many previously-expanded sidebar
/// folders restored from `expandedTreePaths` at once (persisted, capped at 500), each firing its own
/// concurrent off-main load, this compounded into an O(n²)-ish render cascade that looked like a
/// frozen UI until a scroll-triggered layout pass caught it up. As a plain reference type passed
/// directly (not through `@Binding`/`@Observable`), a write here is invisible to SwiftUI's dependency
/// tracking — callers that need a visual update once THEIR OWN load lands must signal it via their
/// own local `@State`, not by relying on this cache's mutation (see `DirectoryTreeNodeView`).
/// `@unchecked Sendable`: only ever read/written from `@MainActor`-isolated View bodies/tasks, never
/// concurrently — same pattern already used by other MainActor-only reference types in this codebase.
final class BoundedFolderNodeCache: @unchecked Sendable {
    private var storage: [URL: [FolderNode]] = [:]
    private var insertionOrder: [URL] = []
    private let maxEntryCount: Int

    init(maxEntryCount: Int = 300) {
        self.maxEntryCount = maxEntryCount
    }

    /// Standardized URLs currently held, for callers that need to skip an already-loaded folder.
    var cachedURLs: Set<URL> {
        Set(storage.keys)
    }

    subscript(url: URL) -> [FolderNode]? {
        get { storage[url.standardizedFileURL] }
        set {
            let std = url.standardizedFileURL
            if storage.removeValue(forKey: std) != nil {
                insertionOrder.removeAll { $0 == std }
            }
            guard let newValue else { return }
            storage[std] = newValue
            insertionOrder.append(std)
            evictIfNeeded()
        }
    }

    private func evictIfNeeded() {
        while storage.count > maxEntryCount, !insertionOrder.isEmpty {
            let oldest = insertionOrder.removeFirst()
            storage.removeValue(forKey: oldest)
        }
    }
}
