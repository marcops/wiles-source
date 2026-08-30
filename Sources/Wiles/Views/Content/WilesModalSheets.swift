import SwiftUI

/// The window's modal presentations. One `.sheet(item:)` bound to `WindowUIState.activeModal`
/// switches on `ActiveModal` to build the right feature sheet; confirmation alerts and the move
/// name-collision prompt live in `WilesModalAlerts`. Extracted out of `MainContentView` to keep
/// that view's body under this project's body-decomposition guideline.
struct WilesModalSheets: ViewModifier {
    let appState: AppState
    let windowUIState: WindowUIState

    func body(content: Content) -> some View {
        @Bindable var windowUIState = windowUIState
        content
            .sheet(item: $windowUIState.activeModal) { modal in
                sheet(for: modal)
            }
            .modifier(WilesModalAlerts(appState: appState, windowUIState: windowUIState))
    }

    @ViewBuilder
    private func sheet(for modal: ActiveModal) -> some View {
        switch modal {
        case let .properties(item):
            FilePropertiesSheet(item: item, appState: appState)
        case let .imageConverter(item):
            ImageConverterSheetView(item: item, appState: appState)
        case let .symlink(item):
            SymlinkSheetView(item: item, appState: appState)
        case let .httpShare(url):
            HttpShareSheet(appState: appState, folderURL: url)
        case let .inspectArchive(url):
            ArchiveInspectionSheetView(archiveURL: url, appState: appState)
        case let .passwordCompress(urls):
            PasswordCompressSheetView(appState: appState, urls: urls)
        case .batchRename:
            BatchRenameSheetView(items: selectedItems, appState: appState)
        case .connectToServer:
            ConnectToServerSheetView(appState: appState)
        case .autoOrganization:
            AutoOrganizationSheet(appState: appState)
        case .duplicateCleaner:
            DuplicateCleanerSheetView(appState: appState)
        case .saveSmartFolder:
            SaveSmartFolderSheetView(appState: appState)
        case .help, .feedback, .about, .settings:
            infoSheet(for: modal)
        }
    }

    /// The four "app info" sheets (no payload), split off `sheet(for:)` to keep its branch count
    /// under the `cyclomatic_complexity` limit.
    @ViewBuilder
    private func infoSheet(for modal: ActiveModal) -> some View {
        switch modal {
        case .feedback:
            FeedbackSheetView(appState: appState)
        case .about:
            AboutSheet(appState: appState)
        case .settings:
            SettingsView(appState: appState)
        default:
            HelpSheet(appState: appState)
        }
    }

    private var selectedItems: [FileItem] {
        appState.fileSystem.items.filter { appState.selection.selectedURLs.contains($0.url) }
    }
}
