import SwiftUI

/// The second half of the window's feature sheets — split out of `WilesModalSheets` purely to
/// keep that modifier's `body(content:)` under this project's ~40-line function-body-length limit
/// (pure code motion, no behavior change).
struct WilesModalSheetsSecondary: ViewModifier {
    let appState: AppState
    let windowUIState: WindowUIState

    func body(content: Content) -> some View {
        @Bindable var appState = appState
        @Bindable var windowUIState = windowUIState
        content
            .sheet(item: $windowUIState.imageConverterItem) { item in
                ImageConverterSheetView(item: item, appState: appState)
            }
            .sheet(isPresented: $windowUIState.showBatchRenameSheet) {
                let selectedItems = appState.fileSystem.items.filter { appState.selection.selectedURLs.contains($0.url) }
                BatchRenameSheetView(items: selectedItems, appState: appState)
            }
            .sheet(isPresented: $windowUIState.showConnectToServerSheet) {
                ConnectToServerSheetView(appState: appState)
            }
            .sheet(item: $windowUIState.symlinkItem) { item in
                SymlinkSheetView(item: item, appState: appState)
            }
            .sheet(isPresented: $windowUIState.showSaveSmartFolderSheet) {
                SaveSmartFolderSheetView(appState: appState)
            }
            .sheet(isPresented: $windowUIState.showPasswordCompressSheet) {
                PasswordCompressSheetView(appState: appState)
            }
            .sheet(isPresented: $windowUIState.showArchiveInspectionSheet) {
                if let url = windowUIState.inspectArchiveURL {
                    ArchiveInspectionSheetView(archiveURL: url, appState: appState)
                }
            }
    }
}
