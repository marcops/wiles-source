import Foundation

/// Single source of truth for "which filename extensions count as an image / text / code /
/// document" — the input-classification lists that were previously hand-typed in `ImageFileType`,
/// `SearchFilterService.matchesKindFilter`, and `SearchFilterService.matchesContent`. Adding a new
/// format now touches exactly one place.
///
/// `ThumbnailService`'s `UTType`-based check is deliberately *not* folded in here: it is the
/// broader "anything Quick Look can preview" superset (SVG, RAW, movies, PDF, presentations), not a
/// curated extension list, and stays where it is — documented as the superset, per
/// `WILES_RULES.md` "One Catalog Per File-Type Concept".
enum FileKindCatalog {
    /// Curated raster-image extensions for file-item image actions (Quick Convert, image→PDF).
    /// Narrower than `ThumbnailService.isImage` on purpose (no SVG/RAW).
    static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "webp", "tiff", "bmp", "gif"]

    /// Plain-text-ish extensions whose bytes are worth scanning for a content-search match.
    static let textExtensions: Set<String> = [
        "txt", "md", "swift", "json", "py", "js", "ts", "css", "html", "sh", "yml", "yaml", "xml", "csv"
    ]

    /// "Code" spans source, scripts, and markup — JSON/HTML don't conform to `.sourceCode`, so this
    /// is curated rather than derived from `UTType`.
    static let codeExtensions: Set<String> = [
        "swift", "py", "js", "ts", "json", "html", "css", "cpp", "c", "h", "sh", "yml", "yaml"
    ]

    /// "Document" is a fuzzy user category with no single clean `UTType` — curated on purpose.
    static let documentExtensions: Set<String> = [
        "doc", "docx", "pdf", "pages", "txt", "md", "rtf", "odt", "xls", "xlsx"
    ]

    static func isImage(_ fileExtension: String) -> Bool {
        imageExtensions.contains(fileExtension.lowercased())
    }

    static func isText(_ fileExtension: String) -> Bool {
        textExtensions.contains(fileExtension.lowercased())
    }

    static func isCode(_ fileExtension: String) -> Bool {
        codeExtensions.contains(fileExtension.lowercased())
    }

    static func isDocument(_ fileExtension: String) -> Bool {
        documentExtensions.contains(fileExtension.lowercased())
    }
}
