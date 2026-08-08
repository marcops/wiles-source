@testable import Wiles
import Foundation
import AppKit
import CoreGraphics
import UniformTypeIdentifiers

/// Continuation of `ImageConverterCoverageTests` — split out purely to stay under SwiftLint's
/// 500-line file-length limit (see `AGENTS.md` rule 16's 1-to-1 file precedent already used for
/// `AppStateOperationsExtraTests`/`AppStateColumnsAndActionsAsyncTests`). Still the same dedicated
/// suite for `ImageConverterService.swift`; `run()` here is called alongside the main file's `run()`.
@MainActor
public struct ImageConverterCoverageExtraTests {
    public static func run() {
        testCustomCropRegionClampsOutOfRangeNormXAndNormY()
        testCustomCropRegionClampsNormWidthAndHeightToRemainingSpace()
        testMax1080pWideAspectTakesWidthConstrainedBranch()
        testZeroSizedTargetThrowsRenderError()
        testReadOnlyDestinationDirectoryThrowsWriteError()
    }

    // MARK: - Fixtures

    private static func makeTestImage(width: Int, height: Int) -> URL {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("source.png")

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            fatalError("Failed to create CGContext for test fixture")
        }
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let cgImage = context.makeImage() else {
            fatalError("Failed to create CGImage for test fixture")
        }

        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            fatalError("Failed to create CGImageDestination for test fixture")
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        CGImageDestinationFinalize(destination)
        return url
    }

    private static func dimensions(at url: URL) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int else {
            return nil
        }
        return (width, height)
    }

    // MARK: - CustomCropRegion clamping

    private static func testCustomCropRegionClampsOutOfRangeNormXAndNormY() {
        // normX above 1.0 clamps to 1.0; normW is derived from the *raw* (unclamped) normX,
        // so 1 - 2.0 = -1 forces normW down to its 0.01 floor.
        let region = CustomCropRegion(normX: 2.0, normY: 0.5, normW: 0.9, normH: 0.9)
        report(
            "ImageConverter",
            "POS: CustomCropRegion clamps an out-of-range normX to 1.0 and floors the derived normW",
            result: region.normX == 1.0 && region.normW == 0.01 && region.normY == 0.5 && region.normH == 0.5
        )

        // Negative normX/normY clamp to 0.0.
        let negativeRegion = CustomCropRegion(normX: -1.0, normY: -2.0, normW: 0.5, normH: 0.5)
        report(
            "ImageConverter",
            "NEG: CustomCropRegion clamps negative normX/normY to 0.0",
            result: negativeRegion.normX == 0.0 && negativeRegion.normY == 0.0
        )
    }

    private static func testCustomCropRegionClampsNormWidthAndHeightToRemainingSpace() {
        // normW/normH above the remaining space (1 - norm origin) clamp down to that remaining space.
        let region = CustomCropRegion(normX: 0.5, normY: 0.5, normW: 2.0, normH: 2.0)
        report(
            "ImageConverter",
            "POS: CustomCropRegion clamps oversized normW/normH to the remaining space from the origin",
            result: region.normW == 0.5 && region.normH == 0.5
        )

        // Negative normW/normH clamp up to the 0.01 floor.
        let flooredRegion = CustomCropRegion(normX: 0.2, normY: 0.3, normW: -5, normH: -5)
        report(
            "ImageConverter",
            "NEG: CustomCropRegion floors a negative normW/normH to 0.01",
            result: flooredRegion.normW == 0.01 && flooredRegion.normH == 0.01
        )
    }

    // MARK: - constrainedSize width-limited branch

    private static func testMax1080pWideAspectTakesWidthConstrainedBranch() {
        // aspect (40.0) > maxWidth/maxHeight (1920/1080 ~= 1.778), so width is the limiting factor
        // and height is derived from it - exercises the branch not covered by a "square-ish" oversized image.
        let source = makeTestImage(width: 4000, height: 100)
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

        guard let dest = try? ImageConverterService.convertImage(at: source, targetFormat: .png, preset: .max1080p),
              let dims = dimensions(at: dest) else {
            report("ImageConverter", "POS: .max1080p on an ultra-wide image is width-constrained", result: false)
            return
        }
        report(
            "ImageConverter",
            "POS: .max1080p on an ultra-wide image is width-constrained",
            result: dims.width == 1920 && dims.height == 48
        )
    }

    // MARK: - Low-level rendering / writing failures

    private static func testZeroSizedTargetThrowsRenderError() {
        // A 1x1 source scaled to 50% truncates to a 0x0 target, which CGContext refuses to create
        // (verified directly: CGContext(width: 0, height: 0, ...) returns nil), so this exercises
        // the "Failed to create graphics context" throw path in renderResizedImage.
        let source = makeTestImage(width: 1, height: 1)
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

        var threw = false
        do {
            _ = try ImageConverterService.convertImage(at: source, targetFormat: .png, preset: .scale50)
        } catch {
            threw = true
        }
        report("ImageConverter", "NEG: a 1x1 source scaled down to a 0x0 target throws a render error", result: threw)
    }

    private static func testReadOnlyDestinationDirectoryThrowsWriteError() {
        // Verified directly: CGImageDestinationCreateWithURL returns nil when the destination
        // directory isn't writable, so this exercises the "Failed to create image destination" throw
        // path in writeImage. The destination is always written alongside the source file.
        let source = makeTestImage(width: 20, height: 20)
        let dir = source.deletingLastPathComponent()
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dir.path)
            try? FileManager.default.removeItem(at: dir)
        }
        try? FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: dir.path)

        var threw = false
        do {
            _ = try ImageConverterService.convertImage(at: source, targetFormat: .png, preset: .original)
        } catch {
            threw = true
        }
        report("ImageConverter", "NEG: a read-only destination directory throws a write error", result: threw)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
