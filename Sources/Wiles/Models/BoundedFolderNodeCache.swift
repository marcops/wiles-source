import Foundation

/// Drop-in replacement for `[URL: [FolderNode]]` used by the sidebar's directory-tree cache —
/// same subscript-based access, but capped by estimated total byte size (not entry count) so a
/// long browsing session can't grow it without bound. Evicts oldest-inserted entries first once
/// the cap is exceeded.
struct BoundedFolderNodeCache {
    private var storage: [URL: [FolderNode]] = [:]
    private var insertionOrder: [URL] = []
    private var totalEstimatedBytes = 0
    private let maxBytes: Int
    /// Real backstop bound: at ~128 bytes/node, `maxBytes`' default alone would take roughly
    /// 800,000 nodes to trigger a single eviction, so a count cap is what actually bounds memory.
    private let maxEntryCount: Int

    private static let estimatedBytesPerNode = 128

    init(maxEntryCount: Int = 300, maxBytes: Int = 100 * 1024 * 1024) {
        self.maxEntryCount = maxEntryCount
        self.maxBytes = maxBytes
    }

    subscript(url: URL) -> [FolderNode]? {
        get { storage[url.standardizedFileURL] }
        set {
            let std = url.standardizedFileURL
            if let existing = storage.removeValue(forKey: std) {
                totalEstimatedBytes -= Self.estimatedBytes(for: existing)
                insertionOrder.removeAll { $0 == std }
            }
            guard let newValue else { return }
            storage[std] = newValue
            insertionOrder.append(std)
            totalEstimatedBytes += Self.estimatedBytes(for: newValue)
            evictIfNeeded()
        }
    }

    private mutating func evictIfNeeded() {
        while totalEstimatedBytes > maxBytes || storage.count > maxEntryCount, !insertionOrder.isEmpty {
            let oldest = insertionOrder.removeFirst()
            if let removed = storage.removeValue(forKey: oldest) {
                totalEstimatedBytes -= Self.estimatedBytes(for: removed)
            }
        }
    }

    private static func estimatedBytes(for nodes: [FolderNode]) -> Int {
        nodes.reduce(0) { $0 + estimatedBytesPerNode + $1.name.utf8.count + $1.url.absoluteString.utf8.count + estimatedBytes(for: $1.children ?? []) }
    }
}
