import AppKit
import CoreGraphics
import Foundation
import PDFKit
@testable import Wiles

/// Covers `FileMetadataTooltipService.tooltip(for:)`'s correctness — in particular the private
/// `pixelDimensions(for:)` helper, exercised indirectly since it's only reachable through the
/// public `tooltip(for:)` entry point. The `Task.detached` wrapping around the CGImageSource read
/// is not independently testable (no timing/dispatch harness), but the parsed "W x H" output it
/// produces is a pure, deterministic result of a real image file and is fully verifiable here.
@MainActor
public struct FileMetadataTooltipServiceTests {
    public static func run() async {
        await testTooltipIncludesPixelDimensionsForRealImage()
        await testTooltipOmitsDimensionsForNonImageFile()
        await testTooltipForDirectoryOmitsDimensions()
        await testTooltipIncludesPageCountForMultiPagePDF()
        await testTooltipUsesSingularGrammarForOnePagePDF()
        await testTooltipHandlesCorruptPDFGracefully()
        await testTooltipHandlesCorruptImageGracefully()
        await testTooltipFallsBackToDocumentForExtensionlessFile()
        await testTooltipUppercasesUnknownExtension()
        await testInvalidateClearsCachedTooltip()
        testFirstCharacterUppercasedOnlyTouchesFirstCharacter()
        testFirstCharacterUppercasedIsSafeOnEmptyAndSingleChar()
    }

    private static func testFirstCharacterUppercasedOnlyTouchesFirstCharacter() {
        report(
            "FileMetadataTooltipService",
            "POS: firstCharacterUppercased upper-cases only the first char, leaving the rest of a multi-word string intact",
            result: FileMetadataTooltipService.firstCharacterUppercased("documento de texto simples") == "Documento de texto simples")
    }

    private static func testFirstCharacterUppercasedIsSafeOnEmptyAndSingleChar() {
        let empty = FileMetadataTooltipService.firstCharacterUppercased("") == ""
        let single = FileMetadataTooltipService.firstCharacterUppercased("a") == "A"
        report(
            "FileMetadataTooltipService",
            "POS: firstCharacterUppercased handles empty and single-character input",
            result: empty && single)
    }

    /// Renders directly into an `NSBitmapImageRep` of exact pixel dimensions instead of going
    /// through `NSImage.lockFocus()`, which rasterizes at the *current screen's* backing scale
    /// factor — on a Retina display a "48x24" `NSImage` silently produces a 96x48 pixel PNG on
    /// disk, making any assertion on exact pixel dimensions non-deterministic across machines.
    private static func makePNG(width: Int, height: Int, at url: URL) {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0) else { return }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        NSGraphicsContext.restoreGraphicsState()

