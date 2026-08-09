import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct FileRowInteractionsModifier: ViewModifier {
    let item: FileItem
    var appState: AppState
    let dragProvider: () -> NSItemProvider
    var onTargetedChanged: (Bool) -> Void = { _ in }

    func body(content: Content) -> some View {
        content
            .onTapGesture(count: 2) {
                appState.navigateTo(item.url)
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    appState.handleSelection(for: item)
                }
            )
            .onDrag(dragProvider)
            .springLoadedFolder(folderURL: item.url, isDirectory: item.isDirectory, appState: appState, onTargetedChanged: onTargetedChanged)
            .overlay(
                RightClickDetector {
                    if !appState.selectedURLs.contains(item.url) {
                        appState.selectedURLs = [item.url]
                    }
                }
            )
            .fileItemContextMenu(for: item, appState: appState)
    }
}
