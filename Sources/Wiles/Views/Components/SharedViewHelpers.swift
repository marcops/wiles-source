import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
func scrollToTopAnimated(_ proxy: ScrollViewProxy) {
    // Deferred a tick: called right as a new row is inserted, so the list's layout hasn't
    // settled yet — scrolling in the same update cycle computes the wrong target offset.
    Task { @MainActor in
        withAnimation(MotionTokens.mediumEase) {
            proxy.scrollTo("top", anchor: .top)
        }
    }
}

private struct ScrollToTopOnRenameOrSearchClear: ViewModifier {
    let appState: AppState
    let proxy: ScrollViewProxy

    func body(content: Content) -> some View {
        content
            .onChange(of: appState.searchQuery) { _, newValue in
                if newValue.isEmpty {
                    scrollToTopAnimated(proxy)
                }
            }
            .onChange(of: appState.fileSystem.renamingURL) { _, newValue in
                if newValue != nil {
                    scrollToTopAnimated(proxy)
                }
            }
    }
}

extension View {
    public func scrollToTopOnRenameOrSearchClear(appState: AppState, proxy: ScrollViewProxy) -> some View {
        modifier(ScrollToTopOnRenameOrSearchClear(appState: appState, proxy: proxy))
    }
}

private struct ScrollToLastMovedSelection: ViewModifier {
    let appState: AppState
    let proxy: ScrollViewProxy

    func body(content: Content) -> some View {
        content
            .onChange(of: appState.selection.lastMovedURL) { _, newValue in
                guard let newValue else { return }
                withAnimation(MotionTokens.quickEase) {
                    proxy.scrollTo(newValue)
                }
            }
    }
}

extension View {
    public func scrollToLastMovedSelection(appState: AppState, proxy: ScrollViewProxy) -> some View {
        modifier(ScrollToLastMovedSelection(appState: appState, proxy: proxy))
    }
}

private struct ResetPaginationAndPrefetchThumbnails: ViewModifier {
    let appState: AppState
    @Binding var visibleLimit: Int
    let thumbnailIconSize: CGFloat

    private func prefetchIfNeeded(_ items: [FileItem]) {
        if items.count > 500 {
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

extension View {
    public func resetPaginationAndPrefetchThumbnails(appState: AppState, visibleLimit: Binding<Int>, thumbnailIconSize: CGFloat) -> some View {
        modifier(ResetPaginationAndPrefetchThumbnails(appState: appState, visibleLimit: visibleLimit, thumbnailIconSize: thumbnailIconSize))
    }
}
