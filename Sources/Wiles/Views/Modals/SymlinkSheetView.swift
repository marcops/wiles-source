import SwiftUI

public struct SymlinkSheetView: View {
    let item: FileItem
    var appState: AppState

    @Environment(\.dismiss)
    private var dismiss
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
            Text(appState.tr(.createSymbolicLink))
                .font(.system(size: 15, weight: .bold))
        }
    }

    private var modePickerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(appState.tr(.linkType))
                .font(.subheadline)
                .foregroundColor(.secondary)
            Picker("", selection: $mode) {
                ForEach(SymlinkMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var nameInputSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(appState.tr(.symlinkNameLabel))
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

            Button(appState.tr(.createLink)) { createSymlink() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
                .disabled(symlinkName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func createSymlink() {
        do {
            let createdURL = try SymlinkService.createSymlink(
                targetURL: item.url,
                destinationFolder: appState.navigation.currentURL,
                symlinkName: symlinkName,
                mode: mode
            )
            appState.refreshCurrentDirectory()
            appState.selectedURLs = [createdURL]
            dismiss()
        } catch {
            appState.showError(error.localizedDescription)
            dismiss()
        }
    }
}
