@testable import Wiles
import Foundation
import AppKit

@MainActor
public struct ThumbnailServiceCoverageTests {
    public static func run() async {
        testIsImage()
        testCachedThumbnailMiss()
        testPrefetchEmptyArrayIsNoOp()
        await testLoadThumbnailForRealPNG()
    }

    private static func testIsImage() {
        // POS: common image extensions are recognized
        TestReporter.report("ThumbnailService", "POS: isImage(fileExtension:) returns true for \"png\"", result: ThumbnailService.isImage(fileExtension: "png"))
        TestReporter.report("ThumbnailService", "POS: isImage(fileExtension:) returns true for \"jpg\"", result: ThumbnailService.isImage(fileExtension: "jpg"))

        // NEG: non-image extensions and nonsense strings return false
        TestReporter.report("ThumbnailService", "NEG: isImage(fileExtension:) returns false for \"txt\"", result: !ThumbnailService.isImage(fileExtension: "txt"))
        TestReporter.report("ThumbnailService", "NEG: isImage(fileExtension:) returns false for empty string", result: !ThumbnailService.isImage(fileExtension: ""))
    }

    private static func testCachedThumbnailMiss() {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
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
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
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
        TestReporter.report("ThumbnailService", "POS: loadThumbnail(for:size:) on a real PNG completes without crashing (image: \(thumbnail != nil))", result: true)

        if thumbnail != nil {
            // POS: once loaded, the same URL/size pair is now served from cache
            let cachedAfterLoad = ThumbnailService.shared.cachedThumbnail(for: pngURL, size: 32)
            TestReporter.report("ThumbnailService", "POS: cachedThumbnail(for:size:) returns the image after a successful loadThumbnail", result: cachedAfterLoad != nil)
        }

        // NEG: loadThumbnail for a nonexistent file returns nil rather than crashing/hanging
        let missingURL = tempDir.appendingPathComponent("does-not-exist-\(UUID().uuidString).png")
        let missingResult = await ThumbnailService.shared.loadThumbnail(for: missingURL, size: 32)
        TestReporter.report("ThumbnailService", "NEG: loadThumbnail(for:size:) returns nil for a nonexistent file", result: missingResult == nil)
    }
}
