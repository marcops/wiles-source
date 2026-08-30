import Foundation
@testable import Wiles

/// Covers `ImageFileType` — the shared curated raster-image extension set used by the file-item
/// context menu's Quick Convert and image-to-PDF merge actions.
@MainActor
public struct ImageFileTypeTests {
    public static func run() {
        testExactExtensionSetIsUnchanged()
        testIsImageIsCaseInsensitive()
        testNonImageExtensionsRejected()
    }

    /// Guards against a silent broaden/narrow: this is the exact set `SharedFileItemContextMenu`
    /// historically hardcoded.
    private static func testExactExtensionSetIsUnchanged() {
        let expected: Set = ["png", "jpg", "jpeg", "heic", "webp", "tiff", "bmp", "gif"]
        report("POS: the curated image-extension set matches the historical hardcoded list", result: ImageFileType.extensions == expected)
    }

    private static func testIsImageIsCaseInsensitive() {
        let allLowerMatch = ImageFileType.extensions.allSatisfy { ImageFileType.isImage(fileExtension: $0) }
        report("POS: every curated extension is recognized as an image", result: allLowerMatch)
        report(
            "POS: isImage lowercases before matching (PNG, JPG, HEIC)",
            result:
            ImageFileType.isImage(fileExtension: "PNG")
                && ImageFileType.isImage(fileExtension: "JPG")
                && ImageFileType.isImage(fileExtension: "HEIC"))
    }

    private static func testNonImageExtensionsRejected() {
        let rejected = ["svg", "pdf", "txt", "", "gifx", "raw", "heif"]
        report(
            "NEG: non-curated extensions are rejected (svg/pdf/txt/empty/raw/heif)",
            result: rejected.allSatisfy { !ImageFileType.isImage(fileExtension: $0) })
    }

    private static func report(_ name: String, result: Bool) {
        TestReporter.report("Model/ImageFileType", name, result: result)
    }
}
