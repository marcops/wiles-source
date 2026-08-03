import SwiftUI
import UniformTypeIdentifiers

public struct FileItemInteractionsModifier: ViewModifier {
    let item: FileItem
    var appState: AppState
    let onRightClick: (() -> Void)?

    public init(item: FileItem, appState: AppState, onRightClick: (() -> Void)? = nil) {
        self.item = item
        self.appState = appState
        self.onRightClick = onRightClick
    }

    public func body(content: Content) -> some View {
        content
            .onDrag {
                if !appState.selectedURLs.contains(item.url) {
                    appState.selectedURLs = [item.url]
                }
                let urls = Array(appState.selectedURLs)
                let provider = NSItemProvider()
                for u in urls {
                    provider.registerObject(u as NSURL, visibility: .all)
                }
                return provider
            }
            .overlay(
                RightClickDetector {
                    if let onRightClick {
                        onRightClick()
                    } else if !appState.selectedURLs.contains(item.url) {
                        appState.selectedURLs = [item.url]
                    }
                }
            )
            .contextMenu {
                SharedFileItemContextMenu(item: item, appState: appState)
            }
    }
}

extension View {
    public func fileItemInteractions(
        item: FileItem,
        appState: AppState,
        onRightClick: (() -> Void)? = nil
    ) -> some View {
        self.modifier(
            FileItemInteractionsModifier(item: item, appState: appState, onRightClick: onRightClick)
        )
    }
}
