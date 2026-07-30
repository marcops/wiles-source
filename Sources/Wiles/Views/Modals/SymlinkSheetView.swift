import SwiftUI

public struct SymlinkSheetView: View {
    let item: FileItem
    var appState: AppState
    
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool
    
    @State private var symlinkName: String = ""
    @State private var mode: SymlinkMode = .absolute
    
    public init(item: FileItem, appState: AppState) {
        self.item = item
        self.appState = appState
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection
            modePickerSection
            nameInputSection
            actionButtonsSection
        }
        .padding(20)
        .frame(width: 380)
        .onAppear {
            symlinkName = item.name + " link"
            isNameFocused = true
        }
    }
    
    private var headerSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
            Text("Create Symbolic Link")
                .font(.system(size: 15, weight: .bold))
        }
    }
    
    private var modePickerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Link Type")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Picker("", selection: $mode) {
                ForEach(SymlinkMode.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var nameInputSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Symlink Name")
                .font(.subheadline)
                .foregroundColor(.secondary)
            TextField("", text: $symlinkName)
                .textFieldStyle(.roundedBorder)
                .focused($isNameFocused)
                .onSubmit { createSymlink() }
        }
    }
    
    private var actionButtonsSection: some View {
        HStack {
            Spacer()
            Button(appState.tr(.cancel)) { dismiss() }
                .keyboardShortcut(.escape, modifiers: [])
            
            Button("Create Link") { createSymlink() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
                .disabled(symlinkName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
    
    private func createSymlink() {
        do {
            let createdURL = try SymlinkService.createSymlink(
                targetURL: item.url,
                destinationFolder: appState.currentURL,
                symlinkName: symlinkName,
                mode: mode
            )
            appState.refreshCurrentDirectory()
            appState.selectedURLs = [createdURL]
            dismiss()
        } catch {
            print("Failed to create symlink: \(error)")
        }
    }
}
