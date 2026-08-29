import SwiftUI

private struct ResetPaginationAndPrefetchThumbnails: ViewModifier {
    private static let thumbnailPrefetchItemThreshold: Int = 500

    let appState: AppState
    @Binding var visibleLimit: Int
    let thumbnailIconSize: CGFloat

    private func prefetchIfNeeded(_ items: [FileItem]) {
        // Always index mtimes — `cachedThumbnail` reads the index from every image cell body regardless of folder size.
        ThumbnailService.shared.indexModificationDates(items)
        if items.count > Self.thumbnailPrefetchItemThreshold {
            ThumbnailService.shared.prefetchThumbnails(for: items, size: thumbnailIconSize)
        }
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: appState.navigation.currentURL) { _, _ in
                visibleLimit = LayoutTokens.paginationThreshold
            }
            .onChange(of: appState.fileSystem.items) { _, newItems in
                prefetchIfNeeded(newItems)
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
