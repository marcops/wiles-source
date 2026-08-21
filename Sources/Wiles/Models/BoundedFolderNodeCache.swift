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

    private static let estimatedBytesPerNode = 128

    init(maxBytes: Int = 100 * 1024 * 1024) {
        self.maxBytes = maxBytes
    }

    subscript(url: URL) -> [FolderNode]? {
        get { storage[url] }
        set {
            if let existing = storage.removeValue(forKey: url) {
                totalEstimatedBytes -= Self.estimatedBytes(for: existing)
                insertionOrder.removeAll { $0 == url }
            }
            guard let newValue else { return }
            storage[url] = newValue
            insertionOrder.append(url)
            totalEstimatedBytes += Self.estimatedBytes(for: newValue)
            evictIfNeeded()
        }
    }

    private mutating func evictIfNeeded() {
        while totalEstimatedBytes > maxBytes, !insertionOrder.isEmpty {
            let oldest = insertionOrder.removeFirst()
            if let removed = storage.removeValue(forKey: oldest) {
                totalEstimatedBytes -= Self.estimatedBytes(for: removed)
            }
        }
    }

    private static func estimatedBytes(for nodes: [FolderNode]) -> Int {
        nodes.reduce(0) { $0 + estimatedBytesPerNode + $1.name.utf8.count + $1.url.absoluteString.utf8.count }
    }
}
