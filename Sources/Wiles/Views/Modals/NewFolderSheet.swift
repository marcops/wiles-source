import SwiftUI

struct NewFolderSheet: View {
    var appState: AppState
    @State private var folderName: String = "New Folder"
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create New Folder").font(.system(size: 15, weight: .bold))
            TextField("Folder Name", text: $folderName)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit { createFolder() }
            
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Create") { createFolder() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20).frame(width: 300)
        .onAppear {
            isFocused = true
            folderName = "New Folder"
        }
    }
    
    private func createFolder() {
        let name = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        do {
            try FileSystemService.createDirectory(at: appState.currentURL, name: name)
            appState.refreshCurrentDirectory()
            dismiss()
        } catch {
            print("Failed to create folder: \(error)")
        }
    }
}
