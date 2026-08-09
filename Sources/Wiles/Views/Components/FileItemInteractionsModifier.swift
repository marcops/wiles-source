import SwiftUI
import UniformTypeIdentifiers

public struct FileItemInteractionsModifier: ViewModifier {
    let item: FileItem
    var appState: AppState
    let onRightClick: (() -> Void)?
    let onSelect: (() -> Void)?
    var onTargetedChanged: (Bool) -> Void

    public init(
        item: FileItem,
        appState: AppState,
        onRightClick: (() -> Void)? = nil,
        onSelect: (() -> Void)? = nil,
        onTargetedChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.item = item
        self.appState = appState
        self.onRightClick = onRightClick
        self.onSelect = onSelect
        self.onTargetedChanged = onTargetedChanged
    }

    public func body(content: Content) -> some View {
        content
            .onTapGesture(count: 2) {
                appState.navigateTo(item.url)
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    if let onSelect {
                        onSelect()
                    } else {
                        appState.handleSelection(for: item)
                    }
                }
            )
            .onDrag {
                if !appState.selectedURLs.contains(item.url) {
                    appState.selectedURLs = [item.url]
                }
                let urls = Array(appState.selectedURLs)
                let provider = NSItemProvider()
                for fileURL in urls {
                    provider.registerObject(fileURL as NSURL, visibility: .all)
                }
                return provider
            }
            .springLoadedFolder(folderURL: item.url, isDirectory: item.isDirectory, appState: appState, onTargetedChanged: onTargetedChanged)
            .overlay(
                RightClickDetector {
                    if let onRightClick {
                        onRightClick()
                    } else if !appState.selectedURLs.contains(item.url) {
                        appState.selectedURLs = [item.url]
                    }
                }
            )
            .fileItemContextMenu(for: item, appState: appState)
    }
}

extension View {
    public func fileItemInteractions(
        item: FileItem,
        appState: AppState,
        onRightClick: (() -> Void)? = nil,
        onSelect: (() -> Void)? = nil,
        onTargetedChanged: @escaping (Bool) -> Void = { _ in }
    ) -> some View {
        self.modifier(
            FileItemInteractionsModifier(
                item: item,
                appState: appState,
                onRightClick: onRightClick,
                onSelect: onSelect,
                onTargetedChanged: onTargetedChanged
            )
        )
    }
}
