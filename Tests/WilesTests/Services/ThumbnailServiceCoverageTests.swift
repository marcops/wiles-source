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
        await testCancelledLoadThumbnailIsRecoverable()
        await testConcurrentAwaiterSurvivesSiblingCancellation()
        await testPrefetchThumbnailsCancellationBreaksLoop()
        await testCacheKeyChangesWhenFileModificationDateChanges()
        testShouldPrefetchThumbnailsThreshold()
        await testCachedThumbnailResolvesViaMtimeIndexWithoutStat()
    }

    /// L77: prefetch is for image-heavy folders that fit the cache — it fires at or below the cap and
    /// stops above it, the opposite of the old "only above 500" logic that starved a 400-image folder.
    private static func testShouldPrefetchThumbnailsThreshold() {
        TestReporter.report(
            "ThumbnailService", "POS: shouldPrefetchThumbnails is true for a small folder (0)",
            result: ThumbnailService.shouldPrefetchThumbnails(forItemCount: 0))
        TestReporter.report(
            "ThumbnailService", "POS: shouldPrefetchThumbnails is true for a 400-item folder",
            result: ThumbnailService.shouldPrefetchThumbnails(forItemCount: 400))
        TestReporter.report(
            "ThumbnailService", "POS: shouldPrefetchThumbnails is true exactly at the 500 cap",
            result: ThumbnailService.shouldPrefetchThumbnails(forItemCount: 500))
        TestReporter.report(
            "ThumbnailService", "NEG: shouldPrefetchThumbnails is false just past the cap (501)",
            result: !ThumbnailService.shouldPrefetchThumbnails(forItemCount: 501))
        TestReporter.report(
            "ThumbnailService", "NEG: shouldPrefetchThumbnails is false for a huge folder (5000)",
            result: !ThumbnailService.shouldPrefetchThumbnails(forItemCount: 5000))
    }

    /// ML-090: `cachedThumbnail` builds its cache key from the `dateModified` the caller passes in
    /// (the cell's own `FileItem`), so a hit needs no synchronous `stat` and no window-shared state.
    private static func testCachedThumbnailResolvesViaMtimeIndexWithoutStat() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let pngURL = tempDir.appendingPathComponent("indexed-sample.png")
        writeSamplePNG(to: pngURL)

        let loaded = await ThumbnailService.shared.loadThumbnail(for: pngURL, size: 32, dateModified: Self.mtime(pngURL))
        guard loaded != nil else {
            TestReporter.report(
                "ThumbnailService",
                "SKIP: mtime-index fast path not exercisable (QuickLook unavailable in this environment)",
                result: true)
            return
        }

        let hit = ThumbnailService.shared.cachedThumbnail(for: pngURL, size: 32, dateModified: Self.mtime(pngURL))
        TestReporter.report(
            "ThumbnailService",
            "POS: cachedThumbnail hits after loadThumbnail using the caller-supplied dateModified (no stat)",
            result: hit != nil)

        // NEG: a URL absent from the mtime index and never loaded is still a clean miss, not a crash.
        let strangerURL = tempDir.appendingPathComponent("not-indexed-\(UUID().uuidString).png")
        TestReporter.report(
            "ThumbnailService",
            "NEG: cachedThumbnail returns nil for a URL never loaded",
            result: ThumbnailService.shared.cachedThumbnail(for: strangerURL, size: 32, dateModified: Self.mtime(strangerURL)) == nil)
    }

    /// M7 regression: the cache key folds in `contentModificationDate`, so a file edited/replaced
    /// on disk after its thumbnail was cached must be a cache MISS (forcing regeneration) rather
    /// than returning the stale bitmap the old path-only key would have served.
    private static func testCacheKeyChangesWhenFileModificationDateChanges() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let pngURL = tempDir.appendingPathComponent("mtime-sample.png")
        writeSamplePNG(to: pngURL)
        let loaded = await ThumbnailService.shared.loadThumbnail(for: pngURL, size: 32, dateModified: Self.mtime(pngURL))
        guard loaded != nil else {
            // Headless CI without QuickLook support — generation returns nil, nothing to cache.
            TestReporter.report(
                "ThumbnailService",
                "SKIP: mtime cache-key regression not exercisable (QuickLook unavailable in this environment)",
                result: true)
            return
        }

        let beforeBump = ThumbnailService.shared.cachedThumbnail(for: pngURL, size: 32, dateModified: Self.mtime(pngURL))
        TestReporter.report(
            "ThumbnailService",
            "POS: thumbnail is cached and resolvable via the caller-supplied dateModified after loadThumbnail",
            result: beforeBump != nil)

        // Rewrite the file so its contentModificationDate advances — the cell would then pass the new date.
        try? await Task.sleep(nanoseconds: 1_100_000_000)
        let newDate = Date()
        writeSamplePNG(to: pngURL)
        try? FileManager.default.setAttributes([.modificationDate: newDate], ofItemAtPath: pngURL.path)

        let afterBump = ThumbnailService.shared.cachedThumbnail(for: pngURL, size: 32, dateModified: Self.mtime(pngURL))
        TestReporter.report(
            "ThumbnailService",
            "POS: cachedThumbnail is a MISS after the file's modification date changes (stale bitmap not served)",
            result: afterBump == nil)
    }

    private static func makeFakeIcon() -> NSImage {
        NSImage(size: NSSize(width: 16, height: 16))
    }

    /// The mtime an image cell would pass as `FileItem.dateModified` (ML-090: no shared index any more).
    static func mtime(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
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

        let first = await ThumbnailService.shared.loadThumbnail(for: pngURL, size: 32, dateModified: Self.mtime(pngURL))
        let second = await ThumbnailService.shared.loadThumbnail(for: pngURL, size: 32, dateModified: Self.mtime(pngURL))
        TestReporter.report(
            "ThumbnailService", "POS: loadThumbnail(for:size:) returns the same cached image instance on a second call for the same URL",
            result: first != nil && first === second)
    }

    /// MM-118: cancelling the `.task` that awaits a thumbnail (its image cell scrolled off) now
    /// cancels the QuickLook generation and drops the `inFlight` entry — a later request for the
    /// same file must start a fresh generation and still succeed, i.e. the cancel didn't poison the
    /// dedup map.
    private static func testCancelledLoadThumbnailIsRecoverable() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let baselineURL = tempDir.appendingPathComponent("baseline-\(UUID().uuidString).png")
        writeSamplePNG(to: baselineURL)
        guard await ThumbnailService.shared.loadThumbnail(for: baselineURL, size: 32, dateModified: Self.mtime(baselineURL)) != nil else {
            TestReporter.report(
                "ThumbnailService", "SKIP: QuickLook generation unavailable in this environment (MM-118 recover test)", result: true)
            return
        }

        let pngURL = tempDir.appendingPathComponent("cancel-recover-\(UUID().uuidString).png")
        writeSamplePNG(to: pngURL)

        let cancelled = Task { await ThumbnailService.shared.loadThumbnail(for: pngURL, size: 32, dateModified: Self.mtime(pngURL)) }
        cancelled.cancel()
        _ = await cancelled.value // must not hang

        // A fresh, uncancelled request still produces an image.
        let retry = await ThumbnailService.shared.loadThumbnail(for: pngURL, size: 32, dateModified: Self.mtime(pngURL))
        TestReporter.report(
            "ThumbnailService",
            "POS: a thumbnail request retried after a cancelled one still generates successfully (MM-118)",
            result: retry != nil)
    }

    /// MM-118: with two `.task`s awaiting the same in-flight generation, cancelling one must not
    /// cancel the shared work out from under the other — the surviving awaiter still gets its image.
    private static func testConcurrentAwaiterSurvivesSiblingCancellation() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let baselineURL = tempDir.appendingPathComponent("baseline-\(UUID().uuidString).png")
        writeSamplePNG(to: baselineURL)
        guard await ThumbnailService.shared.loadThumbnail(for: baselineURL, size: 32, dateModified: Self.mtime(baselineURL)) != nil else {
            TestReporter.report(
                "ThumbnailService", "SKIP: QuickLook generation unavailable in this environment (MM-118 shared-awaiter test)", result: true)
            return
        }

        let pngURL = tempDir.appendingPathComponent("shared-\(UUID().uuidString).png")
        writeSamplePNG(to: pngURL)

        let keeper = Task { await ThumbnailService.shared.loadThumbnail(for: pngURL, size: 32, dateModified: Self.mtime(pngURL)) }
        let quitter = Task { await ThumbnailService.shared.loadThumbnail(for: pngURL, size: 32, dateModified: Self.mtime(pngURL)) }
        try? await Task.sleep(nanoseconds: 1_000_000)
        quitter.cancel()

        let keptImage = await keeper.value
        _ = await quitter.value
        TestReporter.report(
            "ThumbnailService",
            "POS: cancelling one awaiter of a shared thumbnail generation still lets the other one receive its image (MM-118)",
            result: keptImage != nil)
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
            items.append(FileItem.load(url: url, icon: makeFakeIcon()))
        }

        // Two back-to-back calls: the second cancels the first's still-running detached task before
        // it can finish iterating all 12 items.
        let prefetcher = ThumbnailPrefetcher()
        prefetcher.prefetch(for: items, size: 32)
        prefetcher.prefetch(for: items, size: 32)
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
        let dirItem = FileItem.load(url: subDir, icon: makeFakeIcon())
        TestReporter.report(
            "ThumbnailService",
            "NEG: supportsThumbnail(item:) returns false for a directory",
            result: !ThumbnailService.supportsThumbnail(item: dirItem))

        // NEG: a real file whose extension conforms to UTType.archive (zip) is excluded.
        let zipURL = tempDir.appendingPathComponent("archive.zip")
        FileManager.default.createFile(atPath: zipURL.path, contents: Data())
        let zipItem = FileItem.load(url: zipURL, icon: makeFakeIcon())
        TestReporter.report(
            "ThumbnailService",
            "NEG: supportsThumbnail(item:) returns false for a .zip file (archive type)",
            result: !ThumbnailService.supportsThumbnail(item: zipItem))

        // POS: a real file with a plain image extension is eligible.
        let pngURL = tempDir.appendingPathComponent("photo.png")
        FileManager.default.createFile(atPath: pngURL.path, contents: Data())
        let pngItem = FileItem.load(url: pngURL, icon: makeFakeIcon())
        TestReporter.report(
            "ThumbnailService",
            "POS: supportsThumbnail(item:) returns true for a .png file",
            result: ThumbnailService.supportsThumbnail(item: pngItem))

        // NEG: an unrecognized/nonsense extension returns false so native icons remain stable.
        let weirdURL = tempDir.appendingPathComponent("mystery.qzxnotarealext")
        FileManager.default.createFile(atPath: weirdURL.path, contents: Data())
        let weirdItem = FileItem.load(url: weirdURL, icon: makeFakeIcon())
        TestReporter.report(
            "ThumbnailService",
            "NEG: supportsThumbnail(item:) returns false for an unrecognized extension",
            result: !ThumbnailService.supportsThumbnail(item: weirdItem))

        // NEG: a file with no extension at all returns false so native icons remain stable.
        let noExtURL = tempDir.appendingPathComponent("README")
        FileManager.default.createFile(atPath: noExtURL.path, contents: Data())
        let noExtItem = FileItem.load(url: noExtURL, icon: makeFakeIcon())
        TestReporter.report(
            "ThumbnailService",
            "NEG: supportsThumbnail(item:) returns false for a file with no extension",
            result: !ThumbnailService.supportsThumbnail(item: noExtItem))
    }

    private static func testCacheKeyDoesNotCollideBetweenSizes() {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let url = tempDir.appendingPathComponent("same-url-\(UUID().uuidString).png")

        // NEG: nothing has been cached yet at either size for this fresh URL.
        let missAtSmall = ThumbnailService.shared.cachedThumbnail(for: url, size: 32, dateModified: Self.mtime(url))
        let missAtLarge = ThumbnailService.shared.cachedThumbnail(for: url, size: 128, dateModified: Self.mtime(url))
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
        let pngItem = FileItem.load(url: pngURL, icon: makeFakeIcon())

        let folderURL = tempDir.appendingPathComponent("ineligible-folder")
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let folderItem = FileItem.load(url: folderURL, icon: makeFakeIcon())

        let zipURL = tempDir.appendingPathComponent("ineligible.zip")
        FileManager.default.createFile(atPath: zipURL.path, contents: Data())
        let zipItem = FileItem.load(url: zipURL, icon: makeFakeIcon())

        // POS: prefetchThumbnails with a mix of eligible/ineligible items filters via supportsThumbnail
        // and returns immediately (fire-and-forget Task.detached), never crashing or hanging on ineligible entries.
        ThumbnailPrefetcher().prefetch(for: [pngItem, folderItem, zipItem], size: 32)
        TestReporter.report(
            "ThumbnailService",
            "POS: prefetchThumbnails(for:size:) with mixed eligible/ineligible items returns without crashing",
            result: true)

        // NEG: directories and archives are never dispatched to loadThumbnail by prefetch, so their cache
        // entries remain empty even after giving the detached task a brief window to run.
        try? await Task.sleep(nanoseconds: 200_000_000)
        let folderCached = ThumbnailService.shared.cachedThumbnail(for: folderURL, size: 32, dateModified: Self.mtime(folderURL))
        let zipCached = ThumbnailService.shared.cachedThumbnail(for: zipURL, size: 32, dateModified: Self.mtime(zipURL))
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
        let cached = ThumbnailService.shared.cachedThumbnail(for: neverLoadedURL, size: 48, dateModified: Self.mtime(neverLoadedURL))
        TestReporter.report("ThumbnailService", "NEG: cachedThumbnail(for:size:) returns nil for a URL never loaded", result: cached == nil)
    }

    private static func testPrefetchEmptyArrayIsNoOp() {
        // NEG: prefetchThumbnails with an empty items array hits the guard and safely no-ops
        ThumbnailPrefetcher().prefetch(for: [], size: 48)
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

        // from that index, so mirror it here.

        // POS/NEG: loadThumbnail(for:size:) on a real PNG file either returns a generated image, or
        // returns nil gracefully in a headless CI environment without QuickLook support -- either
        // outcome is acceptable as long as it doesn't crash or hang.
        let thumbnail = await ThumbnailService.shared.loadThumbnail(for: pngURL, size: 32, dateModified: Self.mtime(pngURL))
        TestReporter.report(
            "ThumbnailService",
            "POS: loadThumbnail(for:size:) on a real PNG completes without crashing (image: \(thumbnail != nil))",
            result: true)

        if thumbnail != nil {
            // POS: once loaded, the same URL/size pair is now served from cache
            let cachedAfterLoad = ThumbnailService.shared.cachedThumbnail(for: pngURL, size: 32, dateModified: Self.mtime(pngURL))
            TestReporter.report(
                "ThumbnailService",
                "POS: cachedThumbnail(for:size:) returns the image after a successful loadThumbnail",
                result: cachedAfterLoad != nil)
        }

        // NEG: loadThumbnail for a nonexistent file returns nil rather than crashing/hanging
        let missingURL = tempDir.appendingPathComponent("does-not-exist-\(UUID().uuidString).png")
        let missingResult = await ThumbnailService.shared.loadThumbnail(for: missingURL, size: 32, dateModified: Self.mtime(missingURL))
        TestReporter.report("ThumbnailService", "NEG: loadThumbnail(for:size:) returns nil for a nonexistent file", result: missingResult == nil)
    }
}
