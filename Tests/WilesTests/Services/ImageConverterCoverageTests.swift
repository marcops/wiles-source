@testable import Wiles
import Foundation
import AppKit
import CoreGraphics
import UniformTypeIdentifiers

@MainActor
public struct ImageConverterCoverageTests {
    public static func run() {
        testOriginalPresetKeepsDimensions()
        testScale75AndScale50()
        testMax1080pConstrainsLargeImage()
        testMax1080pLeavesSmallImageUntouched()
        testMax4KConstrainsLargeImage()
        testMax4KLeavesSmallImageUntouched()
        testSquareCropOnWideImage()
        testSquareCropOnTallImage()
        testLandscapeCropBothAspectBranches()
        testPortraitCropBothAspectBranches()
        testStandardCropBothAspectBranches()
        testNoCropKeepsFullDimensions()
        testDestinationURLCollisionIncrementsCounter()
        testAllFormatsProduceReadableOutput()
        testNonexistentFileThrowsError()
        testJPEGQualityAffectsFileSize()
        testPNGIgnoresQualityParameter()
        testScalePresetTruncatesFractionalDimensions()
        testOutOfRangeQualityDoesNotThrow()
        testDestinationFileIsWrittenInSameDirectoryAsSource()
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

    // MARK: - Resize presets

    private static func testOriginalPresetKeepsDimensions() {
        let source = makeTestImage(width: 400, height: 300)
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

        guard let dest = try? ImageConverterService.convertImage(at: source, targetFormat: .png, preset: .original) else {
            report("ImageConverter", "POS: .original preset succeeds", result: false)
            return
        }
        let dims = dimensions(at: dest)
        report("ImageConverter", "POS: .original preset keeps exact source dimensions", result: dims?.width == 400 && dims?.height == 300)
    }

    private static func testScale75AndScale50() {
        let source = makeTestImage(width: 400, height: 200)
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

        if let dest75 = try? ImageConverterService.convertImage(at: source, targetFormat: .png, preset: .scale75) {
            let dims = dimensions(at: dest75)
            report("ImageConverter", "POS: .scale75 produces 75% of original dimensions", result: dims?.width == 300 && dims?.height == 150)
        } else {
            report("ImageConverter", "POS: .scale75 produces 75% of original dimensions", result: false)
        }

        if let dest50 = try? ImageConverterService.convertImage(at: source, targetFormat: .png, preset: .scale50) {
            let dims = dimensions(at: dest50)
            report("ImageConverter", "POS: .scale50 produces 50% of original dimensions", result: dims?.width == 200 && dims?.height == 100)
        } else {
            report("ImageConverter", "POS: .scale50 produces 50% of original dimensions", result: false)
        }
    }

    private static func testMax1080pConstrainsLargeImage() {
        let source = makeTestImage(width: 3840, height: 2160)
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

        guard let dest = try? ImageConverterService.convertImage(at: source, targetFormat: .png, preset: .max1080p),
              let dims = dimensions(at: dest) else {
            report("ImageConverter", "POS: .max1080p downsizes an oversized image to fit within 1920x1080", result: false)
            return
        }
        report(
            "ImageConverter",
            "POS: .max1080p downsizes an oversized image to fit within 1920x1080",
            result: dims.width <= 1920 && dims.height <= 1080 && (dims.width == 1920 || dims.height == 1080)
        )
    }

    private static func testMax1080pLeavesSmallImageUntouched() {
        let source = makeTestImage(width: 640, height: 480)
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

        guard let dest = try? ImageConverterService.convertImage(at: source, targetFormat: .png, preset: .max1080p),
              let dims = dimensions(at: dest) else {
            report("ImageConverter", "NEG: .max1080p leaves an already-small image untouched", result: false)
            return
        }
        report("ImageConverter", "NEG: .max1080p leaves an already-small image untouched", result: dims.width == 640 && dims.height == 480)
    }

    private static func testMax4KConstrainsLargeImage() {
        let source = makeTestImage(width: 7680, height: 4320)
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

        guard let dest = try? ImageConverterService.convertImage(at: source, targetFormat: .png, preset: .max4K),
              let dims = dimensions(at: dest) else {
            report("ImageConverter", "POS: .max4K downsizes an oversized image to fit within 3840x2160", result: false)
            return
        }
        report(
            "ImageConverter",
            "POS: .max4K downsizes an oversized image to fit within 3840x2160",
            result: dims.width <= 3840 && dims.height <= 2160 && (dims.width == 3840 || dims.height == 2160)
        )
    }

    private static func testMax4KLeavesSmallImageUntouched() {
        let source = makeTestImage(width: 1000, height: 800)
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

        guard let dest = try? ImageConverterService.convertImage(at: source, targetFormat: .png, preset: .max4K),
              let dims = dimensions(at: dest) else {
            report("ImageConverter", "NEG: .max4K leaves an already-small image untouched", result: false)
            return
        }
        report("ImageConverter", "NEG: .max4K leaves an already-small image untouched", result: dims.width == 1000 && dims.height == 800)
    }

    // MARK: - Crop presets

    private static func testSquareCropOnWideImage() {
        let source = makeTestImage(width: 800, height: 400)
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

        guard let dest = try? ImageConverterService.convertImage(at: source, targetFormat: .png, preset: .original, cropPreset: .square1x1),
              let dims = dimensions(at: dest) else {
            report("ImageConverter", "POS: .square1x1 crop on a wide image crops to the shorter side", result: false)
            return
        }
        report("ImageConverter", "POS: .square1x1 crop on a wide image crops to the shorter side", result: dims.width == 400 && dims.height == 400)
    }

    private static func testSquareCropOnTallImage() {
        let source = makeTestImage(width: 300, height: 900)
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

        guard let dest = try? ImageConverterService.convertImage(at: source, targetFormat: .png, preset: .original, cropPreset: .square1x1),
              let dims = dimensions(at: dest) else {
            report("ImageConverter", "POS: .square1x1 crop on a tall image crops to the shorter side", result: false)
            return
        }
        report("ImageConverter", "POS: .square1x1 crop on a tall image crops to the shorter side", result: dims.width == 300 && dims.height == 300)
    }

    private static func testLandscapeCropBothAspectBranches() {
        // Wider than 16:9 -> height is the limiting factor.
        let wideSource = makeTestImage(width: 2000, height: 500)
        defer { try? FileManager.default.removeItem(at: wideSource.deletingLastPathComponent()) }
        if let dest = try? ImageConverterService.convertImage(at: wideSource, targetFormat: .png, preset: .original, cropPreset: .landscape16x9),
           let dims = dimensions(at: dest) {
            report(
                "ImageConverter",
                "POS: .landscape16x9 crop on an ultra-wide image is height-limited",
                result: dims.height == 500 && abs(dims.width - Int(500.0 * 16.0 / 9.0)) <= 2
            )
        } else {
            report("ImageConverter", "POS: .landscape16x9 crop on an ultra-wide image is height-limited", result: false)
        }

        // Narrower than 16:9 -> width is the limiting factor.
        let narrowSource = makeTestImage(width: 900, height: 900)
        defer { try? FileManager.default.removeItem(at: narrowSource.deletingLastPathComponent()) }
        if let dest = try? ImageConverterService.convertImage(at: narrowSource, targetFormat: .png, preset: .original, cropPreset: .landscape16x9),
           let dims = dimensions(at: dest) {
            report(
                "ImageConverter",
                "POS: .landscape16x9 crop on a square-ish image is width-limited",
                result: dims.width == 900 && abs(dims.height - Int(900.0 / (16.0 / 9.0))) <= 2
            )
        } else {
            report("ImageConverter", "POS: .landscape16x9 crop on a square-ish image is width-limited", result: false)
        }
    }

    private static func testPortraitCropBothAspectBranches() {
        let source1 = makeTestImage(width: 900, height: 900)
        defer { try? FileManager.default.removeItem(at: source1.deletingLastPathComponent()) }
        if let dest = try? ImageConverterService.convertImage(at: source1, targetFormat: .png, preset: .original, cropPreset: .portrait9x16),
           let dims = dimensions(at: dest) {
            report(
                "ImageConverter",
                "POS: .portrait9x16 crop on a square-ish image is height-limited",
                result: dims.height == 900 && abs(dims.width - Int(900.0 * 9.0 / 16.0)) <= 2
            )
        } else {
            report("ImageConverter", "POS: .portrait9x16 crop on a square-ish image is height-limited", result: false)
        }

        let source2 = makeTestImage(width: 300, height: 1600)
        defer { try? FileManager.default.removeItem(at: source2.deletingLastPathComponent()) }
        if let dest = try? ImageConverterService.convertImage(at: source2, targetFormat: .png, preset: .original, cropPreset: .portrait9x16),
           let dims = dimensions(at: dest) {
            report(
                "ImageConverter",
                "POS: .portrait9x16 crop on a very tall image is width-limited",
                result: dims.width == 300 && abs(dims.height - Int(300.0 / (9.0 / 16.0))) <= 2
            )
        } else {
            report("ImageConverter", "POS: .portrait9x16 crop on a very tall image is width-limited", result: false)
        }
    }

    private static func testStandardCropBothAspectBranches() {
        let source1 = makeTestImage(width: 2000, height: 500)
        defer { try? FileManager.default.removeItem(at: source1.deletingLastPathComponent()) }
        if let dest = try? ImageConverterService.convertImage(at: source1, targetFormat: .png, preset: .original, cropPreset: .standard4x3),
           let dims = dimensions(at: dest) {
            report("ImageConverter", "POS: .standard4x3 crop on a wide image is height-limited", result: dims.height == 500 && abs(dims.width - Int(500.0 * 4.0 / 3.0)) <= 2)
        } else {
            report("ImageConverter", "POS: .standard4x3 crop on a wide image is height-limited", result: false)
        }

        let source2 = makeTestImage(width: 300, height: 900)
        defer { try? FileManager.default.removeItem(at: source2.deletingLastPathComponent()) }
        if let dest = try? ImageConverterService.convertImage(at: source2, targetFormat: .png, preset: .original, cropPreset: .standard4x3),
           let dims = dimensions(at: dest) {
            report("ImageConverter", "POS: .standard4x3 crop on a tall image is width-limited", result: dims.width == 300 && abs(dims.height - Int(300.0 / (4.0 / 3.0))) <= 2)
        } else {
            report("ImageConverter", "POS: .standard4x3 crop on a tall image is width-limited", result: false)
        }
    }

    private static func testNoCropKeepsFullDimensions() {
        let source = makeTestImage(width: 500, height: 333)
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

        guard let dest = try? ImageConverterService.convertImage(at: source, targetFormat: .png, preset: .original, cropPreset: .none),
              let dims = dimensions(at: dest) else {
            report("ImageConverter", "NEG: .none crop preset leaves full image dimensions untouched", result: false)
            return
        }
        report("ImageConverter", "NEG: .none crop preset leaves full image dimensions untouched", result: dims.width == 500 && dims.height == 333)
    }

    // MARK: - Destination naming & formats

    private static func testDestinationURLCollisionIncrementsCounter() {
        let source = makeTestImage(width: 100, height: 100)
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

        guard let first = try? ImageConverterService.convertImage(at: source, targetFormat: .png, preset: .original) else {
            report("ImageConverter", "POS: repeated conversion of the same source avoids overwriting by incrementing a counter suffix", result: false)
            return
        }
        guard let second = try? ImageConverterService.convertImage(at: source, targetFormat: .png, preset: .original) else {
            report("ImageConverter", "POS: repeated conversion of the same source avoids overwriting by incrementing a counter suffix", result: false)
            return
        }
        report(
            "ImageConverter",
            "POS: repeated conversion of the same source avoids overwriting by incrementing a counter suffix",
            result: first.lastPathComponent != second.lastPathComponent && second.lastPathComponent.contains("_converted_2")
        )
    }

    private static func testAllFormatsProduceReadableOutput() {
        let source = makeTestImage(width: 64, height: 64)
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

        for format in ImageFormat.allCases {
            guard let dest = try? ImageConverterService.convertImage(at: source, targetFormat: format, preset: .original) else {
                report("ImageConverter", "POS: converting to \(format.rawValue) produces a readable output file", result: false)
                continue
            }
            let readable = dimensions(at: dest) != nil
            let correctExtension = dest.pathExtension == format.fileExtension
            report("ImageConverter", "POS: converting to \(format.rawValue) produces a readable output file with the right extension", result: readable && correctExtension)
        }
    }

    // MARK: - Error handling

    private static func testNonexistentFileThrowsError() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let missing = dir.appendingPathComponent("does_not_exist.png")
        var threw = false
        do {
            _ = try ImageConverterService.convertImage(at: missing, targetFormat: .jpeg, preset: .original)
        } catch {
            threw = true
        }
        report("ImageConverter", "NEG: converting a nonexistent source file throws an error", result: threw)
    }

