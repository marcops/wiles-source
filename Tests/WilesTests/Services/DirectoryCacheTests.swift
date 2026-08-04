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
        let pdfURL = URL(fileURLWithPath: (tempDir as NSString).appendingPathComponent("document.pdf"))
        let txtURL = URL(fileURLWithPath: (tempDir as NSString).appendingPathComponent("readme.txt"))
        let mdURL = URL(fileURLWithPath: (tempDir as NSString).appendingPathComponent("notes.md"))
        let dirURL = URL(fileURLWithPath: (tempDir as NSString).appendingPathComponent("Subfolder"))

        let pngItem = FileItem(url: pngURL, icon: NSImage())
        let pdfItem = FileItem(url: pdfURL, icon: NSImage())
        let txtItem = FileItem(url: txtURL, icon: NSImage())
        let mdItem = FileItem(url: mdURL, icon: NSImage())
        let dirItem = FileItem(url: dirURL, icon: NSImage())

        // Positive check: supportsThumbnail identifies images, PDFs, TXT, MD
        report("ThumbnailService", "POS: supportsThumbnail returns true for .png", result: ThumbnailService.supportsThumbnail(item: pngItem))
        report("ThumbnailService", "POS: supportsThumbnail returns true for .pdf", result: ThumbnailService.supportsThumbnail(item: pdfItem))
        report("ThumbnailService", "POS: supportsThumbnail returns true for .txt", result: ThumbnailService.supportsThumbnail(item: txtItem))
        report("ThumbnailService", "POS: supportsThumbnail returns true for .md", result: ThumbnailService.supportsThumbnail(item: mdItem))

        // Negative check: supportsThumbnail returns false for directories
        report("ThumbnailService", "NEG: supportsThumbnail returns false for directories", result: !ThumbnailService.supportsThumbnail(item: dirItem))

        // Positive/Negative prefetch execution safely accepts all item types without throwing or crashing
        ThumbnailService.shared.prefetchThumbnails(for: [pngItem, pdfItem, txtItem, mdItem, dirItem], size: 48)
        report("ThumbnailService", "POS: prefetchThumbnails handles array containing images, PDFs, text, and directories gracefully", result: true)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
