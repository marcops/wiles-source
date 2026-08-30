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
            scopePath: Self.resolvedScopePath(
                currentURL: appState.navigation.currentURL,
                isSmartFolderActive: appState.smartFolder.activeFolderID != nil))
        appState.addSmartFolder(folder)
        dismiss()
    }

    /// The directory to scope the saved smart folder's query to. A virtual location (Recents, any
    /// `wiles://` URL) or an active smart-folder view has no real directory to scope to, so this
    /// returns `""` — `SmartFolderService.executeQuery` reads an empty scope as "search from the
    /// user's home folder". A real directory passes through unchanged.
    static func resolvedScopePath(currentURL: URL, isSmartFolderActive: Bool) -> String {
        guard !isSmartFolderActive, !isVirtualLocation(currentURL) else { return "" }
        return currentURL.path
    }

    private static func isVirtualLocation(_ url: URL) -> Bool {
        let std = url.standardizedFileURL
        return std == AppState.recentsVirtualURL || std.scheme == "wiles"
    }
}
