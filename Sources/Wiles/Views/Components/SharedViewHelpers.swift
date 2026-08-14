import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Scrolls a `"top"`-anchored `ScrollView` back to the top when the search query clears or a
/// newly-created item enters rename (it's always inserted at index 0) — shared by List and Grid,
/// which both scroll a single vertical list; Column view scrolls per-column instead, so it isn't
/// a fit for this modifier.
private struct ScrollToTopOnRenameOrSearchClear: ViewModifier {
    let appState: AppState
    let proxy: ScrollViewProxy

    func body(content: Content) -> some View {
        content
            .onChange(of: appState.searchQuery) { _, newValue in
                if newValue.isEmpty {
                    withAnimation(MotionTokens.mediumEase) {
                        proxy.scrollTo("top", anchor: .top)
                    }
                }
            }
            .onChange(of: appState.fileSystem.renamingURL) { _, newValue in
                if newValue != nil {
                    withAnimation(MotionTokens.mediumEase) {
                        proxy.scrollTo("top", anchor: .top)
                    }
                }
            }
    }
}

extension View {
    public func scrollToTopOnRenameOrSearchClear(appState: AppState, proxy: ScrollViewProxy) -> some View {
        modifier(ScrollToTopOnRenameOrSearchClear(appState: appState, proxy: proxy))
    }
}

public struct ICloudStatusBadgeView: View {
    let item: FileItem

    public init(item: FileItem) {
        self.item = item
    }

    public var body: some View {
        if item.isUbiquitousDownloading {
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: 14, height: 14)
        } else if item.isUbiquitousNotDownloaded {
            Image(systemName: "icloud.and.arrow.down.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.accentColor)
        } else if item.isUbiquitousUploading {
            Image(systemName: "icloud.and.arrow.up")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }
}
