import SwiftUI
import AppKit

struct ImageThumbnailView: View {
    let url: URL
    let size: CGFloat
    let fallback: NSImage
    @State private var thumbnail: NSImage?

    var body: some View {
        Image(nsImage: thumbnail ?? fallback)
            .resizable()
            .scaledToFit()
            .task(id: url) {
                if let cached = ThumbnailService.shared.cachedThumbnail(for: url, size: size) {
                    thumbnail = cached
                    return
                }
                thumbnail = await ThumbnailService.shared.loadThumbnail(for: url, size: size)
            }
    }
}
