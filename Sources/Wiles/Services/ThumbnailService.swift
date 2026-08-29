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
public final class ThumbnailService {
    public static let shared = ThumbnailService()
    private nonisolated static let maxDimension: CGFloat = 512
    /// `nonisolated(unsafe)`: `NSCache` is documented thread-safe, so the off-actor generate/prefetch
    /// paths can read/write it directly without hopping to `@MainActor`.
    private nonisolated(unsafe) let cache = NSCache<NSString, NSImage>()
    private var prefetchTask: Task<Void, Never>?

    /// Backing scale captured once at init; not worth a per-thumbnail `MainActor` hop just to re-read it.
    private nonisolated let deviceScale: CGFloat

    /// Path→mtime snapshot from the most recent directory load; lets `cacheKey` skip a per-call `stat`.
    private nonisolated(unsafe) var mtimeIndex: [String: Date] = [:]
    private nonisolated let mtimeIndexLock = NSLock()

    /// In-flight generations keyed by cache key, so a duplicate request awaits the first instead of regenerating.
    private nonisolated(unsafe) var inFlight: [String: Task<Void, Never>] = [:]
    private nonisolated let inFlightLock = NSLock()

    private init() {
        deviceScale = NSScreen.main?.backingScaleFactor ?? 2.0
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

    public nonisolated func cachedThumbnail(for url: URL, size _: CGFloat) -> NSImage? {
        cache.object(forKey: cacheKey(url: url))
    }

    /// Callers must invoke this on directory load so `cachedThumbnail` from a view body needs no `stat` (wiring: see report).
    public nonisolated func indexModificationDates(_ items: [FileItem]) {
        var index: [String: Date] = [:]
        index.reserveCapacity(items.count)
        for item in items {
            index[item.url.standardizedFileURL.path] = item.dateModified
        }
        mtimeIndexLock.lock()
        mtimeIndex = index
        mtimeIndexLock.unlock()
    }

    public nonisolated func loadThumbnail(for url: URL, size _: CGFloat) async -> NSImage? {
        await thumbnail(for: url, scale: deviceScale)
    }

    /// Cache-check + generate, entirely off `@MainActor`. `QLThumbnailGenerator` tolerates a missing
    /// file (returns nil via the thrown error), so no synchronous `fileExists` pre-check is needed.
    private nonisolated func thumbnail(for url: URL, scale: CGFloat) async -> NSImage? {
        let key = cacheKey(url: url)
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let dedupKey = key as String
        let (generation, isOwner) = inFlightLock.withLock { () -> (Task<Void, Never>, Bool) in
            if let running = inFlight[dedupKey] {
                return (running, false)
            }
            let new = Task<Void, Never> { [weak self] in
                await self?.generateAndCache(for: url, key: dedupKey, scale: scale)
            }
            inFlight[dedupKey] = new
            return (new, true)
        }
        await generation.value
        if isOwner {
            inFlightLock.withLock { _ = inFlight.removeValue(forKey: dedupKey) }
        }
        return cache.object(forKey: key)
    }

    private nonisolated func generateAndCache(for url: URL, key: String, scale: CGFloat) async {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: Self.maxDimension, height: Self.maxDimension),
            scale: scale,
            representationTypes: .thumbnail)
        guard let representation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) else {
            return
        }
        let image = representation.nsImage
        let cost = Int(image.size.width * image.size.height * 4) // rough RGBA-bitmap byte estimate
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }

    public func prefetchThumbnails(for items: [FileItem], size _: CGFloat) {
        let eligibleURLs = items.filter { Self.supportsThumbnail(item: $0) }.map(\.url)
        guard !eligibleURLs.isEmpty else { return }
        // Cancel any prefetch still running for a previously-viewed folder — otherwise it keeps
        // burning CPU generating thumbnails for a folder the user already navigated away from.
        prefetchTask?.cancel()
        let scale = deviceScale
        prefetchTask = Task.detached(priority: .userInitiated) { [weak self] in
            for url in eligibleURLs {
                if Task.isCancelled {
                    break
                }
                _ = await self?.thumbnail(for: url, scale: scale)
            }
        }
    }

    /// Mirrors `DirectoryCacheService.invalidate` — evicts a stale thumbnail after its file is overwritten.
    public nonisolated func invalidate(url: URL) {
        cache.removeObject(forKey: cacheKey(url: url))
    }

    /// Keyed by path + mtime so an externally replaced file re-renders; mtime from `mtimeIndex`, else a `stat`.
    private nonisolated func cacheKey(url: URL) -> NSString {
        let std = url.standardizedFileURL
        let mtime = indexedModificationDate(forPath: std.path)
            ?? (try? std.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        let stamp = mtime.map { String($0.timeIntervalSinceReferenceDate) } ?? "0"
        return "\(std.path)|\(stamp)" as NSString
    }

    private nonisolated func indexedModificationDate(forPath path: String) -> Date? {
        mtimeIndexLock.lock()
        defer { mtimeIndexLock.unlock() }
        return mtimeIndex[path]
    }
}
