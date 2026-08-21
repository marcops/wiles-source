import Foundation

public final class DirectoryCacheService: @unchecked Sendable {
    public static let shared = DirectoryCacheService()

    /// Rough estimated in-memory cost (bytes) per cached directory item, used to scale
    /// `NSCache`'s cost accounting against `totalCostLimit`.
    private static let estimatedBytesPerCachedItem = 128

    private let cache = NSCache<NSURL, DirectoryCacheEntry>()

    private init() {
        cache.countLimit = 50
        cache.totalCostLimit = 30 * 1024 * 1024 // 30 MB RAM limit
    }

    public func cacheDirectory(_ result: DirectoryLoadResult, for url: URL) {
        let key = url.standardizedFileURL as NSURL
        let entry = DirectoryCacheEntry(result: result)
        let cost = result.items.count * Self.estimatedBytesPerCachedItem
        cache.setObject(entry, forKey: key, cost: cost)
    }

    public func cachedResult(for url: URL) -> DirectoryLoadResult? {
        let key = url.standardizedFileURL as NSURL
        return cache.object(forKey: key)?.result
    }

    public func invalidate(url: URL) {
        let key = url.standardizedFileURL as NSURL
        cache.removeObject(forKey: key)
    }

    public func clearAll() {
        cache.removeAllObjects()
    }
}
