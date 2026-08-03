import SwiftUI

struct RenameSheetView: View {
    let item: FileItem
    var appState: AppState
    @Environment(\.dismiss)
    private var dismiss

    private var cleanTitle: String {
        appState.tr(.rename).replacingOccurrences(of: "...", with: "")
    }

    var body: some View {
        SingleInputSheetView(
            title: cleanTitle,
            iconName: "pencil.line",
            initialValue: item.name,
            actionButtonTitle: cleanTitle,
            cancelTitle: appState.tr(.cancel),
            onCancel: {
                dismiss()
            },
            onSubmit: { newName in
                appState.performRename(item: item, newName: newName)
                dismiss()
            }
        )
    }
}
