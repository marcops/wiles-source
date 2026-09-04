import SwiftUI

private struct ResetPaginationAndPrefetchThumbnails: ViewModifier {
    let appState: AppState
    @Binding var visibleLimit: Int
    let thumbnailIconSize: CGFloat

    private func prefetchIfNeeded(_ items: [FileItem]) {
        // No shared mtime index any more — each image cell passes its own `FileItem.dateModified`
        // straight into `ThumbnailService`.
        guard !appState.fileSystem.isStreamingBatches else { return }
        if ThumbnailService.shouldPrefetchThumbnails(forItemCount: items.count) {
            appState.thumbnailPrefetcher.prefetch(for: items, size: thumbnailIconSize)
        }
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: appState.navigation.currentURL) { _, _ in
                visibleLimit = LayoutTokens.paginationThreshold
            }
            .onChange(of: appState.fileSystem.items) { _, newItems in
                // While a "search everywhere" crawl is streaming, `items` is re-assigned ~8×/s and
                // each hit here would cancel-and-restart the prefetch, so it never warms anything.
                // `prefetchIfNeeded` no-ops during streaming; the crawl's end re-fires it once below
                // on the complete list.
                prefetchIfNeeded(newItems)
            }
            .onChange(of: appState.fileSystem.isStreamingBatches) { _, isStreaming in
                if !isStreaming {
                    prefetchIfNeeded(appState.fileSystem.items)
                }
            }
            .onAppear {
                prefetchIfNeeded(appState.fileSystem.items)
            }
    }
}

public extension View {
    func resetPaginationAndPrefetchThumbnails(appState: AppState, visibleLimit: Binding<Int>, thumbnailIconSize: CGFloat) -> some View {
        modifier(ResetPaginationAndPrefetchThumbnails(appState: appState, visibleLimit: visibleLimit, thumbnailIconSize: thumbnailIconSize))
    }
}
