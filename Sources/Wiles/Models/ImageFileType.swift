import Foundation

/// Curated raster-image extensions for file-item image actions (Quick Convert, image-to-PDF merge).
/// Backed by `FileKindCatalog` (the single source of truth); deliberately narrower than
/// `ThumbnailService.isImage`'s `UTType` check (which also matches SVG/raw).
enum ImageFileType {
    static var extensions: Set<String> {
        FileKindCatalog.imageExtensions
    }

    /// Case-insensitive membership test for a bare filename extension (no leading dot).
    static func isImage(fileExtension: String) -> Bool {
        FileKindCatalog.isImage(fileExtension)
    }
}
