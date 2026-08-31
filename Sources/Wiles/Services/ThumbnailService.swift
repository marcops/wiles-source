import AppKit
import QuickLookThumbnailing
import UniformTypeIdentifiers

/// QLThumbnailRepresentation is a read-only result type we never mutate; mark it unchecked
/// Sendable so awaiting generateBestRepresentation(for:) can return it into MainActor context.
extension QLThumbnailRepresentation: @retroactive @unchecked Sendable { }

/// The request is a value object we build once and never mutate; safe to hand to the `@Sendable`
/// cancellation handler that calls `QLThumbnailGenerator.cancel(_:)` on it.
extension QLThumbnailGenerator.Request: @retroactive @unchecked Sendable { }

/// Generates real image previews via QuickLookThumbnailing, replacing the generic file-type
/// icon `NSWorkspace.icon(forFile:)` otherwise returns for every file regardless of its contents.
/// Always generated once at `maxDimension`, cached per path — SwiftUI's `.resizable()` scales the
/// same bitmap down for whatever icon size is on screen, so zooming never re-triggers QuickLook I/O.
@MainActor
public final class ThumbnailService {
    public static let shared = ThumbnailService()
    private nonisolated static let maxDimension = IconSizeToken.renderResolution
    /// `nonisolated(unsafe)`: `NSCache` is documented thread-safe, so the off-actor generate/prefetch
    /// paths can read/write it directly without hopping to `@MainActor`.
    private nonisolated(unsafe) let cache = NSCache<NSString, NSImage>()

    /// Backing scale captured once at init; not worth a per-thumbnail `MainActor` hop just to re-read it.
    private nonisolated let deviceScale: CGFloat

    /// In-flight generations keyed by cache key, so a duplicate request awaits the first instead of
    /// regenerating. `awaiters` tracks how many `.task`s are currently waiting on it — when the last
    /// one is cancelled (its image cell scrolled off screen) the generation is cancelled too, so a
    /// fast scroll through a 2000-image folder doesn't run 2000 QuickLook generations to completion
    /// for thumbnails nobody will see (finding MM-118).
    private final class InFlightThumbnail: @unchecked Sendable {
        let task: Task<Void, Never>
        var awaiters = 0
        init(task: Task<Void, Never>) {
            self.task = task
        }
    }

    /// One-shot latch so a single waiter's release runs exactly once even though
    /// `withTaskCancellationHandler` can invoke both its body's tail and `onCancel`. Only ever read
    /// or written under `inFlightLock`.
    private final class ReleaseGuard: @unchecked Sendable {
        var released = false
    }

    private nonisolated(unsafe) var inFlight: [String: InFlightThumbnail] = [:]
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

    /// The deliberate *superset* of `FileKindCatalog.imageExtensions`: any `UTType` conforming to
    /// `.image` (SVG, RAW, …), i.e. "anything Quick Look could preview as an image", not the
    /// curated raster list used for image editing actions.
    public static func isImage(fileExtension: String) -> Bool {
        guard let type = UTType(filenameExtension: fileExtension) else { return false }
        return type.conforms(to: .image)
    }

    public static func supportsThumbnail(item: FileItem) -> Bool {
        item.supportsThumbnail
    }

    /// Pure UTType classification, no disk access — `FileItem` precomputes this once at build time
    /// so an icon `body` never re-derives it. `nonisolated` so `FileItem.init` can call it.
    public nonisolated static func supportsThumbnail(isDirectory: Bool, fileExtension: String) -> Bool {
        guard !isDirectory else { return false }
        guard !fileExtension.isEmpty else { return false }
        guard let type = UTType(filenameExtension: fileExtension) else { return false }
        if isExcludedFromThumbnails(type: type) {
            return false
        }
        return isPreviewableType(type: type)
    }

    private nonisolated static func isExcludedFromThumbnails(type: UTType) -> Bool {
        type.conforms(to: .sourceCode) ||
            type.conforms(to: .script) ||
            type.conforms(to: .archive) ||
            type.conforms(to: .folder) ||
            type.conforms(to: .executable)
    }

    private nonisolated static func isPreviewableType(type: UTType) -> Bool {
        type.conforms(to: .image) ||
            type.conforms(to: .movie) ||
            type.conforms(to: .audiovisualContent) ||
            type.conforms(to: .pdf) ||
            type.conforms(to: .presentation)
    }

    /// Prefetch only pays off for image-heavy folders that fit inside the thumbnail cache; above this
    /// a full-folder prefetch churns the 500-entry cache and burns CPU on thumbnails never scrolled to.
    private nonisolated static let prefetchItemCountCap: Int = 500

    public nonisolated static func shouldPrefetchThumbnails(forItemCount count: Int) -> Bool {
        count <= prefetchItemCountCap
    }

