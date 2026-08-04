import SwiftUI

public struct FileContextMenuModifier: ViewModifier {
    public let item: FileItem
    public var appState: AppState

    public func body(content: Content) -> some View {
        content.contextMenu {
            SharedFileItemContextMenu(item: item, appState: appState)
        }
    }
}

extension View {
    public func fileItemContextMenu(for item: FileItem, appState: AppState) -> some View {
        self.modifier(FileContextMenuModifier(item: item, appState: appState))
    }
}
