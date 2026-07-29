import SwiftUI

struct RenameSheetView: View {
    let item: FileItem
    var appState: AppState
    
    @Environment(\.dismiss) private var dismiss
    @State private var newName: String = ""
    @FocusState private var isFocused: Bool
    
    private var cleanTitle: String {
        appState.tr(.rename).replacingOccurrences(of: "...", with: "")
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text(cleanTitle)
                .font(.system(size: 15, weight: .bold))
            
            TextField("", text: $newName)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit {
                    submitRename()
                }
            
            HStack(spacing: 12) {
                Spacer()
                Button(appState.tr(.cancel)) {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                Button(cleanTitle) {
                    submitRename()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(20)
        .frame(width: 340)
        .onAppear {
            newName = item.name
            isFocused = true
        }
    }
    
    private func submitRename() {
        appState.performRename(item: item, newName: newName)
        dismiss()
    }
}
