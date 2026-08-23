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
    private static let cacheCountLimit = 1000
    private static let cache: NSCache<NSString, NSString> = {
        let cache = NSCache<NSString, NSString>()
        cache.countLimit = cacheCountLimit
        return cache
    }()

    public static func tooltip(for item: FileItem, language: AppLanguage) async -> String {
        let key = "\(L10n.activeCode(language))|\(item.url.path)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached as String
        }

        var lines = [item.name]
        if item.isDirectory {
            lines.append(L10n.string(.tooltipFolder, lang: language))
        } else {
            lines.append(kindDescription(for: item, language: language))
            lines.append(item.formattedSize)
            if let extra = await extraInfo(for: item, language: language) {
                lines.append(contentsOf: extra)
            }
        }
        lines.append(String(format: L10n.string(.tooltipModified, lang: language), item.formattedDate(language: language)))
        lines.append(String(format: L10n.string(.tooltipCreated, lang: language), item.formattedDateCreated(language: language)))
        if item.ownerName != "--" {
            lines.append(String(format: L10n.string(.tooltipOwner, lang: language), item.ownerName))
        }

        let text = lines.joined(separator: "\n")
        cache.setObject(text as NSString, forKey: key)
        return text
    }

    public static func invalidate(url: URL) {
        // Cache keys are "<languageCode>|<path>" (see `tooltip(for:language:)`), and `NSCache`
        // can't enumerate/pattern-match its keys — so every language's entry for this path must be
        // removed individually rather than trying to remove by bare path.
        for lang in AppLanguage.allCases {
            let key = "\(L10n.activeCode(lang))|\(url.path)" as NSString
            cache.removeObject(forKey: key)
        }
    }

    private static func kindDescription(for item: FileItem, language: AppLanguage) -> String {
        guard let type = UTType(filenameExtension: item.fileExtension) else {
            return item.fileExtension.isEmpty ? L10n.string(.tooltipDocumentFallback, lang: language) : item.fileExtension.uppercased()
        }
        return type.localizedDescription?.capitalized ?? item.fileExtension.uppercased()
    }

    private static func extraInfo(for item: FileItem, language: AppLanguage) async -> [String]? {
        guard let type = UTType(filenameExtension: item.fileExtension) else { return nil }

        if type.conforms(to: .pdf) {
            return await pdfPageCountLine(for: item.url, language: language)
        }

        if type.conforms(to: .image) {
            return await pixelDimensions(for: item.url).map { [$0] }
        }

        return nil
    }

    /// PDF parsing can be slow for large multi-hundred-page documents or files on a network share,
    /// so it must never block @MainActor synchronously during a hover event.
    private static func pdfPageCountLine(for url: URL, language: AppLanguage) async -> [String]? {
        let oneFormat = L10n.string(.tooltipPageCountOne, lang: language)
        let otherFormat = L10n.string(.tooltipPageCountOther, lang: language)
        return await Task.detached(priority: .utility) {
            guard let doc = PDFDocument(url: url) else { return nil }
            let count = doc.pageCount
            return [String(format: count == 1 ? oneFormat : otherFormat, count)]
        }.value
    }

    /// Image header reads can block on a slow network mount or a large RAW file with an embedded
    /// thumbnail, so this must never block @MainActor synchronously during a hover event.
    private static func pixelDimensions(for url: URL) async -> String? {
        await Task.detached(priority: .utility) {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Int,
                  let height = properties[kCGImagePropertyPixelHeight] as? Int else {
                return nil
            }
            return "\(width) x \(height)"
        }.value
    }
}