    /// Called from an image cell's `.task` — never `stat`s (`allowStatFallback: false`). The caller
    /// passes its `FileItem.dateModified` directly (ML-090): the mtime used to come from a shared
    /// `mtimeIndex` on this singleton that a second window's directory load would overwrite,
    /// silently breaking the first window's cache-key fast path.
    public nonisolated func cachedThumbnail(for url: URL, size _: CGFloat, dateModified: Date?) -> NSImage? {
        cache.object(forKey: cacheKey(url: url, mtime: dateModified, allowStatFallback: false))
    }

    public nonisolated func loadThumbnail(for url: URL, size _: CGFloat, dateModified: Date?) async -> NSImage? {
        await thumbnail(for: url, scale: deviceScale, mtime: dateModified)
    }

    /// Cache-check + generate, entirely off `@MainActor`. `QLThumbnailGenerator` tolerates a missing
    /// file (returns nil via the thrown error), so no synchronous `fileExists` pre-check is needed.
    private nonisolated func thumbnail(for url: URL, scale: CGFloat, mtime: Date?) async -> NSImage? {
        let key = cacheKey(url: url, mtime: mtime)
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let dedupKey = key as String
        let entry = inFlightLock.withLock { () -> InFlightThumbnail in
            let existing: InFlightThumbnail
            if let running = inFlight[dedupKey] {
                existing = running
            } else {
                let new = InFlightThumbnail(task: Task<Void, Never> { [weak self] in
                    await self?.generateAndCache(for: url, key: dedupKey, scale: scale)
                })
                inFlight[dedupKey] = new
                existing = new
            }
            existing.awaiters += 1
            return existing
        }

        let guardOnce = ReleaseGuard()
        await withTaskCancellationHandler {
            await entry.task.value
            releaseAwaiter(entry, dedupKey: dedupKey, once: guardOnce)
        } onCancel: {
            releaseAwaiter(entry, dedupKey: dedupKey, once: guardOnce)
        }
        return cache.object(forKey: key)
    }

    /// Drops one waiter from `entry` (exactly once via `once`); when the last waiter leaves,
    /// cancels the generation and removes it from `inFlight` so a later request starts fresh.
    private nonisolated func releaseAwaiter(_ entry: InFlightThumbnail, dedupKey: String, once: ReleaseGuard) {
        inFlightLock.withLock {
            guard !once.released else { return }
            once.released = true
            entry.awaiters -= 1
            guard entry.awaiters <= 0 else { return }
            entry.task.cancel()
            if inFlight[dedupKey] === entry {
                inFlight.removeValue(forKey: dedupKey)
            }
        }
    }

    private nonisolated func generateAndCache(for url: URL, key: String, scale: CGFloat) async {
        guard !Task.isCancelled else { return }
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: Self.maxDimension, height: Self.maxDimension),
            scale: scale,
            representationTypes: .thumbnail)
        let representation = await withTaskCancellationHandler {
            try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
        } onCancel: {
            // Stop the QuickLook work itself, not just the awaiting task, once every viewer of this
            // thumbnail has scrolled away (finding MM-118).
            QLThumbnailGenerator.shared.cancel(request)
        }
        guard !Task.isCancelled, let representation else { return }
        let image = representation.nsImage
        // `image.size` is points; the backing bitmap is scale× per axis, so real RGBA bytes are ·scale².
        let cost = Int(image.size.width * image.size.height * 4 * scale * scale)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }

    /// Warms the shared cache for one image, off `@MainActor`. The prefetch *session* — which
    /// folder's images, and cancelling a previous folder's walk — is owned per-window by
    /// `ThumbnailPrefetcher`, not by a task stored on this shared singleton (ML-102).
    nonisolated func warmCache(for url: URL, dateModified: Date?) async {
        _ = await thumbnail(for: url, scale: deviceScale, mtime: dateModified)
    }

    /// Mirrors `DirectoryCacheService.invalidate` — evicts a stale thumbnail after its file is overwritten.
    public nonisolated func invalidate(url: URL) {
        cache.removeObject(forKey: cacheKey(url: url, mtime: nil))
    }

    /// Keyed by path + mtime so an externally replaced file re-renders. `mtime` is the caller's
    /// `FileItem.dateModified` (per-window, never shared — ML-090); when it's `nil` a `stat` fills
    /// it in unless `allowStatFallback` is false (render-path callers must never `stat`).
    private nonisolated func cacheKey(url: URL, mtime: Date?, allowStatFallback: Bool = true) -> NSString {
        let std = url.standardizedFileURL
        var mtime = mtime
        if mtime == nil, allowStatFallback {
            mtime = (try? std.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        }
        let stamp = mtime.map { String($0.timeIntervalSinceReferenceDate) } ?? "0"
        return "\(std.path)|\(stamp)" as NSString
    }
}
