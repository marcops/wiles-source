import Foundation
@testable import Wiles

/// Covers `FileKindCatalog` — the single source of truth for the curated image/text/code/document
/// input-classification extension lists (previously hand-typed in `ImageFileType` and
/// `SearchFilterService`).
@MainActor
public struct FileKindCatalogTests {
    public static func run() {
        testExactSetsAreUnchanged()
        testClassifiersAreCaseInsensitive()
        testNonMembersRejected()
        testImageFileTypeDelegatesToCatalog()
    }

    /// Guards against a silent broaden/narrow of any of the four curated lists.
    private static func testExactSetsAreUnchanged() {
        report("POS: imageExtensions is the historical raster set",
               result: FileKindCatalog.imageExtensions == ["png", "jpg", "jpeg", "heic", "webp", "tiff", "bmp", "gif"])
        report("POS: textExtensions is the historical content-scan set",
               result: FileKindCatalog.textExtensions == ["txt", "md", "swift", "json", "py", "js", "ts", "css", "html", "sh", "yml", "xml", "csv"])
        report("POS: codeExtensions is the historical kind:code set",
               result: FileKindCatalog.codeExtensions == ["swift", "py", "js", "ts", "json", "html", "css", "cpp", "c", "h", "sh", "yml", "yaml"])
        report("POS: documentExtensions is the historical kind:doc set",
               result: FileKindCatalog.documentExtensions == ["doc", "docx", "pdf", "pages", "txt", "md", "rtf", "odt", "xls", "xlsx"])
    }

    private static func testClassifiersAreCaseInsensitive() {
        report("POS: isImage lowercases (PNG/HEIC)", result: FileKindCatalog.isImage("PNG") && FileKindCatalog.isImage("HEIC"))
        report("POS: isText lowercases (CSV)", result: FileKindCatalog.isText("CSV"))
        report("POS: isCode lowercases (SWIFT)", result: FileKindCatalog.isCode("SWIFT"))
        report("POS: isDocument lowercases (PDF)", result: FileKindCatalog.isDocument("PDF"))
    }

    private static func testNonMembersRejected() {
        report("NEG: svg is not a curated image", result: !FileKindCatalog.isImage("svg"))
        report("NEG: bin is not text", result: !FileKindCatalog.isText("bin"))
        report("NEG: empty extension classifies as nothing",
               result: !FileKindCatalog.isImage("") && !FileKindCatalog.isText("") && !FileKindCatalog.isCode("") && !FileKindCatalog.isDocument(""))
    }

    private static func testImageFileTypeDelegatesToCatalog() {
        report("POS: ImageFileType.extensions is backed by the catalog",
               result: ImageFileType.extensions == FileKindCatalog.imageExtensions)
        report("POS: ImageFileType.isImage delegates to the catalog",
               result: ImageFileType.isImage(fileExtension: "JPG") == FileKindCatalog.isImage("JPG"))
    }

    private static func report(_ name: String, result: Bool) {
        TestReporter.report("Model/FileKindCatalog", name, result: result)
    }
}
