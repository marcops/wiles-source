import AppKit
import QuickLookThumbnailing
import UniformTypeIdentifiers

/// QLThumbnailRepresentation is a read-only result type we never mutate; mark it unchecked
/// Sendable so awaiting generateBestRepresentation(for:) can return it into MainActor context.
extension QLThumbnailRepresentation: @retroactive @unchecked Sendable { }

/// Generates real image previews via QuickLookThumbnailing, replacing the generic file-type
/// icon `NSWorkspace.icon(forFile:)` otherwise returns for every file regardless of its contents.
/// Always generated once at `maxDimension`, cached per path — SwiftUI's `.resizable()` scales the
/// same bitmap down for whatever icon size is on screen, so zooming never re-triggers QuickLook I/O.
@MainActor
public final class ThumbnailService: ThumbnailServiceProtocol {
    public static let shared = ThumbnailService()
    private static let maxDimension: CGFloat = 512
    private let cache = NSCache<NSString, NSImage>()
    private var prefetchTask: Task<Void, Never>?

    private init() {
        // Without these, a folder with thousands of images would cache every full-size bitmap
        // forever, easily ballooning to gigabytes of RAM. totalCostLimit only takes effect because
        // setObject below passes a real per-image byte cost — without that, NSCache treats every
        // entry as cost 0 and this limit silently never triggers.
        cache.countLimit = 500
        cache.totalCostLimit = 100 * 1024 * 1024 // 100 MB RAM limit
    }

    public static func isImage(fileExtension: String) -> Bool {
        guard let type = UTType(filenameExtension: fileExtension) else { return false }
        return type.conforms(to: .image)
    }

    public static func supportsThumbnail(item: FileItem) -> Bool {
        guard !item.isDirectory else { return false }
        guard !item.fileExtension.isEmpty else { return false }
        guard let type = UTType(filenameExtension: item.fileExtension) else { return false }
        if isExcludedFromThumbnails(type: type) {
            return false
        }
        return isPreviewableType(type: type)
    }

    private static func isExcludedFromThumbnails(type: UTType) -> Bool {
        type.conforms(to: .sourceCode) ||
            type.conforms(to: .script) ||
            type.conforms(to: .archive) ||
            type.conforms(to: .folder) ||
            type.conforms(to: .executable)
    }

    private static func isPreviewableType(type: UTType) -> Bool {
        type.conforms(to: .image) ||
            type.conforms(to: .movie) ||
            type.conforms(to: .audiovisualContent) ||
            type.conforms(to: .pdf) ||
            type.conforms(to: .presentation)
    }

    public func cachedThumbnail(for url: URL, size _: CGFloat) -> NSImage? {
        cache.object(forKey: cacheKey(url: url))
    }

    public func loadThumbnail(for url: URL, size _: CGFloat) async -> NSImage? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let key = cacheKey(url: url)
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: Self.maxDimension, height: Self.maxDimension),
            scale: scale,
            representationTypes: .thumbnail)
        guard let representation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) else {
            return nil
        }
        let image = representation.nsImage
        let cost = Int(image.size.width * image.size.height * 4) // rough RGBA-bitmap byte estimate
        cache.setObject(image, forKey: key, cost: cost)
        return image
    }

    public func prefetchThumbnails(for items: [FileItem], size: CGFloat) {
        let eligibleItems = items.filter { Self.supportsThumbnail(item: $0) }
        guard !eligibleItems.isEmpty else { return }
        // Cancel any prefetch still running for a previously-viewed folder — otherwise it keeps
        // burning CPU generating thumbnails for a folder the user already navigated away from.
        prefetchTask?.cancel()
        prefetchTask = Task(priority: .userInitiated) { [weak self] in
            for item in eligibleItems {
                if Task.isCancelled {
                    break
                }
                _ = await self?.loadThumbnail(for: item.url, size: size)
            }
        }
    }

    private func cacheKey(url: URL) -> NSString {
        url.standardizedFileURL.path as NSString
    }
}
