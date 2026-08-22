import AppKit
import SwiftUI

struct SaveSmartFolderSheetView: View {
    var appState: AppState
    @Environment(\.dismiss)
    private var dismiss
    @State private var folderName: String = ""

    var body: some View {
        ModalScaffoldView(
            icon: .symbol("folder.badge.gearshape"),
            title: appState.tr(.saveAsSmartFolder),
            width: 300,
            primaryButton: ModalFooterButton(
                title: appState.tr(.saveSearch),
                isEnabled: !folderName.trimmingCharacters(in: .whitespaces).isEmpty) {
                    saveSmartFolder()
                },
            secondaryButton: ModalFooterButton(title: appState.tr(.cancel)) { dismiss() },
            content: { nameField })
    }

    private var nameField: some View {
        TextField(appState.tr(.smartFolderName), text: $folderName)
            .textFieldStyle(.roundedBorder)
            .padding(20)
    }

    private func saveSmartFolder() {
        guard !folderName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let folder = SmartFolder(
            name: folderName,
            icon: "folder.badge.gearshape",
            searchQuery: appState.selection.searchQuery,
            scopePath: appState.navigation.currentURL.path)
        appState.addSmartFolder(folder)
        dismiss()
    }
}
