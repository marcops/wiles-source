import AppKit

/// Per-window owner of the thumbnail *prefetch session*: the single `Task` that walks the current
/// folder's eligible images to warm `ThumbnailService`'s shared cache, cancelling the prior folder's
/// walk when navigation moves on. Deliberately NOT stored on `ThumbnailService.shared` — two windows
/// in different folders would each cancel the other's prefetch, so neither ever finished (ML-102).
/// The cache, mtime index and in-flight dedup it drives stay shared; only this session state is
/// per-window.
@MainActor
public final class ThumbnailPrefetcher {
    private let service: ThumbnailService
    private var prefetchTask: Task<Void, Never>?

    public init(service: ThumbnailService = .shared) {
        self.service = service
    }

    public func prefetch(for items: [FileItem], size _: CGFloat) {
        let eligibleURLs = items.filter(\.supportsThumbnail).map(\.url)
        guard !eligibleURLs.isEmpty else { return }
        prefetchTask?.cancel()
        let service = service
        prefetchTask = Task.detached(priority: .userInitiated) {
            for url in eligibleURLs {
                if Task.isCancelled {
                    break
                }
                await service.warmCache(for: url)
            }
        }
    }
}
