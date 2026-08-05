import AppKit
import QuickLookThumbnailing
import UniformTypeIdentifiers

/// Generates real image previews via QuickLookThumbnailing, replacing the generic file-type
/// icon `NSWorkspace.icon(forFile:)` otherwise returns for every file regardless of its contents.
/// Results are cached per (path, size) so re-scrolling never re-requests the same thumbnail.
@MainActor
public final class ThumbnailService: ThumbnailServiceProtocol {
    public static let shared = ThumbnailService()
    private let cache = NSCache<NSString, NSImage>()

    private init() {}

    public static func isImage(fileExtension: String) -> Bool {
        guard let type = UTType(filenameExtension: fileExtension) else { return false }
        return type.conforms(to: .image)
    }

    public static func supportsThumbnail(item: FileItem) -> Bool {
        guard !item.isDirectory else { return false }
        guard let type = UTType(filenameExtension: item.fileExtension) else { return true }
        return !type.conforms(to: .archive) && !type.conforms(to: .folder)
    }

    public func cachedThumbnail(for url: URL, size: CGFloat) -> NSImage? {
        cache.object(forKey: cacheKey(url: url, size: size))
    }

    public func loadThumbnail(for url: URL, size: CGFloat) async -> NSImage? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let key = cacheKey(url: url, size: size)
        if let cached = cache.object(forKey: key) { return cached }

        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: size, height: size),
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

    private func cacheKey(url: URL, size: CGFloat) -> NSString {
        "\(url.standardizedFileURL.path)_\(Int(size))" as NSString
    }
}