        if let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: url)
        }
    }

    private static func testTooltipIncludesPixelDimensionsForRealImage() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("tooltip_dims.png")
        makePNG(width: 48, height: 24, at: file)

        let item = FileItem.load(url: file, icon: NSWorkspace.shared.icon(forFile: file.path))
        let tooltip = await FileMetadataTooltipService.tooltip(for: item, language: .english)

        report(
            "FileMetadataTooltipService",
            "POS: tooltip(for:) includes the real pixel dimensions line for an image file",
            result: tooltip.contains("48 x 24"))
    }

    private static func testTooltipOmitsDimensionsForNonImageFile() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("notes.txt")
        try? "hello world".write(to: file, atomically: true, encoding: .utf8)

        let item = FileItem.load(url: file, icon: NSWorkspace.shared.icon(forFile: file.path))
        let tooltip = await FileMetadataTooltipService.tooltip(for: item, language: .english)

        report(
            "FileMetadataTooltipService",
            "NEG: tooltip(for:) does not include a dimensions-shaped line for a plain text file",
            result: !tooltip.contains(" x "))
    }

    private static func testTooltipForDirectoryOmitsDimensions() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let item = FileItem.load(url: dir, icon: NSWorkspace.shared.icon(forFile: dir.path))
        let tooltip = await FileMetadataTooltipService.tooltip(for: item, language: .english)

        report(
            "FileMetadataTooltipService",
            "NEG: tooltip(for:) for a directory reports Folder and never attempts image parsing",
            result: tooltip.contains("Folder") && !tooltip.contains(" x "))
    }

    /// Writes a real multi-page PDF via native CoreGraphics PDF context APIs (no third-party
    /// dependency, no PDFKit-side document builder needed) so `pdfPageCountLine(for:)` can be
    /// exercised through the public `tooltip(for:)` entry point with a genuine on-disk PDF.
    private static func makePDF(pageCount: Int, at url: URL) {
        var mediaBox = CGRect(x: 0, y: 0, width: 200, height: 200)
        guard let consumer = CGDataConsumer(url: url as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return }
        for _ in 0 ..< pageCount {
            context.beginPDFPage(nil)
            context.endPDFPage()
        }
        context.closePDF()
    }

    private static func testTooltipIncludesPageCountForMultiPagePDF() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("tooltip_pages.pdf")
        makePDF(pageCount: 3, at: file)

        let item = FileItem.load(url: file, icon: NSWorkspace.shared.icon(forFile: file.path))
        let tooltip = await FileMetadataTooltipService.tooltip(for: item, language: .english)

        report(
            "FileMetadataTooltipService",
            "POS: tooltip(for:) includes the real page count line (plural grammar) for a 3-page PDF",
            result: tooltip.contains("3 pages"))
    }

    private static func testTooltipUsesSingularGrammarForOnePagePDF() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("tooltip_one_page.pdf")
        makePDF(pageCount: 1, at: file)

        let item = FileItem.load(url: file, icon: NSWorkspace.shared.icon(forFile: file.path))
        let tooltip = await FileMetadataTooltipService.tooltip(for: item, language: .english)

        report(
            "FileMetadataTooltipService",
            "POS: tooltip(for:) uses singular '1 page' (not '1 pages') for a single-page PDF",
            result: tooltip.contains("1 page") && !tooltip.contains("1 pages"))
    }

    private static func testTooltipHandlesCorruptPDFGracefully() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("corrupt.pdf")
        try? "this is not a real pdf".write(to: file, atomically: true, encoding: .utf8)

        let item = FileItem.load(url: file, icon: NSWorkspace.shared.icon(forFile: file.path))
        let tooltip = await FileMetadataTooltipService.tooltip(for: item, language: .english)

        report(
            "FileMetadataTooltipService",
            "NEG: tooltip(for:) for a corrupt/unparsable PDF omits a page-count line instead of crashing",
            result: !tooltip.contains("page"))
    }

    private static func testTooltipHandlesCorruptImageGracefully() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("corrupt.png")
        try? "this is not a real image".write(to: file, atomically: true, encoding: .utf8)

        let item = FileItem.load(url: file, icon: NSWorkspace.shared.icon(forFile: file.path))
        let tooltip = await FileMetadataTooltipService.tooltip(for: item, language: .english)

        report(
            "FileMetadataTooltipService",
            "NEG: tooltip(for:) for a corrupt/unparsable PNG omits a dimensions line instead of crashing",
            result: !tooltip.contains(" x "))
    }

    private static func testTooltipFallsBackToDocumentForExtensionlessFile() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("noextension")
        try? "hello".write(to: file, atomically: true, encoding: .utf8)

        let item = FileItem.load(url: file, icon: NSWorkspace.shared.icon(forFile: file.path))
        let tooltip = await FileMetadataTooltipService.tooltip(for: item, language: .english)

        report(
            "FileMetadataTooltipService",
            "POS: tooltip(for:) falls back to the generic 'Document' kind for a file with no extension",
            result: tooltip.contains("Document"))
    }

    private static func testTooltipUppercasesUnknownExtension() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("mystery.madeupext123")
        try? "hello".write(to: file, atomically: true, encoding: .utf8)

        let item = FileItem.load(url: file, icon: NSWorkspace.shared.icon(forFile: file.path))
        let tooltip = await FileMetadataTooltipService.tooltip(for: item, language: .english)

        report(
            "FileMetadataTooltipService",
            "POS: tooltip(for:) uppercases an unrecognized extension when macOS has no localized description for it",
            result: tooltip.contains("MADEUPEXT123"))
    }

    /// Verifies real cache/invalidation behavior end-to-end: a second `tooltip(for:)` call for the
    /// same path returns the *stale* cached text even after the underlying file changes size, until
    /// `invalidate(url:)` is called, after which the freshly computed text reflects the new size.
    private static func testInvalidateClearsCachedTooltip() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("invalidate_test.txt")
        try? Data(repeating: 0x61, count: 10).write(to: file)
        let smallItem = FileItem.load(url: file, icon: NSWorkspace.shared.icon(forFile: file.path))
        let firstTooltip = await FileMetadataTooltipService.tooltip(for: smallItem, language: .english)

        try? Data(repeating: 0x62, count: 100_000).write(to: file)
        // `URL.resourceValues(forKeys:)` caches results on the URL value itself, so re-using the
        // same `file` URL instance here would silently keep returning the old 10-byte size (as
        // confirmed by direct testing). A fresh `URL(fileURLWithPath:)` instance forces a real,
        // uncached stat read of the file's current on-disk size.
        let largeFileURL = URL(fileURLWithPath: file.path)
        let largeItem = FileItem.load(url: largeFileURL, icon: NSWorkspace.shared.icon(forFile: file.path))
        let staleTooltip = await FileMetadataTooltipService.tooltip(for: largeItem, language: .english)

        report(
            "FileMetadataTooltipService",
            "POS: tooltip(for:) returns the cached (stale) text for a previously-seen path without recomputing",
            result: staleTooltip == firstTooltip)

        FileMetadataTooltipService.invalidate(url: largeItem.url)
        let freshTooltip = await FileMetadataTooltipService.tooltip(for: largeItem, language: .english)

        report(
            "FileMetadataTooltipService",
            "POS: invalidate(url:) clears the cache so the next tooltip(for:) call reflects the file's new size",
            result: freshTooltip != firstTooltip)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
