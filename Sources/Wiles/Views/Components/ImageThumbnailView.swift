import AppKit
import SwiftUI

struct ImageThumbnailView: View {
    let url: URL
    let size: CGFloat
    let fallback: NSImage
    @State private var thumbnail: NSImage?

    var body: some View {
        Image(nsImage: thumbnail ?? fallback)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .task(id: url) {
                guard thumbnail == nil else { return }
                // Instant path: a hit in the in-memory cache (non-stat) shows immediately, no debounce.
                if let cached = ThumbnailService.shared.cachedThumbnail(for: url, size: size) {
                    thumbnail = cached
                    return
                }
                // Debounce: during a fast scroll fling, rows appear and disappear within a frame
                // or two. SwiftUI cancels this task the instant the row leaves the hierarchy, so
                // waiting a beat before starting the real QuickLook I/O means a row that's only
                // ever transiently visible never costs any CPU — only rows the scroll settles on do.
                try? await Task.sleep(for: AsyncDelayTokens.scrollSettleDebounce)
                guard !Task.isCancelled, thumbnail == nil else { return }
                if let loaded = await ThumbnailService.shared.loadThumbnail(for: url, size: size) {
                    thumbnail = loaded
                }
            }
            // Decorative: the hosting row/card already carries the file's accessible label.
            .accessibilityHidden(true)
    }
}
