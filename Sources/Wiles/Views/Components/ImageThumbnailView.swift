import SwiftUI
import AppKit

struct ImageThumbnailView: View {
    let url: URL
    let size: CGFloat
    let fallback: NSImage
    @State private var thumbnail: NSImage?

    init(url: URL, size: CGFloat, fallback: NSImage) {
        self.url = url
        self.size = size
        self.fallback = fallback
        let cached = ThumbnailService.shared.cachedThumbnail(for: url, size: size)
        self._thumbnail = State(initialValue: cached)
    }

    var body: some View {
        Image(nsImage: thumbnail ?? fallback)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .task(id: url) {
                guard thumbnail == nil else { return }
                // Debounce: during a fast scroll fling, rows appear and disappear within a frame
                // or two. SwiftUI cancels this task the instant the row leaves the hierarchy, so
                // waiting a beat before starting the real QuickLook I/O means a row that's only
                // ever transiently visible never costs any CPU — only rows the scroll settles on do.
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled, thumbnail == nil else { return }
                if let loaded = await ThumbnailService.shared.loadThumbnail(for: url, size: size) {
                    thumbnail = loaded
                }
            }
    }
}
