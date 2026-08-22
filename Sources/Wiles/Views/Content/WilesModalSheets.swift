import SwiftUI

/// The window's full set of modal sheet/alert presentations — Properties, Help, Feedback, About,
/// Settings, Auto-Organization, Duplicate Cleaner, HTTP Share, Image Converter, Batch Rename,
/// Connect to Server, Symlink, Save Smart Folder, Password Compress, Archive Inspection, the Empty
/// Trash confirm, the Move to Trash confirm, and the generic error alert. Extracted out of
/// `MainContentView.mainSplitView` into its own `ViewModifier` purely to keep that computed
/// property under this project's ~30-line body-decomposition guideline (see
/// `.agents/SWIFT_LANG_RULES.md`). This is pure code motion: every sheet/alert's triggering
/// condition, binding, and content are unchanged from before the extraction.
struct WilesModalSheets: ViewModifier {
    let appState: AppState
    let windowUIState: WindowUIState

    func body(content: Content) -> some View {
        @Bindable var appState = appState
        @Bindable var windowUIState = windowUIState
        content
            .sheet(item: $windowUIState.propertiesItem) { item in
                FilePropertiesSheet(item: item, appState: appState)
            }
            .sheet(isPresented: $windowUIState.showHelpSheet) {
                HelpSheet(appState: appState)
            }
            .sheet(isPresented: $windowUIState.showFeedbackSheet) {
                FeedbackSheetView(appState: appState)
            }
            .sheet(isPresented: $windowUIState.showAboutSheet) {
                AboutSheet(appState: appState)
            }
            .sheet(isPresented: $windowUIState.showSettingsSheet) {
                SettingsView(appState: appState)
            }
            .sheet(isPresented: $windowUIState.showAutoOrganizationSheet) {
                AutoOrganizationSheet(appState: appState)
            }
            .sheet(isPresented: $windowUIState.showDuplicateCleanerSheet) {
                DuplicateCleanerSheetView(appState: appState)
            }
            .sheet(isPresented: $windowUIState.showHttpShareSheet) {
                if let url = windowUIState.httpShareFolderURL {
                    HttpShareSheet(appState: appState, folderURL: url)
                }
            }
            .modifier(WilesModalSheetsSecondary(appState: appState, windowUIState: windowUIState))
            .modifier(WilesModalAlerts(appState: appState, windowUIState: windowUIState))
    }
}
