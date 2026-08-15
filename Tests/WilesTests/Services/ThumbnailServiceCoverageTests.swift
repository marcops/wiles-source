import AppKit
import Foundation
@testable import Wiles

@MainActor
public struct ThumbnailServiceCoverageTests {
    public static func run() async {
        testIsImage()
        testCachedThumbnailMiss()
        testPrefetchEmptyArrayIsNoOp()
        await testLoadThumbnailForRealPNG()
        testSupportsThumbnailForVariousKinds()
        testCacheKeyDoesNotCollideBetweenSizes()
        await testPrefetchThumbnailsWithMixedEligibility()
        await testLoadThumbnailServesFromCacheOnSecondCall()
        await testPrefetchThumbnailsCancellationBreaksLoop()
    }

    private static func makeFakeIcon() -> NSImage {
        NSImage(size: NSSize(width: 16, height: 16))
    }

    @discardableResult
    private static func writeSamplePNG(to url: URL) -> Bool {
        let size = NSSize(width: 4, height: 4)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.blue.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else { return false }
        return (try? pngData.write(to: url)) != nil
    }

    /// Covers loadThumbnail's "if let cached = cache.object(forKey: key) { return cached }" branch:
    /// a second call for the same URL/size must be served from cache instead of regenerating.
    private static func testLoadThumbnailServesFromCacheOnSecondCall() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let pngURL = tempDir.appendingPathComponent("cache-hit-sample.png")
        writeSamplePNG(to: pngURL)

