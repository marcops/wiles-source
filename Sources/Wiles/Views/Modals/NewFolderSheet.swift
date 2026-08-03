import SwiftUI

struct NewFolderSheet: View {
    var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        SingleInputSheetView(
            title: appState.tr(.createNewFolder),
            iconName: "folder.badge.plus",
            initialValue: appState.tr(.defaultFolderName),
            actionButtonTitle: appState.tr(.create),
            cancelTitle: appState.tr(.cancel),
            onCancel: {
                dismiss()
            },
            onSubmit: { name in
                createFolder(name: name)
            }
        )
    }
    
    private func createFolder(name: String) {
        do {
            try FileSystemService.createDirectory(at: appState.currentURL, name: name)
            appState.refreshCurrentDirectory()
            dismiss()
        } catch {
            appState.showError(error.localizedDescription)
            dismiss()
        }
    }
}
