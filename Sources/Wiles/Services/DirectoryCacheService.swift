import Foundation

public final class DirectoryCacheService: @unchecked Sendable {
    public static let shared = DirectoryCacheService()

    /// Rough in-memory cost (bytes) per cached directory item: the name/owner/group/extension
    /// strings, tag array, four dates, and the retained `NSImage` icon wrapper. The old 128 was
    /// ~10× low, so `totalCostLimit` never actually bit and only `countLimit` bounded RAM.
    private static let estimatedBytesPerCachedItem = 1200

    /// A listing larger than this isn't cached at all — storing it would evict most of the cache
    /// for one folder, and the instant re-render fast path isn't worth that trade.
    private static let maxCacheableItemCount = 5000

    private let cache = NSCache<NSURL, DirectoryCacheEntry>()

    private init() {
        cache.countLimit = 50
        cache.totalCostLimit = 30 * 1024 * 1024 // 30 MB RAM limit
    }

    public func cacheDirectory(_ result: DirectoryLoadResult, for url: URL) {
        let key = url.standardizedFileURL as NSURL
        guard result.items.count <= Self.maxCacheableItemCount else {
            cache.removeObject(forKey: key)
            return
        }
        let entry = DirectoryCacheEntry(result: result)
        let cost = result.items.count * Self.estimatedBytesPerCachedItem
        cache.setObject(entry, forKey: key, cost: cost)
    }

    public func cachedResult(for url: URL) -> DirectoryLoadResult? {
        let key = url.standardizedFileURL as NSURL
        guard let entry = cache.object(forKey: key) else { return nil }
        guard !entry.isStale else {
            cache.removeObject(forKey: key)
            return nil
        }
        return entry.result
    }

    public func invalidate(url: URL) {
        let key = url.standardizedFileURL as NSURL
        cache.removeObject(forKey: key)
    }

    public func clearAll() {
        cache.removeAllObjects()
    }
}
