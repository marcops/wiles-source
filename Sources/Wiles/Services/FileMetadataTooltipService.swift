import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

/// Builds the hover-tooltip text for a file: name on top, then every metadata line that makes sense
/// for its type below. All files/folders get name, kind, size, dates, owner; only images (pixel
/// dimensions) and PDFs (page count) get extra lines. Reads are header-only, no full decode, and
/// results are cached per path since the tooltip is recomputed on every hover.
@MainActor
public enum FileMetadataTooltipService {
    private static var cache: [String: String] = [:]

    public static func tooltip(for item: FileItem) -> String {
        let key = item.url.path
        if let cached = cache[key] { return cached }

        var lines = [item.name]
        if item.isDirectory {
            lines.append("Folder")
        } else {
            lines.append(kindDescription(for: item))
            lines.append(item.formattedSize)
            if let extra = extraInfo(for: item) {
                lines.append(contentsOf: extra)
            }
        }
        lines.append("Modified \(item.formattedDate)")
        lines.append("Created \(item.formattedDateCreated)")
        if item.ownerName != "--" {
            lines.append("Owner \(item.ownerName)")
        }

        let text = lines.joined(separator: "\n")
        cache[key] = text
        return text
    }

    public static func invalidate(url: URL) {
        cache.removeValue(forKey: url.path)
    }

    private static func kindDescription(for item: FileItem) -> String {
        guard let type = UTType(filenameExtension: item.fileExtension) else {
            return item.fileExtension.isEmpty ? "Document" : item.fileExtension.uppercased()
        }
        return type.localizedDescription?.capitalized ?? item.fileExtension.uppercased()
    }

    private static func extraInfo(for item: FileItem) -> [String]? {
        guard let type = UTType(filenameExtension: item.fileExtension) else { return nil }

        if type.conforms(to: .pdf) {
            guard let doc = PDFDocument(url: item.url) else { return nil }
            return ["\(doc.pageCount) page\(doc.pageCount == 1 ? "" : "s")"]
        }

        if type.conforms(to: .image) {
            return pixelDimensions(for: item.url).map { [$0] }
        }

        return nil
    }

    private static func pixelDimensions(for url: URL) -> String? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            return nil
        }
        return "\(width) x \(height)"
    }
}
