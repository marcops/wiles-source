import Foundation

/// Curated raster-image extensions for file-item image actions (Quick Convert, image-to-PDF merge).
/// Deliberately narrower than `ThumbnailService.isImage`'s `UTType` check (which also matches SVG/raw).
enum ImageFileType {
    static let extensions: Set<String> = ["png", "jpg", "jpeg", "heic", "webp", "tiff", "bmp", "gif"]

    /// Case-insensitive membership test for a bare filename extension (no leading dot).
    static func isImage(fileExtension: String) -> Bool {
        extensions.contains(fileExtension.lowercased())
    }
}
