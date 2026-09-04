import AppKit

/// Per-window owner of the thumbnail *prefetch session*: the single `Task` that walks the current
/// folder's eligible images to warm `ThumbnailService`'s shared cache, cancelling the prior folder's
/// walk when navigation moves on. Deliberately NOT stored on `ThumbnailService.shared` — two windows
/// in different folders would each cancel the other's prefetch, so neither ever finished.
/// The cache, mtime index and in-flight dedup it drives stay shared; only this session state is
/// per-window.
@MainActor
public final class ThumbnailPrefetcher {
    private let service: ThumbnailService
    private var prefetchTask: Task<Void, Never>?

    public init(service: ThumbnailService = .shared) {
        self.service = service
    }

    /// Stops the in-flight prefetch walk when the owning window goes away (otherwise the detached
    /// task keeps warming the cache for a folder nobody is viewing).
    deinit {
        prefetchTask?.cancel()
    }

    public func prefetch(for items: [FileItem], size _: CGFloat) {
        let eligible = items.filter(\.supportsThumbnail).map { ($0.url, $0.dateModified) }
        guard !eligible.isEmpty else { return }
        prefetchTask?.cancel()
        let service = service
        prefetchTask = Task.detached(priority: .userInitiated) {
            for (url, dateModified) in eligible {
                if Task.isCancelled {
                    break
                }
                await service.warmCache(for: url, dateModified: dateModified)
            }
        }
    }
}
