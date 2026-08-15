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

public extension View {
    func fileItemContextMenu(for item: FileItem, appState: AppState) -> some View {
        modifier(FileContextMenuModifier(item: item, appState: appState))
    }
}
