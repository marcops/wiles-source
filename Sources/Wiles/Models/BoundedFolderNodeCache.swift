import Foundation

/// Drop-in replacement for `[URL: [FolderNode]]` used by the sidebar's directory-tree cache —
/// same subscript-based access, but capped at `maxEntryCount` entries so a long browsing session
/// can't grow it without bound. Evicts oldest-inserted entries first once the cap is exceeded.
struct BoundedFolderNodeCache {
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

    private mutating func evictIfNeeded() {
        while storage.count > maxEntryCount, !insertionOrder.isEmpty {
            let oldest = insertionOrder.removeFirst()
            storage.removeValue(forKey: oldest)
        }
    }
}
