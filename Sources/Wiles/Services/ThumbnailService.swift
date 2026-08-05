import AppKit
import QuickLookThumbnailing
import UniformTypeIdentifiers

/// Generates real image previews via QuickLookThumbnailing, replacing the generic file-type
/// icon `NSWorkspace.icon(forFile:)` otherwise returns for every file regardless of its contents.
/// Always generated once at `maxDimension`, cached per path — SwiftUI's `.resizable()` scales the
/// same bitmap down for whatever icon size is on screen, so zooming never re-triggers QuickLook I/O.
@MainActor
public final class ThumbnailService: ThumbnailServiceProtocol {
    public static let shared = ThumbnailService()
    private static let maxDimension: CGFloat = 512
    private let cache = NSCache<NSString, NSImage>()

    private init() {}

    public static func isImage(fileExtension: String) -> Bool {
        guard let type = UTType(filenameExtension: fileExtension) else { return false }
        return type.conforms(to: .image)
    }

    public static func supportsThumbnail(item: FileItem) -> Bool {
        guard !item.isDirectory else { return false }
        guard !item.fileExtension.isEmpty else { return false }
        guard let type = UTType(filenameExtension: item.fileExtension) else { return false }
        if type.conforms(to: .sourceCode) ||
           type.conforms(to: .script) ||
           type.conforms(to: .archive) ||
           type.conforms(to: .folder) ||
           type.conforms(to: .executable) {
            return false
        }
        return type.conforms(to: .image) ||
               type.conforms(to: .movie) ||
               type.conforms(to: .audiovisualContent) ||
               type.conforms(to: .pdf) ||
               type.conforms(to: .presentation)
    }

    public func cachedThumbnail(for url: URL, size: CGFloat) -> NSImage? {
        cache.object(forKey: cacheKey(url: url))
    }

    public func loadThumbnail(for url: URL, size: CGFloat) async -> NSImage? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let key = cacheKey(url: url)
        if let cached = cache.object(forKey: key) { return cached }

        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: Self.maxDimension, height: Self.maxDimension),
            scale: scale,
            representationTypes: .thumbnail
        )
        guard let representation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) else {
            return nil
        }
        cache.setObject(representation.nsImage, forKey: key)
        return representation.nsImage
    }

    public func prefetchThumbnails(for items: [FileItem], size: CGFloat) {
        let eligibleItems = items.filter { Self.supportsThumbnail(item: $0) }
        guard !eligibleItems.isEmpty else { return }
        Task.detached(priority: .userInitiated) {
            for item in eligibleItems {
                _ = await self.loadThumbnail(for: item.url, size: size)
            }
        }
    }

    private func cacheKey(url: URL) -> NSString {
        url.standardizedFileURL.path as NSString
    }
}
