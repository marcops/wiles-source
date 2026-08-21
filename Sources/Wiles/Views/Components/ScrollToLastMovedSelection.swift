import SwiftUI

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

public extension View {
    func scrollToLastMovedSelection(appState: AppState, proxy: ScrollViewProxy) -> some View {
        modifier(ScrollToLastMovedSelection(appState: appState, proxy: proxy))
    }
}
