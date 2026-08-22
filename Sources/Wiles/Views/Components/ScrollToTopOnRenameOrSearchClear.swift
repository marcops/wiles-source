import SwiftUI

private struct ScrollToTopOnRenameOrSearchClear: ViewModifier {
    let appState: AppState
    let proxy: ScrollViewProxy

    func body(content: Content) -> some View {
        content
            .onChange(of: appState.selection.searchQuery) { _, newValue in
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

public extension View {
    func scrollToTopOnRenameOrSearchClear(appState: AppState, proxy: ScrollViewProxy) -> some View {
        modifier(ScrollToTopOnRenameOrSearchClear(appState: appState, proxy: proxy))
    }
}
