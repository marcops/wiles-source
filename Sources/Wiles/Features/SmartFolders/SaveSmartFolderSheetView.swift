import AppKit
import SwiftUI

struct SaveSmartFolderSheetView: View {
    var appState: AppState
    @Environment(\.dismiss)
    private var dismiss
    @State private var folderName: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Text(appState.tr(.saveAsSmartFolder))
                .font(.headline)

            TextField(appState.tr(.smartFolderName), text: $folderName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)

            HStack {
                Button(appState.tr(.cancel)) {
                    dismiss()
                }
                Spacer()
                Button(appState.tr(.saveSearch)) {
                    guard !folderName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    let folder = SmartFolder(
                        name: folderName,
                        icon: "folder.badge.gearshape",
                        searchQuery: appState.searchQuery,
                        scopePath: appState.navigation.currentURL.path)
                    appState.addSmartFolder(folder)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(folderName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
}
