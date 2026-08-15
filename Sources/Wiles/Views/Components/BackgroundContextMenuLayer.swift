import SwiftUI

struct BackgroundContextMenuLayer: View {
    var appState: AppState

    @Environment(WindowUIState.self)
    private var windowUIState

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .overlay(
                RightClickDetector {
                    appState.selectedURLs.removeAll()
                    windowUIState.renameItem = nil
                })
            .contextMenu {
                SharedBackgroundContextMenu(appState: appState)
            }
    }
}
