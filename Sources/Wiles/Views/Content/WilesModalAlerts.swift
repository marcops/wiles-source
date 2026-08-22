import SwiftUI

/// The window's confirmation/error alerts — split out of `WilesModalSheets` purely to keep that
/// modifier's `body(content:)` under this project's ~40-line function-body-length limit (pure code
/// motion, no behavior change).
struct WilesModalAlerts: ViewModifier {
    let appState: AppState
    let windowUIState: WindowUIState

    func body(content: Content) -> some View {
        @Bindable var appState = appState
        @Bindable var windowUIState = windowUIState
        content
            .alert(appState.tr(.emptyTrash) + "?", isPresented: $windowUIState.showEmptyTrashAlert) {
                Button(appState.tr(.emptyTrash)) {
                    appState.performEmptyTrash()
                }
                .keyboardShortcut(.defaultAction)
                Button(appState.tr(.cancel), role: .cancel) { }
            } message: {
                Text(appState.tr(.emptyTrashConfirm))
            }
            .alert(appState.tr(.moveToTrash) + "?", isPresented: $windowUIState.showDeleteConfirmAlert) {
                Button(appState.tr(.moveToTrash)) {
                    appState.performDeleteSelected()
                }
                .keyboardShortcut(.defaultAction)
                Button(appState.tr(.cancel), role: .cancel) { }
            } message: {
                Text(appState.tr(.moveToTrashConfirm))
            }
            .alert(appState.tr(.errorAlertTitle), isPresented: $appState.modal.showErrorAlert) {
                Button(appState.tr(.errorAlertOKButton), role: .cancel) { }
            } message: {
                Text(appState.modal.errorMessage ?? appState.tr(.errorAlertGenericMessage))
            }
    }
}
