@testable import Wiles
import Foundation
import AppKit

@MainActor
public struct DirectoryCacheTests {
    public static func run() {
        testCacheAndRetrieveRoundTrip()
        testUncachedURLReturnsNil()
        testInvalidateRemovesEntry()
    }

    private static func sampleResult() -> DirectoryLoadResult {
        let url = URL(fileURLWithPath: "/tmp/cache-test-item.txt")
        let item = FileItem(url: url, icon: NSWorkspace.shared.icon(forFile: url.path))
        return DirectoryLoadResult(items: [item], isPermissionDenied: false)
    }

    private static func testCacheAndRetrieveRoundTrip() {
        let url = URL(fileURLWithPath: "/tmp/cache-test-dir-\(UUID().uuidString)")
        let service = DirectoryCacheService.shared
        service.invalidate(url: url)

        report("DirectoryCache", "NEG: nothing cached yet for a fresh URL", result: service.cachedResult(for: url) == nil)

        let result = sampleResult()
        service.cacheDirectory(result, for: url)
        let cached = service.cachedResult(for: url)
        report("DirectoryCache", "POS: cached result round-trips with the same item count", result: cached?.items.count == result.items.count)
    }

    private static func testUncachedURLReturnsNil() {
        let url = URL(fileURLWithPath: "/tmp/never-cached-\(UUID().uuidString)")
        let cached = DirectoryCacheService.shared.cachedResult(for: url)
        report("DirectoryCache", "NEG: querying an untouched URL returns nil", result: cached == nil)
    }

    private static func testInvalidateRemovesEntry() {
        let url = URL(fileURLWithPath: "/tmp/cache-invalidate-\(UUID().uuidString)")
        let service = DirectoryCacheService.shared
        service.cacheDirectory(sampleResult(), for: url)
        report("DirectoryCache", "POS: entry exists right after caching", result: service.cachedResult(for: url) != nil)

        service.invalidate(url: url)
        report("DirectoryCache", "POS: invalidate() removes the cached entry", result: service.cachedResult(for: url) == nil)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
