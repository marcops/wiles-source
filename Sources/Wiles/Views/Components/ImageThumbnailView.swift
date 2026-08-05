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
                if thumbnail == nil {
                    if let loaded = await ThumbnailService.shared.loadThumbnail(for: url, size: size) {
                        thumbnail = loaded
                    }
                }
            }
    }
}