    // MARK: - Quality parameter

    private static func testJPEGQualityAffectsFileSize() {
        let source = makeTestImage(width: 800, height: 800)
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

        guard let lowQ = try? ImageConverterService.convertImage(at: source, targetFormat: .jpeg, preset: .original, quality: 0.05) else {
            report("ImageConverter", "POS: low JPEG quality produces a smaller file than high JPEG quality", result: false)
            return
        }
        // Give the low-quality file a distinct destination name pass by converting from a copy for high quality.
        guard let highQ = try? ImageConverterService.convertImage(at: source, targetFormat: .jpeg, preset: .original, quality: 1.0) else {
            report("ImageConverter", "POS: low JPEG quality produces a smaller file than high JPEG quality", result: false)
            return
        }

        let lowAttrs = try? FileManager.default.attributesOfItem(atPath: lowQ.path)
        let highAttrs = try? FileManager.default.attributesOfItem(atPath: highQ.path)

        guard let lowSizeVal = lowAttrs?[.size] as? Int, let highSizeVal = highAttrs?[.size] as? Int else {
            report("ImageConverter", "POS: low JPEG quality produces a smaller file than high JPEG quality", result: false)
            return
        }
        report("ImageConverter", "POS: low JPEG quality produces a smaller file than high JPEG quality", result: lowSizeVal < highSizeVal)
    }