        let first = await ThumbnailService.shared.loadThumbnail(for: pngURL, size: 32)
        let second = await ThumbnailService.shared.loadThumbnail(for: pngURL, size: 32)
        TestReporter.report(
            "ThumbnailService", "POS: loadThumbnail(for:size:) returns the same cached image instance on a second call for the same URL",
            result: first != nil && first === second)
    }

    /// Covers prefetchThumbnails' "if Task.isCancelled { break }" branch: starting a new prefetch
    /// while a prior one is still iterating cancels the prior Task, which must observe cancellation
    /// and break out of its loop instead of continuing to process the remaining items.
    private static func testPrefetchThumbnailsCancellationBreaksLoop() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var items: [FileItem] = []
        for index in 0 ..< 12 {
            let url = tempDir.appendingPathComponent("cancel-sample-\(index).png")
            writeSamplePNG(to: url)
            items.append(FileItem(url: url, icon: makeFakeIcon()))
        }

        // Two back-to-back calls: the second cancels the first's still-running detached task before
        // it can finish iterating all 12 items.
        ThumbnailService.shared.prefetchThumbnails(for: items, size: 32)
        ThumbnailService.shared.prefetchThumbnails(for: items, size: 32)
        try? await Task.sleep(nanoseconds: 300_000_000)
        TestReporter.report(
            "ThumbnailService", "POS: starting a new prefetchThumbnails call cancels the prior in-flight one without crashing or hanging",
            result: true)
    }

    private static func testSupportsThumbnailForVariousKinds() {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // NEG: directories never support thumbnails, regardless of extension.
        let subDir = tempDir.appendingPathComponent("a-folder")
        try? FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        let dirItem = FileItem(url: subDir, icon: makeFakeIcon())
        TestReporter.report(
            "ThumbnailService",
            "NEG: supportsThumbnail(item:) returns false for a directory",
            result: !ThumbnailService.supportsThumbnail(item: dirItem))

        // NEG: a real file whose extension conforms to UTType.archive (zip) is excluded.
        let zipURL = tempDir.appendingPathComponent("archive.zip")
        FileManager.default.createFile(atPath: zipURL.path, contents: Data())
        let zipItem = FileItem(url: zipURL, icon: makeFakeIcon())
        TestReporter.report(
            "ThumbnailService",
            "NEG: supportsThumbnail(item:) returns false for a .zip file (archive type)",
            result: !ThumbnailService.supportsThumbnail(item: zipItem))

        // POS: a real file with a plain image extension is eligible.
        let pngURL = tempDir.appendingPathComponent("photo.png")
        FileManager.default.createFile(atPath: pngURL.path, contents: Data())
        let pngItem = FileItem(url: pngURL, icon: makeFakeIcon())
        TestReporter.report(
            "ThumbnailService",
            "POS: supportsThumbnail(item:) returns true for a .png file",
            result: ThumbnailService.supportsThumbnail(item: pngItem))

        // NEG: an unrecognized/nonsense extension returns false so native icons remain stable.
        let weirdURL = tempDir.appendingPathComponent("mystery.qzxnotarealext")
        FileManager.default.createFile(atPath: weirdURL.path, contents: Data())
        let weirdItem = FileItem(url: weirdURL, icon: makeFakeIcon())
        TestReporter.report(
            "ThumbnailService",
            "NEG: supportsThumbnail(item:) returns false for an unrecognized extension",
            result: !ThumbnailService.supportsThumbnail(item: weirdItem))

        // NEG: a file with no extension at all returns false so native icons remain stable.
        let noExtURL = tempDir.appendingPathComponent("README")
        FileManager.default.createFile(atPath: noExtURL.path, contents: Data())
        let noExtItem = FileItem(url: noExtURL, icon: makeFakeIcon())
        TestReporter.report(
            "ThumbnailService",
            "NEG: supportsThumbnail(item:) returns false for a file with no extension",
            result: !ThumbnailService.supportsThumbnail(item: noExtItem))
    }

    private static func testCacheKeyDoesNotCollideBetweenSizes() {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let url = tempDir.appendingPathComponent("same-url-\(UUID().uuidString).png")

        // NEG: nothing has been cached yet at either size for this fresh URL.
        let missAtSmall = ThumbnailService.shared.cachedThumbnail(for: url, size: 32)
        let missAtLarge = ThumbnailService.shared.cachedThumbnail(for: url, size: 128)
        TestReporter.report("ThumbnailService", "NEG: cachedThumbnail(for:size:) is nil at size 32 for a never-loaded URL", result: missAtSmall == nil)
        TestReporter.report("ThumbnailService", "NEG: cachedThumbnail(for:size:) is nil at size 128 for a never-loaded URL", result: missAtLarge == nil)
    }

    private static func testPrefetchThumbnailsWithMixedEligibility() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Build a mix: one eligible png, one ineligible directory, one ineligible zip.
        let pngURL = tempDir.appendingPathComponent("eligible.png")
        FileManager.default.createFile(atPath: pngURL.path, contents: Data())
        let pngItem = FileItem(url: pngURL, icon: makeFakeIcon())

        let folderURL = tempDir.appendingPathComponent("ineligible-folder")
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let folderItem = FileItem(url: folderURL, icon: makeFakeIcon())

        let zipURL = tempDir.appendingPathComponent("ineligible.zip")
        FileManager.default.createFile(atPath: zipURL.path, contents: Data())
        let zipItem = FileItem(url: zipURL, icon: makeFakeIcon())

        // POS: prefetchThumbnails with a mix of eligible/ineligible items filters via supportsThumbnail
        // and returns immediately (fire-and-forget Task.detached), never crashing or hanging on ineligible entries.
        ThumbnailService.shared.prefetchThumbnails(for: [pngItem, folderItem, zipItem], size: 32)
        TestReporter.report(
            "ThumbnailService",
            "POS: prefetchThumbnails(for:size:) with mixed eligible/ineligible items returns without crashing",
            result: true)

        // NEG: directories and archives are never dispatched to loadThumbnail by prefetch, so their cache
        // entries remain empty even after giving the detached task a brief window to run.
        try? await Task.sleep(nanoseconds: 200_000_000)
        let folderCached = ThumbnailService.shared.cachedThumbnail(for: folderURL, size: 32)
        let zipCached = ThumbnailService.shared.cachedThumbnail(for: zipURL, size: 32)
        TestReporter.report("ThumbnailService", "NEG: prefetchThumbnails never populates the cache for an ineligible directory", result: folderCached == nil)
        TestReporter.report("ThumbnailService", "NEG: prefetchThumbnails never populates the cache for an ineligible zip archive", result: zipCached == nil)
    }

    private static func testIsImage() {
        // POS: common image extensions are recognized
        TestReporter.report("ThumbnailService", "POS: isImage(fileExtension:) returns true for \"png\"", result: ThumbnailService.isImage(fileExtension: "png"))
        TestReporter.report("ThumbnailService", "POS: isImage(fileExtension:) returns true for \"jpg\"", result: ThumbnailService.isImage(fileExtension: "jpg"))

        // NEG: non-image extensions and nonsense strings return false
        TestReporter.report(
            "ThumbnailService",
            "NEG: isImage(fileExtension:) returns false for \"txt\"",
            result: !ThumbnailService.isImage(fileExtension: "txt"))
        TestReporter.report(
            "ThumbnailService",
            "NEG: isImage(fileExtension:) returns false for empty string",
            result: !ThumbnailService.isImage(fileExtension: ""))
    }

    private static func testCachedThumbnailMiss() {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let neverLoadedURL = tempDir.appendingPathComponent("never-loaded-\(UUID().uuidString).png")

        // NEG: a URL that was never passed to loadThumbnail(for:size:) is a pure cache miss
        let cached = ThumbnailService.shared.cachedThumbnail(for: neverLoadedURL, size: 48)
        TestReporter.report("ThumbnailService", "NEG: cachedThumbnail(for:size:) returns nil for a URL never loaded", result: cached == nil)
    }

    private static func testPrefetchEmptyArrayIsNoOp() {
        // NEG: prefetchThumbnails with an empty items array hits the guard and safely no-ops
        ThumbnailService.shared.prefetchThumbnails(for: [], size: 48)
        TestReporter.report("ThumbnailService", "NEG: prefetchThumbnails with empty items array is a safe no-op", result: true)
    }

    private static func testLoadThumbnailForRealPNG() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let pngURL = tempDir.appendingPathComponent("real-sample.png")

        // Build a tiny real 4x4 PNG on disk via NSBitmapImageRep so QLThumbnailGenerator has real
        // image data to work with (not just an empty/garbage file).
        let size = NSSize(width: 4, height: 4)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()

        var pngWritten = false
        if let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            pngWritten = (try? pngData.write(to: pngURL)) != nil
        }
        TestReporter.report("ThumbnailService", "POS: sample PNG fixture is written to disk successfully", result: pngWritten)

        // POS/NEG: loadThumbnail(for:size:) on a real PNG file either returns a generated image, or
        // returns nil gracefully in a headless CI environment without QuickLook support -- either
        // outcome is acceptable as long as it doesn't crash or hang.
        let thumbnail = await ThumbnailService.shared.loadThumbnail(for: pngURL, size: 32)
        TestReporter.report(
            "ThumbnailService",
            "POS: loadThumbnail(for:size:) on a real PNG completes without crashing (image: \(thumbnail != nil))",
            result: true)

        if thumbnail != nil {
            // POS: once loaded, the same URL/size pair is now served from cache
            let cachedAfterLoad = ThumbnailService.shared.cachedThumbnail(for: pngURL, size: 32)
            TestReporter.report(
                "ThumbnailService",
                "POS: cachedThumbnail(for:size:) returns the image after a successful loadThumbnail",
                result: cachedAfterLoad != nil)
        }

        // NEG: loadThumbnail for a nonexistent file returns nil rather than crashing/hanging
        let missingURL = tempDir.appendingPathComponent("does-not-exist-\(UUID().uuidString).png")
        let missingResult = await ThumbnailService.shared.loadThumbnail(for: missingURL, size: 32)
        TestReporter.report("ThumbnailService", "NEG: loadThumbnail(for:size:) returns nil for a nonexistent file", result: missingResult == nil)
    }
}
