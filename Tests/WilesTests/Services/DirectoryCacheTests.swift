@testable import Wiles
import Foundation
import AppKit

@MainActor
public struct DirectoryCacheTests {
    public static func run() {
        testCacheAndRetrieveRoundTrip()
        testUncachedURLReturnsNil()
        testInvalidateRemovesEntry()
        testThumbnailPrefetchPositiveAndNegative()
    }

    private static func sampleResult() -> DirectoryLoadResult {
        let tempDir = NSTemporaryDirectory()
        let url = URL(fileURLWithPath: (tempDir as NSString).appendingPathComponent("cache-test-item.txt"))
        let item = FileItem(url: url, icon: NSWorkspace.shared.icon(forFile: url.path))
        return DirectoryLoadResult(items: [item], isPermissionDenied: false)
    }

    private static func testCacheAndRetrieveRoundTrip() {
        let tempDir = NSTemporaryDirectory()
        let url = URL(fileURLWithPath: (tempDir as NSString).appendingPathComponent("cache-test-dir-\(UUID().uuidString)"))
        let service = DirectoryCacheService.shared
        service.invalidate(url: url)

        report("DirectoryCache", "NEG: nothing cached yet for a fresh URL", result: service.cachedResult(for: url) == nil)

        let result = sampleResult()
        service.cacheDirectory(result, for: url)
        let cached = service.cachedResult(for: url)
        report("DirectoryCache", "POS: cached result round-trips with the same item count", result: cached?.items.count == result.items.count)
    }

    private static func testUncachedURLReturnsNil() {
        let tempDir = NSTemporaryDirectory()
        let url = URL(fileURLWithPath: (tempDir as NSString).appendingPathComponent("never-cached-\(UUID().uuidString)"))
        let cached = DirectoryCacheService.shared.cachedResult(for: url)
        report("DirectoryCache", "NEG: querying an untouched URL returns nil", result: cached == nil)
    }

    private static func testInvalidateRemovesEntry() {
        let tempDir = NSTemporaryDirectory()
        let url = URL(fileURLWithPath: (tempDir as NSString).appendingPathComponent("cache-invalidate-\(UUID().uuidString)"))
        let service = DirectoryCacheService.shared
        service.cacheDirectory(sampleResult(), for: url)
        report("DirectoryCache", "POS: entry exists right after caching", result: service.cachedResult(for: url) != nil)

        service.invalidate(url: url)
        report("DirectoryCache", "POS: invalidate() removes the cached entry", result: service.cachedResult(for: url) == nil)
    }

    private static func testThumbnailPrefetchPositiveAndNegative() {
        let tempDir = NSTemporaryDirectory()
        let pngURL = URL(fileURLWithPath: (tempDir as NSString).appendingPathComponent("test-sample.png"))
        let txtURL = URL(fileURLWithPath: (tempDir as NSString).appendingPathComponent("test-sample.txt"))

        let pngItem = FileItem(url: pngURL, icon: NSImage())
        let txtItem = FileItem(url: txtURL, icon: NSImage())

        // Positive check: isImage correctly identifies .png vs .txt
        let isPngImage = ThumbnailService.isImage(fileExtension: pngItem.fileExtension)
        let isTxtImage = ThumbnailService.isImage(fileExtension: txtItem.fileExtension)
        report("ThumbnailService", "POS: isImage correctly returns true for .png", result: isPngImage)
        report("ThumbnailService", "NEG: isImage correctly returns false for .txt", result: !isTxtImage)

        // Positive/Negative prefetch execution safely accepts items without throwing or crashing
        ThumbnailService.shared.prefetchThumbnails(for: [pngItem, txtItem], size: 48)
        report("ThumbnailService", "POS: prefetchThumbnails handles array containing both image and non-image items gracefully", result: true)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