    private static func testPNGIgnoresQualityParameter() {
        let source = makeTestImage(width: 200, height: 200)
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

        guard let lowQ = try? ImageConverterService.convertImage(at: source, targetFormat: .png, preset: .original, quality: 0.01),
              let lowDims = dimensions(at: lowQ) else {
            report("ImageConverter", "NEG: PNG output ignores lossy quality parameter and stays fully readable", result: false)
            return
        }
        guard let highQ = try? ImageConverterService.convertImage(at: source, targetFormat: .png, preset: .original, quality: 1.0),
              let highDims = dimensions(at: highQ) else {
            report("ImageConverter", "NEG: PNG output ignores lossy quality parameter and stays fully readable", result: false)
            return
        }
        report(
            "ImageConverter",
            "NEG: PNG output ignores lossy quality parameter and stays fully readable",
            result: lowDims.width == highDims.width && lowDims.height == highDims.height && lowDims.width == 200
        )
    }

    private static func testOutOfRangeQualityDoesNotThrow() {
        let source = makeTestImage(width: 100, height: 100)
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

        var succeeded = true
        do {
            _ = try ImageConverterService.convertImage(at: source, targetFormat: .jpeg, preset: .original, quality: -1.0)
        } catch {
            succeeded = false
        }
        do {
            _ = try ImageConverterService.convertImage(at: source, targetFormat: .jpeg, preset: .original, quality: 5.0)
        } catch {
            succeeded = false
        }
        report("ImageConverter", "POS: out-of-range quality values (negative / >1) do not throw", result: succeeded)
    }

    // MARK: - Resize truncation

    private static func testScalePresetTruncatesFractionalDimensions() {
        // 401 * 0.75 = 300.75 -> Int(CGFloat) truncates toward zero to 300.
        let source = makeTestImage(width: 401, height: 401)
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

        guard let dest = try? ImageConverterService.convertImage(at: source, targetFormat: .png, preset: .scale75),
              let dims = dimensions(at: dest) else {
            report("ImageConverter", "POS: fractional scaled dimensions are truncated rather than rounded", result: false)
            return
        }
        report("ImageConverter", "POS: fractional scaled dimensions are truncated rather than rounded", result: dims.width == 300 && dims.height == 300)
    }

    // MARK: - Output location

    private static func testDestinationFileIsWrittenInSameDirectoryAsSource() {
        let source = makeTestImage(width: 50, height: 50)
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

        guard let dest = try? ImageConverterService.convertImage(at: source, targetFormat: .tiff, preset: .original) else {
            report("ImageConverter", "POS: converted file is written into the same directory as the source file", result: false)
            return
        }
        report(
            "ImageConverter",
            "POS: converted file is written into the same directory as the source file",
            result: dest.deletingLastPathComponent().path == source.deletingLastPathComponent().path
        )
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
