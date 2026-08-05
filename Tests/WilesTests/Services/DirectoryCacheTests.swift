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
        testClearAllRemovesMultipleEntries()
        testCachingOverwritesExistingEntry()
        testStandardizedURLEquivalence()
        testInvalidateNonExistentURLIsNoOp()
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
        let dirURL = URL(fileURLWithPath: (tempDir as NSString).appendingPathComponent("Subfolder-\(UUID().uuidString)"))
        try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let pngItem = FileItem(url: pngURL, icon: NSImage())
        let pdfItem = FileItem(url: pdfURL, icon: NSImage())
        let txtItem = FileItem(url: txtURL, icon: NSImage())
        let mdItem = FileItem(url: mdURL, icon: NSImage())
        let dirItem = FileItem(url: dirURL, icon: NSImage())

        // Positive check: supportsThumbnail identifies images and PDFs
        report("ThumbnailService", "POS: supportsThumbnail returns true for .png", result: ThumbnailService.supportsThumbnail(item: pngItem))
        report("ThumbnailService", "POS: supportsThumbnail returns true for .pdf", result: ThumbnailService.supportsThumbnail(item: pdfItem))
        report("ThumbnailService", "NEG: supportsThumbnail returns false for .txt (native file icon preserved)", result: !ThumbnailService.supportsThumbnail(item: txtItem))
        report("ThumbnailService", "NEG: supportsThumbnail returns false for .md (native file icon preserved)", result: !ThumbnailService.supportsThumbnail(item: mdItem))

        // Negative check: supportsThumbnail returns false for directories
        report("ThumbnailService", "NEG: supportsThumbnail returns false for directories", result: !ThumbnailService.supportsThumbnail(item: dirItem))

        // Positive/Negative prefetch execution safely accepts all item types without throwing or crashing
        ThumbnailService.shared.prefetchThumbnails(for: [pngItem, pdfItem, txtItem, mdItem, dirItem], size: 48)
        report("ThumbnailService", "POS: prefetchThumbnails handles array containing images, PDFs, text, and directories gracefully", result: true)
    }

    private static func testClearAllRemovesMultipleEntries() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = DirectoryCacheService.shared
        let urlA = dir.appendingPathComponent("clear-all-a-\(UUID().uuidString)")
        let urlB = dir.appendingPathComponent("clear-all-b-\(UUID().uuidString)")
        service.cacheDirectory(sampleResult(), for: urlA)
        service.cacheDirectory(sampleResult(), for: urlB)
        report("DirectoryCache", "POS: both entries exist before clearAll()", result: service.cachedResult(for: urlA) != nil && service.cachedResult(for: urlB) != nil)

        service.clearAll()
        report("DirectoryCache", "NEG: clearAll() removes an entry cached under urlA", result: service.cachedResult(for: urlA) == nil)
        report("DirectoryCache", "NEG: clearAll() removes an entry cached under urlB", result: service.cachedResult(for: urlB) == nil)
    }

    private static func testCachingOverwritesExistingEntry() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = DirectoryCacheService.shared
        let url = dir.appendingPathComponent("overwrite-\(UUID().uuidString)")

        let itemURL = dir.appendingPathComponent("one-item.txt")
        let firstItem = FileItem(url: itemURL, icon: NSWorkspace.shared.icon(forFile: itemURL.path))
        let firstResult = DirectoryLoadResult(items: [firstItem], isPermissionDenied: false)
        service.cacheDirectory(firstResult, for: url)
        report("DirectoryCache", "POS: first cacheDirectory() call stores a single-item result", result: service.cachedResult(for: url)?.items.count == 1)

        let itemURL2 = dir.appendingPathComponent("two-item.txt")
        let secondItem = FileItem(url: itemURL2, icon: NSWorkspace.shared.icon(forFile: itemURL2.path))
        let secondResult = DirectoryLoadResult(items: [firstItem, secondItem], isPermissionDenied: true)
        service.cacheDirectory(secondResult, for: url)
        let overwritten = service.cachedResult(for: url)
        report("DirectoryCache", "POS: re-caching the same URL overwrites item count", result: overwritten?.items.count == 2)
        report("DirectoryCache", "POS: re-caching the same URL overwrites isPermissionDenied flag", result: overwritten?.isPermissionDenied == true)
    }

    private static func testStandardizedURLEquivalence() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = DirectoryCacheService.shared
        let name = "standardize-\(UUID().uuidString)"
        let plainURL = dir.appendingPathComponent(name)
        // Build an equivalent but non-canonical path via a redundant "sibling/.." hop.
        let messyURL = dir.appendingPathComponent("sibling-\(UUID().uuidString)").appendingPathComponent("..").appendingPathComponent(name)

        service.invalidate(url: plainURL)
        service.cacheDirectory(sampleResult(), for: plainURL)
        report("DirectoryCache", "POS: entry cached under a canonical path is found via an equivalent non-canonical path", result: service.cachedResult(for: messyURL) != nil)

        service.invalidate(url: messyURL)
        report("DirectoryCache", "POS: invalidating via the non-canonical path removes the entry cached under the canonical path", result: service.cachedResult(for: plainURL) == nil)
    }

    private static func testInvalidateNonExistentURLIsNoOp() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = DirectoryCacheService.shared
        let neverCachedURL = dir.appendingPathComponent("never-cached-\(UUID().uuidString)")
        let unrelatedURL = dir.appendingPathComponent("unrelated-\(UUID().uuidString)")
        service.cacheDirectory(sampleResult(), for: unrelatedURL)

        service.invalidate(url: neverCachedURL)

        report("DirectoryCache", "NEG: invalidating a URL with no cached entry does not throw or crash", result: true)
        report("DirectoryCache", "POS: invalidating an unrelated URL leaves an existing entry untouched", result: service.cachedResult(for: unrelatedURL) != nil)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
